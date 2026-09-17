/**
 * 全局尺寸常量（单位：vp，字体除外）。
 *
 * 职责：集中管理间距、圆角、字号、底部 Tab 栏高度等尺寸值。
 * 范围：只保留 Milestone 0 占位骨架实际引用的尺寸，按需增长。
 */
export class AppDimens {
  /** 极小间距 */
  static readonly SPACING_XS: number = 4;
  /** 小间距 */
  static readonly SPACING_SM: number = 8;
  /** 中等间距（页面内元素默认间距） */
  static readonly SPACING_MD: number = 12;
  /** 大间距（页面内边距） */
  static readonly SPACING_LG: number = 16;
  /** 超大间距（区块之间） */
  static readonly SPACING_XL: number = 24;

  /** 小圆角 */
  static readonly RADIUS_SM: number = 8;
  /** 卡片圆角 */
  static readonly RADIUS_MD: number = 12;

  /** 底部 Tab 栏高度 */
  static readonly TAB_BAR_HEIGHT: number = 56;
  /** 底部 Tab 栏字号 */
  static readonly FONT_SIZE_TAB: number = 12;

  /** 页面主标题字号 */
  static readonly FONT_SIZE_TITLE: number = 20;
  /** 区块标题字号 */
  static readonly FONT_SIZE_SUBTITLE: number = 16;
  /** 正文字号 */
  static readonly FONT_SIZE_BODY: number = 14;
  /** 辅助说明字号 */
  static readonly FONT_SIZE_CAPTION: number = 12;

  /** 全屏图片预览的关闭字形尺寸（与详情页标题栏星标 22 保持同一视觉量级） */
  static readonly FONT_SIZE_CLOSE_GLYPH: number = 22;

  /** 正文行高（blockText / blockWarning 共用） */
  static readonly LINE_HEIGHT_BODY: number = 24;
  /** 收藏星标字形尺寸（详情页标题栏） */
  static readonly FAVORITE_GLYPH_SIZE: number = 22;
}
