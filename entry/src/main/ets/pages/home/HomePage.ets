import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { RouteConstants } from '../../constants/RouteConstants';
import { AppStorageKeys } from '../../constants/AppStorageKeys';
import { UIStatus } from '../../models/common/UIStatus';
import { KnowledgeMetadata } from '../../models/knowledge/KnowledgeMetadata';
import { KnowledgeDetailParams } from '../../models/knowledge/KnowledgeDetailParams';
import { HomeViewModel } from '../../viewmodels/HomeViewModel';
import { KnowledgeCard } from '../learn/components/KnowledgeCard';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'HomePage';

/** 本页在根 Tabs 中的下标（Home=0 / Learn=1 / Projects=2 / Practice=3 / Profile=4） */
const HOME_TAB_INDEX: number = 0;
/** 快捷入口目标下标：学习 / 我的 */
const LEARN_TAB_INDEX: number = 1;
const PROFILE_TAB_INDEX: number = 4;

/**
 * 首页（Milestone B：学习概览入口）。
 *
 * 职责：
 *  - 持有 HomeViewModel，在 aboutToAppear 触发一次元数据装配；
 *  - 渲染三个区块：最近阅读（前 3 条）/ 收藏概览（计数 + 前 3 条）/ 快捷入口；
 *  - 卡片点击经根 NavPathStack 跳转知识详情；快捷入口切换根 Tabs 到学习 / 我的。
 * 分层约束：
 *  - 本页严禁遍历 ID 调 Repository（聚合在 HomeViewModel 内完成）。
 *  - 本页严禁直接访问 rawfile / Preferences。
 *  - 严禁在 build() 内修改任何状态变量。
 * 响应式说明（与 ProfilePage 完全同构）：
 *  - 收藏 / 足迹变化由 UserStore 递增 AppStorage 版本号驱动，本页以 @StorageLink + @Watch 接收；
 *  - 切回本 Tab 时由 @Consume('rootTabIndex') + @Watch 触发一次「仅重算、不重取」的刷新。
 * 跨 Tab 切换说明（快捷入口）：
 *  - 根 Tabs 的下标由 RootTabContainer 经 @Provide('rootTabIndex') 提供，本页 @Consume 后写入
 *    即可双向同步回祖先（官方 @Provide/@Consume 为双向数据同步），无需新增任何机制。
 */
@Component
export struct HomePage {
  /** 页面级 ViewModel */
  @State viewModel: HomeViewModel = new HomeViewModel();

  /** 重绘哨兵：@State 不深层监听类实例内部属性，装配完成后翻转以强制驱动 build()。 */
  @State refreshFlag: boolean = false;

  /** 根 Tabs 当前下标（@Provide/@Consume 双向同步；本页也用它作为快捷入口的写入通道） */
  @Consume('rootTabIndex') @Watch('onRootTabChanged') rootTabIndex: number;

  /** 收藏版本号（状态驱动刷新，机理与 ProfilePage 一致） */
  @StorageLink(AppStorageKeys.FAVORITES_VERSION)
  @Watch('onFavoritesChanged')
  favoritesVersion: number = 0;

  /** 阅读历史版本号（状态驱动刷新） */
  @StorageLink(AppStorageKeys.HISTORY_VERSION)
  @Watch('onHistoryChanged')
  historyVersion: number = 0;

  aboutToAppear(): void {
    this.loadItems();
  }

  /** 从其他页面返回本页时触发：仅重算、不重取元数据。 */
  onPageShow(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
  }

  /** 收藏版本变化：收藏数与前 3 条即时同步。 */
  onFavoritesChanged(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
    Logger.debug(MODULE_TAG, `favorites changed, count=${this.viewModel.favoriteCount}`);
  }

  /** 历史版本变化：最近阅读即时同步。 */
  onHistoryChanged(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
    Logger.debug(MODULE_TAG, `history changed, recent=${this.viewModel.recentHistory.length}`);
  }

  /** Tab 切换回调：仅当切回首页时按 UserStore 最新状态重算。 */
  onRootTabChanged(): void {
    if (this.rootTabIndex === HOME_TAB_INDEX) {
      this.viewModel.refreshFromStore();
      this.refreshFlag = !this.refreshFlag;
      Logger.debug(MODULE_TAG, 'refresh on tab activated');
    }
  }

  /** 首次加载：一次性批量取元数据并装配。 */
  private loadItems(): void {
    this.viewModel.loadDisplayItems().then(() => {
      this.refreshFlag = !this.refreshFlag;
    });
  }

  /** 卡片点击：跳转知识详情。 */
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

  /** 快捷入口：切换根 Tabs 到指定下标（经 @Consume 双向同步回祖先）。 */
  private switchTab(index: number): void {
    this.rootTabIndex = index;
    Logger.info(MODULE_TAG, `quick entry: switch tab to ${index}`);
  }

