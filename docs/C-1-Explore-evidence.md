# C-1-Explore 只读探查 · 证据全文

- 任务卡：C-1-Explore（Learn 难度筛选只读探查）
- 分支：feature/difficulty-filter
- 性质：纯只读探查，未修改任何源码、未构建、未 git 写操作
- 说明：本文件为**交付物落盘**（任务卡禁止修改任何文件，本文件为新增文档，
  不属源码改动范围；如需删除请指示）

---

## 证据 1 · LearnPage 列表结构与筛选入口现状

**文件**：`entry/src/main/ets/pages/learn/LearnPage.ets`（264 行）

### 1.1 CategoryBar 挂载点（`LearnPage.ets:169-179`）

```ets
169:  /** SUCCESS 态：分类筛选栏 + 知识卡片列表。 */
170:  @Builder
171:  successState() {
172:    Column() {
173:      CategoryBar({
174:        categories: this.viewModel.categoryList(),
175:        selected: this.viewModel.selectedCategory,
176:        onCategorySelected: (category: string) => {
177:          this.viewModel.selectCategory(category);
178:        }
179:      })
```

结论：筛选栏在 SUCCESS 态内、List 之上，单一挂载点。

### 1.2 列表渲染路径（`LearnPage.ets:181-213`）

```ets
181:      List({ space: AppDimens.SPACING_MD }) {
182:        ForEach(this.viewModel.visibleList(), (item: KnowledgeMetadata) => {
183:          ListItem() {
184:            Row({ space: AppDimens.SPACING_SM }) {
185:              // 知识卡片占满剩余宽度
186:              Column() {
187:                KnowledgeCard({
188:                  item: item,
189:                  onClickItem: (id: string) => {
190:                    this.openKnowledgeDetail(id);
191:                  }
192:                })
193:              }
194:              .layoutWeight(1)
195:
196:              // 收藏标记：仅已收藏时显示，轻量小尺寸不抢主视觉
197:              if (this.isItemFavorite(item.id)) {
198:                Text(AppStrings.GLYPH_STAR_FILLED)
199:                  .fontSize(AppDimens.FAVORITE_MARK_SIZE)
200:                  .fontColor(AppColors.FAVORITE_ACTIVE)
201:              }
202:            }
```

关键：`List` 的数据源是 `this.viewModel.visibleList()`（**ViewModel 计算属性**），
不是 `allList` 直出 → 筛选逻辑改在 ViewModel 即可，UI 层无需改数据装配。

### 1.3 现有筛选维度

仅 **1 个**：分类（category）。**无**阶段筛选、**无**难度筛选。
`LearnPage.ets:17-18` 注释仍写「Home=0 / Learn=1 / Projects=2 / Practice=3 / Profile=4」，
与 UI-Batch-1 后的 3 Tab 现状不符（**注释陈旧，非功能缺陷**）。

---

## 证据 2 · KnowledgeMetadata 是否已有 difficulty 字段

**结论：无 `difficulty`，但已有等价的 `level` 字段。**

**文件**：`entry/src/main/ets/models/knowledge/KnowledgeMetadata.ets`（23 行）

```ets
10: export interface KnowledgeMetadata {
11:   /** 唯一标识，如 stm32_gpio_basic */
12:   id: string;
13:   /** 标题 */
14:   title: string;
15:   /** 分类标识，如 MCU_Peripherals */
16:   category: string;
17:   /** 难度等级：Basic / Medium / Hard */
18:   level: string;
19:   /** 技术标签 */
20:   tags: string[];
21:   /** 文章概括/卡片摘要 */
22:   summary: string;
23: }
```

| 项 | 实况 |
|---|---|
| 字段名 | `level`（**非** `difficulty`） |
| 类型 | `string`（**非枚举**，无联合类型约束） |
| 取值枚举 | `Basic` / `Medium` / `Hard`（注释声明，index.json 实测一致） |
| 来源 | `RawFileAssetDataSource.ets:248,261,277,304` 从 index.json 读取并透传 |
| 是否已在 UI 展示 | 是，见证据 8 |

---

## 证据 3 · index.json 34 章难度分布

**文件**：`entry/src/main/resources/rawfile/database/knowledge/index.json`

