/**
 * 系统统一错误码。
 *
 * 职责：为四层数据链路（UI → ViewModel → Repository → DataSource）提供可辨识的语义化失败标识，
 *      使底层 I/O 失败能够被上层精确判定，而不是依赖异常文本或字符串猜测。
 * 约束：
 *  - 枚举值与架构文档 7.1 节严格一致，任何新增必须先经人工确认架构变更。
 *  - 判断失败语义必须使用枚举成员，禁止在业务代码中裸写错误码字符串。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export enum ErrorCode {
  FILE_NOT_FOUND = "FILE_NOT_FOUND",
  JSON_INVALID = "JSON_INVALID",
  FIELD_MISSING = "FIELD_MISSING",
  DATA_VERSION_UNSUPPORTED = "DATA_VERSION_UNSUPPORTED",
  STORAGE_READ_FAILED = "STORAGE_READ_FAILED",
  STORAGE_WRITE_FAILED = "STORAGE_WRITE_FAILED",
  UNKNOWN = "UNKNOWN"
}
