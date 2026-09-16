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

  // 注：APP_CONTEXT / LOG_LEVEL / LOG_BUNDLE_NAME 为历史遗留键值
  //     （camelCase 无前缀），与上方 embedlab_* 风格不一致。
  //     键值属数据契约，不做重命名以免触发回归。
  /** 应用级 Context（EntryAbility 写入；当前无读取方，契约预留） */
  static readonly APP_CONTEXT: string = 'appContext';
  /** Logger 最小日志级别 */
  static readonly LOG_LEVEL: string = 'logLevel';
  /** Logger 包名标签 */
  static readonly LOG_BUNDLE_NAME: string = 'logBundleName';
}
