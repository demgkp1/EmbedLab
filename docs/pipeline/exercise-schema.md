# EmbedLab 练习题数据规范（exercise-schema）

- 文档版本：v1.0.0（Exercise-Data-1 卡产出）
- 适用目录：`entry/src/main/resources/rawfile/database/exercises/`
- 数据来源：`0voice/EmbeddedSoftwareLearn`（**CC BY-NC-SA 4.0**）
- 本卡范围：**只做数据产出，不做代码接入**（ExerciseDataSource / Repository 属阶段二 V2）

---

## 1. 文件命名与组织

| 项 | 规定 |
| :--- | :--- |
| 目录 | `entry/src/main/resources/rawfile/database/exercises/` |
| 文件名 | `exercises-{chapterId}.json`（如 `exercises-stage1_intro.json`） |
| 粒度 | **一章一文件**（34 章 → 34 个文件） |
| 编码 | UTF-8（无 BOM），JSON 双引号，无尾随逗号 |
| 单文件题量 | 5 题 = 4 选择 + 1 代码 |

### 1.1 `chapterId` 取值（⚠️ 需人类确认的提案）

任务卡示例为 `"chapterId": "01-C语言基础"`，但 App 现有 34 章的**规范主键**是
`knowledge/index.json` 中的 `items[].id`（如 `stage2_c_language`）。为使题目能与现有章节
**无歧义 join**，本规范采用：

- `chapterId`：**沿用 knowledge 索引的既有 id**（`stage1_intro`、`stage2_c_language` …）——这是唯一保证与 34 章一一对应的键；
- `chapterNo`：章号（1–34，便于排序与展示）；
- `chapterTitle`：章节标题（如 `"6. C 语言与嵌入式 C"`，便于人工审阅）。

> 若人类希望 `chapterId` 采用 `06-C语言` 这类展示型 slug，则需同步约定 slug 表；
> 本卡按"主键一致性优先"实现，并在交付报告中列为未决依赖。

### 1.2 `id` 取值（⚠️ 需人类确认的提案）

| 题型 | 规则 | 示例 |
| :--- | :--- | :--- |
| 选择题 | `ex-ch{NN}-{seq}` | `ex-ch01-001` |
| 代码题 | `ex-ch{NN}-{seq}`（seq 连续，代码题固定为该章第 5 题） | `ex-ch01-005` |

- `NN` = 两位章号；`seq` = 三位章内序号（`001`–`005`）。
- 全局唯一（170 题无重复），可直接作为端侧主键。
- 任务卡示例 `ex-c-001` 为示意格式；本规范为"章号可排序 + 全局唯一"做了扩展。

---

## 2. 文件顶层结构

```json
{
  "schemaVersion": "1.0.0",
  "chapterId": "stage1_intro",
  "chapterNo": 1,
  "chapterTitle": "1. 什么是嵌入式系统",
  "source": "0voice/EmbeddedSoftwareLearn (CC BY-NC-SA 4.0)",
  "sourceUrl": "https://github.com/0voice/EmbeddedSoftwareLearn",
  "license": "CC BY-NC-SA 4.0",
  "licenseUrl": "https://creativecommons.org/licenses/by-nc-sa/4.0/",
  "extractedAt": "2026-09-13",
  "exercises": []
}
```

**来源声明（验收项 2）**：`source` + `sourceUrl` 同时出现在**文件级**与**每题级**，双保险。
`license` 声明 CC BY-NC-SA 4.0 的 **BY（署名）/ NC（非商业）/ SA（相同方式共享）** 三条件，
本项目为学习用途、非商业分发，符合 NC 条款；衍生数据以相同协议共享。

---

## 3. 选择题 schema（`type: "choice"`）

```json
{
  "id": "ex-ch01-001",
  "chapterId": "stage1_intro",
  "chapterNo": 1,
  "type": "choice",
  "difficulty": "basic",
  "question": "题干（可含行内代码，使用反引号）",
  "options": [
    { "key": "A", "text": "选项 A" },
    { "key": "B", "text": "选项 B" },
    { "key": "C", "text": "选项 C" },
    { "key": "D", "text": "选项 D" }
  ],
  "answer": "B",
  "explanation": "解析：说明正确项为何正确、干扰项错在哪里。",
  "sourceRef": "02-嵌入式系统基础知识/README.md#嵌入式系统定义与特点",
  "source": "0voice/EmbeddedSoftwareLearn (CC BY-NC-SA 4.0)",
  "sourceUrl": "https://github.com/0voice/EmbeddedSoftwareLearn"
}
```

