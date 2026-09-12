import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';

/**
 * 我的 一级 Tab（V1 含收藏与阅读历史）。
 *
 * 职责：Milestone 0 仅作为 TabContent 内容根。
 * 后续：Milestone 3 接入 ProfileViewModel + UserStore，展示收藏与历史实体。
 */
@Component
export struct ProfilePage {
  build() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.PROFILE_PLACEHOLDER_TITLE)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(AppStrings.PROFILE_PLACEHOLDER_DESC)
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
