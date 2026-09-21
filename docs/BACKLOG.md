# EmbedLab 技术债清单（BACKLOG）

Last Update: 2026-09-17

> 本文件只做**登记**，不触发任何代码改动。
> 所有条目均来自各 Milestone 交付报告中**实际出现过**的未决项，不作推测性扩充。
> 优先级定义：P1 = 阻塞后续开发；P2 = 建议近期处理；P3 = 接受现状 / 长期观察。

---

## P0（最严重 · 虚假绿灯，直接误导判断）

- [ ] **测试代码三重验证盲区**
      **盲区 1 · 不被 lint**：`code-linter.json5` 的 `ignore` 显式排除
            `**/src/test/**/*` 与 `**/src/ohosTest/**/*`。
            实证：全工程 `check lint`（含 `--format json` 完整报告）中
            三个测试文件**零命中**，测试代码从未被静态检查。
      **盲区 2 · 不被主构建编译**：`assembleHap`（`CompileArkTS`）**只编译 main**，
            不编译 `entry/src/test/`。故主 HAP 构建成功**不代表**测试代码可编译。
      **盲区 3（最危险）· 虚假绿灯**：`UnitTestArkTS` 在 `entry/.test` 缺失时
            **空跑并报 BUILD SUCCESSFUL**。实证：本次收尾复跑时该 task
            仅耗时 673 ms，产出 `.tsbuildinfo`（91330 B）对 4 个测试文件
            **全部未命中** —— 即它根本没编译测试代码，却给出成功信号。
      **后果（已实际发生）**：Cleanup-4 因误信 `assembleHap` 的假通过，
            前后延误 **2 轮**交付；期间还一度错误地宣称
            「卡片描述的编译错误不存在」。这是本工程目前最危险的验证陷阱。
      **建议（独立卡评估）**：
        1. 放开 `code-linter.json5` 的 ignore 范围，让测试代码纳入静态检查；
        2. 排查/规避 `UnitTestArkTS` 的假绿灯机制（须 `entry/.test` 存在
           且输入变更时才会真编译）；
        3. **文档明确记录**：验证测试代码编译的唯一可靠方式是
           DevEco Studio 的 Run `List.test`（Local Test）；
           任何 CLI 构建的成功输出**均不可作为**测试代码的验证依据。
      来源：Cleanup-4 第一段探查 + 第二段交付报告未决依赖 T1（架构师升级为 P0）。

- [ ] **lint 覆盖 test 在当前工具链下不可解（用户侧无配置入口）**
      经 D2~D6 五卡探查确证：`devecocli check lint` 对
      `entry/src/test/**` 与 `entry/src/ohosTest/**` 的排除
      **不在** `code-linter.json5`（ignore 两行对直接文件不匹配，见 P1），
      **不在** modulePaths / inModule / collectCheckResourceFile / isNotInFiles
      （代码层四项过滤均已排查）。
      D6 实验（单变量三轮对照 + 阳性对照）证明：
      test 目录下 1/2/3 段深度的 `.ets` 均不产生诊断，
      同规则同内容置于 `entry/src/main/` 下必产生诊断。
      结论：**目录级排除、深度无关、与 ignore 两行无关**。
      实际拦阻点（可能在引擎层：arkPerfCheck / eslintAgent / performanceAgent）
      **未定位**，且在工作区外，用户不可改。
      影响：无法通过配置让 lint 覆盖 test 代码。
      来源：Lint-Filter-Probe（D2）~ Lint-Path-Depth-Experiment（D6）。

- [ ] **test 代码受 0 重门禁（P0 三重盲区的深化）**
      在既有 P0「测试代码三重验证盲区」基础上，D2~D6 进一步确证：
      · 门禁 1「lint」—— 不可解（见上条）
      · 门禁 2「编译」—— `assembleHap` 只驱动 default target，
        不编译 `entry/src/test/`；`ohosTest` target 需显式驱动
        （`devecocli build --modules entry@ohosTest` 可编译 ohosTest）
      · 门禁 3「执行」—— `UnitTestArkTS` 假绿灯未验证（详见原 P0 条）
      结论：test 代码当前无任何自动门禁。
      来源：Lint-Filter-Probe（D2）~ Lint-Path-Depth-Experiment（D6）。

---

## P1（阻塞后续开发）