| 字段 | 类型 | 必填 | 约束 |
| :--- | :--- | :---: | :--- |
| `id` | string | ✔ | `ex-ch{NN}-{seq}`，全局唯一 |
| `chapterId` / `chapterNo` | string / number | ✔ | 见 1.1 |
| `type` | string | ✔ | 固定 `"choice"` |
| `difficulty` | string | ✔ | `basic` \| `intermediate` \| `advanced` |
| `question` | string | ✔ | 非空；单行题干，专有名词用反引号 |
| `options` | array | ✔ | **恰好 4 项**，`key` 为 `A`/`B`/`C`/`D` |
| `answer` | string | ✔ | 必须命中某个 `options[].key`（本期全为单选） |
| `explanation` | string | ✔ | 非空；须解释干扰项 |
| `sourceRef` | string | ✔ | 仓库内具体文件 + 小节，保证可追溯 |
| `source` / `sourceUrl` | string | ✔ | 来源声明 |

---

## 4. 代码题 schema（`type: "code"`）—— 字段命名提案（⚠️ 需人类确认）

```json
{
  "id": "ex-ch02-005",
  "chapterId": "stage1_computer",
  "chapterNo": 2,
  "type": "code",
  "difficulty": "advanced",
  "question": "题干：描述要实现的功能与函数签名",
  "language": "c",
  "starterCode": "/* 待填空的起始代码，含函数签名与注释 */",
  "expectedOutput": "整体期望行为的文字说明（1~3 行）",
  "testCases": [
    { "input": "set_bit(0x00u, 3)", "expectedOutput": "0x08" },
    { "input": "set_bit(0x08u, 3)", "expectedOutput": "0x08" }
  ],
  "solutionCode": "参考实现（完整可编译函数体）",
  "hints": ["提示 1", "提示 2"],
  "explanation": "解析：关键点、常见错误、与章节知识点的联系",
  "sourceRef": "03-驱动开发与外设编程/README.md#位操作技巧",
  "source": "0voice/EmbeddedSoftwareLearn (CC BY-NC-SA 4.0)",
  "sourceUrl": "https://github.com/0voice/EmbeddedSoftwareLearn"
}
```

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :---: | :--- |
| `language` | string | ✔ | 本期统一 `"c"`（后续可 `"asm"`/`"bash"`） |
| `starterCode` | string | ✔ | **任务卡要求**；含函数签名、`TODO` 注释；不得直接给出答案 |
| `testCases` | array | ✔ | **任务卡要求**；每项 `{ input, expectedOutput }`，均为字符串，3~5 条，覆盖边界 |
| `expectedOutput` | string | ✔ | **任务卡要求**；整体期望行为说明（人工可读） |
| `solutionCode` | string | ✔ | 参考实现；与 `starterCode` 同签名 |
| `hints` | string[] | ○ | 1~3 条渐进提示 |
| `explanation` | string | ✔ | 与选择题同义 |
| `sourceRef` | string | ✔ | 可追溯来源 |

**设计说明**：`testCases` 采用 `input` / `expectedOutput` 双字符串对（而非可执行断言），
原因是本期为**纯数据产出**、端侧尚无判题运行时（阶段二 V2 才建设）。
字符串形式既可由人工判读，也可在 V2 由判题器解析为断言。

---

## 5. 难度分级（与 C-1 联动）

| 值 | 含义 | 每章建议题量 |
| :--- | :--- | :--- |
| `basic` | 概念识记 / 单点理解 | 2 |
| `intermediate` | 机制理解 / 对比辨析 / 简单计算 | 2 |
| `advanced` | 综合应用 / 工程权衡 / 编码实现 | 1（通常为代码题） |

- 该枚举与 C-1 卡**共用**；本卡仅在数据侧使用字符串字面量，**不引入任何代码常量**。

---

## 6. 质量红线（出题纪律）

1. **忠于素材**：题干与解析必须能在 `sourceRef` 指向的素材中找到依据，禁止编造数据手册级参数；
2. **干扰项有区分度**：干扰项应为常见误解（如把 `.bss` 说成占 Flash），不得出现明显荒谬项；
3. **解析必须解释干扰项**，而非只复述正确项；
4. **代码题可编译**：`solutionCode` 需为合法 C（本期不含 `main`，便于嵌入判题器）；
5. **不复制大段原文**：转换而非摘抄（NC/SA 合规，且避免版权风险）；
6. **不使用仓库中的第三方 PDF 内容**（`books/`、`面试题与面经/*.pdf` 未纳入素材，避免来源不明的版权内容）。
