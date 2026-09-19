import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { RouteConstants } from '../../constants/RouteConstants';
import { AppStorageKeys } from '../../constants/AppStorageKeys';
import { UIStatus } from '../../models/common/UIStatus';
import { KnowledgeMetadata } from '../../models/knowledge/KnowledgeMetadata';
import { KnowledgeDetailParams } from '../../models/knowledge/KnowledgeDetailParams';
import { LearnViewModel } from '../../viewmodels/LearnViewModel';
import { UserStore } from '../../stores/UserStore';
import { CategoryBar } from './components/CategoryBar';
import { KnowledgeCard } from './components/KnowledgeCard';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'LearnPage';

/**
 * 本页在根 Tabs 中的下标。
 * 说明：UI-Batch-1 后一级 Tab 由 5 个瘦身为 3 个，顺序为
 *      首页(Home)=0 / 学习(Learn)=1 / 我的(Profile)=2。
 *      早期注释曾写「Projects=2 / Practice=3 / Profile=4」，已随 Tab 瘦身失效。
 */
const LEARN_TAB_INDEX: number = 1;

/**
 * 学习页（V1 核心闭环入口）。
 *
 * 职责：
 *  - 持有 LearnViewModel，在 aboutToAppear 触发数据加载；
 *  - 渲染四态（LOADING / EMPTY / ERROR / SUCCESS）；
 *  - SUCCESS 态下渲染分类筛选栏 + 知识卡片列表；
 *  - 卡片点击时经 queryNavigationInfo() 取得根栈，并按强类型参数预埋详情路由跳转。
 * 分层约束：
 *  - 本页严禁直接读写 rawfile / resourceManager / Preferences，一切数据经 ViewModel。
 *  - 本页严禁在 build() 内修改任何状态变量；状态变更只发生在生命周期或事件回调中。
 *  - 根容器锁定 .width('100%').height('100%')，防止高度塌陷。
 */
@Component
export struct LearnPage {
  /** 页面级 ViewModel（经 Provider 获取依赖，严禁在此 new Repository） */
  @State viewModel: LearnViewModel = new LearnViewModel();

  /**
   * 重绘哨兵。
   * 说明：ArkUI 的 @State 不会深层监听类实例的内部属性变化（即使该类被 @Observed 修饰，
   *      作为嵌套成员时仍无法保证触发重绘）。因此在异步加载完成后翻转本布尔值，
   *      以状态变更强制驱动 build() 重新执行，确保四态与列表真实刷新。
   * 注意：仅可在生命周期与事件回调中翻转，严禁在 build() 内修改。
   */
  @State refreshFlag: boolean = false;

  /**
   * 收藏 ID 快照。
   * 说明：UserStore 为 @Observed 单例，但 @State 不深层监听其内部属性变化，
   *      故在生命周期/事件回调中读取一次并存入页面自身的 @State 数组，
   *      使 build() 依赖的是可被观察的页面状态，保证跨页返回后星标能同步刷新。
   */
  @State favoriteIds: string[] = [];

  /**
   * 根 Tabs 当前下标（由 RootTabContainer 经 @Provide('rootTabIndex') 广播）。
   * 刷新机理：TabContent 切换**不会触发 onPageShow**，故借助本变量 + @Watch
   *          在「切回 Learn」的瞬间重新读取收藏快照，保证星标与最新收藏同步。
   */
  @Consume('rootTabIndex') @Watch('onRootTabChanged') rootTabIndex: number;

  /**
   * 收藏版本号（状态驱动刷新，Milestone 3.4-fix3）。
   *
   * 机理：UserStore 在收藏变化时向 AppStorage 写入一个时间戳版本号，
   *      本变量经 @StorageLink 与之双向绑定，版本变化即触发 syncFavorites()。
   *      这是**唯一能在「详情页 pop 返回 TabContent」场景下可靠刷新**的机制
   *      （该场景不触发 onPageShow，Tab 索引也不变化，事件型方案全部失效）。
   * 约束：@StorageLink 必须带 @Watch；key 必须取自 AppStorageKeys 常量，禁止硬编码字符串。
   */
  @StorageLink(AppStorageKeys.FAVORITES_VERSION) @Watch('syncFavorites') favoritesVersion: number = 0;

  aboutToAppear(): void {
    this.syncFavorites();
    this.loadData();
  }

  /**
   * Tab 切换回调：仅当切回本页（Learn）时重新读取收藏快照。
   * 说明：syncFavorites 会赋值新的 @State 数组，从而驱动 build() 重算星标。
   */
  onRootTabChanged(): void {
    if (this.rootTabIndex === LEARN_TAB_INDEX) {
      this.syncFavorites();
      Logger.debug(MODULE_TAG, `favorite snapshot refreshed: count=${this.favoriteIds.length}`);
    }
  }

  /**
   * 从详情页返回本页时触发：重新读取 UserStore 收藏快照并驱动重绘。
   * 这是「详情页收藏 → 返回 Learn 列表星标同步」的关键刷新点。
   */
  onPageShow(): void {
    this.syncFavorites();
  }

  /** 同步收藏快照（仅读内存态，不触达 Preferences，不产生 I/O）。 */
  private syncFavorites(): void {
    this.favoriteIds = UserStore.getInstance().favorites;
  }