- [ ] **【踩坑登记】@Builder 产出节点在特定调用点下可能不随状态重建（归因未隔离）** ⚠️ 证据等级：单一现象 + 未隔离归因
      现象（已由模拟机读数实证）：以
            `@Builder overviewMetric(label: string, value: string, accent: string)`
            渲染随状态变化的数值时，参数值已更新、调用点也已重执行，
            但该 builder 产出的数字停留在首次渲染值。
      实证链（Profile-Overview 系列第 4 轮，四层读数同时上屏）：
            父页 `store` / `viewModel` / `@State` / 子组件 `@Prop` **四层数值
            全部正确更新**（6/13 → 7/14），唯独经该 @Builder 产出的卡片数字不变；
            而直接内联在 build() 中的诊断文本是会更新的。
      ⚠️ **结论措辞：当前最合理解释，非绝对定理。**
            本次修复**同时移除两层**（带参 `overviewMetric` + 无参 `overviewCard`
            的调用位置），**两层未做隔离实验** —— 故**不得**据此断言
            "带参 @Builder 一律不可用"。
      ⚠️ **已知边界例**：
            · `FavoritesPage.ets:133` / `HistoryPage.ets:133` 的
              `itemRow(item: KnowledgeMetadata)` —— 同为带参 @Builder 且在渲染
              动态数据，**工作正常**（调用点在 `ForEach` 内为推断，未对照验证）。
      适用边界（猜测，未做对照实验）：仅在「调用点位置固定、且产出依赖一个
            只在参数中传递的值」的情形下被观察到；`ForEach` 内重建的场景
            **未观察到**该现象。
      本工程当前做法：需要跟随状态变化的数值**内联直读**（Text(`${this.prop}`)），
            **不经 @Builder 中转** —— 这是已验证有效的**实现选择**，
            不是工程级禁令。
      已应用点：`ProfilePage.ProfileOverviewCard`（原经 `overviewMetric` 中转，
            已改为内联；组件文档注释已同步标注证据等级）。
      ⚠️ 待排查（建议独立卡，卡 C）：工程内其余带参 `@Builder` 需按
            "其产出是否承载动态数值 + 调用点是否重建"逐一判断，而非按"是否带参"：
            · `ProfilePage.entryRow(glyph, label, routeName)` —— 参数为常量，**风险低**
            · `KnowledgeDetailPage.blockXxx`（`:344/355/372/422/436`）—— 调用点在
              `:267` 的 `ForEach` 内，渲染不可变内容资产，**风险低**
            · `LearnPage.stateHint(title, description)` / `errorState` —— 参数为文案常量
            · `HomePage.sectionEmptyHint(message)` —— 参数为文案常量
      来源：Profile-Overview-Fix3 之后的自查插桩（模拟机截图四层读数）；
            边界例于 v1.7.1-mvp 交接审计中补入。

- [ ] **@Observed 无 @ObjectLink 配套（状态管理范式问题，非本次 bug 根因）**
      ⚠️ **本条于本轮据实修正**：原登记曾把它列为概览卡不刷新的根因，
            经四层读数插桩证实 **该判断有误**（四层数值均正确更新）。
            本条作为**既有范式问题**保留，但降级为"待评估"。
      现象：全工程 4 个 ViewModel 均标注 `@Observed`
            （`ProfileViewModel` / `HomeViewModel` / `LearnViewModel` /
            `KnowledgeDetailViewModel`），但**全工程 `@ObjectLink` 零使用**。
            状态管理 V1 官方文档明确：`@Observed` 与 `@ObjectLink`
            须配套使用，单独标注 `@Observed` 不产生深层观察能力。
      影响：@State 持有的 ViewModel 实例，其内部字段的重新赋值理论上游离于
            渲染依赖之外；本工程现以「页内 @State 基本类型快照」范式规避
            （见 `ProfilePage.favCount` / `LearnPage.favoriteIds`），已验证有效。
      建议：不作为紧急项；如需统一，用独立卡评估改写为 `@ObjectLink` + 子组件。
      来源：Profile-Overview-Fix-Explore 证据 3/5/7 + 后续插桩修正。

- [ ] **HomePage 收藏概览的刷新表现待实测**
      现象：`HomePage.ets:245` 直接读 `this.viewModel.favoriteCount`，
            而 `HomeViewModel.ets:41` 的 `favoriteCount` 是普通字段。
      ⚠️ **本条同样据实修正**：原判定为"与 ProfilePage 同根因"，
            但真根因是带参 @Builder（见上），HomePage 未使用该写法，
            故其实际行为**需重新实测**，不可沿用原推断。
      建议：独立卡在真机上直接观察 HomePage「收藏概览」计数是否跟随。
      来源：Profile-Overview-Fix-Explore 证据 9 + 本轮根因修正。

- [ ] **hvigorw 对未知参数静默忽略**
      误传参数不会报错，会静默执行默认任务。
      `--modules` 不存在于 `hvigorw`，属 `devecocli build`。
      影响：命令拼错时无提示，可能跑错目标。
      来源：TestBlind-Spot-Verify。

- [ ] **`filesChecked` 语义修正 —— 上一卡 C 类推断被推翻**
      `devecocli check lint` 的 `Files checked` = **有诊断条目的文件去重计数**
      （源码证据：`dist/cli.js` 的 `NR()` / `qd()` 收集 `issue.filePath`），
      **不是"扫描到的文件数"**。
      影响：TestBlind-Spot-Verify 的 C 类推断 #9
      「lint 对 test 过滤不由 `code-linter.json5` 的 ignore 决定」**推理基础被推翻**。
      现况：ignore 是否生效、test 代码是否本就零诊断——**未区分，待受控实验**。
      来源：Lint-Filter-Probe（D2）。

