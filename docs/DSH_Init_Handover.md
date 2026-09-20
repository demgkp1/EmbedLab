> 归档时间：2026-09-20；归档版本：v1.7.1-mvp

# EmbedLab 新 DSH 对话初始化（交接自当前主对话）

> 交接生成时间：2026-09-20
> 本文件所有事实均取自交接时的磁盘 / git 实况，不凭记忆。
> 不确定处已标 `[待核实]`。

## 一、角色设定

**【我填】** 你是纯实现工程师，不再兼任架构师助手。
架构师助手已独立为另一条对话，负责写任务卡 / 审批你交付 / 维护 BACKLOG。
你的职责：写代码 + 自检 + 出交付报告。严禁越权改授权外文件。

## 二、项目背景

**【我填】** 技术栈 / 关键约定。（照抄，不靠记忆）

- HarmonyOS NEXT（API 26 / compatible 6.1.1(24)）
- ArkUI（ArkTS）
- DevEco Studio 5.x（实装在 `E:\app\DevEco Studio`）
- Node.js 22+（用于数据转换流水线）
- 不接云端后端
- V1 不集成大模型（DeepSeek 仅作开发辅助）
- 数据资产与应用状态绝对分离

## 三、当前进度

**【DSH 填】** 截至 2026-09-20

### 3.1 已收口里程碑

| 里程碑 | 状态 | 依据 |
|---|---|---|
| M0 零数据工程骨架 | ✅ 冻结 | 初始化材料；`v1.0.0-mvp` 为 M3.4 |
| M1 分级静态资产通路 | ✅ 冻结 | 同上 |
| M2 动态富文本引擎 + 极客代码块 | ✅ 冻结 | 同上 |
| M2.5 语义化分段阅读 | ✅ 冻结 | 同上 |
| M3.1 用户状态底层（PDS + DI 接缝） | ✅ 冻结 | 同上 |
| M3.2 UserRepository + UserStore | ✅ 冻结 | 同上 |
| M3.3 启动水化 + 生产路径验证 | ✅ 冻结 | 同上 |
| M3.4 Profile + 收藏 + 历史联动 | ✅ 冻结 | `v1.0.0-mvp` |
| M3.5 图片全屏预览 + 双指缩放 | ✅ 冻结 | `v1.1.0-mvp` |
| A-1~A-4 收尾阶段 A | ✅ 收口 | `v1.2.0-mvp` |
| A-5 范围外文案归口 | ✅ 收口 | `v1.2.1-mvp` |
| Milestone B + B-fix-3 | ✅ 交付 | `v1.3.0-mvp` |
| Profile-R 二级入口重构 | ✅ 收口 | `v1.4.0-mvp` |
| Cleanup-1 + Exercise-Data-1 | ✅ 收口 | `v1.5.0-mvp` |
| C-1 Learn 难度筛选 | ✅ 收口 | `v1.6.0-mvp` |
| UI-Polish-1 筛选栏维度标签 | ✅ 收口 | `v1.6.1-mvp` |
| Cleanup-2 / 3 / 4 | ✅ 收口 | `v1.7.0-mvp` |
| **Profile 概览卡不刷新修复 + 死代码清理** | ✅ 收口（真机通过） | **`v1.7.1-mvp`** |

### 3.2 Git tags 序列（`git tag -l` 实况）

```
v1.0.0-mvp
v1.1.0-mvp
v1.2.0-mvp
v1.3.0-mvp
v1.4.0-mvp
v1.5.0-mvp
v1.6.0-mvp
v1.6.1-mvp
v1.7.0-mvp
v1.7.1-mvp
```

### 3.3 当前分支状态（`git status --short --branch` 实况）

```
## main...origin/main
```

- HEAD = `7dbdee3`（`main`，tag `v1.7.1-mvp`，与 `origin/main` 同步，ahead/behind = 0/0）
- **工作区完全干净**（`--untracked-files=all` 亦为空）
- 本地分支：`main` / `feature/cleanup` / `feature/difficulty-filter` / `feature/ui-immersion` / `feature/ui-polish`

