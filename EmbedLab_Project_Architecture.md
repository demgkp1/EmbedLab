# EmbedLab 项目架构说明文档

Version: 1.0.0  
Status: Architecture Frozen  
Last Update: 2026-09  

---

## 1. 当前项目目标

EmbedLab 是一个基于 HarmonyOS 原生技术开发的嵌入式系统体系化学习平台。

目标不是制作普通笔记应用，而是构建：

> 知识体系 → 学习路径 → 实践项目 → 能力训练

的完整学习闭环。

第一阶段不接入云端后端，不直接集成大模型，DeepSeek 仅作为辅助开发的智能体（Agent）。

---

## 2. 核心架构原则（Architecture Principles）

为了保证项目的长期可维护性并杜绝过度设计，本项目必须严格遵守以下核心架构原则：

### 原则一：数据资产与应用状态绝对分离
- 内容资产（Content Assets）：由开发者维护、只读、随应用打包。来源：resources/rawfile/database/。包含：知识库、项目案例、练习题库，内含 schema_version.json 用于版本追踪与向下兼容性判定。
- 用户状态（User State）：由用户在运行时产生、可写。V1 阶段采用 @ohos.data.preferences 轻量持久化。持久化数据必须设定安全边界，历史记录严格执行 30 条先进先出（FIFO）定长控制。
- Preferences 序列化安全红线：复杂对象（如 ID 数组、进度字典）统一经由 JSON.stringify() 写入；读取后必须经过严格字段校验，严禁直接使用 as 类型断言强转。

### 原则二：严格单向分层与静态依赖注入（DI）
- 数据链路严格保持 4 层：UI (Page/Component) → ViewModel → Repository → DataSource。
- 依赖注入（DI）规范：严禁 ViewModel 内部直接 new Repository()，严禁 Repository 内部直接 new DataSource()。统一通过 utils/providers/ 下的 RepositoryProvider 与 DataSourceProvider 静态工厂获取依赖实例，确保未来数据源无缝切换（如替换为 SQLite）且便于单元测试。
- 容器职责拆解：MainPage 仅负责创建并私有持有全局 Navigation 容器与根 NavPathStack（不使用状态装饰器暴露）；Tabs 的布局与 TabContent 的组织交由 RootTabContainer 组件管理，防止入口页面代码膨胀。子页面按「导航防踩坑铁律」所述方式取栈。
- ViewModel 职责边界：ViewModel 严禁直接持有任何 UI Component 或 PageController 引用。ViewModel 仅负责 UI 状态维护、用户交互响应、状态流转与调度 Repository，绝对不参与 UI 布局渲染与组件生命周期管理。
- UserStore 定位与生命周期：UserStore 仅作为内存态的响应式状态中心，不直接与底层 I/O 交互。App 启动时，由 MainPage 生命周期驱动 UserRepository 读取 Preferences，并通过 UserStore.initialize(state) 完成内存注水。
- Profile 数据防腐：Profile 页面展示收藏内容时，必须由 ProfileViewModel 调用 UserRepository 获取 ID 集合，再经由 KnowledgeRepository 批量聚合为展示实体，禁止 UI 层自行遍历查询。
- 业务复杂度驱动 Service：第一阶段坚决不引入空转透传的 Service 层。

### 原则三：按需分级加载与受控内存缓存
- 静态资产分级存储：静态知识库严禁在启动时全量解析全部正文。必须拆分为轻量索引元数据（index.json）与单篇详情正文（details/{id}.json）。
- Repository 内存缓存原则：KnowledgeRepository 允许且仅允许持有进程生命周期内的只读内存缓存（metadataCache 缓存索引，detailCache: Map<string, KnowledgeItem> 缓存已打开的正文），杜绝重复滑动与重复打开时的无意义文件 I/O，但 Repository 严禁承担持久化职责。

### 原则四：MVP 绝对优先原则
- 评判标准：“没有该模块，核心学习闭环（找知识 → 读知识）能否跑通？”如果能，该模块一律在 V1 阶段作为占位处理。

### 原则五：严格类型收窄、标准化错误码与 UI 映射
- 底层 I/O 统一返回携带强类型 ErrorCode 的可辨识联合类型 Result<T>，禁止在层间随意裸抛异常（throw Error）。
- ViewModel 必须基于严格的 ErrorCode 到 UIStatus 映射表流转状态，杜绝各自随意发挥导致错误提示混乱。
- 路由跳转与参数获取必须使用具名强类型参数对象，严禁传递匿名隐式对象。
- 界面视觉统一抽取为全局常量（AppColors, AppDimens, AppStrings），严禁散落魔法值（Magic Values）。