- [ ] **ignore 两行对 `src/test/*.ets` 直接文件实际不匹配**
      `"**/src/test/**/*"` 与 `"**/src/ohosTest/**/*"` 在本工程的
      GlobMatch 实现（连续 `*` 折叠为单个 `.*`）下生成的模式为
      `.*/src/test/.*/.*`（无锚定），要求 `test/` 之后**至少还有两段路径**。
      故 `src/test/X.ets`（1 段）与 `src/test/sub/X.ets`（2 段）
      实际均不被这两条 ignore 匹配。
      **注意**：这两条 ignore 的失效不是 test 未被 lint 的原因
      （见 P0 条：真正原因是工具链层面的目录级排除）；
      本条仅记录 ignore 配置自身的语义偏差。
      来源：Lint-Block-Point-Probe（D4）N1。

---

## P2（建议 3.5 或近期处理）

- [x] **收藏色常量已收敛** ✅（本次完成，作为已关闭项保留记录）
      `#F5A623` 原就近声明于 KnowledgeDetailPage 与 LearnPage 两处，
      已统一收敛为 `AppColors.FAVORITE_ACTIVE`，引用点改为常量引用。
      验收：全工程搜索确认除 AppColors 定义处外无裸写 `#F5A623` 字面量。

- [x] **A-3 视觉常量收敛（颜色 1 项 + 尺寸 3 项）** ✅（已完成）
      颜色：`#FFF7E6` 收敛为 `AppColors.WARNING_BG`。
      尺寸：`lineHeight(24)`（2 处）收敛为 `AppDimens.LINE_HEIGHT_BODY`；
            `FAVORITE_GLYPH_SIZE = 22` 收敛为 `AppDimens.FAVORITE_GLYPH_SIZE`；
            MainPage 裸写 `.fontSize(16)` 改为引用 `AppDimens.FONT_SIZE_SUBTITLE`。
      范围：AppColors / AppDimens / KnowledgeDetailPage / MainPage 共 4 文件。
      验收：`check lint` Errors 0；`assembleHap` BUILD SUCCESSFUL；
            字面量残留全工程仅剩常量定义处；值逐字未变（diff 可证）。
      来源：A-3 阶段 1 探查报告 + 阶段 2 交付报告。

- [ ] **Profile 页无「取消收藏」入口**
      目前仅详情页右上角星标可切换收藏状态；Profile 收藏列表中无法直接取消。
      来源：3.4 交付报告未决依赖 [C]。

- [ ] **Home / Projects / Practice 三个 Tab 仍为 @Builder 占位**
      来源：3.4 / 3.4-fix3 交付报告未决依赖。
      说明：按架构「MVP 绝对优先」原则，这三者不影响核心学习闭环，故保持占位。

- [ ] **appContext 死键待评估删除**
      `EntryAbility` 冷启动时写入该键（A-1 后已引用 `AppStorageKeys.APP_CONTEXT`），
      但**全工程无任何读取方**：MainPage 走 `getUIContext().getHostContext()` 取 Context，
      各 Provider 亦不读该键。
      A-1 已将其纳管并加注「进程级 Context 交付契约预留，当前无读取方」。
      待评估：删除该写入，或明确其未来用途后保留。
      来源：A-1 阶段 1 探查报告 E 项 + 阶段 2 交付报告未决依赖 [C]。

- [ ] **A-4 UI 文案常量化（约 22 条文案 + GLYPH_STAR_* 字形归口）**
      现状：`AppStrings` 仅含骨架期占位与导航探针文案；各页面 UI 文案仍停留在模块级常量：
      KnowledgeDetailPage 7 条、ProfilePage 8 条、LearnPage 5 条、GeekCodeBlock 2 条。
      另：`'★'` 在 KnowledgeDetailPage 与 LearnPage 重复声明为 `GLYPH_STAR_FILLED`，需归口。
      范围：KnowledgeDetailPage / ProfilePage / LearnPage / GeekCodeBlock / AppStrings 共 5 文件，
      建议分两批执行以守住「单次 3~5 文件」纪律。
      来源：A-3 阶段 1 探查报告 C-5 项。

- [ ] **docs/assets/ 下 4 张原理图待决定「补引用 / 保留 / 清理」**
      A-2 处置时已将 `gpio_key_sch.png` / `i2c_pullup_sch.png` / `power_ldo_sch.png` /
      `uart_ch340_sch.png` 从 `rawfile/database/images/` 移至 `docs/assets/`（不再随包发布）。
      待决定：① 在相应章节正文补引用（需移回 rawfile 并改 JSON，属数据改动）；
              ② 作为仓库文档素材长期保留；③ 清理。
      来源：A-3.5 同步时实测发现（原 A-2 条目前提已失效），架构师追认。

- [ ] stage5_adc_sensor_diagram (1568x130) 与 stage9_tinyml_diagram (1568x176)
  两张超宽图在手机竖屏上即使全屏预览也仅约 30~40vp 高。
  建议按语义拆成 2~4 张子图重渲（属 3.5-c）。
  触发条件：用户反馈"看不清"时立项。

