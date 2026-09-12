import { hilog } from '@kit.PerformanceAnalysisKit';
import { LogLevel } from './LogLevel';

/** hilog 业务域标识（十六进制）。 */
const DOMAIN: number = 0x9527;
/** AppStorage 中记录全局日志等级的键，由应用入口唯一写入。 */
const LOG_LEVEL_KEY: string = 'logLevel';
/** AppStorage 中记录应用 bundleName 的键，由应用入口唯一写入。 */
const BUNDLE_NAME_KEY: string = 'logBundleName';

/**
 * 统一日志门面。
 *
 * 职责：全应用唯一日志出口，封装 hilog 并统一携带业务 ModuleTag。
 * 约束：
 *  - 业务代码禁止直接调用 hilog / console.log，必须经由此门面。
 *  - 日志等级由应用入口通过 configure() 统一设定一次；业务代码不得各自设置等级。
 *    构建 Release 包时由入口传入 LogLevel.INFO，即可自动关闭 DEBUG 级别输出。
 *  - 本类属于 utils 层纯工具，不持有任何业务状态，不参与四层数据流。
 */
export class Logger {
  /**
   * 由应用入口调用一次，完成日志门面初始化。
   * @param bundleName 应用包名，用于 hilog 日志域标识
   * @param minLevel 最低输出等级
   */
  static configure(bundleName: string, minLevel: LogLevel): void {
    AppStorage.setOrCreate<string>(BUNDLE_NAME_KEY, bundleName);
    AppStorage.setOrCreate<LogLevel>(LOG_LEVEL_KEY, minLevel);
  }

  /** 输出 DEBUG 级别日志，用于开发期链路追踪。 */
  static debug(moduleTag: string, message: string): void {
    Logger.write(LogLevel.DEBUG, moduleTag, message);
  }

  /** 输出 INFO 级别日志，用于关键流程节点。 */
  static info(moduleTag: string, message: string): void {
    Logger.write(LogLevel.INFO, moduleTag, message);
  }

  /** 输出 WARN 级别日志，用于可恢复的异常分支。 */
  static warn(moduleTag: string, message: string): void {
    Logger.write(LogLevel.WARN, moduleTag, message);
  }

  /** 输出 ERROR 级别日志，用于失败分支（建议同时携带 ErrorCode 文本）。 */
  static error(moduleTag: string, message: string): void {
    Logger.write(LogLevel.ERROR, moduleTag, message);
  }

  /** 读取当前生效的最低输出等级；未初始化时按 DEBUG 处理。 */
  private static minLevel(): LogLevel {
    const configured: LogLevel | undefined = AppStorage.get<LogLevel>(LOG_LEVEL_KEY);
    return configured === undefined ? LogLevel.DEBUG : configured;
  }

  /** 读取日志域标识；未初始化时回退为占位包名。 */
  private static domain(): string {
    const configured: string | undefined = AppStorage.get<string>(BUNDLE_NAME_KEY);
    return configured === undefined ? 'EmbedLab' : configured;
  }

  /** 依据当前阈值决定是否真正落盘输出。 */
  private static write(level: LogLevel, moduleTag: string, message: string): void {
    if (level < Logger.minLevel()) {
      return;
    }
    const content: string = `${Logger.levelTag(level)}/${moduleTag}: ${message}`;
    if (level === LogLevel.ERROR) {
      hilog.error(DOMAIN, Logger.domain(), '%{public}s', content);
    } else if (level === LogLevel.WARN) {
      hilog.warn(DOMAIN, Logger.domain(), '%{public}s', content);
    } else {
      hilog.info(DOMAIN, Logger.domain(), '%{public}s', content);
    }
  }

  /** 将等级枚举转换为紧凑的日志标签。 */
  private static levelTag(level: LogLevel): string {
    switch (level) {
      case LogLevel.DEBUG:
        return 'D';
      case LogLevel.INFO:
        return 'I';
      case LogLevel.WARN:
        return 'W';
      default:
        return 'E';
    }
  }
}
