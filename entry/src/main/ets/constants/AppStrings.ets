/**
 * 全局通用文案常量。
 *
 * 职责：集中管理跨页面复用的 UI 文案，避免同一句提示语在多个组件中重复出现。
 * 范围：V1 不引入国际化资源（$r('app.string.*')），后续如需多语言再统一迁移。
 */
export class AppStrings {
  /** 应用名称 */
  static readonly APP_NAME: string = 'EmbedLab';

  /** 骨架阶段统一占位提示（仅未注册路由兜底在用，见 MainPage.unregisteredRoute） */
  static readonly PLACEHOLDER_TITLE: string = '模块建设中';

  /** 一级 Tab 名称（UI-Batch-1 阶段一后为 3 个 Tab：首页 / 学习 / 我的） */
  static readonly TAB_HOME: string = '首页';
  static readonly TAB_LEARN: string = '学习';
  static readonly TAB_PROFILE: string = '我的';

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
  /**
   * 空态共享文案（Cleanup-2 归口）。
   *
   * 存在原因：原 PROFILE_EMPTY_FAVORITES_TITLE / PROFILE_EMPTY_HISTORY_TITLE 与
   *          HOME_EMPTY_FAVORITES / HOME_EMPTY_HISTORY 取值完全相同（两组同值键），
   *          属重复定义，故合并为跨页共用的中性名。
   * 两形态共用（键名注释要求）：
   *  - **整页空态**：FavoritesPage.emptyState() / HistoryPage.emptyState()
   *    作为标题行（配 PROFILE_EMPTY_*_DESC 描述行）；
   *  - **区块内空态**：HomePage.sectionEmptyHint() 作为单行轻提示，其上方
   *    区块标题已由 HOME_RECENT_HISTORY_TITLE / HOME_FAVORITES_TITLE 承担。
   * 约束：合并后为跨页共享键，任一页面需独立措辞时应重新拆分，不得就地改写。
   */
  static readonly EMPTY_FAVORITES: string = '还没有收藏';
  static readonly EMPTY_HISTORY: string = '还没有阅读记录';
  static readonly PROFILE_EMPTY_FAVORITES_DESC: string = '在知识详情页点击右上角星标即可收藏。';
  static readonly PROFILE_EMPTY_HISTORY_DESC: string = '打开任意知识详情页后会自动记录阅读足迹。';
  static readonly PROFILE_ERROR_TITLE: string = '数据加载失败';

  /** 极客代码块（GeekCodeBlock） */
  static readonly CODE_COPY: string = '复制';
  static readonly CODE_COPIED_TOAST: string = '代码已复制';
  static readonly CODE_COPY_FAILED_TOAST: string = '复制失败，请重试';

  /** 通用错误文案：知识仓库尚未完成依赖注入（3 个 ViewModel 共用） */
  static readonly ERROR_REPOSITORY_NOT_READY: string = '知识仓库尚未完成依赖注入';

  /** Learn 页分类胶囊「全部」项 */
  static readonly LEARN_CATEGORY_ALL: string = '全部';

  /**
   * Learn 页难度胶囊「全部」项（C-1 难度筛选）。
   * 说明：与 LEARN_CATEGORY_ALL 取值相同但**语义不同**（分类维度 vs 难度维度），
   *      按产品决策 D1 独立成键，避免二者日后各自演化时互相牵连。
   */
  static readonly LEARN_LEVEL_ALL: string = '全部';
  /**
   * 双维度筛选组合为空时的空态文案（C-1，产品决策 D4）。
   * 说明：与 LEARN_EMPTY_TITLE（数据源为空）语义严格区分 ——
   *      前者是「数据在但被筛掉了」，后者是「压根没读到数据」。
   */
  static readonly LEARN_EMPTY_FILTERED: string = '当前筛选条件下没有匹配的知识点';