  /** 判断某条目当前是否已收藏（快照查询）。 */
  private isItemFavorite(id: string): boolean {
    return this.favoriteIds.includes(id);
  }

  /** 触发数据加载（生命周期与重试按钮共用入口）。 */
  private loadData(): void {
    this.viewModel.loadKnowledgeList().then(() => {
      this.refreshFlag = !this.refreshFlag;
    });
  }

  /**
   * 卡片点击处理：取根栈并跳转详情页。
   *
   * 刷新设计（Milestone 3.4-fix3 定稿）：
   *  - 实测结论：pushPathByName 的 onPop 重载（3.4-fix2 采用的方案）在本工程的
   *    NavDestination 复用路径下**未被触发**，属死代码，故已移除。
   *  - 现有刷新完全由「状态驱动」承担：UserStore 收藏变化 → AppStorage 版本号递增
   *    → 本页 @StorageLink(FAVORITES_VERSION) 变化 → @Watch 触发 syncFavorites()。
   *    该机制与触发场景无关（pop 返回 / 切 Tab / 冷启动水化均可），是唯一可靠路径。
   *  - onPageShow / onRootTabChanged 保留为兼容与备份，彼此幂等、互不冲突。
   * @param id 知识条目唯一标识
   */
  private openKnowledgeDetail(id: string): void {
    const params: KnowledgeDetailParams = { id: id };
    const stack: NavPathStack | undefined = this.queryNavigationInfo()?.pathStack;
    if (stack === undefined) {
      Logger.error(MODULE_TAG, `push skipped: root stack unavailable, id=${id}`);
      return;
    }
    stack.pushPathByName(RouteConstants.KNOWLEDGE_DETAIL, params);
    Logger.info(MODULE_TAG, `push ${RouteConstants.KNOWLEDGE_DETAIL} id=${id}`);
  }

  build() {
    Column() {
      // 页面标题区
      Row() {
        Text(AppStrings.TAB_LEARN)
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
        this.stateHint(AppStrings.LEARN_LOADING, '')
      } else if (this.viewModel.uiStatus === UIStatus.EMPTY) {
        this.stateHint(AppStrings.LEARN_EMPTY_TITLE, AppStrings.LEARN_EMPTY_DESC)
      } else if (this.viewModel.uiStatus === UIStatus.ERROR) {
        this.errorState()
      } else {
        this.successState()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BACKGROUND)
  }

  /** SUCCESS 态：分类筛选栏 + 难度筛选栏 + 知识卡片列表。 */
  @Builder
  successState() {
    Column() {
      CategoryBar({
        options: this.viewModel.categoryList(),
        selected: this.viewModel.selectedCategory,
        onSelected: (category: string) => {
          this.viewModel.selectCategory(category);
        }
      })

      // 难度筛选栏（C-1）：与分类维度并置，二者为「与」关系，复用同一胶囊组件。
      CategoryBar({
        options: this.viewModel.levelList(),
        selected: this.viewModel.selectedLevel,
        onSelected: (level: string) => {
          this.viewModel.selectLevel(level);
        }
      })

      // 空态分流：数据本身非空（uiStatus 已为 SUCCESS），但当前双维度组合无匹配项。
      // 说明：此处必须保留两条筛选栏可见，用户才能改回其它组合，
      //      故空态文案渲染在列表位置，而非替换整个 successState。
      if (this.viewModel.visibleList().length === 0) {
        this.stateHint(AppStrings.LEARN_EMPTY_FILTERED, '')
      } else {
        List({ space: AppDimens.SPACING_MD }) {
          ForEach(this.viewModel.visibleList(), (item: KnowledgeMetadata) => {
            ListItem() {
              Row({ space: AppDimens.SPACING_SM }) {
                // 知识卡片占满剩余宽度
                Column() {
                  KnowledgeCard({
                    item: item,
                    onClickItem: (id: string) => {
                      this.openKnowledgeDetail(id);
                    }
                  })
                }
                .layoutWeight(1)

                // 收藏标记：仅已收藏时显示，轻量小尺寸不抢主视觉
                if (this.isItemFavorite(item.id)) {
                  Text(AppStrings.GLYPH_STAR_FILLED)
                    .fontSize(AppDimens.FAVORITE_MARK_SIZE)
                    .fontColor(AppColors.FAVORITE_ACTIVE)
                }
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }
          }, (item: KnowledgeMetadata) => item.id)
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .listDirection(Axis.Vertical)
        .scrollBar(BarState.Auto)
        .padding({ left: AppDimens.SPACING_LG, right: AppDimens.SPACING_LG, bottom: AppDimens.SPACING_LG })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: AppDimens.SPACING_SM })
  }

  /** 通用状态提示（LOADING / EMPTY）。 */
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
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
  }

  /** ERROR 态：错误提示 + 语义化错误码 + 重试入口。 */
  @Builder
  errorState() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.LEARN_ERROR_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      Text(`${this.viewModel.lastErrorCode}`)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(AppColors.TEXT_TERTIARY)
      Button(AppStrings.MSG_RETRY)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .backgroundColor(AppColors.PRIMARY)
        .onClick(() => {
          this.loadData();
        })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
  }
}