### 3.1 枚举集合与统计（两套独立正则交叉校验，结果一致）

| level | 章数 |
|---|---|
| Basic | 9 |
| Medium | 15 |
| Hard | 10 |
| **合计** | **34** |

- 校验 A：`"level"\s*:\s*"…"` 精确匹配 → Basic 9 / Medium 15 / Hard 10
- 校验 B：`"id"…"title"…"category"…"level"` 四字段联合匹配 → 34 条，level 一致
- `"id"` 总数 34，与 34 章一致

### 3.2 逐章明细（34 条）

| # | id | level | title |
|---|---|---|---|
| 1 | stage1_intro | Basic | 1. 什么是嵌入式系统 |
| 2 | stage1_computer | Basic | 2. 计算机基础 |
| 3 | stage1_digital_circuit | Basic | 3. 数字电路基础 |
| 4 | stage1_mcu_soc | Basic | 4. MCU 与 SoC：认识嵌入式世界的大脑 |
| 5 | stage2_cpu | Basic | 5. CPU、内存与启动 |
| 6 | stage2_c_language | Medium | 6. C 语言与嵌入式 C |
| 7 | stage3_gpio | Basic | 7. GPIO |
| 8 | stage3_interrupt | Medium | 8. 中断 |
| 9 | stage3_timer_pwm | Medium | 9. 定时器与 PWM |
| 10 | stage4_uart | Basic | 10. UART |
| 11 | stage4_i2c | Medium | 11. I2C |
| 12 | stage4_spi | Medium | 12. SPI |
| 13 | stage5_adc_sensor | Medium | 13. ADC、DAC 与传感器 |
| 14 | stage5_dma | Hard | 14. DMA |
| 15 | stage6_watchdog | Medium | 15. 看门狗与系统可靠性 |
| 16 | stage6_flash | Medium | 16. Flash、EEPROM 与文件系统 |
| 17 | stage6_rtos | Hard | 17. RTOS 与 FreeRTOS |
| 18 | stage6_concurrency | Hard | 18. 并发、同步与互斥 |
| 19 | stage7_network | Medium | 19. 网络通信 |
| 20 | stage7_mqtt | Medium | 20. MQTT |
| 21 | stage7_linux | Hard | 21. 嵌入式 Linux |
| 22 | stage7_bootloader | Hard | 22. Bootloader |
| 23 | stage8_build | Medium | 23. 编译、链接与烧录 |
| 24 | stage8_debug | Medium | 24. 调试方法 |
| 25 | stage8_low_power | Medium | 25. 低功耗 |
| 26 | stage8_driver | Hard | 26. 设备驱动 |
| 27 | stage8_architecture | Hard | 27. 嵌入式软件架构 |
| 28 | stage9_sensors | Medium | 28. 常见传感器 |
| 29 | stage9_robotics | Hard | 29. 机器人与嵌入式 |
| 30 | stage9_tinyml | Hard | 30. AI + 嵌入式 / TinyML |
| 31 | stage9_project | Medium | 31. 项目开发方法 |
| 32 | stage9_troubleshooting | Hard | 32. 常见问题排查 |
| 33 | appendix_learning_path | Basic | 33. 学习路线 |
| 34 | appendix_glossary | Basic | 34. 常用术语表 |

### 3.3 首条原始片段（字段结构确认）

```json
{
  "schemaVersion": "1.0.0",
  "items": [
    {
      "id": "stage1_intro",
      "title": "1. 什么是嵌入式系统",
      "category": "Stage 1: 认识嵌入式世界",
      "level": "Basic",
      "tags": ["嵌入式系统", "通用计算机", "MCU", "实时性", "资源约束", "传感器", "执行器"],
      "summary": "嵌入式系统是为完成特定应用功能而设计的专用计算机系统…"
    },
```

**数据集完备性结论**：34/34 条目均含 level，三个取值均有 9~15 章分布，
**筛选后不会出现空分组**。

---

## 证据 4 · CategoryBar 可复用性评估

**文件**：`entry/src/main/ets/pages/learn/components/CategoryBar.ets`（55 行）

### 4.1 入参（`:18-25`）

