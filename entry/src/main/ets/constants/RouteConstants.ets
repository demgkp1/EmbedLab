/**
 * 路由名称常量。
 *
 * 职责：集中管理 NavPathStack 中注册的页面名称，避免在 pushPathByName 与 pageMap 中散落字符串魔法值。
 * 约定：名称必须与 MainPage 的 @Builder pageMap(name, param) 分支一一对应。
 */
export class RouteConstants {
  /**
   * 路由基础设施验证页（Milestone 0 临时脚手架）。
   * 待 Milestone 2 落地 KNOWLEDGE_DETAIL 后，本常量与对应 NavDestination 一并移除。
   */
  static readonly NAV_PROBE: string = 'NavigationProbePage';

  /**
   * 知识详情页。
   * 契约先行：Milestone 0 仅固定路由名称与强类型参数，页面本身在 Milestone 2 实现。
   */
  static readonly KNOWLEDGE_DETAIL: string = 'KnowledgeDetailPage';
}
