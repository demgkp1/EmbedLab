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

  /** 一级 Tab 文案 */
  static readonly HOME_PLACEHOLDER_TITLE: string = '首页';
  static readonly HOME_PLACEHOLDER_DESC: string = 'V1 仅保留学习状态入口，后续接入学习进度展示。';

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

  /** 收藏星标字形（跨页面复用：详情页标题栏 / Learn 列表标记） */
  static readonly GLYPH_STAR_FILLED: string = '★';
  static readonly GLYPH_STAR_OUTLINE: string = '☆';

  /** 通用重试按钮文案（四个页面共用） */
  static readonly MSG_RETRY: string = '重新加载';

  /** 警示块前缀（详情页 warning 块专用） */
  static readonly WARNING_PREFIX: string = '⚠️ ';

  /** 知识详情页（KnowledgeDetailPage） */
  static readonly DETAIL_LOADING: string = '正在加载知识正文…';
  static readonly DETAIL_EMPTY_TITLE: string = '未找到该知识条目';
  static readonly DETAIL_EMPTY_DESC: string = '该内容可能已被移除，或 details 目录下缺少对应 JSON 文件。';
  static readonly DETAIL_ERROR_TITLE: string = '知识正文加载失败';
  static readonly DETAIL_DEFAULT_TITLE: string = '知识详情';

  /** 知识列表页（LearnPage） */
  static readonly LEARN_LOADING: string = '正在加载知识库…';
  static readonly LEARN_EMPTY_TITLE: string = '暂无数据，请检查 rawfile';
  static readonly LEARN_EMPTY_DESC: string = '未在 resources/rawfile/database/knowledge/index.json 中读到任何知识条目。';
  static readonly LEARN_ERROR_TITLE: string = '知识索引加载失败';

  /** 我的页（ProfilePage） */
  static readonly PROFILE_TAB_FAVORITES: string = '我的收藏';
  static readonly PROFILE_TAB_HISTORY: string = '阅读历史';
  static readonly PROFILE_LOADING: string = '正在加载…';
  static readonly PROFILE_EMPTY_FAVORITES_TITLE: string = '还没有收藏';
  static readonly PROFILE_EMPTY_FAVORITES_DESC: string = '在知识详情页点击右上角星标即可收藏。';
  static readonly PROFILE_EMPTY_HISTORY_TITLE: string = '暂无阅读记录';
  static readonly PROFILE_EMPTY_HISTORY_DESC: string = '打开任意知识详情页后会自动记录阅读足迹。';
  static readonly PROFILE_ERROR_TITLE: string = '数据加载失败';

  /** 极客代码块（GeekCodeBlock） */
  static readonly CODE_COPY: string = '复制';
  static readonly CODE_COPIED_TOAST: string = '代码已复制';
  static readonly CODE_COPY_FAILED_TOAST: string = '复制失败，请重试';
}