---

## 2.1 Agent 施工工序与验证门禁协议（Workflow & Verification Gate）

为了杜绝大模型一次性盲目生成大批文件导致运行时故障，所有 AI Agent 必须遵守以下工程执行纪律：

### 1. 微任务步进原则（Micro-Tasking）
- 严禁单个指令跨越多个架构层级。每个任务只允许修改/新增 3~5 个强相关文件。
- 执行节奏严格锁定为：【单点编码】 -> 【编译检查】 -> 【本地单测/模拟器点亮】 -> 【人类确认】 -> 【进入下一小步】。

### 2. 真实性验证优先（API & Runtime Reality）
- 静态编译通过（assembleHap）只是第一步。
- 涉及 UI 变更时，必须提示人类进行真机/模拟器肉眼观察（确认无高度塌陷、无空白遮挡、无同色文字）。
- 涉及逻辑变更时，必须通过 `src/test/` 单元测试输出事实日志（PASS/FAIL），禁止凭空宣称已验证。

### 3. ArkUI 防御性编码红线
- 严禁在页面根 Navigation 上滥用 `.hideNavBar(true)`，隐藏顶部栏只能使用 `.hideTitleBar(true)`。
- 凡使用 `Tabs({ index: this.currentIndex })`，必须显式配对实现 `.onChange((index: number) => { this.currentIndex = index; })`。
- 页面顶层容器必须显式声明 `.width('100%').height('100%')`。

---

## 3. 当前开发任务

### 阶段目标：完成 EmbedLab V1.0 MVP
- HarmonyOS NEXT 原生单路由栈架构（Navigation + NavDestination 体系）
- 模块级依赖注入 Provider 落地
- 独立于数据的工程骨架（零数据依赖即可正常启动运行）
- 动静分离与按需加载机制（知识索引与正文按需读取 + 内存只读缓存）
- 本地只读知识库驱动（rawfile JSON + 强类型校验 + 语义化 ErrorCode）
- 规范化 UserStore 启动恢复链路与轻量持久化（收藏、30条定长历史足迹）
- 自动化单元测试骨架（覆盖 DataSource 与 Repository 边界分支）
- 项目库与题库（V1 阶段仅做占位展示）

---

## 4. 产品模块与导航拓扑架构

### 推荐 V1 导航结构（Root Navigation 包含 RootTabContainer）

全局采用单一根路由栈拓扑，落实 V1 单栈约束与状态注入：

MainPage（入口骨架）
└── Navigation(this.navPathStack)（全屏单一根路由容器，模式设为 Stack）
    └── RootTabContainer()（抽离出的独立根 Tab 容器组件）
        └── Tabs()
            ├── TabContent(Home - 首页)：学习状态总览入口，V1 简化展示
            ├── TabContent(Learn - 学习)：★ V1 核心闭环：分类浏览、知识条目列表
            ├── TabContent(Projects - 项目)：硬件案例库，V1 静态占位
            ├── TabContent(Practice - 练习)：嵌入式题库，V1 静态占位
            └── TabContent(Profile - 我的)：★ V1 包含：收藏列表、阅读历史

### 导航防踩坑铁律（V1 单栈与生命周期约束）
- 栈生命周期管理：NavPathStack 实例由 MainPage 创建，并以**普通私有成员变量**持有（`private navPathStack: NavPathStack`）。**严禁**用 @Provide / @State / @Link 等状态装饰器修饰该成员——NavPathStack 是 Navigation 组件在渲染期内部会写入的可变控制器，一旦被状态系统观察，即触发 ArkUI 告警 `State variable 'navPathStack' has changed during render!`。子页面/子组件获取根栈统一采用以下两种方式之一：① 在 `NavDestination` 的 onReady 回调中经 `NavDestinationContext.pathStack` 取得；② 在自定义组件内调用 `this.queryNavigationInfo()?.pathStack` 取得。两种方式返回的都是 MainPage 创建的那一个根栈实例。
- 严禁在任何子组件、子页面内部执行 new NavPathStack()，严禁在任何 TabContent 内部嵌套独立 Navigation 容器。
- 路由参数必须通过 Navigation/NavPathStack 的官方参数机制获取，并在 NavDestination 生命周期中完成解析和校验；具体 API 调用方式必须以当前 SDK 官方 API 为准，严禁调用已废弃的 router.getParams()，严禁传递匿名对象。
- 二级页面（如 KnowledgeDetailPage）通过根路由栈的 pushPathByName() 调起，由 NavDestination 承载，压入根栈并全屏覆盖底部 Tabs。
- 返回时由 NavDestination 自带返回逻辑调用 pop()，退回前一个 Tab，底层状态完全保留。

