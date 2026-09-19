# EmbedLab 34 章 × 0voice 素材映射表（exercise-chapter-mapping）

- 文档版本：v1.0.0（Exercise-Data-1 卡产出）
- 素材仓库：`0voice/EmbeddedSoftwareLearn`（**CC BY-NC-SA 4.0**，已核验 `LICENSE.md`）
- 仓库 revision：`main` @ `218bff6978643db93abaae6ce577781190e1117a`
- 探查日期：2026-09-13

---

## 一、仓库可解析素材清单（只读探查结论）

| # | 素材文件 | 字节 | 类型 | 用途 |
| ---: | :--- | ---: | :--- | :--- |
| 1 | `README.md`（根） | 107,547 | 九层知识大纲（398 标题） | 全章概念素材主源（与各层 README 内容重叠） |
| 2 | `01-C语言基础与进阶/Readme.md` | 14,701 | 大纲 + 代码片段 | ch2 / ch6 |
| 3 | `02-嵌入式系统基础知识/README.md` | 12,802 | 大纲 + 表格 + 代码 | ch1 / ch3 / ch4 / ch5 / ch22 / ch23 |
| 4 | `03-驱动开发与外设编程/README.md` | 6,254 | 大纲 + 寄存器位操作 | ch7–ch14 / ch26 |
| 5 | `04-实时操作系统/README.md` | 10,090 | 大纲 + 任务/调度 | ch17 / ch18 |
| 6 | `05-EmbeddedLinux/README.md` | 9,370 | 大纲 + 启动流程 | ch21 / ch22 / ch26 |
| 7 | `06-NetworkIot/README.md` | 19,660 | 大纲 + 协议对比表 | ch10 / ch19 / ch20 |
| 8 | `07-Debug_Optimization/README.md` | 7,554 | 工具链 + GDB/OpenOCD | ch24 / ch32 |
| 9 | `08-项目实战与工具链/README.md` | 19,261 | Git / 工程管理 / 构建 | ch23 / ch27 / ch31 |
| 10 | `09-2025_AI_on_MCU/README.md` | 7,485 | TinyML / 量化 / 推理 | ch30 |
| 11 | `嵌入式图形 Qt 开发/README.md` | 6,696 | Qt 开发体系 | ch1（补充）/ ch27 |
| 12 | `面试题与面经/Linux面试题1.md` | 50,378 | **Q&A（约 78 问）** | ch21 / ch22 / ch26 |
| 13 | `面试题与面经/Linux面试题2.md` | 14,412 | **Q&A（约 45 问，"问题一/答案"式）** | ch21 |
| 14 | `面试题与面经/操作系统面试题.md` | 20,550 | **Q&A（22 问）** | ch18 / ch17 |
| 15 | `面试题与面经/计算机网络原理面试题.md` | 70,171 | **Q&A（约 84 问）** | ch19 / ch20 |
| 16 | `面试题与面经/vivo C++ 嵌入式面经.txt` | 479 | 面经（极短，13 行） | 仅作氛围参考，不成题 |

**未纳入素材**（详见第五节）：
- `面试题与面经/*.PDF`（`ARM嵌入式系统基础教程.PDF` 3.87 MB、`Linux BSP工程师面试常问问题汇集..pdf` 0.92 MB、`嵌入式资料整合第二辑.pdf` 1.95 MB）
- `books/*.pdf`（Arm64 指令集速查、Linux 入门教程、Shell 命令行）
- `面试题与面经/README.md`（仅网盘引流链接，无正文）

---

## 二、34 章映射表

> 题量：每章固定 **5 题 = 4 选择 + 1 代码**；难度：**2 basic + 2 intermediate + 1 advanced**。
> 素材强度：**充足**（≥15 命中标题）/ **一般**（6–14）/ **偏薄**（2–5，需跨文件聚合）。

