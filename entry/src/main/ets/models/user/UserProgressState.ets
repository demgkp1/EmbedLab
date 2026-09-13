/**
 * 用户进度状态（纯内存数据结构）。
 *
 * 职责：以一个聚合对象承载用户在本地的可写状态——收藏、阅读历史与完成标记，
 *      作为 Preferences 序列化与反序列化的中间载体，供 UserRepository 与 UserStore 使用。
 * 约束：
 *  - 本文件属于 models 层纯类型契约，**严禁**包含任何 I/O 逻辑、Preferences 调用或持久化副作用。
 *  - 不得依赖 UserRepository / UserStore / DataSource 的任何类型，保持零反向依赖。
 *  - history 的顺序语义固定为「最新 → 最旧」，由调用方维护，本类不做时间推断。
 */
export class UserProgressState {
  /** 收藏的知识 ID 集合 */
  favorites: string[];
  /** 最近阅读的知识 ID 序列（最新 → 最旧） */
  history: string[];
  /** 知识点已读 / 完成标记字典 */
  progress: Map<string, boolean>;

  /**
   * @param favorites 收藏 ID 数组
   * @param history 阅读历史 ID 数组（最新 → 最旧）
   * @param progress 已读 / 完成标记字典
   */
  constructor(favorites: string[], history: string[], progress: Map<string, boolean>) {
    this.favorites = favorites;
    this.history = history;
    this.progress = progress;
  }

  /**
   * 构造空状态。
   * 用途：首次启动、Preferences 无数据或数据损坏降级时提供安全初值。
   * @returns 三个字段均为空的 UserProgressState 实例
   */
  static empty(): UserProgressState {
    const emptyFavorites: string[] = [];
    const emptyHistory: string[] = [];
    const emptyProgress: Map<string, boolean> = new Map<string, boolean>();
    return new UserProgressState(emptyFavorites, emptyHistory, emptyProgress);
  }
}