### 核心页面清单与职责

- MainPage (pages/MainPage.ets) | MVP 核心 | 根页面，初始化 Navigation 与 NavPathStack 注入，挂载 RootTabContainer，触发 UserStore 启动恢复
- RootTabContainer (components/RootTabContainer.ets) | MVP 核心 | 负责 Tabs 布局与 5 个一级 TabContent 的排布组织
- LearnPage (pages/learn/LearnPage.ets) | MVP 核心 | 知识分类切换与知识条目列表渲染（读取轻量 index 数据）
- KnowledgeDetailPage (pages/learn/KnowledgeDetailPage.ets) | MVP 核心 | NavDestination 承载，onReady 提取参数，按需加载并渲染教材式知识详情，支持收藏与足迹记录
- ProfilePage (pages/profile/ProfilePage.ets) | MVP 核心 | 展示收藏的知识与最近阅读记录，严格通过 ViewModel 获取聚合数据
- HomePage (pages/home/HomePage.ets) | V1 简化 | 快捷入口与进度展示占位
- ProjectsPage (pages/projects/ProjectsPage.ets) | 后续扩展 | 硬件项目案例库（V1 静态占位）
- PracticePage (pages/practice/PracticePage.ets) | 后续扩展 | 嵌入式练习题库（V1 静态占位）

---

## 5. ArkTS 工程分层架构与目录规划

采用轻量 4 层单向驱动：

UI Layer (Pages & Components)
      ↓
ViewModel Layer (持有 UI 状态枚举与用户意图处理，通过 Provider 获取依赖)
      ↓
Repository Layer (数据策略中枢：调度只读资产/内存缓存或调度用户状态持久化)
      ↓
DataSource Layer (底层 I/O：RawFile 读取解码校验 / Preferences 存取)

### 完整工程目录树（基于 entry/src/）

entry/src/
├── test/                   # 本地单元测试目录（Local Unit Tests）
│   ├── datasources/        # DataSource 边界测试（非法 JSON、缺失字段、版本越界等）
│   │   └── RawFileAssetDataSource.test.ets
│   └── repositories/       # Repository 业务与缓存测试
│       └── KnowledgeRepository.test.ets
└── main/
    ├── resources/
    │   ├── base/
    │   │   ├── element/    # 系统字符串、颜色等资源
    │   │   └── media/      # 本地静态图片素材（电路图、原理图、引脚定义）
    │   │       ├── knowledge/
    │   │       └── projects/
    │   └── rawfile/
    │       └── database/   # 只读数据文件（分级 JSON 资产）
    │           ├── schema_version.json
    │           ├── knowledge/
    │           │   ├── index.json      # 全量知识元数据列表（轻量）
    │           │   └── details/        # 各知识点完整正文（按需单篇加载）
    │           │       └── stm32_gpio_basic.json
    │           ├── projects/
    │           ├── questions/
    │           └── config/
    └── ets/
        ├── constants/          # 全局常量规范
        │   ├── AppColors.ets   # 品牌色、背景色、文字颜色常量
        │   ├── AppDimens.ets   # 内边距、圆角、字号尺寸常量
        │   ├── AppStrings.ets  # 提示文案与常用字符串常量
        │   └── RouteConstants.ets # 路由名称常量
        ├── models/             # 业务数据模型（严格模式，按业务域模块化组织）
        │   ├── common/         # 通用基础模型（Result 联合类型、ErrorCode 枚举、UIStatus 枚举、路由参数模型）
        │   ├── knowledge/      # 知识库模型（KnowledgeItem、KnowledgeMetadata、CategoryItem、CodeSnippet）
        │   ├── user/           # 用户状态模型（UserProgressState）
        │   └── project/        # 项目案例模型（ProjectItem，供扩展）
        ├── datasources/        # 底层数据读写与安全校验实现
        │   ├── RawFileAssetDataSource.ets # 读取 rawfile 资产 JSON，负责解码、版本比对与字段校验
        │   └── PreferenceDataSource.ets   # 封装系统 Preferences 轻量持久化与序列化
        ├── repositories/       # 数据仓库
        │   ├── KnowledgeRepository.ets   # 知识索引查询、按需正文提取、内存缓存、分类聚合
        │   └── UserRepository.ets        # 用户状态持久化、启动水化与更新调度
        ├── stores/             # 全局响应式状态中枢
        │   └── UserStore.ets   # 内存态单例，持有一级响应式状态，暴露 initialize(state) 注入接口
        ├── viewmodels/         # 页面级状态管理，维护 Loading / Success / Empty / Error 状态
        ├── components/         # 全局通用 ArkUI 组件（RootTabContainer、状态缺省页、代码块展示等）
        ├── pages/              # 页面与路由模块
        │   ├── MainPage.ets    # 应用根骨架
        │   ├── home/
        │   ├── profile/
        │   ├── projects/
        │   ├── practice/
        │   └── learn/
        │       ├── LearnPage.ets
        │       ├── KnowledgeDetailPage.ets
        │       └── components/ # learn 模块内部私有可复用组件，防止全局组件目录污染
        └── utils/              # 纯通用工具函数
            ├── providers/      # 静态工厂依赖提供器（RepositoryProvider, DataSourceProvider）
            ├── logger/         # 统一日志门面与等级控制（Logger.ets, LogLevel.ets）
            └── format/         # 时间、文本格式化工具