- [ ] **UserStore.broadcast 的毫秒级竞态**
      现象：`UserStore.ets:109` 的版本号广播实现为
            `AppStorage.setOrCreate<number>(key, Date.now())` ——
            以**毫秒时间戳**作为版本号。
      影响：同一毫秒内的两次状态变更会产生**相同**的版本号值；
            而 `@Watch` 仅在**值发生变化**时触发 → 第二次变更**不会**
            唤醒任何监听页面 → 依赖版本号刷新的 UI 漏刷。
            典型触发场景：快速连续收藏 / 取消收藏、详情页连续切章记录足迹。
      修复方式候选：
            · 改用**自增计数器**替代 `Date.now()`（最直接，语义也更准确）；
            · 或版本号 + 内容哈希组合（可额外区分"值变但内容未变"的无谓刷新）。
      建议：独立卡处理，需评估对现有 4 处 `@Watch` 消费者
            （ProfilePage / FavoritesPage / HistoryPage / HomePage）的影响面。
      来源：Profile-Overview-Fix-Explore 第一段证据 4 与根因候选 3。
- [ ] **归档文件 DSH_Init_Handover.md 存在一条 [待核实] 答复错误**
      该文档 §6.1 表格将 `RootTabContainer.tabBarBuilder` 标为 `[待核实]`；
      继承核验时 DSH 曾答"风险低，可结案"，**该答复为误** —— 不应结案，
      因该条从未被观测、且属循环论证（用"应用显然能用"反推结论）。
      归档文件不改，纠正记录于此。
      来源：Profile-Attribution-Correction 卡 A 二次修正。

---

## P3（接受现状 / 长期观察）

- [ ] **LearnPage 存在 4 个刷新入口**
      `aboutToAppear` / `onRootTabChanged`（@Consume+@Watch）/ `onPageShow` /
      `@StorageLink(FAVORITES_VERSION)+@Watch`。
      `@StorageLink` 已在 3.4-fix3 中证明可全覆盖所有触发场景；
      其余三者为历史任务卡明确要求保留的备份路径，且彼此幂等，无功能风险。
      来源：3.4-fix3 交付报告未决依赖 [A]。
      处置建议：若后续确认 @StorageLink 长期稳定，可精简 onPageShow / onRootTabChanged
      （保留 @Consume 广播仍可服务其他页面）。

- [ ] **ProfilePage 的 onRootTabChanged 与 @StorageLink 功能重叠**
      切 Tab 时两者都会触发刷新，属幂等冗余。
      来源：3.4-fix3 交付报告未决依赖 [B]。

- [ ] **ch20 Mermaid 图标签视觉重叠**
      属 mermaid 布局算法固有行为，非渲染缺陷，接受现状。
      来源：Mermaid 字号优化 v3 阶段结论。

- [ ] **26 张 Mermaid 中 7 张相对字号增益 < 20%**
      绝对字号已从 16px 提升至 20px，相对增益受标签长度与画布尺寸约束，接受现状。
      来源：Mermaid 字号优化 v3 阶段结论。

- [x] ImageViewerOverlay 超宽图下方留白 8~18vp（候选 A 的代价）✅（已收口）
      M3.5-d 已真机验证通过，留白不影响观感，**无需**升级到候选 C
      （加"点击查看大图"提示行）。
      来源：M3.5-d 交付报告 + 架构师真机验证结论。

- [ ] **ohosTest target 构建产生 color.json 冲突告警**
      `entry/src/main/resources/base/element/color.json` 与
      `entry/.test/.../ohosTest/resources/base/element/color.json`
      对 `start_window_background` 重复声明（WARN，不阻断）。
      来源：TestBlind-Spot-Verify。

- [ ] **Code Linter 的 GlobMatch 非标准 glob**
      `GlobMatch.globToRegex` 为朴素转换（`*` → `.*`，转义特殊字符），
      **仅当模式以 `.扩展名` 结尾时才加 `$` 锚定**。
      例：`"**/src/ohosTest/**/*"` → `/.*\/src\/ohosTest\/.*/`（无锚定）。
      影响：ignore / files 模式写法不能与标准 glob 互换。
      来源：Lint-Filter-Probe（D2）。

- [ ] **Code Linter DEFAULT_CONFIG 与本工程 ignore 逐字相同**
      `codelinter/index.js` 内建的 `DEFAULT_CONFIG.ignore` 与本工程
      `code-linter.json5` 的 ignore 数组**逐字相同**。
      `isDefaultConfig` 深比较；`generateDefaultConfig()` 仅在项目无配置时落盘。
      来源：Lint-Filter-Probe（D2）N2。

- [ ] **`ROOT_FILE_IGNORE_PATTERNS` 为死常量（无使用点）**
      `codelinter/index.js` 中定义但全 bundle 无消费点。
      避免误将其当作实际过滤源。
      来源：Lint-Filter-Probe（D2）N3。

- [ ] **Code Linter 的 GlobMatch 非标准 glob（补充实例）**
      既有条目记录其转换算法；本条补充具体影响：
      · `"**/src/test/**/*"` → `.*/src/test/.*/.*`（不匹配 `src/test/X.ets`）
      · `"**/src/ohosTest/**/*"` → `.*/src/ohosTest/.*/.*`（同理）
      · `"**/*.ets"` → `.*/.*\.ets$`（匹配，因以扩展名结尾被加锚定）
      来源：Lint-Block-Point-Probe（D4）N1。