```ets
18: @Component
19: export struct CategoryBar {
20:   /** 分类文案清单（首项为「全部」） */
21:   @Prop categories: string[] = [];
22:   /** 当前选中分类 */
23:   @Prop selected: string = '';
24:   /** 选中回调：通知父组件切换分类 */
25:   onCategorySelected: (category: string) => void = () => {};
```

### 4.2 渲染与样式（`:27-54`）

```ets
29:    List({ space: AppDimens.SPACING_SM }) {
30:      ForEach(this.categories, (category: string) => {
31:        ListItem() {
32:          Text(category)
33:            .fontSize(AppDimens.FONT_SIZE_BODY)
34:            .fontWeight(this.selected === category ? FontWeight.Medium : FontWeight.Normal)
35:            .fontColor(this.selected === category ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
36:            .padding({ left: AppDimens.SPACING_MD, right: AppDimens.SPACING_MD,
                          top: AppDimens.SPACING_XS, bottom: AppDimens.SPACING_XS })
42:            .borderRadius(AppDimens.RADIUS_SM)
43:            .backgroundColor(this.selected === category ? AppColors.PRIMARY_LIGHT : AppColors.SURFACE)
44:            .onClick(() => { this.onCategorySelected(category); })
```

组件内常量（`:9`）：`const CATEGORY_BAR_HEIGHT: number = 44;`

### 4.3 可复用性裁决：**可以复用，无需新建组件**

判定依据（均为实况）：

| 判据 | 实况 | 结论 |
|---|---|---|
| 语义耦合 | 入参名 `categories` 但**仅作展示字符串数组**用，无任何 category 专属逻辑 | 解耦 |
| 与数据源耦合 | 无。`:16` 注释明示「只做渲染与事件上抛，不持有任何数据源」 | 解耦 |
| 选中态是单值 | `selected: string` 单值比较（`:34,35,43`） | 适配难度单选 |
| 高度是否写死 | 是，`CATEGORY_BAR_HEIGHT = 44`（模块内常量） | 可接受，两栏等高 |
| 唯一命名瑕疵 | 入参/回调名带 category 语义 | 建议**参数重命名**即可，属纯命名调整 |

**风险点**：若在同一页并置两条 `CategoryBar`，二者 `@Prop selected` 各自独立，
**无状态互染**；但 `ForEach` 的 key 生成器为 `(category: string) => category`（`:48`），
**仅用标签文本作 key**。两条栏若出现同名标签（例如分类名与难度名撞名）会
产生 key 冲突。当前难度取值 `Basic/Medium/Hard` 与分类名
`Stage 1: 认识嵌入式世界` 等**不撞名**，故现状安全；但若后续分类改名需复查。

---

## 证据 5 · LearnViewModel 现状

**文件**：`entry/src/main/ets/viewmodels/LearnViewModel.ets`（121 行，**存在**）

### 5.1 筛选相关状态（`:26-37`）

```ets
26: @Observed
27: export class LearnViewModel {
29:   uiStatus: UIStatus = UIStatus.LOADING;
31:   allList: KnowledgeMetadata[] = [];
33:   selectedCategory: string = AppStrings.LEARN_CATEGORY_ALL;
35:   lastErrorCode: ErrorCode = ErrorCode.UNKNOWN;
37:   lastErrorMessage: string = '';
```

仅 **1 个**筛选状态字段：`selectedCategory`。

### 5.2 现有筛选方法签名（三个方法）

```ets
75:  categoryList(): string[]                              // 生成候选清单，首项「全部」
90:  visibleList(): KnowledgeMetadata[]                    // 计算属性：按 selectedCategory 过滤
108: selectCategory(category: string): void                // 用户意图入口
```

`visibleList()` 实现（`:90-102`）——**单维度过滤，新维度需在此叠加**：

```ets
90:  visibleList(): KnowledgeMetadata[] {
91:    if (this.selectedCategory === AppStrings.LEARN_CATEGORY_ALL) {
92:      return this.allList;
93:    }
94:    const filtered: KnowledgeMetadata[] = [];
95:    for (let index: number = 0; index < this.allList.length; index++) {
96:      const item: KnowledgeMetadata = this.allList[index];
97:      if (item.category === this.selectedCategory) {
98:        filtered.push(item);
99:      }
100:    }
101:    return filtered;
102:  }
```