---

## 6. 数据设计与存储规范

### 6.1 静态只读资产（Content Assets）
目录：resources/rawfile/database/

#### 版本与兼容性配置（schema_version.json）
- schemaVersion: 字符串，数据规范版本号（如 1.0.0）
- minAppVersion: 字符串，所要求的最低 App 版本号（如 1.0.0）
- maxAppVersion: 字符串，当前数据结构所兼容的最大 App 主版本号（如 1.x）
DataSource 初始化时必须严格执行双向版本判定：若 App 版本 < minAppVersion 或 App 主版本超出 maxAppVersion 兼容区间，立即返回 DATA_VERSION_UNSUPPORTED 错误码，严禁执行后续解析。

#### V1 内容规模与素材引用规范
- 知识文章数量上限：V1 阶段总篇数 ≤ 100 篇。
- 单篇 JSON 大小上限：单文件 ≤ 500KB。
- 单张图片素材上限：单张图片大小 ≤ 2MB（2048KB），格式严格限制为 PNG / JPG / WebP，严禁以 Base64 内联在 JSON 中。
- 素材引用规范：图片以相对路径数组统一维护在 images: string[] 字段中（如 ["knowledge/gpio/pinmode.png"]），对应实体放置在 resources/base/media/ 下。
- 代码格式原则：代码示例以纯文本结合 CodeSnippet 结构存储。

#### 分级存储目录与数据模型

1. 知识索引模型（models/knowledge/KnowledgeMetadata.ets，存储于 knowledge/index.json）：
- id: 字符串，唯一标识（如 stm32_gpio_basic）
- title: 字符串，标题（如 GPIO 基础原理与工作模式）
- category: 字符串，分类标识（如 MCU_Peripherals）
- level: 字符串，难度等级（Basic / Medium / Hard）
- tags: 字符串数组，技术标签
- summary: 字符串，文章概括/卡片摘要

2. 代码片段模型（models/knowledge/CodeSnippet.ets）：
- language: 字符串，编程语言（如 C, Assembly）
- code: 字符串，纯文本源代码
- description: 字符串，代码重点说明
- highlightLines?: 数字数组，需要高亮显示的行号集合

3. 完整知识详情模型（models/knowledge/KnowledgeItem.ets，存储于 knowledge/details/{id}.json）：
- id: 字符串，唯一标识
- title: 字符串，标题
- category: 字符串，分类标识
- level: 字符串，难度等级
- tags: 字符串数组，技术标签
- summary: 字符串，文章概括
- images: 字符串数组，引用的图片相对路径集合（对应 resources/base/media/）
- content: 教材化结构正文对象
  - prerequisite: 字符串，学习前置要求
  - objective: 字符串，学习目标
  - concept: 字符串，核心概念
  - principle: 字符串，工作原理
  - example: CodeSnippet 实体，结构化代码示例
  - experiment: 字符串，实操验证与接线实验指南
  - tips: 字符串，工程经验与避坑要点
  - commonErrors: 字符串，常见致命错误排查
  - keyPoints: 字符串数组，章节核心总结条目（避免与外层 summary 命名冲突）