| 章 | chapterId | 章节标题 | 主要素材来源 | 强度 | 题量 | 难度分配 | 缺口与补充方案 |
| ---: | :--- | :--- | :--- | :--- | ---: | :--- | :--- |
| 1 | stage1_intro | 1. 什么是嵌入式系统 | `02/README`（定义·特点·系统构成）、`README` 概述、`Qt/README` | 充足 | 5 | 2/2/1 | — |
| 2 | stage1_computer | 2. 计算机基础 | `01/Readme`（位域/十六进制/指针内存编号）、`03/README`（`SET_BIT`/`CLEAR_BIT`） | 偏薄 | 5 | 2/2/1 | 二进制/十六进制表示法在仓库中无独立章节；**补充方案**：以 `01` 的"内存编号用十六进制表示"+"位域"与 `03` 的寄存器位操作宏为锚点出题，纯进制换算题标注 `sourceRef` 指向 `01/Readme#位域` |
| 3 | stage1_digital_circuit | 3. 数字电路基础 | `02/README`（LDO/DC-DC/上拉下拉）、`03/README`（浮空/上拉/下拉/推挽/开漏/总线仲裁） | 偏薄 | 5 | 2/2/1 | 仓库无独立"数字电路"章节；**补充方案**：从 `02` 电源管理与 `03` 引脚模式两处聚合（电平/上下拉/高阻/LDO 纹波与效率），题干严格引用这两处表述 |
| 4 | stage1_mcu_soc | 4. MCU 与 SoC：认识嵌入式世界的大脑 | `02/README`（Cortex-M/RISC-V/8051/主频/内核位数/片上外设）、`README` 第二层 | 充足 | 5 | 2/2/1 | — |
| 5 | stage2_cpu | 5. CPU、内存与启动 | `02/README`（启动流程/`Reset_Handler`/Flash+SRAM/内存映射/链接脚本/`arm-none-eabi-size`）、`README` 第二层 | 充足 | 5 | 2/2/1 | — |
| 6 | stage2_c_language | 6. C 语言与嵌入式 C | `01/Readme`（指针/位域/关键字/内存）、`README` 第一层 | 充足 | 5 | 2/2/1 | — |
| 7 | stage3_gpio | 7. GPIO | `03/README`（GPIO 输入/输出模式）、`README` 第三层 | 一般 | 5 | 2/2/1 | — |
| 8 | stage3_interrupt | 8. 中断 | `03/README`、`04/README`（中断与任务）、`Linux面试题1` | 充足 | 5 | 2/2/1 | — |
| 9 | stage3_timer_pwm | 9. 定时器与 PWM | `02/README`（PWM 占空比 / 舵机 50Hz → `#4. 定时控制`）、根 `README`（TIM3 Prescaler/Period/Pulse 实例）、`04/README`（软件定时器） | 一般 | 5 | 2/2/1 | **已修正**：`03/README` 中无 PWM/舵机内容（仅"用示波器验证占空比与频率"一句），实际素材见左列 |
| 10 | stage4_uart | 10. UART | `06/README`（串口通信/工作原理）、`03/README`、`README` | 充足 | 5 | 2/2/1 | — |
| 11 | stage4_i2c | 11. I2C | `03/README`（I2C/总线仲裁）、`02/README`（接口对比表） | 一般 | 5 | 2/2/1 | — |
| 12 | stage4_spi | 12. SPI | `02/README`（SPI 四线/高速）、`03/README` | 一般 | 5 | 2/2/1 | — |
| 13 | stage5_adc_sensor | 13. ADC、DAC 与传感器 | `02/README`（ADC 精度/分辨率/DAC）、`03/README` | 一般 | 5 | 2/2/1 | — |
| 14 | stage5_dma | 14. DMA | `03/README`（DMA 与外设搬运）、`02/README`（总线） | 一般 | 5 | 2/2/1 | — |
| 15 | stage6_watchdog | 15. 看门狗与系统可靠性 | `03/README`（1）、`02/README`（复位） | 偏薄 | 5 | 2/2/1 | **补充方案**：聚合 `07-Debug`（HardFault/复位排查）与 `04-RTOS`（任务监控）素材，出题聚焦"复位来源判别/喂狗策略" |
| 16 | stage6_flash | 16. Flash、EEPROM 与文件系统 | `02/README`（NOR/NAND/EEPROM/FRAM）、`Linux面试题1`、`05/README` | 一般 | 5 | 2/2/1 | — |
| 17 | stage6_rtos | 17. RTOS 与 FreeRTOS | `04/README`（RTOS 概念/任务管理/调度）、`README` 第四层 | 充足 | 5 | 2/2/1 | — |
| 18 | stage6_concurrency | 18. 并发、同步与互斥 | `操作系统面试题`（进程线程/同步/通信）、`Linux面试题1`（锁）、`04/README` | 充足 | 5 | 2/2/1 | — |
| 19 | stage7_network | 19. 网络通信 | `计算机网络原理面试题`（TCP/UDP/HTTP/URI）、`06/README`、`README` | 充足 | 5 | 2/2/1 | — |
| 20 | stage7_mqtt | 20. MQTT | `06/README`（MQTT/发布订阅/QoS/对比 HTTP） | 一般 | 5 | 2/2/1 | — |
| 21 | stage7_linux | 21. 嵌入式 Linux | `Linux面试题1`+`Linux面试题2`（内核/进程/驱动）、`05/README`（组成/启动） | 充足 | 5 | 2/2/1 | — |
| 22 | stage7_bootloader | 22. Bootloader | `02/README`（向量表重定向/`SCB->VTOR`/ROM vs RAM 启动）、`05/README`（启动流程） | 充足 | 5 | 2/2/1 | — |
| 23 | stage8_build | 23. 编译、链接与烧录 | `02/README`（编译链接流程/链接脚本/烧录）、`08/README`（工具链） | 充足 | 5 | 2/2/1 | — |
| 24 | stage8_debug | 24. 调试方法 | `07/README`（JTAG/SWD/GDB+OpenOCD/逻辑分析仪）、`02/README`（反汇编/size） | 充足 | 5 | 2/2/1 | — |
| 25 | stage8_low_power | 25. 低功耗 | `02/README`（休眠/RTC 唤醒/动态电压/低功耗案例）、`07/README`（功耗分析） | 充足 | 5 | 2/2/1 | — |
| 26 | stage8_driver | 26. 设备驱动 | `03/README`（寄存器级开发/外设驱动）、`Linux面试题1`（驱动模型） | 充足 | 5 | 2/2/1 | — |
| 27 | stage8_architecture | 27. 嵌入式软件架构 | `02/README`（应用层/驱动层/硬件层三段式）、`08/README`（工程管理） | 充足 | 5 | 2/2/1 | — |
| 28 | stage9_sensors | 28. 常见传感器 | `02/README`（温湿度/光照/气压/加速度/陀螺仪/接口方式） | 一般 | 5 | 2/2/1 | — |
| 29 | stage9_robotics | 29. 机器人与嵌入式 | `02/README`（PWM 舵机 50Hz）、`06/README`（CAN 差分总线） | 偏薄 | 5 | 2/2/1 | **补充方案**：仓库无机器人章节；以"执行器控制（PWM/舵机）+ 工业总线（CAN/Modbus）"两块素材出题，题干不引入仓库外参数 |
| 30 | stage9_tinyml | 30. AI + 嵌入式 / TinyML | `09/README`（TinyML/量化/剪枝/推理流程/性能指标） | 充足 | 5 | 2/2/1 | — |
| 31 | stage9_project | 31. 项目开发方法 | `08/README`（Git 分支策略/提交规范/标签/工程管理） | 充足 | 5 | 2/2/1 | — |
| 32 | stage9_troubleshooting | 32. 常见问题排查 | `02/README`（链接错误/内存溢出/调试技巧）、`07/README`（GDB/OpenOCD/仪器） | 偏薄 | 5 | 2/2/1 | **补充方案**：聚合两处"错误现象→原因→手段"的条目出题（符号未定义、内存溢出、HardFault 定位） |
| 33 | appendix_learning_path | 33. 学习路线 | 根 `README`（九层学习路线）、`02/README`（工具与开发板建议） | 充足 | 5 | 2/2/1 | — |
| 34 | appendix_glossary | 34. 常用术语表 | 全仓库术语聚合（MCU/SoC/RTOS/DMA/HAL/JTAG/OTA 等） | 一般 | 5 | 2/2/1 | **补充方案**：术语取自各层 README 的缩写与中英对照，`sourceRef` 逐条指向首次出现处 |

