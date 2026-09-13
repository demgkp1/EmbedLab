/**
 * EmbedLab 教材章节拆分脚本（阶段一）
 *
 * 输入：docs/嵌入式系统.md（含 YAML front-matter 与 "# 目录" 索引段）
 * 输出：
 *   1. docs/chapters/{NN}_{slug}.md —— 34 个章节独立文件（保留 "# N. 标题" 一级标题行）
 *   2. docs/migration_state.json   —— 逐章解析进度状态机
 *
 * 纪律：本脚本只做"物理切分"，不做任何语义改写；章节标题一律从原文读取，避免人工转写漂移。
 * 用法：node docs/tools/split_chapters.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.cwd());
const SRC = path.join(ROOT, 'docs', '嵌入式系统.md');
const OUT_DIR = path.join(ROOT, 'docs', 'chapters');
const STATE = path.join(ROOT, 'docs', 'migration_state.json');

const STAGE = {
  1: 'Stage 1: 认识嵌入式世界',
  2: 'Stage 2: 计算机 / CPU / Memory / C',
  3: 'Stage 3: GPIO / 中断 / 定时器',
  4: 'Stage 4: UART / I2C / SPI',
  5: 'Stage 5: ADC / DMA',
  6: 'Stage 6: 看门狗 / Flash / RTOS / 并发',
  7: 'Stage 7: 网络 / MQTT / 嵌入式 Linux / Bootloader',
  8: 'Stage 8: 构建 / 调试 / 驱动 / 架构',
  9: 'Stage 9: 传感器 / 机器人 / AI / 项目',
  A: '附录: 学习路线与术语表'
};

/** 章节清单：n = 原文序号，slug = 文件名后缀，stage = 分类键，id = 知识库主键 */
const MANIFEST = [
  { n: 1, slug: 'intro', stage: 1, id: 'stage1_intro' },
  { n: 2, slug: 'computer', stage: 1, id: 'stage1_computer' },
  { n: 3, slug: 'digital_circuit', stage: 1, id: 'stage1_digital_circuit' },
  { n: 4, slug: 'mcu_soc', stage: 1, id: 'stage1_mcu_soc' },
  { n: 5, slug: 'cpu_memory_boot', stage: 2, id: 'stage2_cpu' },
  { n: 6, slug: 'c_language', stage: 2, id: 'stage2_c_language' },
  { n: 7, slug: 'gpio', stage: 3, id: 'stage3_gpio' },
  { n: 8, slug: 'interrupt', stage: 3, id: 'stage3_interrupt' },
  { n: 9, slug: 'timer_pwm', stage: 3, id: 'stage3_timer_pwm' },
  { n: 10, slug: 'uart', stage: 4, id: 'stage4_uart' },
  { n: 11, slug: 'i2c', stage: 4, id: 'stage4_i2c' },
  { n: 12, slug: 'spi', stage: 4, id: 'stage4_spi' },
  { n: 13, slug: 'adc_dac_sensor', stage: 5, id: 'stage5_adc_sensor' },
  { n: 14, slug: 'dma', stage: 5, id: 'stage5_dma' },
  { n: 15, slug: 'watchdog', stage: 6, id: 'stage6_watchdog' },
  { n: 16, slug: 'flash_fs', stage: 6, id: 'stage6_flash' },
  { n: 17, slug: 'rtos', stage: 6, id: 'stage6_rtos' },
  { n: 18, slug: 'concurrency', stage: 6, id: 'stage6_concurrency' },
  { n: 19, slug: 'network', stage: 7, id: 'stage7_network' },
  { n: 20, slug: 'mqtt', stage: 7, id: 'stage7_mqtt' },
  { n: 21, slug: 'embedded_linux', stage: 7, id: 'stage7_linux' },
  { n: 22, slug: 'bootloader', stage: 7, id: 'stage7_bootloader' },
  { n: 23, slug: 'build_link_flash', stage: 8, id: 'stage8_build' },
  { n: 24, slug: 'debugging', stage: 8, id: 'stage8_debug' },
  { n: 25, slug: 'low_power', stage: 8, id: 'stage8_low_power' },
  { n: 26, slug: 'driver', stage: 8, id: 'stage8_driver' },
  { n: 27, slug: 'architecture', stage: 8, id: 'stage8_architecture' },
  { n: 28, slug: 'sensors', stage: 9, id: 'stage9_sensors' },
  { n: 29, slug: 'robotics', stage: 9, id: 'stage9_robotics' },
  { n: 30, slug: 'tinyml', stage: 9, id: 'stage9_tinyml' },
  { n: 31, slug: 'project_method', stage: 9, id: 'stage9_project' },
  { n: 32, slug: 'troubleshooting', stage: 9, id: 'stage9_troubleshooting' },
  { n: 33, slug: 'learning_path', stage: 'A', id: 'appendix_learning_path' },
  { n: 34, slug: 'glossary', stage: 'A', id: 'appendix_glossary' }
];