### 3.4 【必填】本轮 Profile 概览卡修复

**现象**：在知识详情页收藏 / 阅读后，Profile 页顶部「学习概览」卡的收藏数 / 已读数不刷新；
而「我的收藏」「阅读历史」两个二级页数据正常。

**根因（当前最合理解释，非定理）**：

概览卡渲染链路上存在**两层 `@Builder` 中转**：

1. `ProfilePage.build()` 调用**无参** `@Builder overviewCard()`
2. `overviewCard()` 内部调用**带参** `@Builder overviewMetric(label, value, accent)` 渲染数字

修复前的数据侧**完全正常**（这点已由插桩实证：`UserStore` / `viewModel` / 页面 `@State` /
子组件 `@Prop` **四层数值全部正确更新**，仅界面数字不动）。

**最合理解释**：这两层 `@Builder` 中的某一层（或两层叠加）使其产出节点未随状态变化重建，
导致数字停留在首次渲染值。

⚠️ **归因的重要保留**：本次修复**同时移除了两层**（去掉带参 `overviewMetric` +
把卡片调用从无参 `overviewCard` 内移到 `build()` 顶层），**因此无法隔离究竟是哪一层导致**。

⚠️ **反证（务必知悉）**：`FavoritesPage.ets:133` / `HistoryPage.ets:133` 的
`itemRow(item: KnowledgeMetadata)` 是**带参 `@Builder` 且在渲染动态数据**，
且**工作正常**。差异在于其调用点在 `ForEach` 内（`:115`），节点随数据重建。
故「带参 `@Builder` 一律不可用」是**过强断言**，不成立。

**手段**：
- `ProfileOverviewCard` 内**内联直读 `@Prop`**（Text(`${this.favCount}`)），不再经 `@Builder` 中转
- 卡片调用点从 `@Builder` 内移到 `build()` 顶层 Column，用 `.visibility()` 控制显隐（非条件渲染）
- 数据侧保留 `@State favCount/histCount` + `syncCounts()` 单一写点（5 个刷新入口统一调用）

**真机验证结果**：**通过**。人类架构师确认概览卡收藏 / 已读数字刷新恢复正常。
（复核依据：修复前的插桩版本曾上屏四层读数，证实数据侧无问题；修复后人工确认数字跟随。）

**提交**：`7dbdee3 fix(profile): 概览卡收藏/已读数字不刷新修复 + 死代码清理`
（`docs/BACKLOG.md` +84/-1、`ProfilePage.ets` +176/-62）

## 四、核心架构原则

**【我填】** 5 条。（照抄）

**原则一：数据资产与应用状态绝对分离**
- 内容资产：只读，随 App 打包（`resources/rawfile/database/`）
- 用户状态：Preferences 轻量持久化，FIFO 30 条上限

**原则二：严格单向分层 + 静态依赖注入**
- UI (Page/Component) → ViewModel → Repository → DataSource
- ViewModel 不得直接 new Repository
- Repository 不得直接 new DataSource
- 通过 `DataSourceProvider` / `RepositoryProvider` 静态获取

