# EmbedLab Agent Workflow Protocol (SOP)

本文件规定了 EmbedLab 原生鸿蒙项目在 AI Agent（DeepSeek Harness）与人类开发者协同开发时的标准操作程序（SOP）。所有参与编码的 Agent 必须严格遵守此协议。

---

## 1. 角色定义与职责边界 (Roles & Authority)

### 人类开发者 (Chief Architect & Human Gate)
- **定位**：首席架构师、唯一产品决策人、真机验收门禁的最终签发人。
- **职责**：定义 Milestone/Task 范围，执行模拟器/真机运行时观察，审查代码 Diff，下发放行批准。

### AI Agent (Implementation Engineer)
- **定位**：HarmonyOS NEXT 原生实现工程师。
- **职责**：依据架构书与任务卡编写代码、执行本地 CLI 工具链验证、如实汇报验证结果。
- **权限红线**：
  - 严禁自行假定 UI 正常呈现（必须交由人类上机目测确认）。
  - 严禁修改已处于 Architecture Frozen 状态的架构文档。
  - 严禁跨越任务范围修改无关文件。

---

## 2. DevEco CLI 自动化工具链守则 (Tooling Enforcement)

在日常开发中，Agent 必须主动调度本地 `devecocli` 工具链，形成“查验-自检-排障”闭环，严禁仅凭模型概率记忆盲目写代码：

### 1. 编码前：官方文档检索（防 API 虚构与命名误用）
- **触发条件**：凡涉及 ArkUI 原生组件属性（如 Navigation、Tabs、List）、生命周期回调或系统能力 SDK 调用时。
- **强制行为**：若对参数类型、API 命名（如标题栏/导航栏隐藏属性）存在任何不确定性，**必须在终端先行调用官方离线文档检索命令**：
  `devecocli docs search "<关键字或组件名>"`
- **目标**：以本地官方实际 SDK 声明为准，杜绝“把 `.hideTitleBar` 误写为 `.hideNavBar`”等幻觉 Bug。

### 2. 编码后：静态语法与规范自检（自动修复）
- **触发条件**：任何一次代码新增或修改完成之后、向人类交付之前。
- **强制行为**：必须自动执行 ArkTS 语法检查指令：
  `devecocli check lint`
- **目标**：在进入构建前，秒级捕获所有 `any` 滥用、类型断言漏洞、未定义属性，并**自主修复直至静态扫描零告警**。

### 3. 排障时：精准捕获错误日志（真机事实分析）
- **触发条件**：上机运行时遇到白屏、闪退或未捕获异常。
- **强制行为**：必须调用日志抓取命令提取底层真实崩溃堆栈：
  `devecocli log --level E`
- **目标**：根据日志中的 Crash 真实堆栈定位根因，禁止无事实凭据的盲目猜测修改。

---

## 3. 微任务步进与零信任记忆铁律 (Micro-Tasking & Zero-Trust)

为防止大模型单次生成文件过多以及产生“上下文记忆幻觉”，开发过程严格执行以下纪律：

### 1. 读写分离与零信任记忆（Zero-Trust Memory）
- **严禁凭记忆盲写**：严禁依赖历史对话记忆直接覆盖写入代码。
- **先读后写原则**：在修改任何现有文件之前，**必须先执行文件读取操作（Read/View）获取文件在磁盘上的真实最新状态**，确认上下文与行号后再执行精确编辑。
- **模块导出规范**：涉及跨目录调用时，若存在模块出口文件，必须同步检查/更新导出出口，保持路径清晰。

### 2. 单次修改上限（Blast Radius Control）
- 单个微任务允许新增/修改的文件数量**严格限制在 3 ~ 5 个以内**。
- 严禁在单个指令中同时跨越多个架构分层（例如：严禁在写 Model 的同时去写 UI 和 DataSource）。

### 3. 任务锁机制（Task Scope Lock）
- 发现后续步骤所需的信息或接口时，一律记录到交付报告的“未决依赖”中，**绝对禁止提前创建后续阶段的空壳文件、Service 或占位逻辑**。

---

## 4. 双轨验证墙与熔断机制 (Verification Wall & Circuit Breaker)

任何微任务的交付必须通过双轨验证，并受熔断机制保护：

### 轨道一：机器自动化门禁（CLI & Compiler Gate）
- 必须通过 `devecocli check lint` 静态检查（零 any、零规范错误）。
- 必须通过 DevEco 工具链构建（`assembleHap` 构建成功无报错）。

