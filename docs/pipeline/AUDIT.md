# 全书质检审计（verify_chapter 覆盖 34 章）

- 生成时间：2026-09-13 10:38:39
- 校验器：`docs/tools/verify_chapter.mjs`（schema + 代码逐字 + 标题/正文覆盖）
- 结论：PASS 32/34；FAIL：1, 7

| 章节 | id | 校验 | 块数 | 代码块(源/JSON) | index |
| ---: | :-- | :-- | ---: | :-- | :-- |
| 1 | stage1_intro | FAIL | 26 | 0/0 | Y |
| 2 | stage1_computer | PASS | 47 | 4/4 | Y |
| 3 | stage1_digital_circuit | PASS | 30 | 0/0 | Y |
| 4 | stage1_mcu_soc | PASS | 47 | 0/0 | Y |
| 5 | stage2_cpu | PASS | 54 | 1/1 | Y |
| 6 | stage2_c_language | PASS | 62 | 9/9 | Y |
| 7 | stage3_gpio | FAIL | 34 | 0/4 | Y |
| 8 | stage3_interrupt | PASS | 51 | 2/2 | Y |
| 9 | stage3_timer_pwm | PASS | 46 | 1/1 | Y |
| 10 | stage4_uart | PASS | 53 | 2/2 | Y |
| 11 | stage4_i2c | PASS | 37 | 0/0 | Y |
| 12 | stage4_spi | PASS | 42 | 0/0 | Y |
| 13 | stage5_adc_sensor | PASS | 41 | 0/0 | Y |
| 14 | stage5_dma | PASS | 53 | 0/0 | Y |
| 15 | stage6_watchdog | PASS | 35 | 0/0 | Y |
| 16 | stage6_flash | PASS | 45 | 0/0 | Y |
| 17 | stage6_rtos | PASS | 43 | 0/0 | Y |
| 18 | stage6_concurrency | PASS | 53 | 1/1 | Y |
| 19 | stage7_network | PASS | 42 | 0/0 | Y |
| 20 | stage7_mqtt | PASS | 45 | 0/0 | Y |
| 21 | stage7_linux | PASS | 33 | 0/0 | Y |
| 22 | stage7_bootloader | PASS | 47 | 0/0 | Y |
| 23 | stage8_build | PASS | 38 | 0/0 | Y |
| 24 | stage8_debug | PASS | 49 | 0/0 | Y |
| 25 | stage8_low_power | PASS | 43 | 0/0 | Y |
| 26 | stage8_driver | PASS | 35 | 3/3 | Y |
| 27 | stage8_architecture | PASS | 43 | 1/1 | Y |
| 28 | stage9_sensors | PASS | 61 | 2/2 | Y |
| 29 | stage9_robotics | PASS | 37 | 1/1 | Y |
| 30 | stage9_tinyml | PASS | 34 | 0/0 | Y |
| 31 | stage9_project | PASS | 37 | 1/1 | Y |
| 32 | stage9_troubleshooting | PASS | 45 | 0/0 | Y |
| 33 | appendix_learning_path | PASS | 55 | 0/0 | Y |
| 34 | appendix_glossary | PASS | 19 | 0/0 | Y |

## 未通过章节说明

- 第 1、7 章为**上一轮既有成品**（本轮任务开始前已存在于 index.json 与 details/），采用当时的教材化模板切分，未按本轮《数据契约与切分红线》逐段切分，故逐字校验不过：ch1 原文含 1 段 mermaid 图（被渲染为 image 块），ch7 原文 1 段示例被扩写为 4 个代码块。
- 这两章不属于本轮差集（缺失章节）范围，为避免覆盖已验收内容，本轮**未改动**；如需统一，可对二者执行同一流水线重转。

---

# 阶段 2 收口记录：校验规则 v2.1 + mermaid 图片化

> 本文件上半部分（总表与"未通过章节说明"）由 `audit_all.mjs` 自动生成、重跑即重写；
> 本节为人工追加的权威结论。上表中的 `代码块(源/JSON)` 列自 v2.1 起**只统计非 mermaid 围栏**，
> mermaid 相关判定见下文与 `docs/pipeline/logs/audit_*.log` 的 `[verify] mermaid :` 行。

## 一、校验规则版本：verify_chapter.mjs v2.1「mermaid 围栏豁免」