**题量与类型统计**：34 章 × 5 = **170 题 = 136 选择 + 34 代码**；难度合计 **68 basic + 68 intermediate + 34 advanced**。

---

## 三、素材缺口汇总（验收项 3 / 熔断项 6）

| 分类 | 章数 | 章节 |
| :--- | ---: | :--- |
| 充足（≥15 命中） | 17 | 1、4、5、6、8、10、17、18、19、21、22、23、24、25、26、27、30、31、33（含 19 章，其中 33 计入） |
| 一般（6–14 命中） | 12 | 7、9、11、12、13、14、16、20、28、34 |
| 偏薄（2–5 命中，需跨文件聚合） | 5 | **2、3、15、29、32** |
| **完全无素材** | **0** | — |

- **熔断项 6（>1/3 章节无素材 = ≥12 章）未触发**：无素材章节为 0。
- 5 个偏薄章节均已给出**同仓库内的跨文件聚合方案**，不需要外部素材、不需要修改授权范围。

---

## 四、来源与合规

| 项 | 内容 |
| :--- | :--- |
| 许可证 | **CC BY-NC-SA 4.0**（`LICENSE.md` 明示 BY / NC / SA 三条件，已核验，与任务卡预期一致 → 熔断项 4 未触发） |
| 署名（BY） | 每个 JSON 文件与每道题均含 `source` + `sourceUrl`，并在文件级附 `license` / `licenseUrl` |
| 非商业（NC） | 本项目为学习用途、非商业分发 |
| 相同方式共享（SA） | 衍生题目数据以相同协议共享（在文件级 `license` 字段声明） |
| 转换而非摘抄 | 题目为基于素材的再创作（题干、干扰项、解析均为新撰写），不整段复制原文 |
| 未使用素材 | 仓库内 6 份 PDF（合计约 6.8 MB）与网盘引流 README 未纳入，规避来源不明的第三方版权内容 |