`loadKnowledgeList()` 在成功后**强制重置**筛选（`:66`）：
`this.selectedCategory = AppStrings.LEARN_CATEGORY_ALL;`

**筛选逻辑位置结论**：全部收敛在 ViewModel，UI 层零逻辑。
新增难度筛选的正确落点即本文件（`selectedLevel` 字段 + `levelList()` +
`selectLevel()` + `visibleList()` 双条件叠加）。

---

## 证据 6 · B-fix-3 $$ 机制与 LearnPage 兼容性

### 6.1 LearnPage 是否订阅 `@Consume('rootTabIndex')`：**是**

```ets
60: @Consume('rootTabIndex') @Watch('onRootTabChanged') rootTabIndex: number;
```

回调（`:82-87`）：

```ets
82:  onRootTabChanged(): void {
83:    if (this.rootTabIndex === LEARN_TAB_INDEX) {
84:      this.syncFavorites();
```

`syncFavorites()`（`:98-100`）**只写 `favoriteIds`**，不触碰任何筛选状态。

### 6.2 RootTabContainer 提供端实况

```ets
53: @Provide('rootTabIndex') currentIndex: number = 0;
59: Tabs({ barPosition: BarPosition.End, index: $$this.currentIndex }) {
85: .onChange((index: number) => { this.currentIndex = index; })
```

### 6.3 冲突裁决：**无硬冲突**

| 关注点 | 实况 | 结论 |
|---|---|---|
| 筛选状态存放位置 | ViewModel 字段（`@Observed` 类内），**不在 AppStorage** | 与 $$ 机制无关 |
| `@Consume` 回调副作用 | 仅 `syncFavorites()`，只写 `favoriteIds` | 与筛选正交 |
| Tab 切换是否重置筛选 | 不会。`selectedLevel` 存于 `@State viewModel` 实例内，TabContent 切换不重建结构体 | 筛选状态天然保持 |
| `@StorageLink(FAVORITES_VERSION)` | 仅驱动收藏快照刷新（`:71`） | 与筛选正交 |

**结论**：新增难度筛选**不触碰** $$ 双向绑定链、不新增 AppStorage 键、
不改 `onRootTabChanged`，**不存在与 B-fix-3 的冲突**。

---

## 证据 7 · 常量可复用性盘点

### 7.1 AppStrings（`constants/AppStrings.ets`，111 行）

现有 Learn 相关键（`:36-40, 60-61`）：

```ets
37:  static readonly LEARN_LOADING: string = '正在加载知识库…';
38:  static readonly LEARN_EMPTY_TITLE: string = '暂无数据，请检查 rawfile';
39:  static readonly LEARN_EMPTY_DESC: string = '未在 resources/rawfile/database/knowledge/index.json 中读到任何知识条目。';
40:  static readonly LEARN_ERROR_TITLE: string = '知识索引加载失败';
61:  static readonly LEARN_CATEGORY_ALL: string = '全部';
```

| 需求 | 可否复用 |
|---|---|
| 「全部」标签 | ✅ 直接复用 `LEARN_CATEGORY_ALL`（`:61`） |
| 难度标签文本 | ❌ 无对应键 |
| 独立难度「全部」键 | ⚠️ 可选。共用 `LEARN_CATEGORY_ALL` 亦可，但语义从「分类全部」变为「双维度全部」，建议视产品语义决定 |

**建议新增键清单（仅建议，需 C-1 编码卡批准）**：
`LEARN_LEVEL_ALL`（或复用）、`LEARN_LEVEL_BASIC`、`LEARN_LEVEL_MEDIUM`、
`LEARN_LEVEL_HARD`。若不新增，则直接渲染 JSON 原始值 `Basic/Medium/Hard` ——
该做法与 `KnowledgeCard.ets:46` 现状一致（现状即直出原始值），零新增键。

### 7.2 AppColors（`constants/AppColors.ets`，32 行）

已有键：`PRIMARY` `PRIMARY_LIGHT` `BACKGROUND` `SURFACE` `TEXT_PRIMARY`
`TEXT_SECONDARY` `TEXT_TERTIARY` `DIVIDER` `FAVORITE_ACTIVE` `OVERLAY_BACKDROP`
`OVERLAY_CLOSE` `WARNING_BG`。

