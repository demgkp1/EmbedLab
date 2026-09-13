import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ErrorCode } from '../models/common/ErrorCode';
import { Failure, Result, Success } from '../models/common/Result';

/** Preferences 文件名（用户状态专用实例） */
const PREF_NAME: string = 'embedlab_user_state';
/** 收藏键 */
const KEY_FAVORITES: string = 'user_favorites';
/** 阅读历史键 */
const KEY_HISTORY: string = 'user_history';
/** 完成标记键 */
const KEY_PROGRESS: string = 'user_progress';
/** 历史记录定长上限（先进先出，超出即截断） */
const HISTORY_MAX: number = 30;

/**
 * Preferences 存储抽象（可注入接缝）。
 *
 * 存在原因：Preferences 的真实实例必须由具备模块 sandbox 权限的 Context 才能取得，
 * 而测试进程的上下文无法访问业务模块 sandbox，因此无法在测试环境实例化真实 Preferences。
 * 本接口仅声明本数据源实际使用的三个方法，使测试可注入等价的内存实现，
 * 从而在无设备依赖下确定性验证序列化、去重、FIFO 与错误码分支。
 * 生产路径不注入任何实现，行为完全不变。
 */
export interface PreferencesLike {
  /** 读取指定键的值，缺失时返回 defValue */
  getSync(key: string, defValue: preferences.ValueType): preferences.ValueType;
  /** 写入指定键的值 */
  putSync(key: string, value: preferences.ValueType): void;
  /** 将内存改动持久化 */
  flush(): Promise<void>;
}

/**
 * Preferences 数据源（用户状态底层 I/O）。
 *
 * 职责：唯一负责 @ohos.data.preferences 的读写、JSON 序列化与结构校验，
 *      并以 Result<T> 形式向上层返回，严禁裸抛异常。
 * 分层约束：
 *  - 本层是四层架构最底层（DataSource），严禁承载任何业务语义
 *    （收藏按钮、当前页面、UserStore 等一律不得出现在本文件）。
 *  - 严禁依赖 UserRepository / UserStore / ViewModel 的任何类型。
 *  - Preferences 实例在类内部按 context 异步获取，不向外暴露，避免上层感知 preferences 模块。
 * 序列化安全红线：
 *  - 写入统一 JSON.stringify()；读取 JSON.parse() 后必须做结构校验（数组判定 + 逐元素 typeof）。
 *  - 严禁任何 `as string[]` / `as Map` / `as Record` 强转。
 *  - 校验失败（首次使用的空值、损坏 JSON、类型不符）一律降级返回 Success(空结构)，
 *    不返回 Failure —— 首次使用与数据损坏在业务上都不应阻断主流程。
 * 错误码映射（架构文档 7.3 节）：
 *  - Preferences 读失败 → STORAGE_READ_FAILED
 *  - Preferences 写失败 → STORAGE_WRITE_FAILED
 *  - 其他未知异常 → UNKNOWN
 */
export class PreferenceDataSource {
  private readonly context: common.Context;
  /** Preferences 实例缓存（首次访问时异步取得，进程内复用） */
  private preferencesInstance: preferences.Preferences | null = null;
  /** 注入的存储实现；生产路径为 null，此时走 preferences.getPreferences 惰性获取 */
  private readonly injectedStore: PreferencesLike | null = null;

  /**
   * @param context 由 DataSourceProvider 注入的应用上下文。
   *                采用基类 common.Context 而非 UIAbilityContext：preferences.getPreferences()
   *                的形参即为 Context，放宽类型后本数据源可在 UIAbility 与测试环境中复用同一实现。
   * @param store 可选。仅用于测试注入内存实现；生产调用方一律不传，行为与改造前完全一致。
   */
  constructor(context: common.Context, store?: PreferencesLike) {
    this.context = context;
    this.injectedStore = store === undefined ? null : store;
  }

  // ==================== 对外读写接口 ====================

  /**
   * 读取收藏 ID 列表。
   * @returns 成功时返回字符串数组；数据缺失或损坏时降级为 Success(空数组)
   */
  async loadFavorites(): Promise<Result<string[]>> {
    const store: PreferencesLike | null = await this.resolveStore();
    if (store === null) {
      return PreferenceDataSource.failure<string[]>(ErrorCode.STORAGE_READ_FAILED, 'preferences unavailable');
    }
    try {
      const raw: string = PreferenceDataSource.asString(store.getSync(KEY_FAVORITES, ''));
      return PreferenceDataSource.success(PreferenceDataSource.decodeStringArray(raw));
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      return PreferenceDataSource.failure<string[]>(ErrorCode.STORAGE_READ_FAILED,
        `read ${KEY_FAVORITES} failed (${message})`);
    }
  }