---

## 五、探查方法（可复现）

1. `GET https://api.github.com/repos/0voice/EmbeddedSoftwareLearn` → 仓库元数据与许可证字段；
2. `GET https://api.github.com/repos/0voice/EmbeddedSoftwareLearn/git/trees/main?recursive=1` → 全量文件树（未截断）；
3. 逐文件抓取：**`https://cdn.jsdelivr.net/gh/0voice/EmbeddedSoftwareLearn@main/{path}`**
   （本环境 `raw.githubusercontent.com` 不可达：`ECONNRESET`；jsDelivr 实测 200 可用）；
4. 结构化扫描：按"标题行/编号项/问句行"统计各素材的可出题单元；
5. 章节匹配：以 34 章标题关键词在全部素材标题上做正则匹配，得分即"命中标题数"。

---

## 六、批量转换实测修正（Exercise-Data-1 第二段收口）

转换期由 8 组转换师回源核对后，对第一节映射表做出 2 处修正，已回写第 9 行：

| # | 原映射记载 | 实测事实 | 处置 |
| ---: | :--- | :--- | :--- |
| 1 | ch9 素材指向 `03-驱动开发与外设编程/README.md`（PWM/舵机 50Hz） | 该文件**无** PWM/舵机小节（仅"用示波器验证 PWM 占空比与频率"一句）；50Hz 舵机在 `02-嵌入式系统基础知识/README.md#4. 定时控制`，TIM3 `Prescaler=72-1 / Period=1000-1 / Pulse=500` 实例在根 `README.md#调试 PWM 信号示例` | 已改用真实位置；`sourceRef` 全部指向实际素材 |
| 2 | ch34 常用术语表（泛化描述：各层 README 术语聚合） | 示例术语 **`SoC` 在仓库中不存在**（全仓库 10 个 README 正则扫描仅命中 `Socket`，无独立 SoC/片上系统表述） | **未编造**：改用仓库真实收录术语出题，并把 `"SoC"` 用作 ch34-005「未收录返回 0」的测试用例 |

