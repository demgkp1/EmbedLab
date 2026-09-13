import { KnowledgeMetadata } from './KnowledgeMetadata';

/**
 * 动态富文本内容块模型。
 *
 * 职责：以有序数组承载知识正文，使图文、代码、警示等异构内容能够按作者意图自由穿插排版，
 *      替代早期固定九宫格的教材化结构。
 * 约束：
 *  - type 取值严格限定为 5 种，新增类型必须先经人工确认架构变更。
 *  - language 仅允许出现在 type === 'code' 的块中，其余类型携带 language 视为非法结构。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export interface ContentBlock {
  /** 块类型：章节标题 / 正文段落 / 图片 / 代码 / 警示 */
  type: 'header' | 'text' | 'image' | 'code' | 'warning';
  /** 块主体内容：文本类为正文原文，image 为相对 rawfile 的图片路径，code 为源代码原文 */
  content: string;
  /** 代码语言标识，仅 type === 'code' 时允许存在 */
  language?: string;
}

/**
 * 完整知识详情模型。
 *
 * 职责：对应知识库分级存储中的 knowledge/details/{id}.json，是详情页渲染的唯一数据来源，
 *      仅在用户打开某篇知识时按需加载，不参与启动期解析。
 * 继承说明：基础元数据字段继承自 KnowledgeMetadata，保证索引与详情在 id/title/category/level/tags/summary
 *          六个字段上契约完全一致（ArkTS 官方支持接口多继承）。
 * 约束：
 *  - contentBlocks 必须显式声明为具名类型数组，禁止使用内联匿名对象类型。
 *  - images 中仅保存相对路径，实体内置于 resources/rawfile/database/ 下。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export interface KnowledgeItem extends KnowledgeMetadata {
  /** 引用的图片相对路径集合（对应 resources/rawfile/database/） */
  images: string[];
  /** 动态富文本正文块序列（按作者排版顺序渲染） */
  contentBlocks: ContentBlock[];
  /** 关联项目案例 ID 集合 */
  relatedProjectIds: string[];
}
