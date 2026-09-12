/**
 * 页面级 UI 状态枚举。
 *
 * 职责：统一 ViewModel 向 UI 暴露的状态机取值，使加载中/成功/空/错误四态在各页面保持一致。
 * 约束：
 *  - ViewModel 必须依据架构文档 7.3 节的 ErrorCode → UIStatus 标准映射表流转状态，禁止私自发挥。
 *  - UI 只读取该状态决定渲染分支，不得自行猜测失败原因。
 *  - 本文件属于 models 层纯类型契约，不承载任何 I/O 与业务副作用。
 */
export enum UIStatus {
  /** 数据加载中 */
  LOADING,
  /** 加载成功且有数据 */
  SUCCESS,
  /** 目标内容不存在或为空 */
  EMPTY,
  /** 加载失败 */
  ERROR
}