  build() {
    Column() {
      this.welcomeHeader()

      if (this.viewModel.uiStatus === UIStatus.LOADING) {
        this.stateHint(AppStrings.PROFILE_LOADING, '')
      } else if (this.viewModel.uiStatus === UIStatus.ERROR) {
        this.errorState()
      } else {
        this.overviewContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
  }

  /** 顶部欢迎语（固定，不随滚动）。 */
  @Builder
  welcomeHeader() {
    Column({ space: AppDimens.SPACING_XS }) {
      Text(AppStrings.TAB_HOME)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
      Text(AppStrings.HOME_WELCOME_DESC)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: AppDimens.SPACING_LG,
      right: AppDimens.SPACING_LG,
      top: AppDimens.SPACING_LG,
      bottom: AppDimens.SPACING_SM
    })
  }

  /** 概览主体：三区块纵向滚动。 */
  @Builder
  overviewContent() {
    Scroll() {
      Column({ space: AppDimens.SPACING_LG }) {
        this.recentHistorySection()
        this.favoritesSection()
        this.quickEntrySection()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: AppDimens.SPACING_LG,
        right: AppDimens.SPACING_LG,
        bottom: AppDimens.SPACING_LG
      })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
    .width('100%')
    .layoutWeight(1)
  }

  /** 区块 1：最近阅读（最多 3 条）。 */
  @Builder
  recentHistorySection() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.HOME_RECENT_HISTORY_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')

      if (this.viewModel.recentHistory.length === 0) {
        this.sectionEmptyHint(AppStrings.HOME_EMPTY_HISTORY)
      } else {
        ForEach(this.viewModel.recentHistory, (item: KnowledgeMetadata) => {
          Column() {
            KnowledgeCard({
              item: HomePage.cloneMeta(item),
              onClickItem: (id: string) => {
                this.openDetailById(id);
              }
            })
          }
          .width('100%')
        }, (item: KnowledgeMetadata) => `home-hist-${item.id}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 区块 2：收藏概览（计数 + 最多 3 条）。 */
  @Builder
  favoritesSection() {
    Column({ space: AppDimens.SPACING_SM }) {
      Row({ space: AppDimens.SPACING_SM }) {
        Text(AppStrings.HOME_FAVORITES_TITLE)
          .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
        Text(AppStrings.HOME_FAVORITES_COUNT + `${this.viewModel.favoriteCount}`)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.FAVORITE_ACTIVE)
      }
      .width('100%')

      if (this.viewModel.recentFavorites.length === 0) {
        this.sectionEmptyHint(AppStrings.HOME_EMPTY_FAVORITES)
      } else {
        ForEach(this.viewModel.recentFavorites, (item: KnowledgeMetadata) => {
          Column() {
            KnowledgeCard({
              item: HomePage.cloneMeta(item),
              onClickItem: (id: string) => {
                this.openDetailById(id);
              }
            })
          }
          .width('100%')
        }, (item: KnowledgeMetadata) => `home-fav-${item.id}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 区块 3：快捷入口（去学习 / 我的收藏）。 */
  @Builder
  quickEntrySection() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.HOME_QUICK_ENTRY)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')

      Row({ space: AppDimens.SPACING_MD }) {
        Button(AppStrings.TAB_LEARN)
          .fontSize(AppDimens.FONT_SIZE_BODY)
          .backgroundColor(AppColors.PRIMARY)
          .layoutWeight(1)
          .onClick(() => {
            this.switchTab(LEARN_TAB_INDEX);
          })
        Button(AppStrings.PROFILE_TAB_FAVORITES)
          .fontSize(AppDimens.FONT_SIZE_BODY)
          .backgroundColor(AppColors.SURFACE)
          .fontColor(AppColors.PRIMARY)
          .layoutWeight(1)
          .onClick(() => {
            this.switchTab(PROFILE_TAB_INDEX);
          })
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 区块内空态引导（非整页空态）。 */
  @Builder
  sectionEmptyHint(message: string) {
    Text(message)
      .fontSize(AppDimens.FONT_SIZE_BODY)
      .fontColor(AppColors.TEXT_TERTIARY)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding(AppDimens.SPACING_LG)
      .backgroundColor(AppColors.SURFACE)
      .borderRadius(AppDimens.RADIUS_MD)
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

  /** 按 id 跳转（卡片回调仅上抛 id，标题在装配实体中二次查找）。 */
  private openDetailById(id: string): void {
    const matched: KnowledgeMetadata | null = HomePage.findById(id, this.viewModel.recentHistory,
      this.viewModel.recentFavorites);
    if (matched === null) {
      Logger.warn(MODULE_TAG, `open detail skipped: metadata not found for id=${id}`);
      return;
    }
    this.openKnowledgeDetail(matched);
  }

  /** 在两个展示数组中按 id 查找元数据。 */
  private static findById(id: string, first: KnowledgeMetadata[],
    second: KnowledgeMetadata[]): KnowledgeMetadata | null {
    for (let index: number = 0; index < first.length; index++) {
      if (first[index].id === id) {
        return first[index];
      }
    }
    for (let index: number = 0; index < second.length; index++) {
      if (second[index].id === id) {
        return second[index];
      }
    }
    return null;
  }

  /**
   * 复制元数据为全新对象后再传入 @Prop。
   * 说明：@Prop 对 class/Object 类型会做深拷贝并仅观察第一层，传入池内共享对象虽可行，
   *      但显式复制可确保不同区块、不同页面的卡片实例互不共享引用。
   */
  private static cloneMeta(item: KnowledgeMetadata): KnowledgeMetadata {
    const copy: KnowledgeMetadata = {
      id: item.id,
      title: item.title,
      category: item.category,
      level: item.level,
      tags: [...item.tags],
      summary: item.summary
    };
    return copy;
  }
}
