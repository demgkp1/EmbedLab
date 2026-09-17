import pasteboard from '@ohos.pasteboard';
import { promptAction } from '@kit.ArkUI';
import { AppDimens } from '../../../constants/AppDimens';
import { AppStrings } from '../../../constants/AppStrings';
import { Logger } from '../../../utils/logger/Logger';

const MODULE_TAG: string = 'GeekCodeBlock';

/** 深色代码块配色与排版常量（极客风格） */
const CODE_BG: string = '#1E1E1E';
const CODE_FG: string = '#D4D4D4';
const CODE_LANG_FG: string = '#4EC9B0';
const CODE_FONT_SIZE: number = 13;
const CODE_LINE_HEIGHT: number = 20;
const MONOSPACE: string = 'HarmonyOS Sans Monospace, monospace';
const COPY_BTN_BG: string = '#2D2D2D';
const COPY_BTN_FG: string = '#CCCCCC';
const COPY_BTN_ACTIVE_BG: string = '#3A3A3A';
/** 复制按钮绝对定位偏移（vp） */
const COPY_BTN_OFFSET: number = 8;

/**
 * 极客代码块组件。
 *
 * 职责：以深色背景 + 等宽字体呈现源码，并在右上角提供一键复制能力。
 * 关键约束（原样复制防卫战）：
 *  - 写入剪贴板的内容必须是 this.code 原值，**严禁** trim / 重新格式化 / 转义 / 拼接。
 *  - 复制为异步操作，处理 Promise 并给出轻提示，严禁阻塞 UI 线程。
 */
@Component
export struct GeekCodeBlock {
  /** 源代码原文（原样写入剪贴板） */
  @Prop code: string = '';
  /** 代码语言标识，可为空串 */
  @Prop language: string = '';

  build() {
    // Stack 承载「代码文本 + 右上角绝对定位复制按钮」
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: AppDimens.SPACING_SM }) {
        // 语言标识
        Row() {
          Text(this.language.length > 0 ? this.language : 'CODE')
            .fontSize(AppDimens.FONT_SIZE_CAPTION)
            .fontColor(CODE_LANG_FG)
            .fontFamily(MONOSPACE)
        }
        .width('100%')

        // 代码正文：等宽字体、可长按选中复制
        Text(this.code)
          .fontSize(CODE_FONT_SIZE)
          .fontColor(CODE_FG)
          .fontFamily(MONOSPACE)
          .lineHeight(CODE_LINE_HEIGHT)
          .width('100%')
          .copyOption(CopyOptions.InApp)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(AppDimens.SPACING_MD)

      // 极简复制按钮（绝对定位右上角）
      Text(AppStrings.CODE_COPY)
        .fontSize(AppDimens.FONT_SIZE_CAPTION)
        .fontColor(COPY_BTN_FG)
        .backgroundColor(COPY_BTN_BG)
        .padding({
          left: AppDimens.SPACING_SM,
          right: AppDimens.SPACING_SM,
          top: AppDimens.SPACING_XS,
          bottom: AppDimens.SPACING_XS
        })
        .borderRadius(AppDimens.RADIUS_SM)
        .margin({
          top: COPY_BTN_OFFSET,
          right: COPY_BTN_OFFSET
        })
        .onClick(() => {
          this.copyCode();
        })
    }
    .width('100%')
    .backgroundColor(CODE_BG)
    .borderRadius(AppDimens.RADIUS_MD)
  }

  /**
   * 一键复制：将 this.code 原样写入系统剪贴板。
   * 说明：全程不对 code 做任何变换；Promise 化处理并给出轻提示。
   */
  private copyCode(): void {
    try {
      const data: pasteboard.PasteData = pasteboard.createPlainTextData(this.code);
      pasteboard.getSystemPasteboard().setData(data)
        .then(() => {
          this.toast(AppStrings.CODE_COPIED_TOAST);
          Logger.info(MODULE_TAG, `copied ${this.code.length} chars verbatim`);
        })
        .catch((err: Object) => {
          const message: string = err instanceof Error ? err.message : `${err}`;
          this.toast(AppStrings.CODE_COPY_FAILED_TOAST);
          Logger.error(MODULE_TAG, `copy failed: ${message}`);
        });
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      this.toast(AppStrings.CODE_COPY_FAILED_TOAST);
      Logger.error(MODULE_TAG, `copy threw: ${message}`);
    }
  }

  /** 弹出轻提示（异常自兜底，避免提示本身影响主流程）。 */
  private toast(message: string): void {
    try {
      promptAction.showToast({ message: message, duration: 1500 });
    } catch (err) {
      Logger.error(MODULE_TAG, `toast failed: ${err instanceof Error ? err.message : `${err}`}`);
    }
  }
}
