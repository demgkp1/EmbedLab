import { ErrorCode } from '../models/common/ErrorCode';
import { Failure, Result, Success } from '../models/common/Result';
import { UserProgressState } from '../models/user/UserProgressState';
import { PreferenceDataSource } from '../datasources/PreferenceDataSource';

/**
 * 内部错误载体（不对外暴露）。
 *
 * 存在原因（ArkTS 事实约束）：ArkTS 不支持结构化类型，无法把接口形式的
 * Result<T> 可辨识联合收窄为 Failure，联合类型上的 code / error 属性一律不可访问。
 * 因此 Repository 内部改用本载体承载失败信息，仅在公共方法出口处一次性组装为
 * 架构规定的 Result<T>；成功值以「是否为 undefined」判定，全程无需联合类型属性访问。
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
 * 用户状态仓库。
 *
 * 职责：调度 PreferenceDataSource 完成用户状态的读取与持久化，并把分散的三个键
 *      聚合成 UserProgressState；遵循「先持久化成功、再通知调用方更新 Store」原则，
 *      失败时返回 Failure 且**不产生任何状态变更**。
 * 分层约束：
 *  - 依赖通过构造函数注入 PreferenceDataSource（唯一获取入口）；
 *    严禁在类内静态调用 DataSourceProvider —— 时序由 RepositoryProvider 保证。
 *  - 零 Context 持有（与 KnowledgeRepository 范式一致）。
 *  - 全部对外方法返回 Promise<Result<T>>，严禁裸抛异常。
 *  - 本层不持有 UserStore 引用，不直接改写 Store；由调用方在成功后同步。
 * 历史记录契约：
 *  - 对外暴露的 history 始终为「最新 → 最旧」有序数组；
 *  - 去重与 30 条截断由 DataSource 内部完成，本层只负责把目标 id 置顶。
 */
export class UserRepository {
  private readonly dataSource: PreferenceDataSource;

  /**
   * @param dataSource 由 RepositoryProvider 注入的用户状态数据源
   */
  constructor(dataSource: PreferenceDataSource) {
    this.dataSource = dataSource;
  }

  /**
   * 读取并聚合完整用户状态。
   * 三项任一读取失败即返回 Failure（Preferences 读失败才失败；
   * 数据缺失或损坏由 DataSource 降级为空结构，不会失败）。
   * @returns 聚合后的用户状态；读取失败时返回对应 Failure
   */
  async loadState(): Promise<Result<UserProgressState>> {
    const favorites: ErrorCarrier = new ErrorCarrier();
    const loadedFavorites: string[] | undefined =
      await UserRepository.loadOrMark<string[]>(
        (): Promise<Result<string[]>> => this.dataSource.loadFavorites(), favorites);
    if (loadedFavorites === undefined) {
      return UserRepository.failure<UserProgressState>(favorites.code, favorites.message);
    }

    const history: ErrorCarrier = new ErrorCarrier();
    const loadedHistory: string[] | undefined =
      await UserRepository.loadOrMark<string[]>(
        (): Promise<Result<string[]>> => this.dataSource.loadHistory(), history);
    if (loadedHistory === undefined) {
      return UserRepository.failure<UserProgressState>(history.code, history.message);
    }

    const progress: ErrorCarrier = new ErrorCarrier();
    const loadedProgress: Map<string, boolean> | undefined =
      await UserRepository.loadOrMark<Map<string, boolean>>(
        (): Promise<Result<Map<string, boolean>>> => this.dataSource.loadProgress(), progress);
    if (loadedProgress === undefined) {
      return UserRepository.failure<UserProgressState>(progress.code, progress.message);
    }

    const state: UserProgressState = new UserProgressState(loadedFavorites, loadedHistory, loadedProgress);
    return UserRepository.success<UserProgressState>(state);
  }

  /**
   * 切换收藏状态。
   * 逻辑：读取现有收藏 → 已存在则移除、不存在则插入首位 → 持久化 → 成功后才返回最新数组。
   * @param id 知识条目唯一标识
   * @returns 成功时返回最新的收藏数组（供调用方同步 Store）；失败时不改变任何状态
   */
  async toggleFavorite(id: string): Promise<Result<string[]>> {
    const readError: ErrorCarrier = new ErrorCarrier();
    const current: string[] | undefined =
      await UserRepository.loadOrMark<string[]>(
        (): Promise<Result<string[]>> => this.dataSource.loadFavorites(), readError);
    if (current === undefined) {
      return UserRepository.failure<string[]>(readError.code, readError.message);
    }

    const updated: string[] = UserRepository.nextFavorites(current, id);

    const writeError: ErrorCarrier = new ErrorCarrier();
    const saved: boolean = await UserRepository.saveOrMark(
      (): Promise<Result<void>> => this.dataSource.saveFavorites(updated), writeError);
    if (!saved) {
      // 持久化失败：不返回新数组，调用方不得更新 Store（避免伪成功状态）
      return UserRepository.failure<string[]>(writeError.code, writeError.message);
    }
    return UserRepository.success<string[]>(updated);
  }

