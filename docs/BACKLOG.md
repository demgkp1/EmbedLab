# EmbedLab 技术债清单（BACKLOG）

Last Update: 2026-09-17

> 本文件只做**登记**，不触发任何代码改动。
> 所有条目均来自各 Milestone 交付报告中**实际出现过**的未决项，不作推测性扩充。
> 优先级定义：P1 = 阻塞后续开发；P2 = 建议近期处理；P3 = 接受现状 / 长期观察。

---

## P1（阻塞后续开发）

当前无 P1 项 —— Milestone 3.4-fix3 已使收藏 / 历史的跨页面刷新链路全覆盖（K1~K4 通过）。

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

---

## 维护约定

1. 本文件由人类架构师与 AI Agent 共同维护；Agent 仅可在交付报告中登记新项。
2. 关闭条目不删除，移入「已关闭」区并保留来源追溯。
3. 禁止写入任何未在交付报告中实际出现过的条目。
4. 本文件不含任何代码引用或构建配置，改动不影响编译产物。
