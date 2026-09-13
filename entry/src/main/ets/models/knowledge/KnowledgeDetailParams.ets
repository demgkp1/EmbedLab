/**
 * 知识详情页路由参数契约。
 *
 * 职责：固定 KnowledgeDetailPage 的强类型入参形态，供 pushPathByName 传参使用。
 * 约束：
 *  - 路由跳转严禁传递匿名对象字面量，必须构造本类型实例。
 *  - 参数提取在 NavDestination 的 onReady 生命周期中完成，并经结构校验后使用。
 *  - title 为可选展示信息：列表页已持有该字段，传入可让 NavDestination 标题栏直接显示
 *    知识标题；缺失时页面回退为通用标题，不影响正文按 id 加载。
 */
export interface KnowledgeDetailParams {
  /** 知识条目唯一标识，对应 knowledge/index.json 中的 id */
  id: string;
  /** 知识标题（可选，仅用于标题栏展示，不作为数据加载依据） */
  title?: string;
}
