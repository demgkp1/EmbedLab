/**
 * AppStorage 键名常量。
 *
 * 职责：集中管理跨页面广播所用的 AppStorage 键，避免在 @StorageLink / @StorageProp
 *      注解与写入侧散落硬编码字符串（一旦拼写不一致将导致刷新静默失效）。
 * 使用范围（V1 仅用于状态版本广播）：
 *  - 版本号为 number 时间戳，仅用于「通知状态已变化」，**不承载业务数据**；
 *    业务数据始终由 stores/UserStore 单例持有，禁止把数组/字典写进 AppStorage。
 * 约束：本文件属于 constants 层纯常量，不含任何 I/O 与业务逻辑。
 */
export class AppStorageKeys {
  /** 收藏版本号（UserStore.updateFavorites / initialize 写入，页面 @StorageLink 监听） */
  static readonly FAVORITES_VERSION: string = 'embedlab_favorites_version';
  /** 阅读历史版本号（UserStore.updateHistory / initialize 写入，页面 @StorageLink 监听） */
  static readonly HISTORY_VERSION: string = 'embedlab_history_version';
}
