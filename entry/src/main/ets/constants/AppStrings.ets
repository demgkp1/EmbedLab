/**
 * 全局通用文案常量。
 *
 * 职责：集中管理跨页面复用的 UI 文案，避免同一句提示语在多个组件中重复出现。
 * 范围：V1 不引入国际化资源（$r('app.string.*')），后续如需多语言再统一迁移。
 */
export class AppStrings {
  /** 应用名称 */
  static readonly APP_NAME: string = 'EmbedLab';

  /** 骨架阶段统一占位提示 */
  static readonly PLACEHOLDER_TITLE: string = '模块建设中';
  static readonly PLACEHOLDER_DESC: string = '该模块将在后续里程碑提供，当前仅验证工程骨架与路由基础设施。';

  /** 一级 Tab 名称 */
  static readonly TAB_HOME: string = '首页';
  static readonly TAB_LEARN: string = '学习';
  static readonly TAB_PROJECTS: string = '项目';
  static readonly TAB_PRACTICE: string = '练习';
  static readonly TAB_PROFILE: string = '我的';

  /** 各一级 Tab 占位说明 */
  static readonly HOME_PLACEHOLDER_TITLE: string = '首页';
  static readonly HOME_PLACEHOLDER_DESC: string = 'V1 仅保留学习状态入口，后续接入学习进度展示。';

  static readonly LEARN_PLACEHOLDER_TITLE: string = '学习';
  static readonly LEARN_PLACEHOLDER_DESC: string = 'V1 核心模块：分类浏览与知识列表，将在 Milestone 2 点亮。';

  static readonly PROJECTS_PLACEHOLDER_TITLE: string = '项目';
  static readonly PROJECTS_PLACEHOLDER_DESC: string = '硬件案例库，V1 阶段保持静态占位。';

  static readonly PRACTICE_PLACEHOLDER_TITLE: string = '练习';
  static readonly PRACTICE_PLACEHOLDER_DESC: string = '嵌入式练习题库，V1 阶段保持静态占位。';

  static readonly PROFILE_PLACEHOLDER_TITLE: string = '我的';
  static readonly PROFILE_PLACEHOLDER_DESC: string = '收藏与阅读历史，将在 Milestone 3 接入本地持久化。';

  /** 路由基础设施验证入口（Milestone 0 临时脚手架，随 KnowledgeDetailPage 落地后移除） */
  static readonly NAV_PROBE_ENTRY: string = '验证二级页面路由（push / pop）';
  static readonly NAV_PROBE_TITLE: string = '路由验证页';
  static readonly NAV_PROBE_DESC: string = '本页由 NavDestination 承载，压入唯一根 NavPathStack，用于验证 push / pop 基础设施。';
  static readonly NAV_PROBE_PARAM_PREFIX: string = '路由参数来源：';
  static readonly NAV_PROBE_PARAM_EMPTY: string = 'null（本页未传递业务参数）';
  static readonly NAV_PROBE_PUSH_AGAIN: string = '再次 push 本页';
  static readonly NAV_PROBE_POP: string = '返回上一页（pop）';
}