- [ ] **`projectBuildFile` 优先读 `.hvigor/outputs/sync/output.json`**
      `parseProjectBuildProfile` 先尝试读 `.hvigor/outputs/sync/output.json`
      的 `ohos-project.PROFILE_OPT`，命中则直接返回；
      仅在未命中时才解析 `build-profile.json5`。
      来源：Lint-Block-Point-Probe（D4）N2。

- [ ] **codelinter 的 `--targets` 经环境变量传入（非 CLI 参数）**
      `Options` 构造函数：`this._targets = process.env.targets`。
      来源：Lint-Block-Point-Probe（D4）N3。

- [ ] **`--dir` 在未设 `--isTooManyFiles true` 时被当作 JSON 数组解析**
      `getCustomCheckPaths(dir, isTooManyFiles)`：
      `isTooManyFiles === 'true'` 时读文件 + `JSON.parse`；
      否则直接把 `dir` 当 JSON 字符串解析。
      来源：Lint-Block-Point-Probe（D4）N4。

- [ ] **`devecocli` 顶层无 `clean` 子命令**
      `devecocli --help` 列出的 15 个顶层命令中无清理类命令。
      清理能力在子命令：`devecocli build clean`。
      实测 `devecocli clean` 报 `unknown command 'clean'`。
      来源：Lint-Block-Point-Probe（D4）N5。

- [ ] **codelinter 把清单写 `$TEMP/<ts>_check_file `（尾随空格）**
      `Options` 构造：`_checkFileJsonPath = resolve(tmpdir(), `${Date.now()}_check_file `)`。
      该命名在 Windows / NTFS 下形成元数据幽灵项：
      可被 `GetFiles` 枚举，但 `FileInfo.Exists = False`、
      `ReadAllBytes` 抛异常（4 种读法全失败，281,853 次尝试 0 成功）。
      **与"test 未被 lint 扫描"无关**（两件独立事项，证据链未连通）。
      来源：Lint-Entry-Chain-Probe（D5）。

- [ ] **`modulePaths` = 模块根（`entry/`）而非 `entry/src/main/`**
      `getAllModulePaths` 遍历 `projectBuildFile.modules[].srcPath`
      （本工程为 `./entry`）拼接路径 + `path.sep`。
      故 `inModule` 判定范围为整个模块根，比直觉更宽。
      来源：Lint-Block-Point-Probe（D4）N7。

---

## 近期完成与遗留登记（Cleanup-4 补登记）

> 登记说明：本节由 Cleanup-4 补登记，补齐此前未登记的各卡进度。
> 来源均为各卡交付报告中**实际出现过**的结论；无交付报告依据的条目已标注
> 「来源待架构师确认」，请架构师核实或删除，以符合本文件「禁止推测性扩充」约定。

### 已完成（保留追溯）

- [x] **Cleanup-2 空态文案统一与同值键合并** ✅
      措辞统一：`PROFILE_EMPTY_HISTORY_TITLE` 由「暂无阅读记录」改为「还没有阅读记录」。
      同值键合并：`PROFILE_EMPTY_FAVORITES_TITLE` + `HOME_EMPTY_FAVORITES` → `EMPTY_FAVORITES`；
                  `PROFILE_EMPTY_HISTORY_TITLE` + `HOME_EMPTY_HISTORY` → `EMPTY_HISTORY`。
      空态键总数 11 → 9；`*_DESC` 两键保留。
      范围：AppStrings / FavoritesPage / HistoryPage / HomePage 共 4 文件。
      附带清理：`entry/.preview` 陈旧预览缓存（291 文件 / 7.19 MB，已 gitignore）。
      验收：`check lint` Errors 0；`assembleHap` BUILD SUCCESSFUL。

- [x] **Cleanup-3 level 联合类型约束 + 运行期校验** ✅
      收窄：`KnowledgeMetadata.level` 由 `string` 改为 `KnowledgeLevel`
            （`'Basic' | 'Medium' | 'Hard'`，字符串字面量联合类型，非 enum）。
      校验：`RawFileAssetDataSource` 新增 `isLevel` 白名单（对齐既有 `isBlockType` 先例），
            非法值抛 `JSON_INVALID`；保持 `parseKnowledgeIndex` 全有或全无语义。
      范围：KnowledgeMetadata / RawFileAssetDataSource 共 2 文件；
            因联合类型收窄传导出 2 处空态哨兵编译错误，经扩权修复
            KnowledgeCard / KnowledgeDetailPage 的 `level: '' as KnowledgeLevel`。
      来源：C-1 D3 登记 → Cleanup-3 第一段探查 + 第二段交付报告（含熔断上报 + 扩权）。

- [x] **C-1 Learn 难度筛选** ✅（tag v1.6.0-mvp）
      新增难度筛选维度，与既有分类筛选并置，二者为「与」关系。
      范围：LearnViewModel（新增 `selectedLevel` / `levelList()` / `selectLevel()`，
            改写 `visibleList()` 为双条件）/ LearnPage（并置第二条筛选栏 + 空态分流）/
            CategoryBar（参数重命名 `categories`→`options`、`onCategorySelected`→`onSelected`，
            `ForEach` key 改为 `${index}-${item}` 避免双栏撞名）/ AppStrings（+2 键）。
      数据实况：index.json 34 章 level 分布 Basic 9 / Medium 15 / Hard 10。
      来源：C-1-Explore 探查报告 + C-1-Impl 交付报告。