- relatedProjectIds: 字符串数组，关联项目案例 ID

#### JSON 数据校验与防腐原则
RawFileAssetDataSource 必须实现防御性校验，返回 Result<T>：
1. 校验必填字段是否存在。
2. 校验复合字段合法性（如 example 中的 language/code 是否齐全，tags/images 是否为 Array，缺失时设置安全默认值）。
3. 校验失败时返回明确的 Failure 结果与具体 ErrorCode（如 JSON_INVALID、FIELD_MISSING），严禁在业务层引发未捕获的运行时异常。

### 6.2 运行时用户状态（User State）
使用系统 @ohos.data.preferences 轻量存储，Key-Value 组织：
- user_favorites: 序列化后的 string（收藏的知识 ID 数组）
- user_history: 序列化后的 string（最近阅读的知识 ID 序列，按时间倒序）
- user_progress: 序列化后的 string（知识点已读/完成标记字典）

#### 历史记录容量限制原则（FIFO）与反序列化校验
- user_history 必须实施定长先进先出（FIFO）队列策略，最大保存上限严格设定为 30 条。新增足迹超过上限时，自动移除最旧记录。
- PreferenceDataSource 反序列化读取数据时，必须检查解析结果是否满足目标数组/字典结构，解析失败必须降级回退为空数组/空字典，严禁直接使用 as 类型断言。

---

## 7. 状态流转、异常与生命周期规范

### 7.1 错误码枚举（models/common/ErrorCode.ets）

export enum ErrorCode {
  FILE_NOT_FOUND = "FILE_NOT_FOUND",
  JSON_INVALID = "JSON_INVALID",
  FIELD_MISSING = "FIELD_MISSING",
  DATA_VERSION_UNSUPPORTED = "DATA_VERSION_UNSUPPORTED",
  STORAGE_READ_FAILED = "STORAGE_READ_FAILED",
  STORAGE_WRITE_FAILED = "STORAGE_WRITE_FAILED",
  UNKNOWN = "UNKNOWN"
}

### 7.2 通用结果模型（models/common/Result.ets）

export interface Success<T> {
  success: true
  data: T
}

export interface Failure {
  success: false
  error: string
  code: ErrorCode
}

export type Result<T> = Success<T> | Failure

### 7.3 ErrorCode 到 UIStatus 的标准映射规则
ViewModel 在接收到 Result.Failure 时，必须严格遵循以下状态映射，禁止私自发挥：
- FILE_NOT_FOUND 映射为 UIStatus.EMPTY（目标内容不存在或已被移除，展示缺省空页面）。
- JSON_INVALID 映射为 UIStatus.ERROR（数据文件损坏，提示数据格式异常）。
- DATA_VERSION_UNSUPPORTED 映射为 UIStatus.ERROR（提示当前应用版本过低，请升级后使用）。
- STORAGE_READ_FAILED / STORAGE_WRITE_FAILED 映射为 UIStatus.ERROR（轻提示存储异常，不阻断主流程）。
- UNKNOWN 映射为 UIStatus.ERROR（展示通用重试页面）。

### 7.4 完整状态生命周期时序

#### 阶段 A：应用启动与 UserStore 状态水化（Hydration）
1. 应用冷启动，MainPage 的 aboutToAppear() 生命周期触发。
2. MainPage 的 aboutToAppear() 触发 MainViewModel.initializeApp()，由 MainViewModel 调度 UserRepository。
3. UserRepository 调用 PreferenceDataSource 读取本地持久化数据。
4. 反序列化与格式校验成功后，UserRepository 调用 UserStore.initialize(loadedState) 将持久化状态注入内存单例。
5. 全局状态就绪，后续所有页面均从 UserStore 获取响应式状态。

#### 阶段 B：用户收藏状态流转
1. 用户在 KnowledgeDetailPage 点击收藏图标。
2. UI 触发 KnowledgeDetailViewModel.toggleFavorite(id)。
3. ViewModel 调用 UserRepository.toggleFavorite(id)。
4. UserRepository 驱动 PreferenceDataSource 完成序列化并写入磁盘。
5. 写入成功后，UserRepository 触发 UserStore.updateFavorites(newFavorites) 更新内存状态。
6. LearnPage 与 ProfilePage 监听 UserStore 的状态，驱动 UI 收藏图标响应式同步变色。

