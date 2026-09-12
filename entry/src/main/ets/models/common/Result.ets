import { ErrorCode } from './ErrorCode';

/**
 * 通用结果模型（可辨识联合类型）。
 *
 * 职责：统一四层之间成功/失败的传递契约，以 success 字段作为可辨识标签，
 *      使调用方在类型层面被强制处理失败分支，杜绝跨层裸抛异常。
 * 约束：
 *  - 底层 I/O 一律返回 Result<T>，禁止 throw Error 穿透到 UI。
 *  - ViewModel 依据 Failure.code 按架构文档 7.3 节映射表转换为 UIStatus，禁止自行发挥。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */

/** 成功分支：data 为已通过校验的强类型结果。 */
export interface Success<T> {
  success: true;
  data: T;
}

/** 失败分支：error 供日志与排障，code 供上层做状态流转判定。 */
export interface Failure {
  success: false;
  error: string;
  code: ErrorCode;
}

/** 统一结果类型：调用方必须先判断 success 再访问 data。 */
export type Result<T> = Success<T> | Failure;