- [x] **UI-Polish-1 筛选栏维度标签** ✅（tag v1.6.1-mvp）
      两条筛选栏左侧各加小字标签（「分类」/「难度」），解决「两排首项都是『全部』」
      无法区分维度的可用性缺口。
      范围：LearnPage（Row 包裹 + Text 标签）/ AppStrings（+2 键，`LEARN_FILTER_*_LABEL`）。

- [x] **Cleanup-4 index.json level 校验（核心价值，已落地）** ✅
      校验：`docs/tools/append_index.mjs` 新增 `LEVEL_WHITELIST` +
            `collectInvalidLevels()`，在 `main()` 内于**任何写盘之前**对
            `index.items` 做**全量**校验（覆盖存量 + 新增，D5 裁决），
            非法即 `throw` → 复用 `run_pipeline.mjs` CRITICAL 熔断语义。
            补齐了「meta 侧 / details 侧有校验、唯独随包发布的 index.json 无校验」的缺口。
      实证：校验函数 5 项独立用例 PASS（真实 34 条零非法 / 注入小写 basic 精确捕获 /
            undefined·null·数字全捕获 / 缺 id 标记 / 全合法不误报）；
            `node --check` 语法通过。
      治理：BACKLOG 补登记 Cleanup-2/3/4 + C-1 + UI-Polish-1 + D1 文档偏差等条目。
      关注点：校验集合多处重复（`append_index.mjs LEVEL_WHITELIST` /
            `verify_chapter.mjs:46 LEVELS` / `check_meta.mjs:39` 与
            `run_pipeline.mjs:61` 内联数组），见下方待收敛项。

- [x] **Cleanup-4 负向单测与测试挂载（已回退）** ⛔
      回退内容：
        - 删除 `entry/src/test/datasources/RawFileAssetDataSource.test.ets`；
        - `List.test.ets` 回退为仅挂载 `localUnitTest`；
        - `KnowledgeRepository.test.ets` 保留文件但**不挂载**（文件头已加说明注释）。
      回退原因：mock `ResourceManager`（64 成员 interface）无合理成本方案，
            详见上方「测试套件因 mock 成本过高而暂未挂载」条目。
      保留的部分修复：`KnowledgeRepository.test.ets` 的 `as Failure` 类型收窄
            （纯类型改进，与 mock 无关，独立有效）。
      代价（如实记录）：运行期 level 白名单的负向验证**未取得**；
            但构建期防线（append_index.mjs 全量校验）已建立且有 5 项实证。
      来源：Cleanup-4 收尾指令（方案 3）。

### 待处理 / 待评估

- [ ] **测试套件因 mock 成本过高而暂未挂载**
      现状：`entry/src/test/repositories/KnowledgeRepository.test.ets`（6 个用例）
            与已删除的 `entry/src/test/datasources/RawFileAssetDataSource.test.ets`
            均**不在** `List.test.ets` 挂载范围内，故其用例不会被执行。
      根因：两者都需要一个 `resourceManager.ResourceManager` 实例，而它是
            **64 个成员的 interface**（SDK `@ohos.resourceManager.d.ts:487`），
            ArkTS 严格模式下：
              - `as unknown as` 不可用（ArkTS 禁 `unknown`，工程零先例）；
              - hamock `mockObject` 不可用（源码 `MockKit.ts:228-241` 只复制
                传入对象**已有**的函数成员，无法凭空合成 64 个方法；
                且返回类型为 `Object`，仍过不了参数类型检查）；
              - 手写 64 个 stub 成本高于负向单测本身价值。
      候选方案（待独立卡裁决）：
            ① 放宽 `RawFileAssetDataSource` 构造签名为可空
               （测试场景本就不使用 resourceMgr，参数如实声明比断言欺骗更诚实）；
            ② 由脚本从 SDK 声明机械生成 64 方法 stub 文件（不手写、可复核）；
            ③ 改用其他 mock 策略 / 交由 DevEco 的 mock-config 机制处理。
      来源：Cleanup-4 收尾指令方案 3（回退负向单测）+ 交付报告未决依赖。

- [ ] **架构文档 level 类型精度偏差**
      `EmbedLab_Project_Architecture.md:225`（「level: 字符串，难度等级（Basic / Medium / Hard）」）
      与 `:239`（「level: 字符串，难度等级」）仍描述为 `string`，
      而实现已于 Cleanup-3 收窄为 `KnowledgeLevel` 联合类型。
      处置：需架构师裁决「实现细节收紧（不必改文档）」还是「架构变更（须先改文档）」。
      约束：该文档为 Architecture Frozen，禁止 Agent 修改。
      来源：Cleanup-3 第一段 D1 + 第二段交付报告未决依赖 D1。

- [ ] **`check_meta.mjs` 为孤立脚本（无任何调用点）**
      现状：`docs/tools/check_meta.mjs` 含 meta 合规检查（字段集合 / id / title /
            category / level 白名单 / tags / summary），但全工程 grep 确认
            **无任何脚本或配置调用它**，不在 `run_pipeline.mjs` 的 `runChild` 链内。
      与其功能重叠者：`run_pipeline.mjs:44-66 validateMeta`（阶段 1 前置校验）。
      待评估：① 接入 pipeline 作为独立检查步骤；② 确认冗余后删除。
      来源：Cleanup-4 第一段证据 1 / 证据 2。

