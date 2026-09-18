/**
 * 知识详情页路由名称（模块级具名导出）。
 * 说明：与 RouteConstants.KNOWLEDGE_DETAIL 指向同一字符串，二者共用同一字面量定义，
 *      保证 pushPathByName 与 pageMap 分支永远一致。
 */
export const ROUTE_KNOWLEDGE_DETAIL: string = 'KnowledgeDetailPage';

/**
 * Profile 二级页路由名称（模块级具名导出）。
 * 说明：与下方 RouteConstants 的静态键指向同一字符串，保证 pushPathByName 与
 *      MainPage.pageMap 分支永远一致（与 ROUTE_KNOWLEDGE_DETAIL 同构）。
 *      四者均为**无参路由**，push 时 param 传 null。
 */
export const ROUTE_PROFILE_FAVORITES: string = 'ProfileFavoritesPage';
export const ROUTE_PROFILE_HISTORY: string = 'ProfileHistoryPage';
export const ROUTE_PROFILE_SETTINGS: string = 'ProfileSettingsPage';
export const ROUTE_PROFILE_ABOUT: string = 'ProfileAboutPage';

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

  /** 我的收藏（Profile 二级页，无参） */
  static readonly PROFILE_FAVORITES: string = ROUTE_PROFILE_FAVORITES;
  /** 阅读历史（Profile 二级页，无参） */
  static readonly PROFILE_HISTORY: string = ROUTE_PROFILE_HISTORY;
  /** 设置（Profile 二级页，无参） */
  static readonly PROFILE_SETTINGS: string = ROUTE_PROFILE_SETTINGS;
  /** 关于（Profile 二级页，无参） */
  static readonly PROFILE_ABOUT: string = ROUTE_PROFILE_ABOUT;
}