**难度筛选零新增色值**：选中态 = `PRIMARY` / `PRIMARY_LIGHT`，未选中 = `TEXT_SECONDARY` / `SURFACE`
—— 与 CategoryBar `:35,43` 现用值完全一致。

### 7.3 AppDimens（`constants/AppDimens.ets`，51 行）

已有键：`SPACING_XS/SM/MD/LG/XL`(4/8/12/16/24)、`RADIUS_SM/MD`(8/12)、
`FONT_SIZE_TITLE/SUBTITLE/BODY/CAPTION`(20/16/14/12) 等。

**难度筛选零新增尺寸值**：可完全复用 CategoryBar 现用组合
（`SPACING_SM/MD/XS` + `FONT_SIZE_BODY` + `RADIUS_SM`）。

> 注：`CATEGORY_BAR_HEIGHT = 44` 为 CategoryBar 组件内私有常量（`:9`），
> 注释说明「非跨模块设计系统数值，故就近声明而不污染全局 AppDimens」。
> 复用组件则自动继承该高度，无需新增。

---

## 证据 8 · 与 C-2（已读标记）的关系

### 8.1 难度**已经**在卡片上展示（关键发现）

**文件**：`entry/src/main/ets/pages/learn/components/KnowledgeCard.ets`（96 行）

```ets
37:      // 分类 + 难度徽章
38:      Row({ space: AppDimens.SPACING_SM }) {
39:        Text(this.item.category)
40:          .fontSize(AppDimens.FONT_SIZE_CAPTION)
41:          .fontColor(AppColors.TEXT_SECONDARY)
42:          .maxLines(1)
43:          .textOverflow({ overflow: TextOverflow.Ellipsis })
44:          .layoutWeight(1)
45:
46:        Text(this.item.level)
47:          .fontSize(AppDimens.FONT_SIZE_CAPTION)
48:          .fontColor(AppColors.PRIMARY)
49:          .backgroundColor(AppColors.PRIMARY_LIGHT)
50:          .padding({ left: AppDimens.SPACING_SM, right: AppDimens.SPACING_SM,
                        top: AppDimens.SPACING_XS, bottom: AppDimens.SPACING_XS })
56:          .borderRadius(AppDimens.RADIUS_SM)
57:      }
```

**结论**：难度徽章已存在（胶囊样式，主色底）。

### 8.2 已读标记位现状

LearnPage 的 `Row`（`:184-202`）中，**只有收藏星标**占位（`:197-201`，
`FAVORITE_MARK_SIZE = 16`，`AppDimens.ets:50`）。
**无已读标记**，**无预留空位**（`if` 条件渲染，未收藏时该位置不占宽度）。

### 8.3 视觉冲突评估

| 若 C-2 落地位置 | 与难度筛选的冲突 | 与现有徽章/星标的冲突 |
|---|---|---|
| 卡片内（如标题旁打勾） | **无**。筛选只改列表数据，不改卡片结构 | 需与难度徽章、分类同行排布，空间紧张 |
| 列表中卡片的行尾（与星标并排） | **无** | ⚠️ 与收藏星标争位。`Row` 现有 2 个子节点（Column + 可选星标），再加 1 个标记需重排 |
| 卡片新增整行 | **无** | 增加卡片高度，与「轻量小尺寸不抢主视觉」的既有设计取向（`:196` 注释）相悖 |

**结论**：难度筛选与 C-2 **无直接视觉冲突**（筛选作用于集合，标记作用于单卡）。
但若 C-2 选择「行尾并排星标」方案，需与本次筛选栏**共享同一张卡的纵向空间预算**，
建议 C-2 立项时一并评审卡片布局，而不是各自追加。

---

## 证据 9 · 筛选状态是否需要持久化

### 9.1 UserStore 现状（任务卡授权外文件，已只读访问并声明）

**文件**：`entry/src/main/ets/stores/UserStore.ets`（111 行）

