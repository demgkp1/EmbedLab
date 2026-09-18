import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { RouteConstants } from '../../constants/RouteConstants';
import { AppStorageKeys } from '../../constants/AppStorageKeys';
import { UIStatus } from '../../models/common/UIStatus';
import { ProfileViewModel } from '../../viewmodels/ProfileViewModel';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'ProfilePage';

/** 本页在根 Tabs 中的下标（Home=0 / Learn=1 / Projects=2 / Practice=3 / Profile=4） */
const PROFILE_TAB_INDEX: number = 4;

/**
 * 「我的」页（Profile-R 重构版：顶部学习概览卡 + 二级入口列表）。
 *
 * 职责：
 *  - 持有 ProfileViewModel，在 aboutToAppear 触发一次元数据装配（仅用于概览卡计数）；
 *  - 顶部展示「学习概览」卡：收藏数 / 已读数；
 *  - 下方为二级入口列表：我的收藏 / 阅读历史 / 设置 / 关于，点击经根 NavPathStack push。
 * 变更说明（Profile-R）：
 *  - 原「收藏 / 历史双 Tab + 页内列表」已拆分到 FavoritesPage / HistoryPage 两个二级页；
 *  - 本页因此删除 tabBar() / tabPill()，以及页内 itemList / itemRow / emptyState；
 *  - 数据层调用（loadDisplayItems / refreshFromStore）**全部保留**，未删除任何数据逻辑。
 * 分层约束：
 *  - 本页严禁遍历 ID 调 Repository（聚合在 ProfileViewModel 内完成）。
 *  - 本页严禁直接访问 rawfile / Preferences / resourceManager，亦不直连 UserStore。
 *  - 严禁在 build() 内修改任何状态变量。
 *  - 严禁内嵌 Navigation / 新建 NavPathStack（全应用唯一根栈由 MainPage 持有）。
 * 响应式说明：
 *  - UserStore 为 @Observed 单例，ProfileViewModel 在每次装配时重新读取其最新数组；
 *  - 从详情页返回本页时由 onPageShow 触发一次「仅重算、不重取」的刷新；
 *  - 切回本 Tab 时由 @Consume('rootTabIndex') + @Watch 触发同语义刷新。
 */
@Component
export struct ProfilePage {
  /** 页面级 ViewModel（保留：概览卡计数与数据装配均依赖它） */
  @State viewModel: ProfileViewModel = new ProfileViewModel();

  /**
   * 重绘哨兵。
   * 说明：@State 不深层监听类实例内部属性，异步装配完成后翻转本布尔值强制驱动 build()。
   */
  @State refreshFlag: boolean = false;

  /**
   * 根 Tabs 当前下标（由 RootTabContainer 经 @Provide('rootTabIndex') 广播）。
   * 刷新机理：TabContent 切换**不会触发 onPageShow**，因此必须借助本变量 + @Watch
   *          在「切回本 Tab」的瞬间执行一次刷新，才能反映最新的收藏 / 历史。
   */
  @Consume('rootTabIndex') @Watch('onRootTabChanged') rootTabIndex: number;

  /**
   * 收藏版本号（状态驱动刷新，Milestone 3.4-fix3）。
   * 机理：UserStore 收藏变化 → AppStorage 版本号递增 → 本变量变化 → @Watch 触发刷新。
   * 约束：key 取自 AppStorageKeys 常量，禁止硬编码；@StorageLink 必须带 @Watch。
   */
  @StorageLink(AppStorageKeys.FAVORITES_VERSION)
  @Watch('onFavoritesChanged')
  favoritesVersion: number = 0;

  /**
   * 阅读历史版本号（状态驱动刷新，Milestone 3.4-fix3）。
   * 机理同收藏版本号：history 变化即驱动概览卡已读数刷新。
   */
  @StorageLink(AppStorageKeys.HISTORY_VERSION)
  @Watch('onHistoryChanged')
  historyVersion: number = 0;

  aboutToAppear(): void {
    this.loadItems();
  }

  /** 收藏版本变化：依据 UserStore 最新状态重算概览计数并驱动重绘。 */
  onFavoritesChanged(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
    Logger.debug(MODULE_TAG, `favorites changed, count=${this.viewModel.favoriteItems.length}`);
  }

  /** 历史版本变化：依据 UserStore 最新状态重算概览计数并驱动重绘。 */
  onHistoryChanged(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
    Logger.debug(MODULE_TAG, `history changed, count=${this.viewModel.historyItems.length}`);
  }

  /**
   * Tab 切换回调：仅当切回本页（Profile）时按 UserStore 最新状态重算概览计数。
   * 说明：仅重算、不重取元数据（复用 metadataPool），避免无谓的 Repository 调用。
   */
  onRootTabChanged(): void {
    if (this.rootTabIndex === PROFILE_TAB_INDEX) {
      this.viewModel.refreshFromStore();
      this.refreshFlag = !this.refreshFlag;
      Logger.debug(MODULE_TAG, 'refresh on tab activated');
    }
  }

  /**
   * 从其他页面返回本页时触发：仅依据 UserStore 最新状态重算概览计数（不重复请求元数据），
   * 随后翻转哨兵驱动重绘。这是跨页收藏联动的关键刷新点。
   */
  onPageShow(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
  }