### 轨道二：运行时事实检查（Runtime Gate）
- **涉及 UI 层的任务**：
  - 静态编译通过**不等于**任务完成！
  - 必须由人类在模拟器/真机上确认：屏幕正常显示无白屏、容器宽高无塌陷、文字对比度清晰、交互无卡死。
- **涉及底层数据（DataSource / Repository）的任务**：
  - 必须在 `entry/src/test/` 编写并执行单元测试，提供真实输出日志（PASS），证明边界异常（缺失字段、损坏 JSON、版本越界）被正确拦截。

### 轨道三：Agent 错误自愈熔断机制（Circuit Breaker）
- 当 `assembleHap` 编译构建失败或单元测试断言失败时，**Agent 最多仅允许进行 2 次自我修复尝试**。
- **熔断红线**：若连续 2 次修复依然未通过编译或依然报错，**Agent 必须立即停止对代码的一切写操作**！如实向人类开发者输出真实错误堆栈，详细说明已尝试的方案与受阻原因，请求人类介入调试，**严禁在未理解根因的情况下死循环盲改**。

---

## 5. ArkTS 与 ArkUI 原生编码底线 (Native Guardrails)

在编写 ArkTS/ArkUI 代码时，Agent 必须严格遵守以下防止崩溃、白屏与响应式失效的硬性规范：

### 1. 状态管理（State Management）隔离铁律
- **严禁复杂多层对象浅监听**：严禁在 `@State` 变量中直接嵌套多层复杂对象且不使用 `@Observed` / `@ObjectLink`（会导致深层属性变化时 UI 失去响应）。
- **严禁在 `build()` 内触发状态变更**：绝对禁止在 `build()` 渲染函数内部对任何状态变量（如 `@State`、`@Link`）执行赋值操作，否则会引发无限重新渲染死循环并直接崩溃。

### 2. 日志系统（Logging）规范
- **禁止裸写控制台**：全工程废弃 `console.log`，必须统一使用项目中封装好的 `Logger` 工具类（底层映射 `@ohos.hilog`）。
- **格式化规范**：日志必须附带明确的模块标签（ModuleTag）与格式化修饰符（如 `%{public}s`、`%{public}d`），保证在 Release 模式下敏感信息受控。

### 3. UI 容器与路由防踩坑
- **根 Navigation 禁止误用 `.hideNavBar(true)`**：隐藏顶部标题栏必须使用 `.hideTitleBar(true)`，严禁在单一全局根 Navigation 上设置 `.hideNavBar(true)` 导致整屏内容被清空白屏。
- **Tabs 动态索引必须绑定 `.onChange`**：凡使用 `Tabs({ index: this.currentIndex })` 绑定动态状态的，必须成对声明 `.onChange((index: number) => { this.currentIndex = index; })`，确保高亮与底层索引双向同步。
- **顶层容器全屏尺寸约束**：所有 Page 和根容器组件必须显式声明 `.width('100%').height('100%')`，防止被系统折叠为 0 尺寸。页面背景色与文字颜色必须形成明确对比，禁止同色遮蔽。
- **NavDestination 必须作为分发顶级节点**：在 `pageMap` 路由分发中，分支返回的必须直接是 `NavDestination`，严禁在外部多余套用 `Stack` 等外层容器。

---

## 6. Agent 交付报告规范 (Delivery Format)

每个微任务执行完毕后，Agent 必须按照以下标准格式向人类汇报，严禁仅回答“已完成”：

```text
==================== Agent Task Delivery Report ====================
1. 本任务修改/创建文件清单：
   - 路径 (操作类型: 新增/修改, 变动概况)

2. CLI 自检与编译/单测验证结果：
   - devecocli check lint 结果: [PASS / 已清零警告]
   - assembleHap / 单元测试构建结果: [BUILD SUCCESS / 附带末尾摘要]

3. 运行时验证请求 (Runtime Verification Gate)：
   - [若涉及UI]: 静态代码已就绪，请求人类在模拟器/真机上目视确认 (检查白屏/塌陷/高亮交互)。
   - [若涉及纯底层]: 附带本地单元测试执行事实日志 (PASS)。

4. 未决依赖与下一小步建议 (Pending Dependencies)：
   - 记录本次任务中发现但受限于“任务锁机制”未提前创建的下游接口、模型或组件依赖。
   - 给出推荐的下一个微任务范围（Micro-Task Card 建议）。
====================================================================