- [ ] **level 白名单字面量三处重复，待收敛**
      重复点：`docs/tools/append_index.mjs`（Cleanup-4 新增 `LEVEL_WHITELIST`）/
              `docs/tools/verify_chapter.mjs:46`（`LEVELS`）/
              `docs/tools/check_meta.mjs:39` + `docs/tools/run_pipeline.mjs:61`（内联数组）。
      现状：四处各自硬编码同一集合，新增难度档位时需同步改多处，易漏改
            （Cleanup-3 已在 `KnowledgeLevel` 与 `isLevel` 之间建立同样的同步约束，
             现扩展为「源码 + 4 处脚本」共 6 个落点）。
      处置建议：**独立卡**处理，需新建共享常量模块并触及多个 pipeline 脚本；
            `verify_chapter.mjs` 的 v2.1 规则为 FROZEN（`docs/pipeline/AUDIT.md:69`），
            触碰前须再次裁决。
      来源：Cleanup-4 第一段风险 R4 + 第二段交付报告未决依赖。

- [ ] **ProfilePage 概览卡不刷新 bug**
      现象与复现条件**未经我验证**，本卡仅按人类架构师指令登记。
      来源待架构师确认（未在既有交付报告中出现过，建议补充现象、复现步骤与影响面）。
      登记依据：Cleanup-4 第二段指令 D4 指定登记项。

- [ ] **UI-Immersion-1 提交进入 main 的流程偏差**
      实况：提交 `02b895b`（"feat: NavDestination title bar material"）的提交信息
            自述 **"R2 not passed"**（即真机验证未通过），但该提交已快进合并入 `main`。
      冲突：与既定规矩「main 仅接受已通过真机验证的合并」不一致。
      代码现状：`KnowledgeDetailPage` 的 `systemMaterial` 实现仍在包内；
            因 R2 判定无可见效果，其可见性取决于后续沉浸式布局立项。
      待处置：由架构师决定 ① 保留并降级为「待布局配合」；② 从 main 回退；
            并明确「未验证即入 main」的例外是否需要补记流程说明。
      登记依据：Cleanup-4 第二段指令 D4 指定登记项；
            提交信息与合并事实来自本会话 `git log` / `git reflog` 实况。

### 来源待架构师确认（本卡按指令登记，但缺交付报告依据）

- [ ] **上面两项带「来源待架构师确认 / 登记依据：Cleanup-4 指令」标注的条目**
      说明：`docs/BACKLOG.md` 维护约定第 3 条要求「禁止写入任何未在交付报告中
            实际出现过的条目」。其中「ProfilePage 概览卡不刷新 bug」在既有交付报告
            中**未出现过**（UI-Immersion-1 真机验证报告未回传），
            故如实标注其来源为任务卡指令而非交付报告。
      请架构师：确认保留并补充依据，或从本文件删除。

---

## 已关闭（保留追溯）

- [x] **收藏色常量收敛到 AppColors**（本次 Freeze 任务完成）
- [x] **Mermaid 字号优化 v1 → v2 → v3**（3 项验收达标，26 张图已入包）
- [x] **3.4 刷新链路 4 次迭代定稿**
      3.4（@Provide/@Consume+@Watch，仅覆盖切 Tab）
        → fix1（同方案补 onPageShow）
        → fix2（pushPathByName onPop 回调，**实测未触发**，属死代码已移除）
        → **fix3（@StorageLink + @Watch 版本号广播，状态驱动，全覆盖定稿）**
- [x] **base/media/knowledge 非法嵌套目录**
      HarmonyOS 的 `resources/base/media/` 不支持子目录，导致 assembleHap 资源扫描失败；
      已整体迁移至 `rawfile/database/images/knowledge/`（内容零改动）。
- [x] **PushPathByName onPop 死代码移除**（随 3.4-fix3 一并清理）

- [x] M3.5 图片全屏预览 + 双指缩放（真机验证通过，几天使用无问题）
- [x] bindContentCover 多绑定未定义行为（收敛为全页唯一绑定）
- [x] image 块点击热区不足 40vp（候选 A constraintSize 修复）

- [x] **AppStorageKeys 未纳管现有 3 个键** ✅（A-1 已完成纳管）
      原状：`appContext`（EntryAbility 写入）、`logLevel` 与 `logBundleName`（Logger 写入）
            仍为硬编码字符串，未纳入 `constants/AppStorageKeys.ets`。
      处置：3 个键值原样纳管为 `APP_CONTEXT` / `LOG_LEVEL` / `LOG_BUNDLE_NAME`；
            EntryAbility 1 处、Logger 4 处引用全部改为常量引用；
            Logger 内 2 个私有键常量（`LOG_LEVEL_KEY` / `BUNDLE_NAME_KEY`）删除；
            EntryAbility 中与事实不符的注释一并修正（原称"由 MainPage 读取"，实际不读）。
      验收：全工程 grep 三个键的字面量仅剩 AppStorageKeys 定义处；
            `check lint` Errors 0；`assembleHap` BUILD SUCCESSFUL。
      来源：3.4-fix3 交付报告未决依赖 [E] → A-1 阶段 1 探查 + 阶段 2 交付报告。

