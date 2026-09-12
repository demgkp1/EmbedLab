import { CodeSnippet } from './CodeSnippet';
import { KnowledgeMetadata } from './KnowledgeMetadata';

/**
 * 教材化结构正文模型。
 *
 * 职责：固定知识详情正文的章节骨架，使详情页能够按稳定的语义章节渲染，
 *      而非解析自由格式文本。
 * 约束：字段集合与架构文档 6.1 节正文结构严格一致，新增字段必须先经人工确认架构变更。
 */
export interface KnowledgeContent {
  /** 学习前置要求 */
  prerequisite: string;
  /** 学习目标 */
  objective: string;
  /** 核心概念 */
  concept: string;
  /** 工作原理 */
  principle: string;
  /** 结构化代码示例 */
  example: CodeSnippet;
  /** 实操验证与接线实验指南 */
  experiment: string;
  /** 工程经验与避坑要点 */
  tips: string;
  /** 常见致命错误排查 */
  commonErrors: string;
  /** 章节核心总结条目（避免与外层 summary 命名冲突） */
  keyPoints: string[];
}

/**
 * 完整知识详情模型。
 *
 * 职责：对应知识库分级存储中的 knowledge/details/{id}.json，是详情页渲染的唯一数据来源，
 *      仅在用户打开某篇知识时按需加载，不参与启动期解析。
 * 继承说明：基础元数据字段继承自 KnowledgeMetadata，保证索引与详情在 id/title/category/level/tags/summary
 *          六个字段上契约完全一致（ArkTS 官方支持接口多继承）。
 * 约束：
 *  - content 必须显式声明为具名类型 KnowledgeContent，禁止使用内联匿名对象类型。
 *  - images 中仅保存相对路径，实体内置于 resources/base/media/ 下。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export interface KnowledgeItem extends KnowledgeMetadata {
  /** 引用的图片相对路径集合（对应 resources/base/media/） */
  images: string[];
  /** 教材化结构正文 */
  content: KnowledgeContent;
  /** 关联项目案例 ID 集合 */
  relatedProjectIds: string[];
}