---

## 8. 开发约束与技术底线

必须严格遵守：

1. ArkTS 严格静态类型：所有数据模型必须由 interface 或 class 严格定义，严禁使用 any，对象字段必须显式声明。
2. 现代单栈路由：全应用基于唯一根 Navigation + NavPathStack 构建，由 MainPage 注入，严禁在 TabContent 内部嵌套 Navigation 或独立 new NavPathStack。
3. 强类型传参与提取：路由跳转必须使用专属定义模型（KnowledgeDetailParams），提取参数必须通过 NavDestination 的 onReady 上下文获取，严禁使用 router.getParams()。
4. 依赖解耦（DI）：ViewModel 与 Repository 必须通过 RepositoryProvider 与 DataSourceProvider 静态获取依赖，严禁在类内部直接硬编码 new 构造依赖项。
5. 视觉规范集中化：全局颜色、尺寸与通用文案必须统一从 constants/ 引用，禁止在组件内散落裸写魔法值。
6. 状态管理收敛：
   - 页面级/组件级私有状态：使用 ArkUI 响应式状态管理（如 @State）。
   - 全局跨页面共享状态：统一由 stores/UserStore 单例维护，组件按需监听。
7. 数据与页面解耦：禁止在 Page/Component 内部直接写 resourceManager 或 JSON.parse。UI 只能读取 ViewModel 暴露的状态。
8. 异步操作非阻塞：rawfile 读取与 JSON 解码必须在 DataSource 层封装为异步 Promise<Result<T>>，严禁占用主线程导致滑动卡顿。
9. 规范日志输出与级别控制：全应用统一使用 utils/logger 封装的 Logger 门面输出日志（附带 ModuleTag 与 ErrorCode）。生产模式（Release）必须自动关闭 DEBUG 级别日志输出，禁止散落未经管理的 console.log。

---

## 9. 自动化单元测试策略（Unit Test Strategy）

为了保障强类型体系与异常兜底的可靠性，工程必须在 entry/src/test/ 维护核心单元测试：

### 测试范围与用例矩阵
1. RawFileAssetDataSource 边界测试：
   - 正常解析测试：给定合规 index.json 与 detail.json，验证能完整转化为对应强类型模型。
   - 字段缺失测试：故意破坏 detail.json 中的必填字段（如缺少 id 或 content），验证能够捕获并返回 FIELD_MISSING 错误码。
   - 损坏数据测试：传入非法 JSON 文本，验证能够捕获并返回 JSON_INVALID 错误码。
   - 版本越界测试：修改 schema_version.json 中 minAppVersion 大于当前版本，验证触发 DATA_VERSION_UNSUPPORTED 拦截。
2. KnowledgeRepository 缓存与逻辑测试：
   - 内存命中测试：连续两次调用 getKnowledgeDetail(id)，验证第二次直接命中 detailCache，不重复调用 DataSource。
   - 空数据测试：查询不存在的 ID，验证返回 FILE_NOT_FOUND 错误码。

---

## 10. Agent 禁止行为清单（Prohibited Behaviors）

所有辅助开发的 AI Agent 必须严格遵守以下红线禁止行为：

1. 禁止修改已处于 Architecture Frozen 状态的架构文档（如 EmbedLab_Project_Architecture.md）。任何架构变更必须经人工确认。
2. 禁止使用已废弃的旧版 router（如 router.pushUrl、router.getParams、router.replaceUrl）。
3. 禁止在子组件或页面内部私自 new NavPathStack()。
4. 禁止在 ViewModel 内部直接 new Repository()，禁止在 Repository 内部直接 new DataSource()。
5. 禁止在 Page/Component 层直接调用 resourceManager 读取底层资产。
6. 禁止在 Page/Component 层直接读取或写入 Preferences。
7. 禁止在任何 ArkTS 代码中使用 any 类型声明。
8. 禁止在路由跳转时传递匿名对象字面量。
9. 禁止在 Preferences 反序列化时使用未经结构校验的 as 类型断言。
10. 禁止使用 Base64 格式内嵌大图，禁止引入未压缩超过 500KB 的图片。
11. 禁止在 Page 中硬编码大段静态 mock 数据充当业务展示。
12. 禁止为了未来功能提前创建无实际逻辑的空转 Service 类或提前实现复杂的搜索分词引擎。
13. 禁止引入任何未经验证的第三方重量级 UI 框架。
14. 禁止一次性生成大批量互不关联的文件，开发推进必须按单模块步进验收并配套单元测试。

