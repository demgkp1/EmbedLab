/**
 * 知识详情页路由参数契约。
 *
 * 职责：固定 KnowledgeDetailPage 的强类型入参形态，供 pushPathByName 传参使用。
 * 约束：
 *  - 路由跳转严禁传递匿名对象字面量，必须构造本类型实例。
 *  - 参数提取在 NavDestination 的 onReady 生命周期中完成，并经结构校验后使用。
 * 说明：本文件仅固定契约，页面实现属于 Milestone 2。
 */
export interface KnowledgeDetailParams {
  /** 知识条目唯一标识，对应 knowledge/index.json 中的 id */
  id: string;
}