  /**
   * 写入收藏 ID 列表。
   * @param ids 收藏 ID 数组（顺序由调用方负责）
   */
  async saveFavorites(ids: string[]): Promise<Result<void>> {
    const store: PreferencesLike | null = await this.resolveStore();
    if (store === null) {
      return PreferenceDataSource.failure<void>(ErrorCode.STORAGE_WRITE_FAILED, 'preferences unavailable');
    }
    try {
      store.putSync(KEY_FAVORITES, JSON.stringify(ids));
      await store.flush();
      return PreferenceDataSource.success<void>(undefined);
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      return PreferenceDataSource.failure<void>(ErrorCode.STORAGE_WRITE_FAILED,
        `write ${KEY_FAVORITES} failed (${message})`);
    }
  }

  /**
   * 读取阅读历史。
   * 读取后同样截断到 30 条，防止旧版本写入的越界数据。
   */
  async loadHistory(): Promise<Result<string[]>> {
    const store: PreferencesLike | null = await this.resolveStore();
    if (store === null) {
      return PreferenceDataSource.failure<string[]>(ErrorCode.STORAGE_READ_FAILED, 'preferences unavailable');
    }
    try {
      const raw: string = PreferenceDataSource.asString(store.getSync(KEY_HISTORY, ''));
      const decoded: string[] = PreferenceDataSource.decodeStringArray(raw);
      return PreferenceDataSource.success(PreferenceDataSource.truncate(decoded));
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      return PreferenceDataSource.failure<string[]>(ErrorCode.STORAGE_READ_FAILED,
        `read ${KEY_HISTORY} failed (${message})`);
    }
  }

  /**
   * 写入阅读历史。
   *
   * 输入契约：ids 必须是「最新 → 最旧」的有序数组，且调用方负责保证重复 ID 已按最新访问位置归位。
   * 本方法不推断时间、不持有时间戳、不重排顺序，仅执行：
   *   ① 按首次出现位置保留（防御性去重，输入 [A,B,C,A,D] → [A,B,C,D]）
   *   ② 截断到最多 30 条
   *   ③ JSON.stringify 写入
   * @param ids 最新 → 最旧的历史 ID 数组
   */
  async saveHistory(ids: string[]): Promise<Result<void>> {
    const store: PreferencesLike | null = await this.resolveStore();
    if (store === null) {
      return PreferenceDataSource.failure<void>(ErrorCode.STORAGE_WRITE_FAILED, 'preferences unavailable');
    }
    try {
      const normalized: string[] = PreferenceDataSource.truncate(PreferenceDataSource.dedupKeepFirst(ids));
      store.putSync(KEY_HISTORY, JSON.stringify(normalized));
      await store.flush();
      return PreferenceDataSource.success<void>(undefined);
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      return PreferenceDataSource.failure<void>(ErrorCode.STORAGE_WRITE_FAILED,
        `write ${KEY_HISTORY} failed (${message})`);
    }
  }

  /**
   * 读取知识点完成标记字典。
   * @returns 成功时返回 Map；数据缺失或损坏时降级为 Success(空 Map)
   */
  async loadProgress(): Promise<Result<Map<string, boolean>>> {
    const store: PreferencesLike | null = await this.resolveStore();
    if (store === null) {
      return PreferenceDataSource.failure<Map<string, boolean>>(ErrorCode.STORAGE_READ_FAILED,
        'preferences unavailable');
    }
    try {
      const raw: string = PreferenceDataSource.asString(store.getSync(KEY_PROGRESS, ''));
      return PreferenceDataSource.success(PreferenceDataSource.decodeBooleanMap(raw));
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      return PreferenceDataSource.failure<Map<string, boolean>>(ErrorCode.STORAGE_READ_FAILED,
        `read ${KEY_PROGRESS} failed (${message})`);
    }
  }

  /**
   * 写入知识点完成标记字典。
   * @param map 完成标记字典
   */
  async saveProgress(map: Map<string, boolean>): Promise<Result<void>> {
    const store: PreferencesLike | null = await this.resolveStore();
    if (store === null) {
      return PreferenceDataSource.failure<void>(ErrorCode.STORAGE_WRITE_FAILED, 'preferences unavailable');
    }
    try {
      store.putSync(KEY_PROGRESS, PreferenceDataSource.encodeBooleanMap(map));
      await store.flush();
      return PreferenceDataSource.success<void>(undefined);
    } catch (err) {
      const message: string = err instanceof Error ? err.message : `${err}`;
      return PreferenceDataSource.failure<void>(ErrorCode.STORAGE_WRITE_FAILED,
        `write ${KEY_PROGRESS} failed (${message})`);
    }
  }

