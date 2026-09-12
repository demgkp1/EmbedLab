/**
 * 日志等级。
 *
 * 职责：为 Logger 门面提供显式等级枚举，避免散落字符串级别导致的拼写错误。
 * 说明：等级数值递增，Logger 依据当前阈值过滤。
 */
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  NONE = 4
}
