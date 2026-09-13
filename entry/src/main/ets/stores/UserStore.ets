import { UserProgressState } from '../models/user/UserProgressState';
import { AppStorageKeys } from '../constants/AppStorageKeys';

/**
 * 用户状态全局响应式单例（内存态）。
 *
 * 职责：作为跨页面共享的运行时状态中心，仅持有收藏 / 历史 / 完成标记三项状态，
 *      并向 UI 暴露只读语义的查询入口。
 * 分层约束（严禁越界）：
 *  - **严禁**持有 DataSource / Repository / ViewModel 的任何引用。
 *  - **严禁**在本类内调用 Preferences 或任何 I/O；持久化一律由 UserRepository 负责。
 *  - **严禁**做持久化决策（例如「先写 Store 再写盘」这类伪成功流程）。
 *  - 本类不属于四层中的任何一层，只做内存状态持有。
 * 生命周期：
 *  - 进程内单例，由 UserRepository 在启动水化时经 initialize(state) 一次性注水。
 * 响应式风险登记（Milestone 2.1 实测教训）：
 *  - @Observed 使本类属性变化可被 ArkUI 观察，但 @State 不深层监听类实例内部属性；
 *    页面侧若出现「数据已变但 UI 不刷新」，可使用 refreshFlag 哨兵或 @ObjectLink 绑定。
 *    该验证属 Milestone 3.3 的响应式 UI 验证点。
 */
@Observed
export class UserStore {
  /** 进程内唯一实例 */
  private static instance: UserStore | null = null;

  /** 收藏的知识 ID 集合 */
  favorites: string[] = [];
  /** 最近阅读的知识 ID 序列（最新 → 最旧） */
  history: string[] = [];
  /** 知识点已读 / 完成标记字典 */
  progress: Map<string, boolean> = new Map<string, boolean>();

  /** 获取全局单例（首次访问时创建）。 */
  static getInstance(): UserStore {
    const existing: UserStore | null = UserStore.instance;
    if (existing !== null) {
      return existing;
    }
    const created: UserStore = new UserStore();
    UserStore.instance = created;
    return created;
  }

  /**
   * 启动水化：把持久化恢复出的状态一次性注入内存。
   * 说明：直接覆盖三个字段，不做增量合并（水化语义为「以磁盘为准」）；
   *      采用不可变替换（展开为新数组 / 新 Map），确保 @Observed 能观察到变化。
   * 广播：水化完成后写入两个版本号，驱动各处 @StorageLink 页面刷新。
   * @param state 由 UserRepository.loadState() 聚合出的用户状态
   */
  initialize(state: UserProgressState): void {
    this.favorites = [...state.favorites];
    this.history = [...state.history];
    this.progress = new Map(state.progress);
    UserStore.broadcast(AppStorageKeys.FAVORITES_VERSION);
    UserStore.broadcast(AppStorageKeys.HISTORY_VERSION);
  }

  /**
   * 更新收藏集合（仅在 UserRepository 持久化成功后调用）。
   * @param ids 最新收藏 ID 数组
   */
  updateFavorites(ids: string[]): void {
    this.favorites = [...ids];
    UserStore.broadcast(AppStorageKeys.FAVORITES_VERSION);
  }

  /**
   * 更新阅读历史（仅在 UserRepository 持久化成功后调用）。
   * @param ids 最新历史 ID 数组（最新 → 最旧）
   */
  updateHistory(ids: string[]): void {
    this.history = [...ids];
    UserStore.broadcast(AppStorageKeys.HISTORY_VERSION);
  }

  /**
   * 更新完成标记字典（仅在 UserRepository 持久化成功后调用）。
   * @param map 最新完成标记字典
   */
  updateProgress(map: Map<string, boolean>): void {
    this.progress = map;
  }

  /**
   * 查询某知识是否已收藏（UI 只读入口）。
   * @param id 知识条目唯一标识
   */
  isFavorite(id: string): boolean {
    return this.favorites.includes(id);
  }

  /** 释放单例引用（仅用于测试隔离）。 */
  static reset(): void {
    UserStore.instance = null;
  }

  /**
   * 广播状态版本号（仅时间戳，不承载业务数据）。
   *
   * 存在原因（Milestone 3.4-fix3）：详情页 pop 返回 TabContent 时，页面既不触发
   * onPageShow，Tab 索引也未变化，任何事件都打不到 Learn / Profile 页；
   * 而 @Observed 单例的属性变化又无法被页面的 @State 深层观察到。
   * 因此改用「状态驱动」：本方法向 AppStorage 写入一个递增的时间戳，
   * 页面以 @StorageLink + @Watch 监听该键，从而在数据真正变化时被唤醒刷新。
   * 约束：只广播 number 时间戳，严禁把数组 / 字典等业务数据写入 AppStorage。
   */
  private static broadcast(key: string): void {
    AppStorage.setOrCreate<number>(key, Date.now());
  }
}