---

## 11. 暂不开发内容（Strictly Out of Scope for V1）

当前版本坚决不实现：
- 关系型数据库（SQLite / RelationalStore）复杂表设计
- 全文搜索分词索引 / 端侧向量检索 / SearchService
- AI 助教管道 / 提示词管理 / 文本切片
- 后端服务器 / HTTP 网络请求
- 用户登录 / 账号体系 / 云端同步
- 社区 / 评论 / 社交分享
- 商业化与支付系统
- 复杂的富文本排版引擎与自定义全局换肤

---

## 12. 未来演进路径（Roadmap）

- V1.0 (当前目标)：纯本地分级数据驱动、静态 DI 工厂、V1 单 Navigation 路由、Preferences 轻量持久化与水化恢复、4 层单向轻量架构、核心单测防护。
- V2.0 (业务复杂度驱动)：当出现端侧检索算法、多知识源混合聚合时按需引入 Service 层；用户数据规模扩大时平滑迁移至 RelationalStore；项目与练习题库完整打通。
- V3.0 (智能化期)：引入 AIService，利用知识库已有的 summary、tags、prerequisite、keyPoints 与结构化 CodeSnippet 字段进行端云混合 RAG 扩展，提供智能解惑。

---

## 13. 下一步工程行动顺序与严格验收标准

在 DevEco Studio 中按以下顺序渐进落地：

### Milestone 0: 零数据工程骨架点亮与基础设施
- 开发目标：创建基础工程，建立模块化 models/ 目录结构与规范工程树。落地 constants/（AppColors, AppDimens, AppStrings）。落地 utils/logger 与 utils/providers/ 基础依赖工厂。落地 MainPage、UserStore 与 RootTabContainer，实现单个 Navigation 嵌套 Tabs 的根框架，完成 5 个一级 Tab 占位组件与全局 NavPathStack 注入。
- 验收标准（DoD - Definition of Done）：
  1. 工程在当前锁定的 DevEco Studio 与 SDK 环境下编译通过，且无编译错误。。
  2. 全工程 ArkTS 检查零 any 警告。
  3. 全局 NavPathStack 正常实现 push 与 pop 跳转，使用强类型参数传递与 onReady 提取。
  4. 5 个 Tab 切换平滑，底部指示器状态正常保持。
  5. 视觉常量落地，所有占位组件均引用统一的 AppColors 和 AppDimens。
  6. 在没有放置任何真实 JSON 数据文件的状态下启动 App，无任何闪退、白屏或未处理异常。

### Milestone 1: 分级静态资产通路、强类型校验与单测防护
- 开发目标：实现 models/common/（Result 联合类型、ErrorCode 枚举）与 models/knowledge/ 模型。落地 RawFileAssetDataSource（含字段校验、按需详情读取与 schemaVersion 校验）与 KnowledgeRepository（含内存缓存机制）。导入首批 2~3 篇嵌入式知识 JSON（含 index.json 与 details/）。编写 entry/src/test/ 核心单测。
- 验收标准：
  1. 单元测试全部通过（含版本不兼容、JSON 损坏、字段缺失兜底分支）。
  2. 单元调用 KnowledgeRepository 可正确返回结构化列表与按需详情，重复请求正确命中 detailCache。

### Milestone 2: 核心学习闭环点亮
- 开发目标：实现 LearnPage 分类与列表展示，通过 navPathStack.pushPathByName 调起 KnowledgeDetailPage，以 NavDestination 形式全屏渲染教材式知识详情（含代码块高亮展示占位与图片加载占位）。
- 验收标准：用户能完整走通“分类切换 -> 条目点击 -> 按需加载详情 -> 详情浏览 -> 返回列表”的全流程闭环。

### Milestone 3: 状态持久化与全局联动
- 开发目标：落地 PreferenceDataSource（带安全序列化校验与 30 条 FIFO 历史限制）、UserRepository 与 UserStore 单例，打通应用启动水化（Hydration）流程与收藏状态的跨页面响应式更新。
- 验收标准：
  1. 应用冷启动时，MainPage 正确触发 UserRepository 恢复历史状态并注水至 UserStore。
  2. 详情页点击收藏后，返回 Learn 列表以及进入 Profile 页面，收藏状态与历史列表即时同步呈现，重启 App 后状态完全保留。