- [x] **PreferenceDataSource.production.test.ets.disabled 的最终处置** ✅（A-2 已删除该文件）
      路径（原）：`entry/src/ohosTest/ets/test/PreferenceDataSource.production.test.ets.disabled`
      原状：已从 List.test.ets 摘除挂载并加 `.disabled` 后缀保留。
      原因（已验证的结论）：ohosTest 进程的 `getAppContext()` 返回应用级 BaseContext，
            无 module sandbox 绑定，Preferences 服务运行时拒绝；
            而 App 进程内 MainPage 走的是 `getUIContext().getHostContext()`，二者来源不同。
      替代验证：生产路径已由 `I/MainPage: user state hydrated: fav=N hist=M` 日志覆盖。
      处置：已由架构师侧删除该文件（A-2 清理动作）（实测该路径已不存在）。
      来源：3.4 交付报告裁决「3.4 收口时暂留」→ A-2 处置 → A-3.5 同步登记。

- [x] **5 个未引用资产待处置** ✅（已由架构师侧执行（A-2 清理动作））
      原状：`WarShip STM32F1_V3.4_SCH.pdf`(711 KB) 与 4 张原理图
            （`gpio_key_sch.png` / `i2c_pullup_sch.png` / `power_ldo_sch.png` / `uart_ch340_sch.png`）
            位于 `rawfile/database/images/` 下但无任何 JSON 引用。
      处置：PDF 删除；4 张原理图移至 `docs/assets/`（不再随包发布）。
      交叉验证：5 个文件名在 `details/*.json` 中零引用（无断链）；
            处置后 `assembleHap` 仍 BUILD SUCCESSFUL。
      遗留：4 图后续「补引用 / 保留 / 清理」三选一，已另行登记于 P2。
      来源：M35_DIAGNOSE.md 第 4 节建议 4 → A-2 执行 → A-3.5 同步登记。
- [x] **`refreshFlag` 哨兵为全工程死代码** ✅（Cleanup-B 已清理 7 页）
      关闭理由：Cleanup-B 已清理 7 页 `refreshFlag`（含 `ProfilePage`）。
            现况：`.ets` 全工程归零，仅 `UserStore.ets:18` 注释保留。
      原状：`refreshFlag` 在 6 个页面均为「只写不读」（`HomePage` 写 5 /
            `ProfilePage` 写 5 / `LearnPage` 写 1 / `FavoritesPage` 写 3 /
            `HistoryPage` 写 3 / `KnowledgeDetailPage` 写 1），读取点全工程为 0；
            仅写入而从不被 `build()` 读取的状态变量不构成渲染依赖，从未驱动过重绘。
      处置：7 页的字段声明、绑定注释与全部赋值点一并移除
            （`HomePage` -9 / `LearnPage` -10 / `KnowledgeDetailPage` -10 /
            `FavoritesPage` -6 / `HistoryPage` -6 行）。
      验收：全工程 grep `refreshFlag` 于 `.ets` 仅剩 `UserStore.ets:18` 注释；
            `check lint` Errors 0；`assembleHap` BUILD SUCCESSFUL。
      来源：本轮冗余代码审计（`grep refreshFlag` 全工程扫描）→ Cleanup-B 执行。

- [x] **`ProfileViewModel` 孤儿符号簇** ✅（Cleanup-B 已清理）
      关闭理由：Cleanup-B 已清理。实际为 4 符号（`selectTab` /
            `visibleItems` / `isEmpty` / `selectedTab`）+ 2 常量
            （`TAB_FAVORITES` / `TAB_HISTORY`），构成内部互引死簇。
      原状（全工程 + docs 扫描，零外部调用点）：
            · `selectTab(tab)` —— 无调用方
            · `visibleItems()` —— 仅被 `isEmpty()` 调用
            · `isEmpty()` —— 无调用方
            · `selectedTab` —— 仅被上述两者读写
            · 连带 `TAB_FAVORITES` / `TAB_HISTORY` 两个模块级常量
      成因：Profile-R 重构把「收藏 / 历史双 Tab + 页内列表」拆到
            `FavoritesPage` / `HistoryPage` 二级页后，这组 Tab 选择逻辑失去消费者。
      处置：整簇一次性移除（`ProfileViewModel.ets` -23 行，纯删除零插入）。
      验收：6 符号于 `.ets`/`.ts` 全仓 grep 归零；`assembleHap` BUILD SUCCESSFUL
            且零「找不到符号」报错（证明无外部引用遗漏）。
      来源：本轮冗余代码审计 → Cleanup-B 执行（扩权后整簇删除）。

---

## 维护约定

1. 本文件由人类架构师与 AI Agent 共同维护；Agent 仅可在交付报告中登记新项。
2. 关闭条目不删除，移入「已关闭」区并保留来源追溯。
3. 禁止写入任何未在交付报告中实际出现过的条目。
4. 本文件不含任何代码引用或构建配置，改动不影响编译产物。