| 项 | 内容 |
| :--- | :--- |
| 规则版本 | `v2.1 mermaid 围栏豁免`（校验日志首行打印版本号） |
| 变更 1 | 新增 **mermaid 围栏豁免**：原文 ` ```mermaid ` 围栏 N 段时，JSON 中 **image 块数 ≥ N** 即判 PASS（图表以位图资产承载，不再要求 code 块还原） |
| 变更 2 | 严格规则**原样保留**：C / asm / bash / text 等一切非 mermaid 围栏仍须逐字或可加性还原，且 JSON 中不得出现源码不存在的 code 块 |
| 变更 3 | **豁免范围仅限 `language === 'mermaid'`**，严禁泛化；非 mermaid 围栏即使 image 块再多也不豁免 |
| 变更 4 | 自检用例由 11 条扩至 **19 条**（新增：mermaid+1 图 PASS、图不足 FAIL、0 图 FAIL、mermaid 与 C 混合双合规 PASS、混合但 C 被篡改 FAIL、bash/asm 不得用图豁免 FAIL） |
| 自检结果 | `node docs/tools/verify_chapter.mjs --self-test` → **19/19 通过** |
| 回归影响 | v2.0 严格路径逐字未改；28 章完成 mermaid 图片化后仍全部 PASS，无回归 |
| 改动文件 | 仅 `docs/tools/verify_chapter.mjs`（`evaluateCode` 增加 `imageBlocks` 入参并做围栏分流；新增 `MERMAID_LANG` 常量）；**未改任何 ArkTS、未改任何 md** |
| **状态** | **v2.1 规则冻结（FROZEN）** —— 经架构师裁决确认，后续转换/校验一律以 v2.1 为准；如需变更须再次裁决并升级版本号 |

## 二、mermaid 图片化（阶段 2）执行记录

| 项 | 值 |
| :--- | :--- |
| 渲染器 | `@mermaid-js/mermaid-cli` **11.17.0**（Chromium `win64-152.0.7977.75`，本地 puppeteer 缓存） |
| 渲染参数 | `-t neutral -b white -s 2`（统一，无额外配置） |
| 输出目录 | `entry/src/main/resources/rawfile/database/images/diagrams/`（平铺，无额外层级） |
| 命名 | `{id}_diagram.png` |
| JSON 引用 | `"content": "database/images/diagrams/{id}_diagram.png"`（**26 章**由 `code(mermaid)` 块**原位替换**为 `image` 块） |
| 渲染产出 | 28 张，2.46 MB（含 2 张最终未采用的孤儿图） |
| **交付资产（收口后）** | **26 张，合计 2,346.0 KB（2.29 MB）**；最大 `appendix_learning_path_diagram.png` 155.1 KB；**超 200 KB 阈值 = 0**；`diagrams/` 目录文件数 = **26** |
| 已删除（3 个，共 309,016 B = 301.8 KB） | `stage1_intro_diagram.png`（125,661 B）、`stage3_gpio_diagram.png`（50,104 B）—— 无 JSON 引用的孤儿图，架构师裁决 1；`_SAMPLE.png`（133,251 B）—— 阶段 1 目视样图，裁决 3。逐条理由与大小见 `docs/pipeline/diagrams_manifest.json` 的 `deleted` 字段 |
| `images[]` | 34 章全部按裁决填充：`images = 该章所有 image 块 content（去重，保持出现顺序）` |
| 清单证据 | `docs/pipeline/diagrams_manifest.json`（`items` 26 条 + `deleted` 3 条 + `summary`） |
| 渲染期修复 | ch15、ch20 原文边标签含**未加引号的括号**（`-->|是 (正常)|`），mermaid 11 解析报错；渲染层对边标签统一加引号后渲染成功（**源 `.md` 未改动**，引号不参与显示，观感不变） |
| 打包验证 | `clean` + `assembleHap` → **BUILD SUCCESSFUL**；HAP = **5,028,273 B（4.80 MB）**，包内 26 张 diagram + 6 个历史资产（含 PDF）；`_SAMPLE.png` / 两张孤儿图在 HAP 内条目数均为 **0**（无残留） |

### 已知视觉瑕疵清单（架构师裁决 2：接受，不修）

| 编号 | 章节 | 现象 | 定性 | 处置 |
| ---: | :--- | :--- | :--- | :--- |
| V-1 | ch20 `stage7_mqtt` | 自环边标签「2. 检查谁订阅了 home/temp」与相邻两条出边标签（「3. 主动推送 (Push) / 内容: 25.5」）存在**视觉重叠** | mermaid 自动布局固有问题，**非数据缺陷**；不影响语义理解（读图可辨自环边） | **接受现状**。实测加大 `nodeSpacing(90)/rankSpacing(110)` 会使重叠更严重，已回退为 v2.1 统一参数；修标签文案 = 改源 `.md`，违反"源零改动"契约，不做 |

## 三、分级就绪结论（v2.1 口径，已收口）

| 分级 | 章节 | 数量 | 验收口径 | 结果 |
| :--- | :--- | ---: | :--- | :--- |
| **自动转换批次** | ch2–ch6、ch8–ch34 | **32** | `verify_chapter.mjs v2.1`（严格逐字 + 可加性拆解 + mermaid 围栏豁免） | **32/32 PASS** |
| **人工增强章节** | ch1、ch7 | **2** | Milestone 2.5 人工 Review 通过；降级口径 = schema 合规 + 内容非空 + code 块 language 合法 | **2/2 PASS** |

### 全书就绪度：34/34 = 32/32 自动 + 2/2 人工

> **ch1/ch7 与 v2.1 逐字契约的差异为内容增强，非数据缺陷，端侧渲染不受影响（同一 ContentBlock 契约）。**

## 四、ch1 / ch7 在 v2.1 口径下的残留差异（实证）

| 项 | ch1（stage1_intro） | ch7（stage3_gpio） |
| :--- | :--- | :--- |
| v2.1 mermaid 维度 | **PASS**：源 1 段围栏 / JSON 1 个 image 块 | **PASS**：源 1 段围栏 / JSON 1 个 image 块 |
| 非 mermaid 代码维度 | 源 0 / JSON 0，无差异 | **FAIL**：源 0 段，JSON 有 4 个源码不存在的 C code 块 |
| 残留 FAIL 条数 | 26 条（标题未映射 5 + 正文行/表格缺失 21） | 32 条（多余 code 块 1 + 标题未映射 10 + 正文缺失 21） |
| 定性 | 整章级人工增强改写（模板化标题体系与正文组织），与 mermaid / 代码规则无关 | 同上，另含上一轮人工补写的 C 示例 |

→ 二者在"分级就绪"中按**人工增强口径**验收（Milestone 2.5 人工 Review + schema/非空/language 降级口径 = PASS），
v2.1 逐字口径下的 FAIL 事实**原样保留、未伪造 PASS**。

## 五、图片引用核验（阶段 2 更新）

- 原文（`docs/chapters/*.md`）图片引用：**0 处**（Markdown `![](...)` + HTML `<img>` 两种语法全库扫描；与阶段 1 侦察结论一致）
- JSON image 块合计：**28 个** = **26 章 × 1**（本次 mermaid 图片化）+ **ch1/ch7 × 1**（上一轮人工插图）；其余 6 章（ch2/3/6/26/28/34）无 image 块
- **丢失 = 0**（原文本无图片引用，不存在"原文有图、JSON 无 image 块"）；新增 = 28（全部指向 `resources/rawfile/` 下真实存在的资产，无伪造路径；已逐块校验键集合仅 `type`/`content` 两键且文件存在）
- **孤儿图已按裁决 1 删除**：`stage1_intro_diagram.png`、`stage3_gpio_diagram.png` 已从 `diagrams/` 移除（这两章为人工增强章节，`contentBlocks` 中不存在 `code(mermaid)` 块可替换，其 image 块仍指向上一轮的人工插图 `mcu_board_top.png` / `gpio/gpio_led_sch.png`，故渲染产物无任何 JSON 引用）。删除记录见 `docs/pipeline/diagrams_manifest.json` 的 `deleted` 字段。
- 结论：`diagrams/` 目录 **26 个文件 = 26 个 JSON 引用**，一一对应、无孤儿、无缺失。

## 六、裁决记录（阶段 2 收口，全部关闭）

| 编号 | 事项 | 裁决 | 执行结果 |
| ---: | :--- | :--- | :--- |
| 1 | ch1/ch7 的 2 张孤儿图 | **删除**（无引用 = 白占包体） | ✅ 已删除 2 个文件（175,765 B）；HAP 内条目数 = 0 |
| 2 | ch20 自环标签视觉重叠 | **接受现状**，记入"已知视觉瑕疵清单" | ✅ 记入 V-1，未改源 `.md`、未改渲染参数 |
| 3 | `_SAMPLE.png` | **现在删除**（阶段 2 已收口） | ✅ 已删除（133,251 B）；HAP 内条目数 = 0 |
| — | 合计释放 | — | **309,016 B = 301.8 KB**（源树与包体同步减少，clean 重建后无中间产物残留） |

**阶段 2 至此收口**：v2.1 规则冻结、26 张图交付并全部被 JSON 引用、`images[]` 已填充、审计 32/34（+2 人工 = 34/34 就绪）、`assembleHap` BUILD SUCCESSFUL。

---

# 字号优化轮记录（mermaid 源头 fontSize 16px → 20px）

## 一、改造内容

| 项 | 内容 |
| :--- | :--- |
| 新增工具 | **`docs/tools/mermaid2image.mjs`**（任务卡要求"修改"该文件，但此前并不存在——26 张图由内联 PowerShell 循环产出；本轮将其固化为可复现的渲染器，属**新建**） |
| config 注入 | `-c docs/pipeline/mermaid_config.json`：`themeVariables.fontSize=20px`、`flowchart{nodeSpacing:30, rankSpacing:40, padding:8, useMaxWidth:false}`、`sequence{actor/note=20, message=18}` |
| 不变参数 | `-t neutral -b white -s 2`（红线要求：scale/background/theme 主配置未动） |
| 渲染层归一化 | 保留边标签加引号修复（ch15/ch20），**源 `.md` 未改动** |
| 内建熔断 | 字号 20→18→17 降级；单张 > 200 KB 时 scale 2→1.8→1.6；仍超则报 FATAL 并停机 |
| 重渲范围 | 26 张全量覆盖（文件名/路径不变），`details/*.json` 与 `index.json` **零改动** |

## 二、结果（交付态）

| 项 | 值 |
| :--- | :--- |
| 交付张数 / 体积 | **26 张，3,075.8 KB（3.00 MB）**（原 2.29 MB） |
| 最大单张 | `appendix_learning_path_diagram.png` **183,338 B（179.0 KB）** → **26/26 全部 < 200 KB 阈值** ✅ |
| 字号生效值 | **20px（25 张）**；1 张例外见第四节 |
| 宽/高变化 > ±20% | **7 张**：`stage1_mcu_soc(+98%/+101%)`、`stage4_spi(+46%/+44%)`、`stage5_adc_sensor(+138%/+115%)`、`stage6_concurrency(+37%/+80%)`、`stage8_debug(+32%/+49%)`、`stage9_tinyml(+203%/+212%)`、`stage4_uart(−4%/−23%)` |
| 宽高比变化 > ±20% | **3 张**：`stage4_uart(+24.2%)`、`stage6_concurrency(−23.5%)`、`stage9_troubleshooting(+23.3%)` |

### 抽样对照（任务卡指定 3 张；ch1 的图已按其裁决 1 删除，改取 ch19）

| 章节 | 尺寸 before → after | 字节 before → after | 宽高比变化 | **相对字号**（fontPx ÷ 逻辑宽度，手机按宽适配时越大越好） |
| :--- | :--- | :--- | ---: | :--- |
| ch15 `stage6_watchdog` | 1568x1502 → 1780x1786 | 111,294 → 146,302 | **−4.5%** ✅ | 0.0204 → **0.0225（+10%）** |
| ch19 `stage7_network` | 620x2708 → 616x2258 | 105,953 → 124,440 | **+19.2%** ✅ | 0.0516 → **0.0649（+26%）** |
| ch29 `stage9_robotics` | 1568x2112 → 1464x2116 | 133,251 → 147,766 | **−6.8%** ✅ | 0.0204 → **0.0273（+34%）** |

> ch29 目视确认：文字明显变大、布局更紧凑；副作用是部分长标签折行（如「ROS2 导航与规划节点」）与子图标题贴框线（`padding:8` 所致）。

## 三、⚠️ 关键发现：`useMaxWidth:false` 对"宽图"适得其反（实测数据）

mermaid-cli 默认以 ~800px 视口布局（导出宽度被钳制在 1568px@scale2）。指定 config 的 `useMaxWidth:false` **解除了该钳制**，导致横向铺开的图变得极宽，而手机端是**按宽适配**的 —— 于是"相对字号"不升反降：

| 章节 | 旧（16px，1568 宽） | 本轮指定 config（20px，useMaxWidth:false） | 变体：`useMaxWidth:true` |
| :--- | :--- | :--- | :--- |
| ch13 `stage5_adc_sensor` | 0.0204 | **0.0107（−47%，退化）**，3,732×284，100,792 B | **0.0255（+25%）**，1568×120，**40,501 B** |
| ch23 `stage8_build` | 0.0204 | 超限（见第四节） | **0.0255（+25%）**，1568×2006，**182,266 B** |
| ch29 `stage9_robotics` | 0.0204 | 0.0273（+34%）✅ 自然宽 732 < 784，未被钳制 | 0.0273（同左） |

**结论**：`useMaxWidth:true`（即 mermaid 默认）才是达成"字号提升"目标的正确取值——同等画布宽度下直接获得 **+25% 字号**，且图片更小（ch13 由 100 KB 降至 40 KB）。当前交付态对 7 张宽图**未达成**任务卡验收项 1"文字清晰度显著提升"，3 张宽高比超出 ±20%。**建议批准一键修正**（改 `flowchart.useMaxWidth` → `true` 后全量重渲 26 张，预计 3 分钟内完成、全部 < 200 KB）。

## 四、熔断上报：`stage8_build`（ch23）

| 参数 | 结果 |
| :--- | :--- |
| font 20px / scale 2 | 265,511 B（超限） |
| font 20px / scale 1.8 | 237,488 B（超限） |
| font 20px / scale 1.6 | 213,996 B（**仍超限 → 触发熔断停机**，上报 id：`stage8_build`） |
| 补充探针 font 18 / scale 1.8 · 18 / 2 · 17 / 2 | 219,334 / 236,682 / 230,188 B（**均超限**） |
| **交付处置** | 已按红线要求**未放行超限图**：ch23 回退为 mermaid 默认配置渲染（146,910 B / 1568×1892，与优化前完全一致），并在 manifest 标记 `pendingDecision` |
| 推荐解法 | `useMaxWidth:true` + 20px → **182,266 B（合规）** 且相对字号 +25% |
| 其余 25 张 | 20px 一次渲染成功，无字号降级 |

## 五、红线与新增文件

| 项 | 状态 |
| :--- | :--- |
| `details/*.json` | **未触碰**（最新 mtime 18:38:29，属上一轮 apply 步骤） |
| `index.json` | **未触碰**：sha256 `233C11DCD9549EB6…`，mtime 14:11:12 |
| 源 `.md` | **未触碰**（最新 mtime 13:28:39） |
| `.ets` | 未触碰 |
| 现有 26 张图 | 未删除，仅覆盖内容（文件名不变） |
| mmdc 主参数 | `-t neutral -b white -s 2` 未改 |
| **新增文件（第 4 个，超出任务卡 3 个授权清单，此处披露）** | `docs/pipeline/mermaid_config.json`（config 注入的载体，由渲染器自动写出） |

---

# 字号优化 v2 记录（useMaxWidth 修正 + 26 张全量重渲）

## 一、裁决执行

| 裁决 | 执行 |
| :--- | :--- |
| ① `flowchart.useMaxWidth: false → true` | ✅ 已改（改在渲染器 `buildConfig`，config 由脚本生成，避免被覆盖）；生效 config 已核验 |
| ② ch23 熔断解除 | ✅ 重渲后 **182,266 B（178.0 KB）合规**，相对字号 +25% |
| ③ padding 保持 8 | ✅ 26 张全部以 padding 8 一次渲染成功，**未触发任何 padding/scale 降级** |
| ④ 接受体积增长 | ✅ 实际 **2,753.5 KB（2.69 MB）**，低于 v1 的 3.00 MB |

## 二、验收结果

| 验收项 | 要求 | 实测 | 结论 |
| :--- | :--- | :--- | :--- |
| 26/26 < 200 KB | 是 | 最大 **182,792 B（178.5 KB）**，超限 = 0 | ✅ PASS |
| 抽样 ch13/ch19/ch29 相对字号 | ≥ +20% | **+25.0% / +25.8% / +33.8%** | ✅ PASS |
| 无宽高比越界 | \|Δ\| < 20% | **3 张越界**：`stage4_uart(+24.2%)`、`stage6_concurrency(−23.7%)`、`stage9_troubleshooting(+23.3%)` | ❌ **未达成** |
| index.json sha256 不变 | 是 | `233C11DCD9549EB6…`，mtime 仍 14:11:12 | ✅ PASS |
| .ets / details / 源 md 零改动 | 是 | mtime 分别为 18:38:29 / 13:28:39（本轮未写） | ✅ PASS |

**相对字号全量分布**：+4.8% ~ +44.1%；其中 4 张 < +20%（`stage9_troubleshooting +4.8%`、`stage8_low_power +8.5%`、`stage6_rtos +11.7%`、`appendix_learning_path +12.3%`）—— 这 4 张的自动布局在字号变大后**画布同时变宽**，抵消了部分字号收益。

## 三、宽高比越界的根因与实测解法（待批准）

根因不是字号本身，而是 config 中 `nodeSpacing:30 / rankSpacing:40` 相较 mermaid 默认 50/50 **收紧了排布**，与字号增大叠加后改变了布局比例。参数探针（fontSize 20 固定，仅改间距）：

| 章节 | 基线 16px | 本轮 30/40 | Δ | 探针 **50/50** | Δ | 字节 |
| :--- | :--- | :--- | ---: | :--- | ---: | ---: |
| `stage4_uart` | 886x984 | 850x760 | +24.2% ⚠️ | 890x920 | **+7.4% ✅** | 66,290 ✅ |
| `stage9_troubleshooting` | 702x2104 | 836x2032 | +23.3% ⚠️ | 836x2312 | **+8.4% ✅** | 164,469 ✅ |
| `stage8_low_power` | 758x1154 | 874x1228 | +8.4% ✅ | 894x1268 | **+7.3% ✅** | 82,933 ✅ |
| `stage6_concurrency` | 1568x528 | 1568x692 | −23.7% ⚠️ | 1568x690 | −23.5% ⚠️ | 67,492 ✅ |

`stage6_concurrency` 的宽度被 1568 上限钳制，字号 +25% 只能通过**纵向换行**消化，故间距无解；它需要单独降字号：

| ch18 方案 | 尺寸 | 宽高比 Δ | 字节 | 相对字号 |
| :--- | :--- | ---: | ---: | ---: |
| 20px 30/40（本轮交付） | 1568x692 | −23.7% ⚠️ | 68,392 ✅ | 0.0255（+25%） |
| 20px 50/50 | 1568x690 | −23.5% ⚠️ | 67,492 ✅ | 0.0255（+25%） |
| 19px 50/50 | 1568x678 | −22.1% ⚠️ | 64,683 ✅ | 0.0242（+18.6%） |
| **18px 50/50** | 1568x626 | **−15.7% ✅** | 61,069 ✅ | 0.0230（+12.7%） |
| **18px 30/40** | 1568x622 | **−15.1% ✅** | 63,142 ✅ | 0.0230（+12.7%） |

**建议（待批准，一行配置改动）**：`nodeSpacing/rankSpacing` → **50/50** 全量重渲（可修正 ch10、ch32，并改善 ch25/ch32/ch33 的低增益），另将 **`stage6_concurrency` 单独以 18px 渲染**，即可达成"26/26 宽高比 |Δ| < 20%"。预计 3 分钟内完成，届时重新核验体积（探针数据均 < 200 KB）。

## 四、本轮 26 张交付明细（对照"优化前 16px 基线"）

| 章节 | id | 基线 | 本轮 | 宽高比Δ | 相对字号Δ | 字节 |
| ---: | :--- | :--- | :--- | ---: | ---: | ---: |
| 4 | stage1_mcu_soc | 1568x374 | 1568x380 | −1.6% | +25.0% | 63,909 |
| 5 | stage2_cpu | 552x1276 | 496x1404 | −18.3% | +39.0% | 66,098 |
| 8 | stage3_interrupt | 1568x910 | 1568x910 | 0.0% | +25.0% | 75,685 |
| 9 | stage3_timer_pwm | 526x1554 | 496x1662 | −11.8% | +32.6% | 90,541 |
| 10 | stage4_uart | 886x984 | 850x760 | **+24.2% ⚠️** | +30.5% | 61,792 |
| 11 | stage4_i2c | 1568x1158 | 1362x1042 | −3.5% | +44.1% | 92,264 |
| 12 | stage4_spi | 1568x316 | 1568x314 | +0.6% | +25.0% | 42,279 |
| 13 | stage5_adc_sensor | 1568x132 | 1568x120 | +10.0% | +25.0% | 40,501 |
| 14 | stage5_dma | 1072x1172 | 1096x1144 | +4.7% | +22.1% | 107,665 |
| 15 | stage6_watchdog | 1568x1502 | 1568x1574 | −4.6% | +25.0% | 128,140 |
| 16 | stage6_flash | 1568x1090 | 1568x1140 | −4.4% | +25.0% | 146,141 |
| 17 | stage6_rtos | 1038x956 | 1162x940 | +13.9% | +11.7% | 86,662 |
| 18 | stage6_concurrency | 1568x528 | 1568x692 | **−23.7% ⚠️** | +25.0% | 68,392 |
| 19 | stage7_network | 620x2708 | 616x2258 | +19.2% | +25.8% | 123,085 |
| 20 | stage7_mqtt | 1568x1152 | 1568x1136 | +1.4% | +25.0% | 88,441 |
| 21 | stage7_linux | 1292x2132 | 1220x2002 | +0.6% | +32.3% | 173,118 |
| 22 | stage7_bootloader | 900x2056 | 788x2064 | −12.8% | +42.7% | 142,432 |
| 23 | stage8_build | 1568x1892 | 1568x2006 | −5.7% | +25.0% | 182,266 |
| 24 | stage8_debug | 1568x908 | 1568x1032 | −12.0% | +25.0% | 117,741 |
| 25 | stage8_low_power | 758x1154 | 874x1228 | +8.4% | +8.5% | 80,861 |
| 27 | stage8_architecture | 1180x1840 | 1216x1612 | +17.6% | +21.4% | 146,036 |
| 29 | stage9_robotics | 1568x2112 | 1464x2116 | −6.8% | +33.8% | 150,017 |
| 30 | stage9_tinyml | 1568x164 | 1568x170 | −3.5% | +25.0% | 44,238 |
| 31 | stage9_project | 702x1900 | 680x1940 | −5.1% | +28.9% | 156,359 |
| 32 | stage9_troubleshooting | 702x2104 | 836x2032 | **+23.3% ⚠️** | +4.8% | 162,150 |
| 33 | appendix_learning_path | 692x2144 | 770x2172 | +9.8% | +12.3% | 182,792 |

> 全量数据（含 `previous` / `baseline16px` / `vsBaseline`）见 `docs/pipeline/diagrams_manifest.json`。

---

# 字号优化 v3 记录（间距 50/50 + 逐图字号覆盖）—— 三项验收全部通过

## 一、裁决执行

| 裁决 | 执行 |
| :--- | :--- |
| ① `nodeSpacing/rankSpacing` 30/40 → **50/50** | ✅ 已改（渲染器常量 `NODE_SPACING/RANK_SPACING`，与 mermaid 默认一致） |
| ② `stage6_concurrency` 单独 18px | ✅ 已实施（渲染器 `FONT_OVERRIDE`） |
| ③ 全量重渲 26 张 | ✅ 完成（26 张全部一次渲染成功，未触发 padding/scale 降级） |
| ④ 更新 manifest / AUDIT / STATE | ✅ 本文件 + `diagrams_manifest.json` + `STATE.md` |
| ⑤ 追加例外（本报告新增，见第三节） | ⚠️ `stage2_cpu` 亦以 18px 渲染 —— v3 的 50/50 间距使其宽高比恶化到 **−23.8%**，按同一机制修正；**请确认** |

## 二、验收结果（对照优化前 16px 基线）

| 验收项 | 要求 | 实测 | 结论 |
| :--- | :--- | :--- | :--- |
| 26/26 < 200 KB | 是 | 最大 `appendix_learning_path_diagram.png` **193,567 B（189.0 KB）**，超限 **0** | ✅ **PASS** |
| 宽高比 \|Δ\| < 20% | 是 | 最大 **15.9%**（`stage3_timer_pwm`），**26/26 全部 < 20%** | ✅ **PASS** |
| 抽样字号 ≥ +20% | ch13/ch19/ch29 | **+25.0% / +21.9% / +25.0%** | ✅ **PASS** |
| 体积 | — | **2,787.7 KB（2.72 MB）**（优化前 2.29 MB → v1 3.00 MB → v2 2.69 MB → **v3 2.72 MB**） | — |
| 逐图字号分布 | — | **20px × 24 张 + 18px × 2 张**（`stage2_cpu`、`stage6_concurrency`） | — |

## 三、两处逐图字号例外（含实测依据）

| 章节 | 基线 | 20px 50/50 | Δ | **18px 50/50（采用）** | Δ | 字节 |
| :--- | :--- | :--- | ---: | :--- | ---: | ---: |
| `stage6_concurrency`（已批准） | 1568x528 | 1568x690 | −23.5% ⚠️ | **1568x626** | **−15.7% ✅** | 61,069 ✅ |
| `stage2_cpu`（本轮追加） | 552x1276 | 496x1504 | **−23.8% ⚠️** | **496x1210** | **−5.2% ✅** | 60,414 ✅ |

`stage2_cpu` 的备选方案（未采用，供参考）：`20px + rankSpacing 40` → 496x1404，宽高比 −18.3% ✅ / 相对字号 **+39.1%**（优于 18px 的 +25.2%）。若您希望该图保留 20px 字号，可改为**逐图 rankSpacing 覆盖**，我可随时切换。

## 四、⚠️ 指标口径修正（本轮发现并修复）

`diagrams_manifest.json` 的 `baseline16px` 字段在 v2 轮次被写成了 **v1 中间态**（`useMaxWidth:false` 的膨胀尺寸），导致 v3 首轮验收表出现 `+147.6%`、`+280.6%` 等虚高数值。本轮已：
1. 将 26 条 `baseline16px` **全部改写为真实 16px 基线**（取自 v2 记录第二节的实测表）；
2. 修正渲染器基线传递逻辑（`prev.baseline16px → prev.previous → prev`），避免多轮重渲后基线继续漂移；
3. 依据真基线重算 `vsBaseline`（宽高比 Δ 与相对字号 before/after/Δ），**修正后才有上表的三项 PASS**。

## 五、v3 最终 26 张明细

| 章节 | id | 本轮尺寸 | 宽高比Δ | 相对字号Δ | 字节 |
| ---: | :--- | :--- | ---: | ---: | ---: |
| 4 | stage1_mcu_soc | 1568x390 | −4.1% | +25.0% | 61,644 |
| 5 | stage2_cpu（18px） | 496x1210 | −5.2% | +25.2% | 60,414 |
| 8 | stage3_interrupt | 1568x910 | 0.0% | +25.0% | 75,685 |
| 9 | stage3_timer_pwm | 496x1742 | −15.9% | +32.6% | 91,245 |
| 10 | stage4_uart | 890x920 | +7.4% | +24.4% | 66,290 |
| 11 | stage4_i2c | 1522x1162 | −3.3% | +28.9% | 99,326 |
| 12 | stage4_spi | 1568x312 | +1.3% | +25.0% | 40,658 |
| 13 | stage5_adc_sensor | 1568x130 | +1.5% | +25.0% | 38,628 |
| 14 | stage5_dma | 1166x1244 | +2.5% | +14.7% | 112,034 |
| 15 | stage6_watchdog | 1568x1566 | −4.1% | +25.0% | 125,747 |
| 16 | stage6_flash | 1568x1152 | −5.4% | +25.0% | 142,479 |
| 17 | stage6_rtos | 1172x1000 | +7.9% | +10.7% | 87,799 |
| 18 | stage6_concurrency（18px） | 1568x626 | −15.7% | +12.7% | 61,069 |
| 19 | stage7_network | 636x2658 | +4.5% | +21.9% | 125,520 |
| 20 | stage7_mqtt | 1568x1182 | −2.5% | +25.0% | 92,556 |
| 21 | stage7_linux | 1260x2262 | −8.1% | +27.8% | 178,124 |
| 22 | stage7_bootloader | 838x2224 | −13.9% | +34.0% | 152,182 |
| 23 | stage8_build | 1568x2046 | −7.5% | +25.0% | 177,828 |
| 24 | stage8_debug | 1568x1034 | −12.2% | +25.0% | 113,991 |
| 25 | stage8_low_power | 894x1268 | +7.3% | +5.9% | 82,933 |
| 27 | stage8_architecture | 1276x1864 | +6.7% | +15.5% | 151,628 |
| 29 | stage9_robotics | 1568x2304 | −8.3% | +25.0% | 159,328 |
| 30 | stage9_tinyml | 1568x176 | −6.8% | +25.0% | 41,482 |
| 31 | stage9_project | 680x2160 | −14.8% | +28.9% | 157,941 |
| 32 | stage9_troubleshooting | 836x2312 | +8.4% | +4.8% | 164,469 |
| 33 | appendix_learning_path | 770x2352 | +1.4% | +12.3% | 193,567 |

**遗留观察（非验收项）**：7 张相对字号增益 < +20%（`stage9_troubleshooting +4.8%`、`stage8_low_power +5.9%`、`stage6_rtos +10.7%`、`appendix_learning_path +12.3%`、`stage6_concurrency +12.7%`、`stage5_dma +14.7%`、`stage8_architecture +15.5%`）—— 原因是这些图在字号变大后**画布同步变宽**，相对字号被摊薄；其绝对字号（20px 声明值）均已提升。如需进一步优化，可对这几张单独收紧布局宽度，但会再次改变宽高比，建议维持现状。

## 六、配置与文件语义说明

- **全局参数**（渲染器常量）：`fontSize 20px`、`nodeSpacing 50`、`rankSpacing 50`、`padding 8`、`useMaxWidth true`；mermaid 主参数 `-t neutral -b white -s 2` 不变。
- **逐图覆盖**：`FONT_OVERRIDE = { stage6_concurrency: 18, stage2_cpu: 18 }`。
- `docs/pipeline/mermaid_config.json` 是**每次渲染的瞬时产物**（由渲染器写出），当前内容对应最后一次渲染（`stage2_cpu` 的 18px 覆盖），**不代表全局配置**；全局配置以上述常量为准。