  /** 首次加载：一次性批量取元数据并装配。 */
  private loadItems(): void {
    this.viewModel.loadDisplayItems().then(() => {
      this.refreshFlag = !this.refreshFlag;
    });
  }

  /**
   * 二级入口点击：经根 NavPathStack push 对应路由（四者均为无参路由，param 传 null）。
   * 取栈方式与 Profile 原实现一致：queryNavigationInfo()?.pathStack，严禁 new NavPathStack()。
   */
  private openRoute(routeName: string): void {
    const stack: NavPathStack | undefined = this.queryNavigationInfo()?.pathStack;
    if (stack === undefined) {
      Logger.error(MODULE_TAG, `push skipped: root stack unavailable, route=${routeName}`);
      return;
    }
    stack.pushPathByName(routeName, null);
    Logger.info(MODULE_TAG, `push ${routeName}`);
  }

  build() {
    Column() {
      // 顶部标题区
      Row() {
        Text(AppStrings.TAB_PROFILE)
          .fontSize(AppDimens.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
      }
      .width('100%')
      .padding({
        left: AppDimens.SPACING_LG,
        right: AppDimens.SPACING_LG,
        top: AppDimens.SPACING_LG,
        bottom: AppDimens.SPACING_SM
      })

      if (this.viewModel.uiStatus === UIStatus.LOADING) {
        this.stateHint(AppStrings.PROFILE_LOADING, '')
      } else if (this.viewModel.uiStatus === UIStatus.ERROR) {
        this.errorState()
      } else {
        this.overviewCard()
        this.entryList()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
  }

  /** 学习概览卡：收藏数 / 已读数（数据来自 ProfileViewModel，不直连 UserStore）。 */
  @Builder
  overviewCard() {
    Column({ space: AppDimens.SPACING_MD }) {
      Text(AppStrings.PROFILE_OVERVIEW_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')

      Row({ space: AppDimens.SPACING_XL }) {
        this.overviewMetric(AppStrings.PROFILE_OVERVIEW_FAVORITES,
          `${this.viewModel.favoriteItems.length}`, AppColors.FAVORITE_ACTIVE)
        this.overviewMetric(AppStrings.PROFILE_OVERVIEW_HISTORY,
          `${this.viewModel.historyItems.length}`, AppColors.PRIMARY)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppDimens.SPACING_LG)
    .margin({ left: AppDimens.SPACING_LG, right: AppDimens.SPACING_LG })
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
  }

  /** 单个概览指标：数值 + 标签。 */
  @Builder
  overviewMetric(label: string, value: string, accent: string) {
    Column({ space: AppDimens.SPACING_XS }) {
      Text(value)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(accent)
      Text(label)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(AppColors.TEXT_SECONDARY)
    }
    .alignItems(HorizontalAlign.Start)
  }

  /** 二级入口列表：4 行，统一经 entryRow 渲染。 */
  @Builder
  entryList() {
    Column({ space: AppDimens.SPACING_SM }) {
      this.entryRow(AppStrings.PROFILE_ENTRY_GLYPH_FAVORITES,
        AppStrings.PROFILE_ENTRY_FAVORITES, RouteConstants.PROFILE_FAVORITES)
      this.entryRow(AppStrings.PROFILE_ENTRY_GLYPH_HISTORY,
        AppStrings.PROFILE_ENTRY_HISTORY, RouteConstants.PROFILE_HISTORY)
      this.entryRow(AppStrings.PROFILE_ENTRY_GLYPH_SETTINGS,
        AppStrings.PROFILE_ENTRY_SETTINGS, RouteConstants.PROFILE_SETTINGS)
      this.entryRow(AppStrings.PROFILE_ENTRY_GLYPH_ABOUT,
        AppStrings.PROFILE_ENTRY_ABOUT, RouteConstants.PROFILE_ABOUT)
    }
    .width('100%')
    .padding({
      left: AppDimens.SPACING_LG,
      right: AppDimens.SPACING_LG,
      top: AppDimens.SPACING_LG,
      bottom: AppDimens.SPACING_LG
    })
  }

  /** 单条入口行：字形 + 文案 + 右箭头。 */
  @Builder
  entryRow(glyph: string, label: string, routeName: string) {
    Row({ space: AppDimens.SPACING_MD }) {
      Text(glyph)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.PRIMARY)

      Text(label)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.TEXT_PRIMARY)
        .layoutWeight(1)

      Text(AppStrings.PROFILE_ENTRY_ARROW)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_TERTIARY)
    }
    .width('100%')
    .padding(AppDimens.SPACING_LG)
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
    .onClick(() => {
      this.openRoute(routeName);
    })
  }

  /** 通用状态提示（LOADING）。 */
  @Builder
  stateHint(title: string, description: string) {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(title)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      if (description.length > 0) {
        Text(description)
          .fontSize(AppDimens.FONT_SIZE_BODY)
          .fontColor(AppColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
  }

  /** 错误态：提示 + 原因 + 重试。 */
  @Builder
  errorState() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.PROFILE_ERROR_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      Text(this.viewModel.lastErrorMessage)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(AppColors.TEXT_TERTIARY)
      Button(AppStrings.MSG_RETRY)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .backgroundColor(AppColors.PRIMARY)
        .onClick(() => {
          this.loadItems();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
  }
}
