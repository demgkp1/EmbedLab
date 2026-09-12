/**
 * 代码片段模型。
 *
 * 职责：以纯文本结构化承载知识正文中的代码示例，供详情页代码块组件渲染。
 * 约束：
 *  - 代码以纯文本保存，严禁在 JSON 中以图片或 Base64 承载代码。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export interface CodeSnippet {
  /** 编程语言，如 C、Assembly */
  language: string;
  /** 纯文本源代码 */
  code: string;
  /** 代码重点说明 */
  description: string;
  /** 需要高亮显示的行号集合（可选） */
  highlightLines?: number[];
}
