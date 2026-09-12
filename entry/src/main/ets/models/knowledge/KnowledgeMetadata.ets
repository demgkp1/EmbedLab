/**
 * 知识索引元数据模型（轻量级）。
 *
 * 职责：对应知识库分级存储中的 knowledge/index.json，仅承载列表渲染与分类聚合所需的最小字段，
 *      使应用启动与列表滑动无需解析任何正文，落实按需分级加载原则。
 * 约束：
 *  - 字段集合必须与 index.json 一一对应，正文专属字段不得出现在本模型中。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export interface KnowledgeMetadata {
  /** 唯一标识，如 stm32_gpio_basic */
  id: string;
  /** 标题 */
  title: string;
  /** 分类标识，如 MCU_Peripherals */
  category: string;
  /** 难度等级：Basic / Medium / Hard */
  level: string;
  /** 技术标签 */
  tags: string[];
  /** 文章概括/卡片摘要 */
  summary: string;
}
