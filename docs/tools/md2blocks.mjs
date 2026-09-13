/**
 * EmbedLab Markdown -> contentBlocks 语义切分器（阶段二机械层）
 *
 * 设计原则（与《数据契约与切分红线》一一对应）：
 *  1. 机械层由确定性代码保证"绝对无损"：代码块逐字搬运（含 \n 与缩进），杜绝人工转写漂移。
 *  2. 语义层由 LLM 以 meta 文件形式注入：id / title / category / level / tags / summary。
 *  3. 切分规则：
 *     - "# "        -> 章节标题，交由 metadata.title 承载，不进入 contentBlocks
 *     - "## / ###"  -> {"type":"header"}
 *     - 段落        -> {"type":"text"}（段内软换行以 \n 原样保留）
 *     - 圆点列表项  -> 独立 {"type":"text"}，前缀 "•"（层级递进为 "••" / "•••"）
 *     - 有序列表项  -> 独立 {"type":"text"}，保留原序号
 *     - 围栏代码块  -> {"type":"code", language, content}（原样，含 callout 内嵌代码块）
 *     - 表格        -> 单元格以 " ｜ " 连接为多行 text 块
 *     - 常见误区 / 陷阱 章节与 [!warning] [!danger] [!caution] callout -> {"type":"warning"}
 *     - callout 内的段落与列表合并为同一个块，避免警示框被切碎
 *  4. 噪音过滤：**、*、~~、行内反引号、[[]]、[[]](url) 等 Markdown 标记一律剥离；
 *     callout 标记 "[!note]" 剥离，但其标题文字（如"正式定义"）作为块首行保留。
 *
 * 用法：
 *   node docs/tools/md2blocks.mjs --chapter docs/chapters/02_computer.md \
 *        --meta docs/tools/meta/stage1_computer.meta.json \
 *        --out entry/src/main/resources/rawfile/database/knowledge/details/stage1_computer.json
 */
import fs from 'node:fs';
import path from 'node:path';
import { startLog } from './lib/log.mjs';

const HR_RE = /^\s*(-{3,}|\*{3,}|_{3,})\s*$/;
const HEAD_RE = /^(#{1,6})\s+(.*?)\s*$/;
const BULLET_RE = /^(\s*)[-*+]\s+(.*)$/;
const ORDERED_RE = /^(\s*)(\d+)[.)]\s+(.*)$/;
const TABLE_RE = /^\s*\|.*\|\s*$/;
const TABLE_SEP_RE = /^\s*\|[\s:|-]+\|\s*$/;
const QUOTE_RE = /^\s*>\s?(.*)$/;
const FENCE_RE = /^(\s*)```(.*)$/;
const CALLOUT_RE = /^\[!(\w+)\]\s*(.*)$/;

/** 需要渲染为警示框的 callout 类型 */
const WARNING_CALLOUTS = new Set(['warning', 'danger', 'caution', 'attention', 'bug', 'failure']);
/** 需要整节渲染为警示框的章节标题特征 */
const WARNING_SECTION_RE = /常见误区|工程陷阱|工程排错|排错陷阱|故障排查|学习陷阱/;

const isBlank = (line) => line.trim() === '';

/** 剥离 Markdown 行内标记，保留正文与中文标点 */
function cleanInline(text) {
  const codes = [];
  let s = text.replace(/`([^`]*)`/g, (_m, p1) => {
    codes.push(p1);
    return `\u0000${codes.length - 1}\u0000`;
  });
  s = s.replace(/\[\[#?([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_m, target, label) =>
    (label === undefined ? target : label).trim()
  );
  s = s.replace(/\[([^\]]*)\]\(([^)]*)\)/g, (_m, label) => label);
  s = s.replace(/\*\*\*(.+?)\*\*\*/g, '$1');
  s = s.replace(/\*\*(.+?)\*\*/g, '$1');
  s = s.replace(/__(.+?)__/g, '$1');
  s = s.replace(/~~(.+?)~~/g, '$1');
  s = s.replace(/(^|[^*])\*(?!\s)([^*]+?)(?<!\s)\*(?!\*)/g, '$1$2');
  s = s.replace(/\u0000(\d+)\u0000/g, (_m, i) => codes[Number(i)]);
  return s.trim();
}

function isSpecialStart(line) {
  return (
    isBlank(line) ||
    HR_RE.test(line) ||
    HEAD_RE.test(line) ||
    BULLET_RE.test(line) ||
    ORDERED_RE.test(line) ||
    TABLE_RE.test(line) ||
    QUOTE_RE.test(line) ||
    FENCE_RE.test(line)
  );
}

