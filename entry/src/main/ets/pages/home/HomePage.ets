import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';

/**
 * 首页一级 Tab（V1 简化）。
 *
 * 职责：作为 Home TabContent 的内容根组件，Milestone 0 仅渲染统一占位。
 * 约束：不访问任何数据源；页面级状态由后续 ViewModel 提供。
 */
@Component
export struct HomePage {
  build() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.HOME_PLACEHOLDER_TITLE)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(AppStrings.HOME_PLACEHOLDER_DESC)
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