**其他口径说明（不影响映射表）**

- ch34 的"术语首次出现"采用"**首次被实质展开**（定义/对比/归属）"口径：`RTOS`、`BSP` 等字面首现处仅为顺带提及，故 `sourceRef` 指向首个实质讲解小节，保证可追溯。
- ch30 的根 `README` 第九层与 `09-2025_AI_on_MCU/README.md` 内容一致，5 题 `sourceRef` 统一锚定 09 README 便于逐条追溯。
- **代码解可编译性口径**：本机 clang（DevEco SDK 自带 15.0.4）**无 libc sysroot**，`<string.h>`/`<ctype.h>` 不可用。34 段 `solutionCode` 中 30 段可直接编译通过；其余 4 段（ch20/ch27/ch31/ch34）在校验侧注入等价原型后通过，**数据未做任何迁就性修改**。

### 六.1 对第 1~5 章已验收文件的修改（显式披露 / 补正）

本轮在质检中发现：有 14 段 `solutionCode` 使用了 `NULL` 但未包含 `<stddef.h>`，无法独立编译。其中 **4 段位于第 1~5 章已验收文件**，本轮对其做了修改——此点此前仅在交付报告中一笔带过，属**披露不充分**，现补正如下：

| 文件 | 改动 | 量化证据 |
| :--- | :--- | :--- |
| `exercises-stage1_intro.json` | `solutionCode` 值首部插入 `#include <stddef.h>\n` | `git diff --numstat` = **1 增 1 删**；hunk 数 = 1 |
| `exercises-stage1_digital_circuit.json` | 同上 | 1 增 1 删；hunk = 1 |
| `exercises-stage1_mcu_soc.json` | 同上 | 1 增 1 删；hunk = 1 |
| `exercises-stage2_cpu.json` | 同上 | 1 增 1 删；hunk = 1 |

（第 5 个文件 `exercises-stage1_computer.json` **未被修改**：其解法只用 `#include <stdint.h>`，不含 `NULL`。）

- **改动性质**：非 schema 变更、非字段增删、非格式规范化 —— 唯一实质变化是那一个字符串的头部插入；已用机械比对证明 `+行 ≡ −行 + 插入前缀`（4/4 为真）。
- **中途发生过但已回退的改动**：首轮补丁脚本用 `JSON.parse → JSON.stringify` 回写，**顺带把那 4 个文件的内联选项对象展开为多行**（`+332/−86`）。发现后立即 `git checkout --` 还原为已验收内容，再以"外科式单行插入"重做，故净格式变更 = **0 行**。
- **行尾符**：4 个文件当前均为 **CRLF**（116~117 个 CRLF、0 个裸 LF）；`git diff --numstat` 在加/不加 `--ignore-cr-at-eol` 时结果完全一致（均 1/1），说明行尾未构成任何 diff 行。中间步骤（补丁脚本用 node 回写）曾短暂为 LF，已随 `git checkout --` 回到 CRLF。仓库 `core.autocrlf=true` 且无 `.gitattributes`，索引存 LF、工作区落 CRLF。
- **授权判定**：改动落在本卡授权目录 `entry/src/main/resources/rawfile/database/exercises/` 之内，属授权路径；但**它修改的是已验收产物**，超出"只做批量新增"的默认预期，故按披露纪律显式记账，供架构师决定是否保留（保留 = 4 段代码解可独立编译；回退 = 恢复验收时字节，需接受其不能独立编译）。
- **语义影响**：无。新增头文件仅提供 `NULL` 的声明，不改变任何逻辑与 `testCases` 期望值；改后 schema 校验仍 0 错误、语法检查 34/34 PASS。

**批量转换结果**：34 章 / 170 题（136 选择 + 34 代码）、难度 68/68/34、`sourceRef` 170 条共 114 个锚点**全部回源命中**、schema 校验 0 错误、0 个 INSUFFICIENT 章节。
