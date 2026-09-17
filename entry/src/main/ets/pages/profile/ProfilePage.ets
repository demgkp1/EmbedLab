import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { RouteConstants } from '../../constants/RouteConstants';
import { AppStorageKeys } from '../../constants/AppStorageKeys';
import { UIStatus } from '../../models/common/UIStatus';
import { KnowledgeMetadata } from '../../models/knowledge/KnowledgeMetadata';
import { KnowledgeDetailParams } from '../../models/knowledge/KnowledgeDetailParams';
import { ProfileViewModel } from '../../viewmodels/ProfileViewModel';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'ProfilePage';

/** 本页在根 Tabs 中的下标（Home=0 / Learn=1 / Projects=2 / Practice=3 / Profile=4） */
const PROFILE_TAB_INDEX: number = 4;

/**
 * 「我的」页（V1：收藏列表 + 阅读历史）。
 *
 * 职责：
 *  - 持有 ProfileViewModel，在 aboutToAppear 触发一次元数据装配；
 *  - 以双 Tab 切换展示收藏 / 历史，各含空态与列表；
 *  - 列表项点击经根 NavPathStack 跳转知识详情。
 * 分层约束：
 *  - 本页严禁遍历 ID 调 Repository（聚合在 ProfileViewModel 内完成）。
 *  - 本页严禁直接访问 rawfile / Preferences。
 *  - 严禁在 build() 内修改任何状态变量。
 * 响应式说明：
 *  - UserStore 为 @Observed 单例，ProfileViewModel 在每次装配时重新读取其最新数组；
 *  - 从详情页返回本页时由 onPageShow 触发一次「仅重算、不重取」的刷新，
 *    以规避 @State 不深层监听类实例内部属性的已知问题。
 */
@Component
export struct ProfilePage {
  /** 页面级 ViewModel */
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
   *      与触发场景无关，可覆盖「从 Profile 收藏列表进详情后取消收藏并返回」这一路径。
   * 约束：key 取自 AppStorageKeys 常量，禁止硬编码；@StorageLink 必须带 @Watch。
   */
  @StorageLink(AppStorageKeys.FAVORITES_VERSION)
  @Watch('onFavoritesChanged')
  favoritesVersion: number = 0;

  /**
   * 阅读历史版本号（状态驱动刷新，Milestone 3.4-fix3）。
   * 机理同收藏版本号：history 变化即驱动历史列表刷新。
   */
  @StorageLink(AppStorageKeys.HISTORY_VERSION)
  @Watch('onHistoryChanged')
  historyVersion: number = 0;

  aboutToAppear(): void {
    this.loadItems();
  }

  /** 收藏版本变化：依据 UserStore 最新状态重算展示数组并驱动重绘。 */
  onFavoritesChanged(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
    Logger.debug(MODULE_TAG, `favorites changed, list refreshed: count=${this.viewModel.favoriteItems.length}`);
  }

  /** 历史版本变化：依据 UserStore 最新状态重算展示数组并驱动重绘。 */
  onHistoryChanged(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
    Logger.debug(MODULE_TAG, `history changed, list refreshed: count=${this.viewModel.historyItems.length}`);
  }

  /**
   * Tab 切换回调：仅当切回本页（Profile）时按 UserStore 最新状态重算展示数组。
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
   * 从其他页面返回本页时触发：仅依据 UserStore 最新状态重算展示数组（不重复请求元数据），
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

  /** 列表项点击：跳转知识详情。 */
  private openKnowledgeDetail(item: KnowledgeMetadata): void {
    const params: KnowledgeDetailParams = { id: item.id, title: item.title };
    const stack: NavPathStack | undefined = this.queryNavigationInfo()?.pathStack;
    if (stack === undefined) {
      Logger.error(MODULE_TAG, `push skipped: root stack unavailable, id=${item.id}`);
      return;
    }
    stack.pushPathByName(RouteConstants.KNOWLEDGE_DETAIL, params);
    Logger.info(MODULE_TAG, `push ${RouteConstants.KNOWLEDGE_DETAIL} id=${item.id}`);
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
        this.tabBar()
        if (this.viewModel.isEmpty()) {
          this.emptyState()
        } else {
          this.itemList()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
  }

  /** 形态切换：收藏 / 历史。 */
  @Builder
  tabBar() {
    Row({ space: AppDimens.SPACING_SM }) {
      this.tabPill(0, AppStrings.PROFILE_TAB_FAVORITES)
      this.tabPill(1, AppStrings.PROFILE_TAB_HISTORY)
    }
    .width('100%')
    .padding({
      left: AppDimens.SPACING_LG,
      right: AppDimens.SPACING_LG,
      bottom: AppDimens.SPACING_SM
    })
  }

  /** 单个形态胶囊。 */
  @Builder
  tabPill(tab: number, label: string) {
    Text(label)
      .fontSize(AppDimens.FONT_SIZE_BODY)
      .fontWeight(this.viewModel.selectedTab === tab ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.viewModel.selectedTab === tab ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
      .padding({
        left: AppDimens.SPACING_MD,
        right: AppDimens.SPACING_MD,
        top: AppDimens.SPACING_XS,
        bottom: AppDimens.SPACING_XS
      })
      .borderRadius(AppDimens.RADIUS_SM)
      .backgroundColor(this.viewModel.selectedTab === tab ? AppColors.PRIMARY_LIGHT : AppColors.SURFACE)
      .onClick(() => {
        this.viewModel.selectTab(tab);
      })
  }

  /** 展示列表（收藏或历史，取决于当前形态）。 */
  @Builder
  itemList() {
    List({ space: AppDimens.SPACING_MD }) {
      ForEach(this.viewModel.visibleItems(), (item: KnowledgeMetadata) => {
        ListItem() {
          this.itemRow(item)
        }
      }, (item: KnowledgeMetadata) => `profile-${this.viewModel.selectedTab}-${item.id}`)
    }
    .width('100%')
    .layoutWeight(1)
    .listDirection(Axis.Vertical)
    .scrollBar(BarState.Auto)
    .padding({ left: AppDimens.SPACING_LG, right: AppDimens.SPACING_LG, bottom: AppDimens.SPACING_LG })
  }

  /** 单条展示项（轻量卡片，避免与 Learn 的 KnowledgeCard 视觉重复）。 */
  @Builder
  itemRow(item: KnowledgeMetadata) {
    Row({ space: AppDimens.SPACING_SM }) {
      Column({ space: AppDimens.SPACING_XS }) {
        Text(item.title)
          .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(item.category)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TEXT_SECONDARY)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(item.level)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(AppColors.PRIMARY)
        .backgroundColor(AppColors.PRIMARY_LIGHT)
        .padding({
          left: AppDimens.SPACING_SM,
          right: AppDimens.SPACING_SM,
          top: AppDimens.SPACING_XS,
          bottom: AppDimens.SPACING_XS
        })
        .borderRadius(AppDimens.RADIUS_SM)
    }
    .width('100%')
    .padding(AppDimens.SPACING_LG)
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
    .onClick(() => {
      this.openKnowledgeDetail(item);
    })
  }

  /** 空态：按当前形态给出对应提示。 */
  @Builder
  emptyState() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(this.viewModel.selectedTab === 1 ? AppStrings.PROFILE_EMPTY_HISTORY_TITLE : AppStrings.PROFILE_EMPTY_FAVORITES_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      Text(this.viewModel.selectedTab === 1 ? AppStrings.PROFILE_EMPTY_HISTORY_DESC : AppStrings.PROFILE_EMPTY_FAVORITES_DESC)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
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

  /** 错误态：提示 + 错误码 + 重试。 */
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