/** 读取围栏代码块：返回 {lang, code, next}，代码内容逐字保留 */
function readFence(lines, start) {
  const open = FENCE_RE.exec(lines[start]);
  const lang = open[2].trim() === '' ? 'text' : open[2].trim();
  const body = [];
  let i = start + 1;
  for (; i < lines.length; i++) {
    if (FENCE_RE.test(lines[i])) {
      break;
    }
    body.push(lines[i]);
  }
  return { lang, code: body.join('\n'), next: Math.min(i + 1, lines.length) };
}

/** 将行序列切分为语法项 */
function tokenize(lines) {
  const items = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (isBlank(line)) {
      i++;
      continue;
    }
    if (HR_RE.test(line)) {
      i++;
      continue;
    }
    if (FENCE_RE.test(line)) {
      const f = readFence(lines, i);
      items.push({ kind: 'code', lang: f.lang, code: f.code });
      i = f.next;
      continue;
    }
    let m = HEAD_RE.exec(line);
    if (m) {
      // "# " 为章节标题，由 metadata.title 承载，不重复进入正文
      if (m[1].length >= 2) {
        items.push({ kind: 'header', level: m[1].length, text: cleanInline(m[2]) });
      }
      i++;
      continue;
    }
    if (TABLE_RE.test(line)) {
      const rows = [];
      while (i < lines.length && TABLE_RE.test(lines[i])) {
        if (!TABLE_SEP_RE.test(lines[i])) {
          const cells = lines[i]
            .trim()
            .replace(/^\|/, '')
            .replace(/\|$/, '')
            .split('|')
            .map((c) => cleanInline(c));
          rows.push(cells);
        }
        i++;
      }
      items.push({ kind: 'table', rows });
      continue;
    }
    m = BULLET_RE.exec(line);
    if (m) {
      items.push({ kind: 'bullet', indent: m[1].length, text: cleanInline(m[2]) });
      i++;
      continue;
    }
    m = ORDERED_RE.exec(line);
    if (m) {
      items.push({ kind: 'ordered', indent: m[1].length, num: m[2], text: cleanInline(m[3]) });
      i++;
      continue;
    }
    if (QUOTE_RE.test(line)) {
      const inner = [];
      while (i < lines.length && QUOTE_RE.test(lines[i])) {
        inner.push(QUOTE_RE.exec(lines[i])[1]);
        i++;
      }
      items.push({ kind: 'quote', lines: inner });
      continue;
    }
    const buf = [];
    while (i < lines.length && !isSpecialStart(lines[i])) {
      buf.push(lines[i]);
      i++;
    }
    items.push({ kind: 'para', text: cleanInline(buf.join('\n')) });
  }
  return items;
}

/** 圆点层级前缀：0-1 空格 -> •，2-3 -> ••，>=4 -> ••• */
function bulletPrefix(indent) {
  const level = indent >= 4 ? 3 : indent >= 2 ? 2 : 1;
  return '•'.repeat(level);
}

/** 表格 -> 单元格以 " ｜ " 连接的多行文本 */
function tableText(rows) {
  return rows.map((r) => r.join(' ｜ ')).join('\n');
}

/** 列表/表格项 -> 纯文本行（用于 callout 内部合并） */
function itemToProseLine(item) {
  if (item.kind === 'bullet') {
    return `${bulletPrefix(item.indent)} ${item.text}`;
  }
  if (item.kind === 'ordered') {
    return `${item.num}. ${item.text}`;
  }
  if (item.kind === 'table') {
    return tableText(item.rows);
  }
  return item.text;
}

/**
 * 将语法项渲染为 contentBlocks。
 * @param {object[]} items tokenize 结果
 * @param {{warningDefault: boolean, mergeProse: boolean}} opt
 */
