/**
 * 知识详情页路由名称（模块级具名导出）。
 * 说明：与 RouteConstants.KNOWLEDGE_DETAIL 指向同一字符串，二者共用同一字面量定义，
 *      保证 pushPathByName 与 pageMap 分支永远一致。
 */
export const ROUTE_KNOWLEDGE_DETAIL: string = 'KnowledgeDetailPage';

/**
 * 路由名称常量。
 *
 * 职责：集中管理 NavPathStack 中注册的页面名称，避免在 pushPathByName 与 pageMap 中散落字符串魔法值。
 * 约定：名称必须与 MainPage 的 @Builder pageMap(name, param) 分支一一对应。
 */
export class RouteConstants {
  /**
   * 知识详情页（类访问形式，等价于模块级常量 ROUTE_KNOWLEDGE_DETAIL）。
   */
  static readonly KNOWLEDGE_DETAIL: string = ROUTE_KNOWLEDGE_DETAIL;
}