```ets
26:  /** 收藏的知识 ID 集合 */
27:  favorites: string[] = [];
28:  /** 最近阅读的知识 ID 序列（最新 → 最旧） */
29:  history: string[] = [];
30:  /** 知识点已读 / 完成标记字典 */
31:  progress: Map<string, boolean> = new Map<string, boolean>();
```

类头约束（`:9-13`）：

```ets
 9:  * 分层约束（严禁越界）：
10:  *  - **严禁**持有 DataSource / Repository / ViewModel 的任何引用。
11:  *  - **严禁**在本类内调用 Preferences 或任何 I/O；持久化一律由 UserRepository 负责。
12:  *  - **严禁**做持久化决策（例如「先写 Store 再写盘」这类伪成功流程）。
13:  *  - 本类不属于四层中的任何一层，只做内存状态持有。
```

数据模型 `models/user/UserProgressState.ets`：**仅 3 个字段**
`favorites` / `history` / `progress`。**无任何 UI 偏好槽位**。

### 9.2 AppStorage 现状

`constants/AppStorageKeys.ets` 仅 5 个键：`FAVORITES_VERSION`、`HISTORY_VERSION`
（版本号广播）、`APP_CONTEXT`、`LOG_LEVEL`、`LOG_BUNDLE_NAME`（Logger/Context）。
`:7-8` 明示「版本号为 number 时间戳，**不承载业务数据**」。

### 9.3 参考场景：**UserStore 无同类先例**

全工程无任何 UI 偏好（如上次选中 Tab、上次筛选）的持久化实现。
现有持久化**仅有**用户产生的业务状态（收藏 / 历史 / progress）。

### 9.4 影响面评估（若坚持持久化）

| 方案 | 改动面 | 评价 |
|---|---|---|
| A. 不持久化（仅内存 ViewModel 字段） | 0 额外文件 | ✅ **推荐**。切换 Tab 不丢（结构体不重建），冷启动重置为「全部」符合直觉 |
| B. 写入 AppStorage（不落盘） | +1 键 | 与 `AppStorageKeys` 定位冲突（该文件声明不承载业务数据） |
| C. 落盘 Preferences | UserProgressState + PreferenceDataSource + UserRepository + UserStore + LearnViewModel = **≥5 文件，跨 3 层** | ❌ 违反架构原则一「数据资产与应用状态绝对分离」的精神；UI 偏好非用户状态；且触及 5 个**已冻结文件** |
| D. 新增独立 Preferences 键 | 仍需改 PreferenceDataSource（冻结文件） | ❌ 同上 |

**结论**：**不建议持久化**。理由——(1) 无先例；(2) 会触及 5 个冻结文件并跨层；
(3) 筛选条件是**瞬时视图状态**，非用户资产；(4) 内存态已在 Tab 切换下天然保持，
仅冷启动重置，属可接受行为。若产品坚持，应单独立项并走冻结文件授权流程。

---

## 方案建议（不含编码，供 C-1 编码卡决策）

### 建议 A（推荐）：复用 CategoryBar + ViewModel 双维度叠加

- **组件**：复用 `CategoryBar`，不新建。仅在 `LearnPage` 的成功态内并置第二条。
- **参数命名**：建议把 `CategoryBar` 的 `categories/selected/onCategorySelected`
  改为中性名（如 `options/selected/onSelected`），或新增一个薄封装组件；
  二者取一，由编码卡裁决。
- **ViewModel**：新增 `selectedLevel: string`、`levelList(): string[]`、
  `selectLevel(level: string): void`；`visibleList()` 改为**双条件与**过滤。
- **常量**：零新增色值 / 零新增尺寸；文案键按证据 7.1 二选一。
- **文件数预估**：`LearnPage.ets`、`LearnViewModel.ets`、
  `CategoryBar.ets`（若重命名）、`AppStrings.ets` = **3~4 文件**，符合微任务上限。

### 建议 B（备选）：新建 `FilterBar` 通用组件，CategoryBar 改为其薄封装

- 适用于「预期还会有第三个筛选维度」的场景。
- 代价：新增 1 文件 + 改动 CategoryBar，文件数升至 4~5，接近上限。
- 当前仅 2 个维度，**属过度设计**，Architecture 原则四（MVP 绝对优先）不支持。

