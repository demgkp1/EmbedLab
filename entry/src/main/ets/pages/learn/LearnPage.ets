import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';

/**
 * 学习一级 Tab（V1 核心模块）。
 *
 * 职责：Milestone 0 仅作为 TabContent 内容根，验证分类 / 列表页面的挂载位置。
 * 后续：Milestone 2 接入 LearnViewModel，实现分类浏览与知识列表。
 */
@Component
export struct LearnPage {
  build() {
    Column({ space: AppDimens.SPACING_SM }) {
      Text(AppStrings.LEARN_PLACEHOLDER_TITLE)
        .fontSize(AppDimens.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(AppStrings.LEARN_PLACEHOLDER_DESC)
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
