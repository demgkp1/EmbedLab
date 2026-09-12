import { ErrorCode } from '../models/common/ErrorCode';
import { Failure, Result, Success } from '../models/common/Result';
import { KnowledgeItem } from '../models/knowledge/KnowledgeItem';
import { KnowledgeMetadata } from '../models/knowledge/KnowledgeMetadata';
import { RawFileAssetDataSource } from '../datasources/RawFileAssetDataSource';

/**
 * 内部错误载体（不对外暴露）。
 *
 * 存在原因（ArkTS 事实约束）：ArkTS 不支持结构化类型，无法把接口形式的
 * Result<T> 可辨识联合收窄为 Failure，联合类型上的 code / error 属性一律不可访问。
 * 因此 Repository 内部改用本载体承载失败信息，仅在公共方法出口处一次性组装为
 * 架构规定的 Result<T>；成功值则以「是否为 undefined」判定，全程无需联合类型属性访问。
 */
class ErrorCarrier {
  code: ErrorCode;
  message: string;

  constructor() {
    this.code = ErrorCode.UNKNOWN;
    this.message = '';
  }

  /** 标记失败原因。 */
  mark(code: ErrorCode, message: string): void {
    this.code = code;
    this.message = message;
  }
}

/**
 * 知识仓库。
 *
 * 职责：知识数据的策略中枢——负责调度只读静态资产、维护进程生命周期内的只读内存缓存，
 *      并按需向上层提供结构化结果。
 * 分层约束：
 *  - 依赖通过构造函数注入 RawFileAssetDataSource，严禁在类内部 new 数据源。
 *  - 本层严禁承担 UI 职责，严禁直接访问 resourceManager 或 Preferences。
 *  - 所有方法统一返回 Promise<Result<T>>，严禁裸抛异常。
 * 缓存策略：
 *  - metadataCache：缓存轻量索引列表，避免重复解析 index.json。
 *  - detailCache：按 id 缓存已打开的正文，避免重复滑动与重复进入详情时的无意义文件 I/O。
 *  - 缓存均为进程内只读缓存，Repository 不承担任何持久化职责。
 */
export class KnowledgeRepository {
  private readonly dataSource: RawFileAssetDataSource;

  /** 轻量索引内存缓存；null 表示尚未加载 */
  private metadataCache: KnowledgeMetadata[] | null = null;
  /** 知识正文内存缓存，键为知识 id */
  private detailCache: Map<string, KnowledgeItem> = new Map<string, KnowledgeItem>();

  /**
   * @param dataSource 由 RepositoryProvider 注入的静态资产数据源
   */
  constructor(dataSource: RawFileAssetDataSource) {
    this.dataSource = dataSource;
  }

  /**
   * 获取知识元数据列表。
   * 命中 metadataCache 时直接返回，不触发任何文件 I/O。
   * @returns 元数据列表；资产缺失、JSON 损坏或字段缺失时返回对应 Failure
   */
  async getKnowledgeMetadataList(): Promise<Result<KnowledgeMetadata[]>> {
    const cached: KnowledgeMetadata[] | null = this.metadataCache;
    if (cached !== null) {
      return KnowledgeRepository.success<KnowledgeMetadata[]>(cached);
    }
    const error: ErrorCarrier = new ErrorCarrier();
    const loaded: KnowledgeMetadata[] | undefined =
      await KnowledgeRepository.loadOrMark<KnowledgeMetadata[]>(
        (): Promise<Result<KnowledgeMetadata[]>> => this.dataSource.readKnowledgeMetadataList(), error);
    if (loaded === undefined) {
      return KnowledgeRepository.failure<KnowledgeMetadata[]>(error.code, error.message);
    }
    this.metadataCache = loaded;
    return KnowledgeRepository.success<KnowledgeMetadata[]>(loaded);
  }

  /**
   * 获取单篇知识详情正文。
   * 命中 detailCache 时直接返回，不触发任何文件 I/O。
   * @param id 知识条目唯一标识
   * @returns 知识详情实体；资产缺失、JSON 损坏或字段缺失时返回对应 Failure
   */
  async getKnowledgeItem(id: string): Promise<Result<KnowledgeItem>> {
    const cached: KnowledgeItem | undefined = this.detailCache.get(id);
    if (cached !== undefined) {
      return KnowledgeRepository.success<KnowledgeItem>(cached);
    }
    const error: ErrorCarrier = new ErrorCarrier();
    const loaded: KnowledgeItem | undefined =
      await KnowledgeRepository.loadOrMark<KnowledgeItem>(
        (): Promise<Result<KnowledgeItem>> => this.dataSource.readKnowledgeItem(id), error);
    if (loaded === undefined) {
      return KnowledgeRepository.failure<KnowledgeItem>(error.code, error.message);
    }
    this.detailCache.set(id, loaded);
    return KnowledgeRepository.success<KnowledgeItem>(loaded);
  }

  /** 清空全部内存缓存（仅用于测试隔离或显式刷新）。 */
  clearCache(): void {
    this.metadataCache = null;
    this.detailCache.clear();
  }

  /**
   * 调用数据源并把失败信息统一导入内部载体。
   *
   * 关键实现说明（ArkTS 严格模式实测结论）：
   *  - ArkTS 仅在 `if (!x.success)` 这一否定式判别下收窄 Result<T>；
   *    正向判别（`if (x.success) ... else ...`）不会收窄，其 else 分支仍视为
   *    含 Success<T> 的联合类型，访问 code/error 会直接编译失败。
   *  - 因此在否定式判别成立后，使用官方文档认可的 as 做「已校验类型对齐」，
   *    读取失败信息并写入非泛型载体，全程不把联合类型变量作为函数实参传递。
   * @param loader 返回数据源 Promise<Result<T>> 的闭包
   * @param error 失败信息出参
   * @returns 成功时的强类型数据；失败返回 undefined
   */
  private static async loadOrMark<T>(loader: () => Promise<Result<T>>,
    error: ErrorCarrier): Promise<T | undefined> {
    try {
      const result: Result<T> = await loader();
      if (!result.success) {
        const failure: Failure = result as Failure;
        error.mark(failure.code, failure.error);
        return undefined;
      }
      return result.data;
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      error.mark(ErrorCode.UNKNOWN, `data source call failed (${message})`);
      return undefined;
    }
  }

  /** 构造成功结果。 */
  private static success<T>(data: T): Result<T> {
    const value: Success<T> = { success: true, data: data };
    return value;
  }

  /** 构造失败结果。 */
  private static failure<T>(code: ErrorCode, error: string): Result<T> {
    const value: Failure = { success: false, error: error, code: code };
    return value;
  }
}
