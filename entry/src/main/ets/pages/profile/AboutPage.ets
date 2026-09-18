import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';

/**
 * 关于（Profile 二级页，V1 静态说明）。
 *
 * 职责：由 NavDestination 承载，展示应用定位、内容与数据说明、技术架构说明。
 * V1 范围（产品决策）：纯静态文案页，无数据订阅、无 ViewModel、无状态。
 * 分层约束：
 *  - 本页严禁直接访问 rawfile / Preferences / resourceManager / bundleManager。
 *  - 严禁内嵌 Navigation / 新建 NavPathStack。
 *  - 文案全部取自 AppStrings，颜色全部取自 AppColors，尺寸全部取自 AppDimens。
 */
@Component
export struct AboutPage {
  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: AppDimens.SPACING_LG }) {
            this.titleBlock()
            this.section(AppStrings.ABOUT_SECTION_DATA, AppStrings.ABOUT_DATA_DESC)
            this.section(AppStrings.ABOUT_SECTION_TECH, AppStrings.ABOUT_TECH_DESC)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(AppDimens.SPACING_LG)
        }
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BACKGROUND)
    }
    .title(AppStrings.PROFILE_ENTRY_ABOUT)
    .backgroundColor(AppColors.SURFACE)
  }

  /** 顶部标识区：应用名 + 标语 + 一句话简介。 */
  @Builder
  titleBlock() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.ABOUT_APP_NAME_TEXT)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
      Text(AppStrings.ABOUT_SLOGAN)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.PRIMARY)
        .width('100%')
      Text(AppStrings.ABOUT_DESC)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppDimens.SPACING_LG)
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
  }

  /** 通用说明区块：小节标题 + 正文。 */
  @Builder
  section(title: string, description: string) {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(title)
        .fontSize(AppDimens.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
        .width('100%')
      Text(description)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .lineHeight(AppDimens.LINE_HEIGHT_BODY)
        .fontColor(AppColors.TEXT_SECONDARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppDimens.SPACING_LG)
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
  }
}
