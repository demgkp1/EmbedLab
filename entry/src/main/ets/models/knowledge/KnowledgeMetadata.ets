/**
 * 知识索引元数据模型（轻量级）。
 *
 * 职责：对应知识库分级存储中的 knowledge/index.json，仅承载列表渲染与分类聚合所需的最小字段，
 *      使应用启动与列表滑动无需解析任何正文，落实按需分级加载原则。
 * 约束：
 *  - 字段集合必须与 index.json 一一对应，正文专属字段不得出现在本模型中。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */

/**
 * 知识难度等级（Cleanup-3 收窄）。
 *
 * 来源：knowledge/index.json 的 level 字段。实测 34 章仅 3 种取值：
 *      Basic(9) / Medium(15) / Hard(10)，无第 4 种、无大小写异写。
 * 取值形态：**字符串字面量联合类型**（非 enum）。
 *      选型理由：与同目录 KnowledgeItem.ets 的 ContentBlock.type
 *      （'header' | 'text' | 'image' | 'code' | 'warning'）保持同一风格；
 *      且运行期无「枚举载体」需求，避免引入 enum 层。
 * 约束语义：编译期即拦截错拼（如 'basic' 小写）——不能赋给本类型；
 *      运行期由 RawFileAssetDataSource.isLevel 做同集合白名单校验，
 *      非法值以 JSON_INVALID 上抛（对齐既有 isBlockType 先例）。
 * 维护提示：新增难度档位须**同时**修改本联合类型与 DataSource.isLevel，
 *      二者是同一契约的两个落点，漏改任一处会导致校验与类型不一致。
 */
export type KnowledgeLevel = 'Basic' | 'Medium' | 'Hard';

export interface KnowledgeMetadata {
  /** 唯一标识，如 stm32_gpio_basic */
  id: string;
  /** 标题 */
  title: string;
  /** 分类标识，如 MCU_Peripherals */
  category: string;
  /** 难度等级：收窄为 KnowledgeLevel 联合类型（Basic / Medium / Hard） */
  level: KnowledgeLevel;
  /** 技术标签 */
  tags: string[];
  /** 文章概括/卡片摘要 */
  summary: string;
}
