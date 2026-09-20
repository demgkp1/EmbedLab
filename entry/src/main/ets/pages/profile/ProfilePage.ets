import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { RouteConstants } from '../../constants/RouteConstants';
import { AppStorageKeys } from '../../constants/AppStorageKeys';
import { UIStatus } from '../../models/common/UIStatus';
import { ProfileViewModel } from '../../viewmodels/ProfileViewModel';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'ProfilePage';

/** 本页在根 Tabs 中的下标（UI-Batch-1 后为 3 个 Tab：Home=0 / Learn=1 / Profile=2） */
const PROFILE_TAB_INDEX: number = 2;

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
/**
 * 学习概览卡（ProfilePage 的独立子组件）。
 *
 * 职责：渲染「学习概览」标题与两项指标（收藏数 / 已读数）。
 * 数据来源：父组件 ProfilePage 经 `@Prop` 单向传入 favCount / histCount。
 * 布局：标题与两项指标整体水平居中（承接 Profile-R1 方案 C），内边距 / 圆角 /
 *      配色与初版一致。
 *
 * ⚠️ 维护约束（踩坑登记，详见 BACKLOG「带参 @Builder 不跟随状态变化」条）：
 *      本组件内**严禁**用带参 @Builder（如 `overviewMetric(label, value, ...)`）
 *      渲染需要跟随状态变化的数值 —— 实测其**参数虽已更新，builder 体不会以
 *      新参数重新执行**，界面将停留在旧值。数值必须**内联直读 @Prop**。
 */
@Component
struct ProfileOverviewCard {
  /** 收藏数（由 ProfilePage 的 @State favCount 单向同步） */
  @Prop favCount: number = 0;
  /** 已读数（由 ProfilePage 的 @State histCount 单向同步） */
  @Prop histCount: number = 0;

  build() {
    Column({ space: AppDimens.SPACING_MD }) {
      Text(AppStrings.PROFILE_OVERVIEW_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
        .textAlign(TextAlign.Center)

      Row({ space: AppDimens.SPACING_XL }) {
        // 收藏指标（内联：直接读 @Prop，不经 @Builder）
        Column({ space: AppDimens.SPACING_XS }) {
          Text(`${this.favCount}`)
            .fontSize(AppDimens.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.FAVORITE_ACTIVE)
          Text(AppStrings.PROFILE_OVERVIEW_FAVORITES)
            .fontSize(AppDimens.FONT_SIZE_CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        // 已读指标（内联：直接读 @Prop，不经 @Builder）
        Column({ space: AppDimens.SPACING_XS }) {
          Text(`${this.histCount}`)
            .fontSize(AppDimens.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.PRIMARY)
          Text(AppStrings.PROFILE_OVERVIEW_HISTORY)
            .fontSize(AppDimens.FONT_SIZE_CAPTION)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding(AppDimens.SPACING_LG)
    .margin({ left: AppDimens.SPACING_LG, right: AppDimens.SPACING_LG })
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
  }
}

@Component
export struct ProfilePage {
  /** 页面级 ViewModel（保留：概览卡计数与数据装配均依赖它） */
  @State viewModel: ProfileViewModel = new ProfileViewModel();

  /**
   * 概览卡收藏数。
   *
   * 设计说明：计数以**页面自身的 @State 基本类型**持有，而非直接读
   *      `viewModel.favoriteItems.length`。
   *      原因：@State 不深层监听类实例的内部属性，读 ViewModel 字段无法保证
   *      在装配完成后驱动重绘；而基本类型的赋值可被 @State 可靠观察到。
   *      这是本工程已验证有效的范式（参见 LearnPage 的 favoriteIds 快照）。
   * 约束：本字段是只读快照，**唯一写点是 syncCounts()**，严禁在 build() 内写入。
   */
  @State favCount: number = 0;

  /** 概览卡已读数（同 favCount 机理，见上）。 */
  @State histCount: number = 0;

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

  /**
   * 把 ViewModel 的最新计数同步为页面自身的 @State 快照。
   *
   * 约束：
   *  - **唯一写点**：favCount / histCount 只在此处赋值，便于审计与排障；
   *  - 必须在 `refreshFromStore()` **之后**调用，否则快照的是旧数组长度；
   *  - 须由各刷新入口（2 个 @Watch + onRootTabChanged + onPageShow +
   *    loadItems 完成回调）统一调用；严禁在 build() 内调用（红线：build() 内禁写状态）。
   */
  private syncCounts(): void {
    this.favCount = this.viewModel.favoriteItems.length;
    this.histCount = this.viewModel.historyItems.length;
  }

  /** 收藏版本变化：依据 UserStore 最新状态重算概览计数并驱动重绘。 */
  onFavoritesChanged(): void {
    this.viewModel.refreshFromStore();
    this.syncCounts();
    Logger.debug(MODULE_TAG, `favorites changed, count=${this.favCount}`);
  }

  /** 历史版本变化：依据 UserStore 最新状态重算概览计数并驱动重绘。 */
  onHistoryChanged(): void {
    this.viewModel.refreshFromStore();
    this.syncCounts();
    Logger.debug(MODULE_TAG, `history changed, count=${this.histCount}`);
  }

  /**
   * Tab 切换回调：仅当切回本页（Profile）时按 UserStore 最新状态重算概览计数。
   * 说明：仅重算、不重取元数据（复用 metadataPool），避免无谓的 Repository 调用。
   */
  onRootTabChanged(): void {
    if (this.rootTabIndex === PROFILE_TAB_INDEX) {
      this.viewModel.refreshFromStore();
      this.syncCounts();
      Logger.debug(MODULE_TAG, 'refresh on tab activated');
    }
  }

  /**
   * 从其他页面返回本页时触发：仅依据 UserStore 最新状态重算概览计数（不重复请求元数据）。
   */
  onPageShow(): void {
    this.viewModel.refreshFromStore();
    this.syncCounts();
  }

  /** 首次加载：一次性批量取元数据并装配。 */
  private loadItems(): void {
    this.viewModel.loadDisplayItems().then(() => {
      this.syncCounts();
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
    // 【ArkTS 结构约束备忘】
    //  1. build() 的**第一条语句必须且只能是容器组件** —— 任何前置语句
    //     （含 Logger 调用）都会触发 ArkTS 10905210 并中断构建。
    //  2. @Builder 是 UI DSL，内**禁止任何非 UI 语句**（ArkTS 10905204）。
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

      // 概览卡：常驻节点树（非条件渲染），由 visibility 控制显隐 ——
      // 使 @Prop 的更新不受 if/else 分支缓存影响。
      // 显隐语义：uiStatus === SUCCESS 时可见；LOADING / ERROR 时隐藏。
      //   ProfileViewModel 的 uiStatus 仅有 LOADING / SUCCESS / ERROR 三种赋值
      //   （永不进入 EMPTY），故本条件与「非 LOADING 且非 ERROR」等价。
      ProfileOverviewCard({ favCount: this.favCount, histCount: this.histCount })
        .visibility(this.viewModel.uiStatus === UIStatus.SUCCESS
          ? Visibility.Visible : Visibility.None)

      if (this.viewModel.uiStatus === UIStatus.LOADING) {
        this.stateHint(AppStrings.PROFILE_LOADING, '')
      } else if (this.viewModel.uiStatus === UIStatus.ERROR) {
        this.errorState()
      } else {
        this.entryList()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
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
