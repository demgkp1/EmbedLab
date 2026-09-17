/**
 * 全局颜色常量。
 *
 * 职责：集中管理应用视觉色值，禁止在 Page / Component 中散落裸写颜色魔法值。
 * 范围：V1 仅提供浅色主题所需的语义化色板，不建设复杂 Design System。
 */
export class AppColors {
  /** 品牌主色 */
  static readonly PRIMARY: string = '#0A59F7';
  /** 品牌主色浅色底（选中态背景） */
  static readonly PRIMARY_LIGHT: string = '#E8F0FE';
  /** 页面背景色 */
  static readonly BACKGROUND: string = '#F1F3F5';
  /** 卡片 / 内容容器背景色 */
  static readonly SURFACE: string = '#FFFFFF';
  /** 主要文字颜色 */
  static readonly TEXT_PRIMARY: string = '#182431';
  /** 次要说明文字颜色 */
  static readonly TEXT_SECONDARY: string = '#666666';
  /** 弱化文字颜色（Tab 未选中态） */
  static readonly TEXT_TERTIARY: string = '#8C8C8C';
  /** 分割线 / 边框颜色 */
  static readonly DIVIDER: string = '#E5E5E5';
  /** 收藏激活色（金色）：详情页星标已收藏态、Learn 列表收藏标记 */
  static readonly FAVORITE_ACTIVE: string = '#F5A623';
  /** 全屏图片预览底色（纯黑，最大化图片对比度） */
  static readonly OVERLAY_BACKDROP: string = '#000000';
  /** 全屏图片预览的关闭字形颜色（浅灰，在纯黑底上保持可辨识） */
  static readonly OVERLAY_CLOSE: string = '#E5E5E5';
  /** 警示块浅色背景（warning 块专用） */
  static readonly WARNING_BG: string = '#FFF7E6';
}
