import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';

/**
 * 项目一级 Tab（V1 静态占位）。
 *
 * 职责：Milestone 0 仅作为 TabContent 内容根，不引入任何项目业务数据。
 */
@Component
export struct ProjectsPage {
  build() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.PROJECTS_PLACEHOLDER_TITLE)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(AppStrings.PROJECTS_PLACEHOLDER_DESC)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(AppDimens.SPACING_XL)
    .backgroundColor(AppColors.BACKGROUND)
  }
}