  // ==================== 内部：Preferences 获取 ====================

  /**
   * 获取（并缓存）Preferences 实例。
   * 获取失败时返回 null，由各公共方法映射为对应的 STORAGE_* 错误码，不抛异常。
   */
  private async obtainStore(): Promise<preferences.Preferences | null> {
    const cached: preferences.Preferences | null = this.preferencesInstance;
    if (cached !== null) {
      return cached;
    }
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREF_NAME);
      this.preferencesInstance = store;
      return store;
    } catch (err) {
      return null;
    }
  }

  /**
   * 解析本次操作使用的存储实现。
   * 优先使用注入实现（测试路径）；未注入时惰性获取真实 Preferences（生产路径）。
   * @returns 存储实现；生产路径获取失败时返回 null
   */
  private async resolveStore(): Promise<PreferencesLike | null> {
    const injected: PreferencesLike | null = this.injectedStore;
    if (injected !== null) {
      return injected;
    }
    return await this.obtainStore();
  }

  // ==================== 内部：JSON 编解码与结构校验 ====================

  /**
   * 将存储值安全转换为字符串。
   * 说明：Preferences 取出的值类型为联合类型，此处显式收窄，
   *      非 string 值一律降级为空串（交由 JSON 解析环节判定为损坏并降级）。
   */
  private static asString(value: preferences.ValueType): string {
    if (typeof value === 'string') {
      const text: string = value;
      return text;
    }
    return '';
  }

  /**
   * 解码字符串数组。
   * 校验规则：JSON 必须可解析、根必须是数组、每个元素必须是 string。
   * 任一不满足 → 返回空数组（降级，不报错）。
   */
  private static decodeStringArray(raw: string): string[] {
    if (raw.length === 0) {
      return [];
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(raw) as Object;
    } catch (err) {
      return [];
    }
    if (!Array.isArray(parsed)) {
      return [];
    }
    const items: Object[] = parsed as Object[];
    const result: string[] = [];
    for (let index: number = 0; index < items.length; index++) {
      const element: Object = items[index];
      if (typeof element !== 'string') {
        return [];
      }
      const text: string = element;
      result.push(text);
    }
    return result;
  }

  /**
   * 解码布尔字典。
   * 校验规则：JSON 必须可解析、根必须是对象、每个值必须是 boolean。
   * 任一不满足 → 返回空 Map（降级，不报错）。
   */
  private static decodeBooleanMap(raw: string): Map<string, boolean> {
    const result: Map<string, boolean> = new Map<string, boolean>();
    if (raw.length === 0) {
      return result;
    }
    let parsed: Object;
    try {
      parsed = JSON.parse(raw) as Object;
    } catch (err) {
      return result;
    }
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return result;
    }
    const record: Record<string, Object> = parsed as Record<string, Object>;
    const keys: string[] = Object.keys(record);
    for (let index: number = 0; index < keys.length; index++) {
      const key: string = keys[index];
      const value: Object = record[key];
      if (typeof value !== 'boolean') {
        return new Map<string, boolean>();
      }
      const flag: boolean = value;
      result.set(key, flag);
    }
    return result;
  }

  /** 将布尔字典编码为 JSON 字符串（Record 由逐项赋值构造，避免匿名对象类型问题）。 */
  private static encodeBooleanMap(map: Map<string, boolean>): string {
    const record: Record<string, boolean> = {};
    map.forEach((value: boolean, key: string) => {
      record[key] = value;
    });
    return JSON.stringify(record);
  }

  // ==================== 内部：历史序列规整 ====================

  /**
   * 防御性去重：按首次出现位置保留。
   * 输入顺序即「最新 → 最旧」语义，故保留首次出现等价于保留最新一次访问位置。
   * 例：[A, B, C, A, D] → [A, B, C, D]
   */
  private static dedupKeepFirst(ids: string[]): string[] {
    const result: string[] = [];
    for (let index: number = 0; index < ids.length; index++) {
      const id: string = ids[index];
      if (id.length > 0 && !result.includes(id)) {
        result.push(id);
      }
    }
    return result;
  }

  /** 截断到历史记录定长上限。 */
  private static truncate(ids: string[]): string[] {
    if (ids.length <= HISTORY_MAX) {
      return ids;
    }
    const result: string[] = [];
    for (let index: number = 0; index < HISTORY_MAX; index++) {
      result.push(ids[index]);
    }
    return result;
  }

  // ==================== 内部：Result 构造 ====================

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
