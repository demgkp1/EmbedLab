import { AppColors } from '../../constants/AppColors';
import { AppDimens } from '../../constants/AppDimens';
import { AppStrings } from '../../constants/AppStrings';

/**
 * 设置（Profile 二级页，V1 只读）。
 *
 * 职责：由 NavDestination 承载，只读展示版本、构建号与知识索引校验前缀。
 * V1 范围（产品决策）：**只读**，不提供任何可切换设置项，故无 ViewModel、无数据订阅。
 * 取值来源（静态具名常量，**非运行时计算**，避免引入 bundleManager / resourceManager）：
 *  - SETTINGS_VERSION_NAME / SETTINGS_VERSION_CODE / SETTINGS_BUILD_VERSION
 *    ← AppScope/app.json5（versionName / versionCode / buildVersion）
 *  - SETTINGS_INDEX_SHA256_PREFIX ← docs/pipeline/STATE.md 记录的知识索引构建期哈希
 * 分层约束：
 *  - 本页严禁直接访问 rawfile / Preferences / resourceManager / bundleManager。
 *  - 严禁内嵌 Navigation / 新建 NavPathStack。
 *  - 本页无状态，故不存在 build() 内写状态的问题。
 */
@Component
export struct SettingsPage {
  build() {
    NavDestination() {
      Column({ space: AppDimens.SPACING_LG }) {
        this.infoCard()

        Text(AppStrings.SETTINGS_NOTE)
          .fontSize(AppDimens.FONT_SIZE_CAPTION)
          .fontColor(AppColors.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(AppDimens.SPACING_LG)
      .backgroundColor(AppColors.BACKGROUND)
    }
    .title(AppStrings.PROFILE_ENTRY_SETTINGS)
    .backgroundColor(AppColors.SURFACE)
  }

  /** 只读信息卡：三行「标签 + 取值」。 */
  @Builder
  infoCard() {
    Column({ space: AppDimens.SPACING_MD }) {
      this.infoRow(AppStrings.SETTINGS_LABEL_VERSION, AppStrings.SETTINGS_VERSION_NAME)
      this.infoRow(AppStrings.SETTINGS_LABEL_BUILD,
        `${AppStrings.SETTINGS_BUILD_VERSION} (${AppStrings.SETTINGS_VERSION_CODE})`)
      this.infoRow(AppStrings.SETTINGS_LABEL_INDEX_HASH, AppStrings.SETTINGS_INDEX_SHA256_PREFIX)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(AppDimens.SPACING_LG)
    .backgroundColor(AppColors.SURFACE)
    .borderRadius(AppDimens.RADIUS_MD)
  }

  /** 单行信息：左标签、右取值（取值可复制）。 */
  @Builder
  infoRow(label: string, value: string) {
    Row({ space: AppDimens.SPACING_SM }) {
      Text(label)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.TEXT_SECONDARY)
      Text(value)
        .fontSize(AppDimens.FONT_SIZE_BODY)
        .fontColor(AppColors.TEXT_PRIMARY)
        .textAlign(TextAlign.End)
        .layoutWeight(1)
        .copyOption(CopyOptions.InApp)
    }
    .width('100%')
  }
}