### 建议 C：难度取值枚举化（独立小卡）

- 现状 `level: string` 无约束，错拼 `'basic'`（小写）不会被拦截。
- 可新增 `models/knowledge/KnowledgeLevel.ets` 枚举 + DataSource 校验。
- 但与 C-1 目标（筛选 UI）无强依赖，建议**独立登记 BACKLOG**，不在本卡捆绑。

---

## 风险声明

| # | 风险 | 等级 | 说明 |
|---|---|---|---|
| R1 | `CategoryBar` 的 `ForEach` key 仅用标签文本 | 低 | 两条栏若标签撞名会 key 冲突。当前难度值不撞名，安全；分类改名需复查 |
| R2 | `@Prop` 数组传值性能 | 低 | 每帧重建 `categoryList()`，但 34 条量级可忽略 |
| R3 | 双条件过滤后的空结果 | 低 | 已有数据集无空分组（证据 3.1），但极端组合（如「附录」+「Hard」）可能为空 → 需空态文案 |
| R4 | `LearnPage.ets:17-18` 注释陈旧（仍写 5 Tab） | 极低 | 仅注释，建议编码卡顺手修正 |
| R5 | 筛选后 `List` 复用旧 `ForEach` key 缓存 | 低 | key 为 `item.id`（`:206`），稳定，无风险 |
| R6 | 与 C-2 的卡片空间竞争 | 中 | 见证据 8.3，建议 C-2 立项时联合评审 |
| R7 | `level` 无枚举约束 | 中 | 见建议 C，建议独立卡处理 |

---

## 未决依赖

| # | 未决项 | 阻塞什么 | 需谁裁决 |
|---|---|---|---|
| D1 | 「全部」是否与分类共用 `LEARN_CATEGORY_ALL` | 文案键数量 | 产品/架构师 |
| D2 | 难度标签渲染中文 or 原始值 `Basic/Medium/Hard` | 是否需要新增 4 个文案键 | 产品 |
| D3 | `CategoryBar` 参数是否重命名（影响已冻结文件） | 编码卡授权范围 | 架构师 |
| D4 | 双维度组合为空时的空态文案 | 是否新增 `LEARN_EMPTY_FILTERED` 键 | 产品 |
| D5 | C-2 是否与 C-1 合并评审卡片布局 | 排期 | 架构师 |
| D6 | 难度筛选是否需持久化（本卡结论：不建议） | 改动面 3 文件 vs ≥5 文件 | 架构师确认 |

---

## 工作区外访问清单

**无。** 本卡全部证据均来自工作区内文件的 read / grep，
以及工作区内只读 git 查询（`git status` / `git branch` / `git diff` / `git log`）。

未访问 `E:\app\DevEco Studio`、`C:\Users\dkp\*` 或任何工作区外路径。
未运行任何构建（`assembleHap`）、lint 或真机部署。
未执行任何 git 写操作（无 add / commit / checkout / branch / tag / push）。

---

## 行为合规声明

| 验收项 | 状态 |
|---|---|
| 1 证据完整（9 项，含路径+行号+原始片段） | ✅ |
| 2 零写操作（仅 read + grep） | ✅ 源码零改动 |
| 3 零构建（未 assembleHap / lint / 真机 / git 写） | ✅ |
| 4 难度字段结论明确 | ✅ 有 `level`：Basic 9 / Medium 15 / Hard 10 |
| 5 可复用性结论明确 | ✅ CategoryBar 可复用，无需新建 |
| 6 可复核（行号可直接打开核对） | ✅ 全部标注文件+行号 |

**授权外只读访问披露**（任务卡未列，但为完成第 9 项所需）：
- `entry/src/main/ets/stores/UserStore.ets`（只读）
- `entry/src/main/ets/models/user/UserProgressState.ets`（只读）
- `entry/src/main/ets/constants/AppStorageKeys.ets`（只读）
- `entry/src/main/ets/components/RootTabContainer.ets`（只读，证据 6 所需）
- `entry/src/main/ets/repositories/` 内文件（**未读取**）

**唯一写操作**：新增本文件 `docs/C-1-Explore-evidence.md`（交付物落盘）。
如需改为对话内交付并删除本文件，请指示。