**原则三：按需分级加载**
- 知识库分索引（index.json）+ 详情（details/*.json）
- 内存只读缓存（metadataCache + detailCache）

**原则四：MVP 绝对优先**
- 没有该模块，核心闭环（找知识→读知识）能否跑通？不能则占位

**原则五：强类型 + 标准错误码 + UI 映射**
- 底层 I/O 统一返回 `Result<T>`
- ErrorCode 到 UIStatus 有标准映射表
- 严禁 `any`

## 五、8 条硬红线 + 状态同步原则 + 平台限制

**【我填】** （照抄）

1. 严禁使用 `any` 类型
2. 严禁在 Page/Component 层直接调用 Repository / Preferences / resourceManager / bundleManager
3. 严禁在 `build()` 内修改任何状态变量
4. 严禁给全局 `NavPathStack` 加 `@State` / `@Provide` / `@Link` 装饰器（渲染期死锁）
5. 严禁在 `TabContent` 内嵌套 `Navigation` / 新建 `NavPathStack`
6. 严禁在根 `NavDestination` 上使用 `.hideTitleBar(true)`
7. UI 视觉常量必须来自 `constants/`（AppColors / AppDimens / AppStrings）
8. 跨 Tab 响应式刷新必须用 `@StorageLink` 状态驱动，不要用 `onPageShow`（TabContent 切换不触发）

**状态同步原则**
- 必须先由 Repository 写盘成功，再更新 UserStore
- 禁止「Store 已更新但磁盘写入失败」的伪成功

**平台限制**
- `@Provide` / `@Consume` 不支持装饰 Function 类型（API 23 起为编译期 ERROR）
- 跨组件传回调必须用构造参数 + 无装饰器常规成员

## 六、已知踩坑清单（ArkTS + 状态管理）

**【DSH 填】**

### 6.1 【本轮新增·必读】`@Builder` 产出节点在特定调用点下可能不随状态重建（归因未隔离）

**证据链（本轮实测，模拟机读数）**：

修复前加装两层可见诊断文本后，单次收藏操作前后读数如下：

| 层 | 收藏前 | 收藏后 | 判定 |
|---|---|---|---|
| `UserStore` 真值 | 6/13 | **7/14** | ✅ 更新 |
| `viewModel` 装配结果 | 6/13 | **7/14** | ✅ 更新 |
| 页面 `@State` 快照 | 6/13 | **7/14** | ✅ 更新 |
| 子组件 `@Prop` 入参 | 6/13 | **7/14** | ✅ 更新 |
| **卡片显示数字** | **6/13** | **6/13** | ❌ **不更新** |

关键对照：加在卡片 `build()` 内的 `CARD prop=...` 诊断文本**更新了**，
说明 `build()` 确实重执行、`@Prop` 确实是新值 —— 唯独经 `@Builder` 产出的数字不动。

**结论措辞（当前最合理解释，非绝对定理）**：
`@Builder` 的产出节点在「调用点位置固定、参数变化」的情形下可能不被重建，
导致其渲染内容停留在首次值。

**⚠️ 该解释的已知反例（不可忽略）**：
`FavoritesPage` / `HistoryPage` 的 `itemRow(item)` 同为带参 `@Builder` 且渲染动态数据，
**工作正常** —— 因其调用点在 `ForEach` 内（节点随数据重建）。
**故本条不可简化为「禁用带参 @Builder」。**

**当前工程做法**：需要跟随状态变化的数值，**内联直读**（Text(`${this.favCount}`)），
不经任何 `@Builder` 中转。

**待排查面**（工程内带参 `@Builder` 全量清单，均需按「调用点是否重建」逐一判断）：

| 文件:行 | 签名 | 调用点上下文 | 初步风险 |
|---|---|---|---|
| `FavoritesPage.ets:133` | `itemRow(item)` | `ForEach` 内（`:115`） | 低（已验证正常） |
| `HistoryPage.ets:133` | `itemRow(item)` | `ForEach` 内（`:115`） | 低（已验证正常） |
| `ProfilePage.ets:288` | `entryRow(glyph, label, routeName)` | `@Builder entryList` 内 | 低（参数为常量） |
| `ProfilePage.ets:314` | `stateHint(title, description)` | `build()` 内 | 低（参数为常量） |
| `HomePage.ets:306` | `sectionEmptyHint(message)` | 分支内 | 低（参数为常量） |
| `HomePage.ets:319` | `stateHint(title, description)` | — | 低 |
| `LearnPage.ets:262` | `stateHint(title, description)` | — | 低 |
| `KnowledgeDetailPage.ets:344/355/372/422/436/442` | `blockHeader/blockText/blockImage/blockWarning/blockCode/stateHint` | `ForEach` 内（疑似） | **[待核实]** |
| `AboutPage.ets:70` | `section(title, description)` | — | 低 |
| `SettingsPage.ets:60` | `infoRow(label, value)` | — | 低 |
| `RootTabContainer.ets:92` | `tabBarBuilder(index, label)` | `.tabBar()` 内 | **[待核实]** |
| `MainPage.ets:110/128` | `pageMap(name, param)` / `unregisteredRoute(name)` | 路由分发 | 特殊（路由机制） |

### 6.2 【必填】`@Builder` 内读取 `@State` 可能不建立依赖

**证据等级：单次观察，未做对照实验。**
Diag3 曾把可见诊断文本放在 `build()` 顶层（内联）与卡片 `@Builder` 内对比，
观察到内联者更新、`@Builder` 内者不更新。
**但因与 6.1 的现象同源，无法排除是同一机制的不同表现。** `[待核实]`

### 6.3 【必填】`if/else` 分支内内容是否「条件未变时不重建」

**状态：未验证假设。** Fix3 曾据此把概览卡移出 `else` 分支，
但后续证明真因在别处，**该假设从未被独立验证**。
当时的改动（移出分支 + `.visibility()`）保留在最终版中，属"无害但归因不明"的改动。
`[待核实]`

### 6.4 `@Observed` 无 `@ObjectLink` 配套（P1 系统债）

全工程 4 个 ViewModel 均标注 `@Observed`（`ProfileViewModel` / `HomeViewModel` /
`LearnViewModel` / `KnowledgeDetailViewModel`），但**全工程 `@ObjectLink` 零实际使用**。
官方文档明确 `@Observed` 与 `@ObjectLink` **须配套使用**。

⚠️ **本条已降级**：原登记曾把它列为概览卡不刷新的根因，经四层读数插桩**已证伪**。
现作为"既有范式问题，待评估"保留。
工程现以「页内 `@State` 基本类型快照」范式规避（`ProfilePage.favCount` / `LearnPage.favoriteIds`），已验证有效。

### 6.5 `refreshFlag` 只写不读（死代码）

`refreshFlag` 在 **6 个页面**均为「只写不读」，**读取点全工程为 0**。
仅写入而不被 `build()` 读取的状态变量在 ArkUI 中不构成渲染依赖，从未驱动过重绘。

实况（`grep refreshFlag` 计数）：

| 文件 | 命中处数 | 行号 | 状态 |
|---|---|---|---|
| `HomePage.ets` | 6 | 47, 73, 79, 86, 93, 136 | 待清理 |
| `KnowledgeDetailPage.ets` | 3 | 104(注释), 117, 249 | 待清理 |
| `LearnPage.ets` | 2 | 50, 115 | 待清理 |
| `FavoritesPage.ets` | 4 | 35, 54, 60, 72 | 待清理 |
| `HistoryPage.ets` | 4 | 35, 54, 60, 72 | 待清理 |
| `UserStore.ets` | 1 | 18（注释中提及） | 非死代码 |
| `ProfilePage.ets` | **0** | — | ✅ 本轮已清除 |

### 6.6 ArkTS 已知错误码

| 错误码 | 含义 | 规避 |
|---|---|---|
| `10905210` | `build()` 第一条语句必须且只能是容器组件 | 任何前置语句（含 Logger 调用、箭头函数 IIFE 赋给局部变量）都会中断构建 |
| `10905204` | `@Builder` 内禁止非 UI 语句 | `@Builder` 是 UI DSL，只能写组件调用与属性链；**无法在其中打日志** |
| `10505001` | 类型不可赋值 | 联合类型收窄后，`''` 不再合法（曾致 `level: '' as KnowledgeLevel`） |
| `10605999` | `null` 转 `object` 可疑 | `super(null as object)` 不通过；`as unknown as` 为 ArkTS 所禁（工程零 `unknown` 先例） |
| `arkts-no-utility-types` | 不支持 `InstanceType` | 不可用工具类型推导 |
| `arkts-no-type-query` | `typeof` 仅允许表达式上下文 | 不可用 `typeof` 做类型查询 |
| `arkts-no-obj-literals-as-types` | 对象字面量不能作类型声明 | 需显式声明 class / interface |
| `arkts-no-untyped-obj-literals` | 无类型对象字面量 | 同上 |

### 6.7 Preferences 测试限制

`ohosTest` 进程的 `getAppContext()` 返回应用级 BaseContext，无 module sandbox 绑定，
**Preferences 服务运行时拒绝**；而 App 进程内 `MainPage` 走的是
`getUIContext().getHostContext()`（具备 sandbox）。二者是**不同的 Context 来源**。
→ 生产路径验证必须走 `MainPage.aboutToAppear`。

### 6.8 `NavDestination` 返回不触发 `onPop`

系统返回箭头走 `pop()` 内部路径，**不触发** `pushPathByName` 的 `onPop` 回调
（本工程实测该回调属死代码，已移除）。跨页刷新用 `@StorageLink` 状态驱动。

### 6.9 其他既有约束

- **Tab 切换**：`TabContent` 切换**不触发** `onPageShow`
- **`bindContentCover`**：N 个绑定共享同一状态变量属未定义行为，必须收敛为全页唯一绑定
- **ArkUI 自定义组件**：属性不能用方法链，必须构造参数传参
  （错误 `KnowledgeCard().onClickItem(...)`；正确 `KnowledgeCard({ item: ..., onClickItem: ... })`）
- **`@Prop` / `@Provide`**：不支持装饰 Function 类型变量

## 七、协作 SOP

**【我填】**

**分级框架（低 / 中 / 高风险）**
- 低风险（已知 API + 单层级 + ≤7 文件）：一卡到底
- 中风险（已知 API + ≤5 文件）：一卡两段（探查 + 编码连续执行）
- 高风险（新 API / 跨层级 / >5 文件）：保留微任务

**零信任（先读后写 + 真实证据）**
- 先读后写，禁止凭记忆盲写
- 每次交付必须附真实证据（grep 输出 / build 日志 / 真机截图）
- 证据必须来自文件实况，不得凭 edit 参数推断

**双轨验证（CLI + 真机）**
- 轨道一：CLI 静态检查（lint Errors 0 + assembleHap BUILD SUCCESSFUL）
- 轨道二：真机肉眼验证（UI 由人类确认）

**熔断机制（更新版）**
- 同一根因连续 2 次失败 → 停止上报
- 不同根因累计 4 次失败 → 停止上报
- 发现授权外文件需修改 → 停止上报，请求扩权
- 前提不成立 → 停止上报

**【本轮新增】诊断插桩不得豁免红线**
- 插桩也要走授权；插桩代码同样受 8 条红线约束
- **反面教材**：本轮诊断插桩曾引入 `Color.Red` / `Color.Yellow` 硬编码
  与 `ProfilePage` 直连 `UserStore`（与页面头注释明写的约束冲突），
  虽事后自查清除，但属违规既遂

**【本轮新增】不许在脏工作区上叠卡**
- 本轮曾有 7 张卡叠加在同一文件且未提交，导致 `git diff` 无法区分归属，
  交付报告的可审计性严重下降（DSH 曾 4 次提请提交）
- 规则：新卡开始前若工作区不干净，先提请架构师提交或明确豁免

## 八、冻结文件清单

**【我填】** （照抄）

**数据层**
```
entry/src/main/ets/datasources/PreferenceDataSource.ets
entry/src/main/ets/datasources/RawFileAssetDataSource.ets
entry/src/main/ets/repositories/UserRepository.ets
entry/src/main/ets/repositories/KnowledgeRepository.ets
entry/src/main/ets/stores/UserStore.ets
entry/src/main/ets/models/user/UserProgressState.ets
entry/src/main/ets/utils/providers/DataSourceProvider.ets
entry/src/main/ets/utils/providers/RepositoryProvider.ets
```

**UI 层**
```
entry/src/main/ets/pages/MainPage.ets
entry/src/main/ets/components/RootTabContainer.ets
entry/src/main/ets/pages/profile/ProfilePage.ets
entry/src/main/ets/pages/profile/FavoritesPage.ets
entry/src/main/ets/pages/profile/HistoryPage.ets
entry/src/main/ets/pages/profile/SettingsPage.ets
entry/src/main/ets/pages/profile/AboutPage.ets
entry/src/main/ets/viewmodels/ProfileViewModel.ets
entry/src/main/ets/viewmodels/KnowledgeDetailViewModel.ets
entry/src/main/ets/viewmodels/HomeViewModel.ets
entry/src/main/ets/pages/learn/LearnPage.ets
entry/src/main/ets/pages/learn/KnowledgeDetailPage.ets
entry/src/main/ets/pages/learn/components/GeekCodeBlock.ets
entry/src/main/ets/pages/learn/components/ImageViewerOverlay.ets
entry/src/main/ets/pages/home/HomePage.ets
```

**常量层（可授权修改，但值不可变）**
```
entry/src/main/ets/constants/AppColors.ets
entry/src/main/ets/constants/AppDimens.ets
entry/src/main/ets/constants/AppStrings.ets
entry/src/main/ets/constants/AppStorageKeys.ets
entry/src/main/ets/constants/RouteConstants.ets
```

**数据资产（绝对禁止修改）**
```
entry/src/main/resources/rawfile/database/knowledge/index.json
entry/src/main/resources/rawfile/database/knowledge/details/*.json
entry/src/main/resources/rawfile/database/images/**
entry/src/main/resources/rawfile/database/exercises/*.json
docs/chapters/*.md
docs/pipeline/**
docs/tools/**
```

**规范文档（冻结）**
```
EmbedLab_Project_Architecture.md
AGENT_WORKFLOW.md
docs/BACKLOG.md
```

## 九、沙箱与权限

**【我填】** （照抄）

**【权限分级】**
1. 工作区内：默认读写
2. 工作区外只读：允许（读取 SDK 声明文件、参考文档等）
3. 工作区外写入 / 删除 / 迁移：禁止，必须停止并请求人类架构师授权
4. 工具链缓存（`C:\Users\dkp\.hvigor` / `.ohpm` / `AppData\Local\npm-cache`）：
   允许 DevEco / hvigor / ohpm / npm 自动维护；
   禁止人为直接修改、迁移、删除其中文件

**【必守规范】**
5. 严格遵守 `EmbedLab_Project_Architecture.md` 与 `AGENT_WORKFLOW.md`
6. 不得擅自做规范外工作；若规范外权限不可避免，立即暂停并请求授权
7. 不得修改、删除、迁移工作区外的任何文件
8. 若需访问工作区外文件，先请求授权

**【交付报告附加要求】**
9. 工作区外访问清单（无则明示「无」）
10. `git status --short` 原始输出
11. `git diff --stat` 原始输出

**【熔断条件新增】**
- F0：发现工作区外写入 / 删除 / 迁移需求 → 立即停止上报，请求扩权
- F0b：发现工作区外越界行为已发生 → 立即停止上报，附完整证据

**【CLI 环境要点（本轮取证）】**
- `devecocli` 全局可用（`C:\Users\dkp\AppData\Roaming\npm\devecocli.ps1`，版本 `1.3.0-stable`）
- 直调 `hvigorw` **必须自行提供环境变量**：
  - `DEVECO_SDK_HOME = E:\app\DevEco Studio\sdk`
  - `JAVA_HOME = E:\app\DevEco Studio\jbr`（否则 `PackageHap` 报 `spawn java ENOENT`）
  - `NODE_HOME = E:\app\DevEco Studio\tools\node`
- **hvigor daemon 会缓存环境**：改环境变量后需 `hvigorw --stop-daemon-all` 再跑
- IDE 的构建配置是 `assembleHap`（非 `UnitTestBuild`），两者行为不同

## 十、协作对话清单

**【DSH 填】** 当前并行的对话及各自角色：

| 角色 | 职责 | 状态 |
|---|---|---|
| **实现工程师** | 写代码 + 自检 + 出交付报告 | ← **你（新对话）** |
| 人类架构师 | 唯一决策人 + 门禁签发 + 真机验证 | 唯一真人 |
| **辅助架构师** | 写任务卡 / 审批交付 / 维护 BACKLOG / 路线建议。对话存在（独立于实现工程师），本轮因采用"人机直连快速迭代"模式处于低活跃状态。 | 存在，低活跃 |

> 数据线已冻结（`docs/tools/**`、`index.json` sha256 已锁定），当前无活跃数据转换对话。

## 十一、最近一轮工作的失败模式教训

**【DSH 填】** 必须包含你自曝的三条：

### 教训 1：前三轮修复方向**系统性错误**，而根因其实最简单

在真机读数出来之前，我连续提出并实施了 3 个假说，**全部被真机否掉**：

| 轮次 | 假说 | 实际改动 | 结果 |
|---|---|---|---|
| Fix-Impl | `@State` 无法观察 `@Observed` 类内部字段 → 加页内 `@State` 快照 | 新增 `favCount`/`histCount` + `syncCounts()` | ❌ 无效 |
| Fix2 | `@Builder` 读取不建立依赖 → 抽为 `@Component` + `@Prop` | 新增 `ProfileOverviewCard` | ❌ 无效 |
| Fix3 | `if/else` 分支体条件未变时不重建 → 移出分支 + `visibility` | 结构调整 | ❌ 无效 |

**代价**：3 轮返工、3 次真机验证消耗，且每轮都"有看起来像的证据"支撑。
**教训**：当多个假说都"合理"时，说明缺少**能同时观测多环节的对照实验**，
此时应停止提假说，先做插桩。

### 教训 2：本该**更早**做插桩，对照实验一次就能定性

最终定性只用了**一次**插桩（在两个位置各加一行可见文本），
一次性读出四层数值，直接排除前三个假说。

**这笔成本本可以在第一张修复卡之前付出。** 我却等到第三次失败后才做。
**教训**：对"数据不刷新"类问题，第一步就该让**数据链每一跳同时上屏**，
而不是逐个环节猜。

### 教训 3：插桩时**违反红线**（且是我自己违反的）

为了让诊断文本"绝不可能被漏看"，我用了 `Color.Red` / `Color.Yellow` **硬编码颜色**（违反红线 7），
并为了读出数据源真值，在 `ProfilePage` 里**直接调用 `UserStore.getInstance()`**
—— 而**同一文件的头部注释第 28 行明写**「本页严禁……亦不直连 UserStore」。

**这是我在"验证优先"的压力下放松了自律**：我给自己找了个理由（诊断临时性），
就把明确的约束当成了可豁免项。**事实上插桩代码同样是代码，同样受约束。**

**处置**：事后自查发现并全部清除（`grep` 零命中验证），但属**违规既遂**。
**教训**：插桩也要走授权；`[本轮新增]` 的 SOP 条目即由此而来。

### 补充教训 4：归因过早，且**未标注为待核实**

Fix3/最终修复的产出自查中，我把根因断言为"带参 `@Builder` 不跟随状态变化"，
并据此写入 BACKLOG 与组件注释。

但在交接前的审计中我发现**反证**：`FavoritesPage`/`HistoryPage` 的
`itemRow(item)` 同为带参 `@Builder` 渲染动态数据，**工作正常**。
且本次修复**同时移除了两层**（带参 `overviewMetric` + 无参 `overviewCard` 的调用位置），
**无法隔离归因**。

**教训**：同时改动多个变量时，不得声称已定位单一根因；结论必须标注证据等级。

## 十二、BACKLOG 摘要

**【DSH 填】** P0 / P1 / P2 分层，标注本轮新增 / 降级 / 修正的条目

> 实况：`docs/BACKLOG.md`（411 行，已随 `7dbdee3` 提交）
> 段落起始行：P0 `:11` / P1 `:38` / P2 `:111` / P3 `:181` / 近期完成登记 `:211` / 已关闭 `:355` / 维护约定 `:406`

### P0（最严重 · 虚假绿灯）

| # | 条目 | 本轮变化 |
|---|---|---|
| 1 | **测试代码三重验证盲区**：① `code-linter.json5` ignore 排除 `src/test/**` 与 `src/ohosTest/**`，测试代码从未被 lint；② `assembleHap` 的 `CompileArkTS` 不编译 `entry/src/test/`；③ **`UnitTestArkTS` 在 `entry/.test` 缺失时空跑并报 BUILD SUCCESSFUL**（虚假绿灯） | 无变化（Cleanup-4 登记） |

### P1（阻塞后续开发）

| # | 条目 | 本轮变化 |
|---|---|---|
| 1 | **带参 `@Builder` 的参数更新不驱动 builder 体重执行** | ⚠️ **本轮新增，但交接时已发现归因不完整** —— 见 §6.1 的反证与保留说明，**需修正措辞** |
| 2 | `@Observed` 无 `@ObjectLink` 配套 | ⚠️ **本轮降级 + 修正**：原列为概览卡根因，插桩已证伪，改注为"范式问题" |
| 3 | `refreshFlag` 哨兵为全工程死代码（6 处） | **本轮新增**（ProfilePage 已清，余 5 页待授权） |
| 4 | `ProfileViewModel` 存在 3 个孤儿方法 + 1 个孤儿字段 | **本轮新增**（Profile-R 遗留，零风险纯删除，待授权） |
| 5 | HomePage 收藏概览的刷新表现待实测 | ⚠️ **本轮修正**：原判"同根因"不成立，改注为"待实测" |

### P2（建议近期处理）

| # | 条目 | 本轮变化 |
|---|---|---|
| 1 | `UserStore.broadcast` 毫秒级竞态（`Date.now()` 同毫秒值相同 → `@Watch` 不触发） | 无变化 |
| 2 | 架构文档 level 类型精度偏差（`:225/:239` 仍写"字符串"，实现已收窄为联合类型） | 无变化 |
| 3 | `check_meta.mjs` 孤立脚本（无任何调用点） | 无变化 |
| 4 | level 白名单字面量多处重复（`append_index.mjs` / `verify_chapter.mjs:46` / `check_meta.mjs:39` / `run_pipeline.mjs:61`） | 无变化 |
| 5 | lint 规则 `@performance/avoid-overusing-custom-component-check` 与本修复方向结构性冲突 | **本轮新增**（代码有 profile 修复引入了第 6 处该告警） |
| 6 | ProfilePage 概览卡不刷新 bug | ✅ 已由 `v1.7.1-mvp` 修复 |

### P3（接受现状 / 长期观察）

见 BACKLOG `:181` 起，含 `LearnPage` 4 个刷新入口、`ProfilePage` 冗余刷新、
`ch20` Mermaid 标签重叠等，本轮未动。

## 十三、Git 工作流

**【我填】** 分支策略 + tag 节奏。（照抄）

**分支策略**
- `main`：稳定，仅接受已通过真机验证的合并
- `feature/ui-immersion`：UI 沉浸光感试验分支
- 后续可按需新建 `feature/xxx` 分支

**常用命令**
```
git status
git log --oneline --decorate -10
git checkout -b feature/xxx
git push -u origin feature/xxx
git add .
git commit -m "type: description"
git pull --rebase origin main
git push origin main
git tag -a vX.Y.Z-mvp HEAD -m "..."
git push origin vX.Y.Z-mvp
```

**tag 节奏**
- 按里程碑打，不按微任务打

## 十四、请求

**【我填】** 请确认已完整继承。
如发现与磁盘不符，停止并请求人类核实。

---

## 附：本次交接的取证说明

- 所有 git 数据取自 `git branch` / `git tag -l` / `git log` / `git status` 实况输出
- 所有文件行号取自 `read` 工具实际读取（非 `grep` 估算）
- `refreshFlag` / 带参 `@Builder` 清单取自全工程 `grep` 扫描
- 第三节的"真机通过"结论来自人类架构师口述 + 提交事实（`7dbdee3` 的 commit message）
  与修复前后插桩读数的对照；**插桩读数本身取自模拟机截图**（人类提供）

### 交接时未能确证的两项（已标 `[待核实]`）

1. `[待核实]` 的带参 `@Builder` 调用点上下文（`KnowledgeDetailPage` 的
   `blockXxx` / `RootTabContainer.tabBarBuilder`）是否为高风险位置
2. §6.2 / §6.3 两个假设均未做对照验证，与 §6.1 现象是否同源未知
