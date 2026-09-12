import { KnowledgeMetadata } from './KnowledgeMetadata';

/**
 * 知识索引文件模型。
 *
 * 职责：描述 database/knowledge/index.json 的外层信封结构，供 Repository 在按需加载正文前
 *      先取得轻量元数据列表，落实「启动不全量解析正文」的分级加载原则。
 * 说明：本模型自 Milestone 1.2 的 RawFileAssetDataSource 内部就近声明提取而来，
 *      现作为正式模型沉淀，使 Repository 与 DataSource 共享同一份索引契约。
 * 约束：本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export interface KnowledgeIndex {
  /** 数据规范版本号 */
  schemaVersion: string;
  /** 全量知识元数据列表（轻量，不含正文） */
  items: KnowledgeMetadata[];
}
