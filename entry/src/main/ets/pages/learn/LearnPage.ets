import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';
import { RouteConstants } from '../../constants/RouteConstants';
import { UIStatus } from '../../models/common/UIStatus';
import { KnowledgeMetadata } from '../../models/knowledge/KnowledgeMetadata';
import { KnowledgeDetailParams } from '../../models/knowledge/KnowledgeDetailParams';
import { LearnViewModel } from '../../viewmodels/LearnViewModel';
import { CategoryBar } from './components/CategoryBar';
import { KnowledgeCard } from './components/KnowledgeCard';
import { Logger } from '../../utils/logger/Logger';

const MODULE_TAG: string = 'LearnPage';

/** 四态提示文案（页面私有文案，避免污染全局 AppStrings） */
const MSG_LOADING: string = '正在加载知识库…';
const MSG_EMPTY_TITLE: string = '暂无数据，请检查 rawfile';
const MSG_EMPTY_DESC: string = '未在 resources/rawfile/database/knowledge/index.json 中读到任何知识条目。';
const MSG_ERROR_TITLE: string = '知识索引加载失败';
const MSG_RETRY: string = '重新加载';

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

  aboutToAppear(): void {
    this.loadData();
  }

  /** 触发数据加载（生命周期与重试按钮共用入口）。 */
  private loadData(): void {
    this.viewModel.loadKnowledgeList().then(() => {
      this.refreshFlag = !this.refreshFlag;
    });
  }

  /**
   * 卡片点击处理：取根栈并跳转详情页。
   * 说明：KnowledgeDetailPage 实体在 Milestone 2.2 落地，本阶段为路由预埋，
   *      点击后由 pageMap 的兜底分支接管，属预期内表现。
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
        this.stateHint(MSG_LOADING, '')
      } else if (this.viewModel.uiStatus === UIStatus.EMPTY) {
        this.stateHint(MSG_EMPTY_TITLE, MSG_EMPTY_DESC)
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

  /** SUCCESS 态：分类筛选栏 + 知识卡片列表。 */
  @Builder
  successState() {
    Column() {
      CategoryBar({
        categories: this.viewModel.categoryList(),
        selected: this.viewModel.selectedCategory,
        onCategorySelected: (category: string) => {
          this.viewModel.selectCategory(category);
        }
      })

      List({ space: AppDimens.SPACING_MD }) {
        ForEach(this.viewModel.visibleList(), (item: KnowledgeMetadata) => {
          ListItem() {
            KnowledgeCard({
              item: item,
              onClickItem: (id: string) => {
                this.openKnowledgeDetail(id);
              }
            })
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
      Text(MSG_ERROR_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      Text(`${this.viewModel.lastErrorCode}`)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(AppColors.TEXT_TERTIARY)
      Button(MSG_RETRY)
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