  /**
   * 筛选栏维度标签（UI-Polish-1）。
   * 存在原因：两条筛选栏的首项都是「全部」，用户无法从胶囊本身区分维度，
   *          故在每排左侧加一枚小字标签予以消歧。
   */
  static readonly LEARN_FILTER_CATEGORY_LABEL: string = '分类';
  static readonly LEARN_FILTER_LEVEL_LABEL: string = '难度';

  /** 首页（HomePage） */
  static readonly HOME_WELCOME_DESC: string = '知识体系 · 学习路径 · 实践项目';
  static readonly HOME_RECENT_HISTORY_TITLE: string = '最近阅读';
  static readonly HOME_FAVORITES_TITLE: string = '收藏概览';
  static readonly HOME_FAVORITES_COUNT: string = '已收藏 ';
  static readonly HOME_QUICK_ENTRY: string = '快捷入口';

  /** Profile 二级入口字形（工程无 media 图标资源，统一用 Unicode 字形方案） */
  static readonly PROFILE_ENTRY_GLYPH_FAVORITES: string = '★';
  static readonly PROFILE_ENTRY_GLYPH_HISTORY: string = '⏱';
  static readonly PROFILE_ENTRY_GLYPH_SETTINGS: string = '⚙';
  static readonly PROFILE_ENTRY_GLYPH_ABOUT: string = 'ⓘ';
  /** 入口行右侧指示箭头 */
  static readonly PROFILE_ENTRY_ARROW: string = '›';

  /** Profile 概览卡与二级入口 */
  static readonly PROFILE_OVERVIEW_TITLE: string = '学习概览';
  static readonly PROFILE_OVERVIEW_FAVORITES: string = '收藏';
  static readonly PROFILE_OVERVIEW_HISTORY: string = '已读';
  static readonly PROFILE_ENTRY_FAVORITES: string = '我的收藏';
  static readonly PROFILE_ENTRY_HISTORY: string = '阅读历史';
  static readonly PROFILE_ENTRY_SETTINGS: string = '设置';
  static readonly PROFILE_ENTRY_ABOUT: string = '关于';

  /** 设置页（取值来源见各常量注释，均为静态常量，非运行时计算） */
  /** 版本文本：AppScope/app.json5 L6 versionName */
  static readonly SETTINGS_VERSION_NAME: string = '1.0.0';
  /** 版本号：AppScope/app.json5 L5 versionCode */
  static readonly SETTINGS_VERSION_CODE: string = '1000000';
  /** 构建号：AppScope/app.json5 L7 buildVersion */
  static readonly SETTINGS_BUILD_VERSION: string = '1';
  /** 知识索引 sha256 前 8 位：docs/pipeline/STATE.md 记录值（构建产物哈希，非包内数据） */
  static readonly SETTINGS_INDEX_SHA256_PREFIX: string = '233c11dc';
  static readonly SETTINGS_LABEL_VERSION: string = '版本';
  static readonly SETTINGS_LABEL_BUILD: string = '构建号';
  static readonly SETTINGS_LABEL_INDEX_HASH: string = '索引校验';
  static readonly SETTINGS_NOTE: string = '以上信息为构建期常量，非运行时计算。';

  /** 关于页 */
  static readonly ABOUT_APP_NAME_TEXT: string = 'EmbedLab 嵌入式学习平台';
  static readonly ABOUT_SLOGAN: string = '知识体系 → 学习路径 → 实践项目';
  static readonly ABOUT_DESC: string = '基于 HarmonyOS NEXT 原生 ArkUI 构建的嵌入式系统学习平台，离线可用。';
  static readonly ABOUT_SECTION_DATA: string = '内容与数据';
  static readonly ABOUT_DATA_DESC: string = '知识内容以只读 JSON 资产随包发布，用户收藏与阅读足迹经 Preferences 本地持久化。';
  static readonly ABOUT_SECTION_TECH: string = '技术架构';
  static readonly ABOUT_TECH_DESC: string = '单根 Navigation 路由栈 · 四层单向架构（UI → ViewModel → Repository → DataSource）· 静态依赖注入。';
}
