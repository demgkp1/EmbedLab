import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';

/**
 * 练习一级 Tab（V1 静态占位）。
 *
 * 职责：Milestone 0 仅作为 TabContent 内容根，不引入题库数据与答题逻辑。
 */
@Component
export struct PracticePage {
  build() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.PRACTICE_PLACEHOLDER_TITLE)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(AppStrings.PRACTICE_PLACEHOLDER_DESC)
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