/** 上一轮已导入成品的章节：状态直接置为 done，严禁重复追加 index 条目 */
const PRE_EXISTING = {
  1: 'pre-existing: 上一轮已导入 details/stage1_intro.json 与 index 条目',
  7: 'pre-existing: 上一轮已导入 details/stage3_gpio.json 与 index 条目'
};

function readSource() {
  if (!fs.existsSync(SRC)) {
    throw new Error(`源文件不存在: ${SRC}`);
  }
  return fs.readFileSync(SRC, 'utf8').replace(/\r\n?/g, '\n').replace(/^\uFEFF/, '');
}

/** 去掉 YAML front-matter */
function stripFrontMatter(text) {
  if (!text.startsWith('---\n')) {
    return text;
  }
  const end = text.indexOf('\n---', 4);
  if (end < 0) {
    return text;
  }
  return text.slice(text.indexOf('\n', end + 1) + 1);
}

/** 按 "# " 一级标题切段 */
function splitTopLevel(text) {
  const lines = text.split('\n');
  const sections = [];
  let current = null;
  for (const line of lines) {
    if (/^#\s+\S/.test(line) && !/^##/.test(line)) {
      current = { heading: line.replace(/^#\s+/, '').trim(), lines: [] };
      sections.push(current);
      continue;
    }
    if (current) {
      current.lines.push(line);
    }
  }
  return sections;
}

/** 去掉章节尾部多余的分隔线与空行 */
function trimTail(lines) {
  const out = lines.slice();
  while (out.length > 0) {
    const last = out[out.length - 1].trim();
    if (last === '' || last === '---' || last === '***' || last === '___') {
      out.pop();
      continue;
    }
    break;
  }
  return out;
}

function main() {
  const raw = stripFrontMatter(readSource());
  const sections = splitTopLevel(raw);
  const byNumber = new Map();
  for (const sec of sections) {
    const m = /^(\d+)\.\s*(.+)$/.exec(sec.heading);
    if (m) {
      byNumber.set(Number(m[1]), sec);
    }
  }

  fs.mkdirSync(OUT_DIR, { recursive: true });
  const state = [];
  const problems = [];

  for (const entry of MANIFEST) {
    const sec = byNumber.get(entry.n);
    if (!sec) {
      problems.push(`原文缺少第 ${entry.n} 章一级标题`);
      continue;
    }
    const file = `${String(entry.n).padStart(2, '0')}_${entry.slug}.md`;
    const title = `${entry.n}. ${sec.heading.replace(/^\d+\.\s*/, '')}`;
    const body = trimTail(sec.lines);
    const chapterText = [`# ${title}`, '', ...body, ''].join('\n');
    fs.writeFileSync(path.join(OUT_DIR, file), chapterText, 'utf8');

    const record = {
      chapter: entry.n,
      file,
      title,
      id: entry.id,
      category: STAGE[entry.stage],
      status: PRE_EXISTING[entry.n] ? 'done' : 'pending'
    };
    if (PRE_EXISTING[entry.n]) {
      record.note = PRE_EXISTING[entry.n];
    }
    state.push(record);
  }

  if (byNumber.size !== MANIFEST.length) {
    problems.push(`原文一级标题章节数 ${byNumber.size} ≠ 清单 ${MANIFEST.length}`);
  }

  fs.writeFileSync(STATE, JSON.stringify(state, null, 2) + '\n', 'utf8');

  const pending = state.filter((s) => s.status === 'pending');
  console.log(`[split] 源文件: docs/嵌入式系统.md`);
  console.log(`[split] 输出目录: docs/chapters/`);
  console.log(`[split] 已写出章节文件: ${state.length}`);
  console.log(`[split] 状态文件: docs/migration_state.json`);
  console.log(`[split] done=${state.length - pending.length} pending=${pending.length}`);
  console.log(`[split] 首个待处理: ${pending.length > 0 ? `第 ${pending[0].chapter} 章 -> ${pending[0].file} (${pending[0].id})` : '无'}`);
  if (problems.length > 0) {
    console.log('[split] 警告:');
    for (const p of problems) {
      console.log(`  - ${p}`);
    }
    process.exitCode = 1;
  }
}

main();