  /**
   * 记录阅读足迹。
   * 逻辑：读取现有历史 → 移除该 id 的旧位置 → unshift 到首位 → 持久化。
   * 截断 30 条与去重由 DataSource 内部完成（本层只保证置顶语义）。
   * @param id 知识条目唯一标识
   * @returns 成功时返回最新的历史数组（最新 → 最旧）；失败时不改变任何状态
   */
  async recordHistory(id: string): Promise<Result<string[]>> {
    const readError: ErrorCarrier = new ErrorCarrier();
    const current: string[] | undefined =
      await UserRepository.loadOrMark<string[]>(
        (): Promise<Result<string[]>> => this.dataSource.loadHistory(), readError);
    if (current === undefined) {
      return UserRepository.failure<string[]>(readError.code, readError.message);
    }

    const updated: string[] = UserRepository.nextHistory(current, id);

    const writeError: ErrorCarrier = new ErrorCarrier();
    const saved: boolean = await UserRepository.saveOrMark(
      (): Promise<Result<void>> => this.dataSource.saveHistory(updated), writeError);
    if (!saved) {
      return UserRepository.failure<string[]>(writeError.code, writeError.message);
    }
    return UserRepository.success<string[]>(updated);
  }

  /**
   * 查询某知识是否已收藏。
   * @param id 知识条目唯一标识
   * @returns 已收藏为 true；读取失败时保守返回 false（不阻断查询语义）
   */
  async isFavorite(id: string): Promise<boolean> {
    const readError: ErrorCarrier = new ErrorCarrier();
    const current: string[] | undefined =
      await UserRepository.loadOrMark<string[]>(
        (): Promise<Result<string[]>> => this.dataSource.loadFavorites(), readError);
    if (current === undefined) {
      return false;
    }
    return current.includes(id);
  }

  // ==================== 内部：纯函数状态演算 ====================

  /**
   * 演算下一次收藏数组：存在则移除，不存在则插入首位。
   * 纯函数，不触碰任何 I/O，便于推理与复用。
   */
  private static nextFavorites(current: string[], id: string): string[] {
    const result: string[] = [];
    if (current.includes(id)) {
      for (let index: number = 0; index < current.length; index++) {
        const item: string = current[index];
        if (item !== id) {
          result.push(item);
        }
      }
      return result;
    }
    result.push(id);
    for (let index: number = 0; index < current.length; index++) {
      result.push(current[index]);
    }
    return result;
  }

  /**
   * 演算下一次历史数组：移除旧位置后置顶。
   * 纯函数；长度截断交由 DataSource 处理（写入与读取两侧均有保护）。
   */
  private static nextHistory(current: string[], id: string): string[] {
    const result: string[] = [];
    result.push(id);
    for (let index: number = 0; index < current.length; index++) {
      const item: string = current[index];
      if (item !== id) {
        result.push(item);
      }
    }
    return result;
  }

  // ==================== 内部：Result 处理范式 ====================

  /**
   * 调用数据源并取出成功值，失败信息写入载体。
   * 关键实现说明（ArkTS 严格模式实测结论）：
   *  - ArkTS 仅在 `if (!x.success)` 否定式判别下收窄 Result<T>；
   *    正向判别不会收窄，其 else 分支仍视为含 Success<T> 的联合类型。
   *  - 故在否定式判别成立后用官方认可的 as 做「已校验类型对齐」，读取失败信息。
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
      error.mark(ErrorCode.UNKNOWN, `user data source read failed (${message})`);
      return undefined;
    }
  }

  /**
   * 调用数据源的写操作，仅关心成功与否。
   * @param writer 返回数据源 Promise<Result<void>> 的闭包
   * @param error 失败信息出参
   * @returns 写入成功为 true
   */
  private static async saveOrMark(writer: () => Promise<Result<void>>,
    error: ErrorCarrier): Promise<boolean> {
    try {
      const result: Result<void> = await writer();
      if (!result.success) {
        const failure: Failure = result as Failure;
        error.mark(failure.code, failure.error);
        return false;
      }
      return true;
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      error.mark(ErrorCode.UNKNOWN, `user data source write failed (${message})`);
      return false;
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
