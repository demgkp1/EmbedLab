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

const MODULE_TAG: string = 'HistoryPage';

/**
 * 阅读历史（Profile 二级页）。
 *
 * 职责：由 NavDestination 承载，展示 UserStore.history 的全量阅读足迹（最新 → 最旧）。
 * 数据来源：沿用 ProfileViewModel（本卡保留该类，不重构、不删除）——
 *          其 historyItems 为「按 history 顺序映射的全量实体」（mapByIds 无 limit）。
 * 分层约束：
 *  - 本页严禁遍历 ID 调 Repository（聚合在 ProfileViewModel 内完成）。
 *  - 本页严禁直接访问 rawfile / Preferences / resourceManager，亦不直连 UserStore。
 *  - 严禁在 build() 内修改任何状态变量。
 *  - 严禁内嵌 Navigation / 新建 NavPathStack（全应用唯一根栈由 MainPage 持有）。
 * 响应式说明（与 ProfilePage 同构，但**不含** @Consume('rootTabIndex')——本页非一级 Tab）：
 *  - 足迹变化由 UserStore 递增 AppStorage 版本号驱动，本页以 @StorageLink + @Watch 接收；
 *  - 从知识详情页返回本页时由 onPageShow 触发一次「仅重算、不重取」的刷新。
 */
@Component
export struct HistoryPage {
  /** 页面级 ViewModel（复用 ProfileViewModel，仅读取 historyItems） */
  @State viewModel: ProfileViewModel = new ProfileViewModel();

  /** 重绘哨兵：@State 不深层监听类实例内部属性，装配完成后翻转以强制驱动 build()。 */
  @State refreshFlag: boolean = false;

  /** 阅读历史版本号（状态驱动刷新） */
  @StorageLink(AppStorageKeys.HISTORY_VERSION)
  @Watch('onHistoryChanged')
  historyVersion: number = 0;

  /** 收藏版本号：订阅但不重算本页列表，仅保证与全局状态保持同步认知 */
  @StorageLink(AppStorageKeys.FAVORITES_VERSION)
  @Watch('onFavoritesChanged')
  favoritesVersion: number = 0;

  aboutToAppear(): void {
    this.loadItems();
  }

  /** 从知识详情页返回时触发：仅重算、不重取元数据。 */
  onPageShow(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
  }

  /** 历史变化：列表即时同步。 */
  onHistoryChanged(): void {
    this.viewModel.refreshFromStore();
    this.refreshFlag = !this.refreshFlag;
    Logger.debug(MODULE_TAG, `history changed, count=${this.viewModel.historyItems.length}`);
  }

  /** 收藏变化：本页不展示收藏，仅记录（保持订阅完整性）。 */
  onFavoritesChanged(): void {
    Logger.debug(MODULE_TAG, `favorites changed (not displayed here)`);
  }

  /** 首次加载：一次性批量取元数据并装配。 */
  private loadItems(): void {
    this.viewModel.loadDisplayItems().then(() => {
      this.refreshFlag = !this.refreshFlag;
    });
  }

  /** 列表项点击：跳转知识详情（经根 NavPathStack，强类型参数）。 */
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
    NavDestination() {
      Column() {
        if (this.viewModel.uiStatus === UIStatus.LOADING) {
          this.stateHint(AppStrings.PROFILE_LOADING, '')
        } else if (this.viewModel.uiStatus === UIStatus.ERROR) {
          this.errorState()
        } else if (this.viewModel.historyItems.length === 0) {
          this.emptyState()
        } else {
          this.itemList()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BACKGROUND)
    }
    .title(AppStrings.PROFILE_ENTRY_HISTORY)
    .backgroundColor(AppColors.SURFACE)
  }

  /** 历史列表（全量，最新在前）。 */
  @Builder
  itemList() {
    List({ space: AppDimens.SPACING_MD }) {
      ForEach(this.viewModel.historyItems, (item: KnowledgeMetadata) => {
        ListItem() {
          this.itemRow(item)
        }
      }, (item: KnowledgeMetadata) => `history-${item.id}`)
    }
    .width('100%')
    .layoutWeight(1)
    .listDirection(Axis.Vertical)
    .scrollBar(BarState.Auto)
    .padding({
      left: AppDimens.SPACING_LG,
      right: AppDimens.SPACING_LG,
      top: AppDimens.SPACING_MD,
      bottom: AppDimens.SPACING_LG
    })
  }

  /** 单条展示项（轻量卡片，与 Profile 原列表项保持同一视觉）。 */
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

  /** 空态。 */
  @Builder
  emptyState() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.PROFILE_EMPTY_HISTORY_TITLE)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.Center)
      Text(AppStrings.PROFILE_EMPTY_HISTORY_DESC)
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