function render(items, opt) {
  const blocks = [];
  /** @type {{text: string, list: boolean}[]} */
  let pending = [];
  const flush = () => {
    if (pending.length === 0) {
      return;
    }
    // 相邻列表项之间用单换行贴合，段落之间保留空行
    let content = pending[0].text;
    for (let i = 1; i < pending.length; i++) {
      const sep = pending[i - 1].list && pending[i].list ? '\n' : '\n\n';
      content += sep + pending[i].text;
    }
    blocks.push({ type: opt.warningDefault ? 'warning' : 'text', content });
    pending = [];
  };

  for (const item of items) {
    if (item.kind === 'header') {
      flush();
      blocks.push({ type: 'header', content: item.text });
      continue;
    }
    if (item.kind === 'code') {
      flush();
      blocks.push({ type: 'code', language: item.lang, content: item.code });
      continue;
    }
    if (item.kind === 'quote') {
      flush();
      for (const b of renderCallout(item.lines, opt.warningDefault)) {
        blocks.push(b);
      }
      continue;
    }
    if (item.kind === 'para' && !opt.mergeProse) {
      flush();
      blocks.push({ type: opt.warningDefault ? 'warning' : 'text', content: item.text });
      continue;
    }
    if ((item.kind === 'bullet' || item.kind === 'ordered') && !opt.mergeProse) {
      flush();
      const content = itemToProseLine(item);
      blocks.push({ type: opt.warningDefault ? 'warning' : 'text', content });
      continue;
    }
    // callout 内部：段落 / 列表 / 表格合并进同一块，遇到代码块再断开
    pending.push({
      text: itemToProseLine(item),
      list: item.kind === 'bullet' || item.kind === 'ordered'
    });
  }
  flush();
  return blocks;
}

/** callout -> 块序列（标题并入首块，代码块独立） */
function renderCallout(innerLines, sectionWarning) {
  let type = 'note';
  let title = '';
  const firstIdx = innerLines.findIndex((l) => !isBlank(l));
  let body = innerLines;
  if (firstIdx >= 0) {
    const m = CALLOUT_RE.exec(innerLines[firstIdx].trim());
    if (m) {
      type = m[1].toLowerCase();
      title = cleanInline(m[2]);
      body = innerLines.slice(firstIdx + 1);
    }
  }
  const warning = sectionWarning || WARNING_CALLOUTS.has(type);
  const sub = tokenize(body);
  const blocks = render(sub, { warningDefault: warning, mergeProse: true });
  if (title.length > 0) {
    if (blocks.length > 0 && (blocks[0].type === 'text' || blocks[0].type === 'warning')) {
      blocks[0].content = `${title}\n${blocks[0].content}`;
    } else {
      blocks.unshift({ type: warning ? 'warning' : 'text', content: title });
    }
  }
  return blocks;
}

/** 主转换：章节 markdown -> contentBlocks */
export function convert(markdown) {
  const lines = markdown.replace(/\r\n?/g, '\n').split('\n');
  const items = tokenize(lines);
  const blocks = [];
  let sectionWarning = false;
  let buf = [];

  const flushSection = () => {
    if (buf.length === 0) {
      return;
    }
    for (const b of render(buf, { warningDefault: sectionWarning, mergeProse: false })) {
      blocks.push(b);
    }
    buf = [];
  };

  for (const item of items) {
    if (item.kind === 'header' && item.level === 2) {
      flushSection();
      sectionWarning = WARNING_SECTION_RE.test(item.text);
      buf.push(item);
      continue;
    }
    buf.push(item);
  }
  flushSection();
  return blocks;
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      args[a.slice(2)] = argv[i + 1];
      i++;
    }
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  startLog(args.log);
  for (const key of ['chapter', 'meta', 'out']) {
    if (!args[key]) {
      throw new Error(`缺少参数 --${key}`);
    }
  }
  const markdown = fs.readFileSync(args.chapter, 'utf8');
  const meta = JSON.parse(fs.readFileSync(args.meta, 'utf8'));
  const contentBlocks = convert(markdown);
  const item = {
    id: meta.id,
    title: meta.title,
    category: meta.category,
    level: meta.level,
    tags: meta.tags,
    summary: meta.summary,
    images: meta.images === undefined ? [] : meta.images,
    relatedProjectIds: meta.relatedProjectIds === undefined ? [] : meta.relatedProjectIds,
    contentBlocks
  };
  fs.mkdirSync(path.dirname(args.out), { recursive: true });
  fs.writeFileSync(args.out, JSON.stringify(item, null, 2) + '\n', 'utf8');

  const stat = {};
  for (const b of contentBlocks) {
    stat[b.type] = (stat[b.type] || 0) + 1;
  }
  console.log(`[md2blocks] chapter=${args.chapter}`);
  console.log(`[md2blocks] out=${args.out}`);
  console.log(`[md2blocks] blocks=${contentBlocks.length} ${JSON.stringify(stat)}`);
}

// 作为库被校验器 import 时不执行 CLI 逻辑
if (process.argv.slice(2).includes('--chapter')) {
  main();
}
