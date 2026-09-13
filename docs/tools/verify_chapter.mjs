/**
 * EmbedLab 章节 JSON 校验器（阶段二质检门）
 *
 * 规则版本：v2.1
 *   - v1.0（初版）：源文件每个围栏代码块必须与 JSON 中同序的单个 code 块逐字节相等。
 *   - v2.0：新增「可加性拆解豁免」——源围栏 C 被拆成 JSON 中连续 N 个 code 块且
 *           concat(C1..CN) === C（逐字节，分隔符 \n 或空串）则 PASS；拆解组内 language 必须一致。
 *   - v2.1（本次）：新增「mermaid 围栏豁免」——原文 ```mermaid 围栏 N 段时，JSON 中 image 块
 *           数量 ≥ N 即判 PASS（图表改以位图资产承载，不再要求 code 块还原）。
 *           严格规则原样保留：C / asm / bash / text 等一切非 mermaid 围栏仍须逐字或可加性还原，
 *           且 JSON 中不得出现源码不存在的 code 块。
 *           **豁免范围仅限 language === 'mermaid'，严禁泛化到任何其他语言。**
 *
 * 校验维度：
 *  A. JSON 可被 JSON.parse 完美解析
 *  B. 结构契约：9 个字段齐全、类型正确、contentBlocks 字段无冗余、language 仅出现在 code 块
 *  C. 代码无损：非 mermaid 围栏严格逐字或可加性还原（v2.0）；mermaid 围栏按 image 块数量豁免（v2.1）
 *  D. 代码未污染正文：代码块内容不得出现在任何 text / warning 块中
 *  E. 标题覆盖：源文件每个 ## / ### 标题均存在于 header 块
 *  F. 正文覆盖：源文件所有非代码正文行（含表格单元格、列表项）均可在 text / warning / header 块中检索到
 *  G. 图片约束：v2.1 起 image 块用于承载 mermaid 图，不再要求为空
 *
 * 用法：node docs/tools/verify_chapter.mjs --chapter docs/chapters/02_computer.md \
 *        --detail entry/src/main/resources/rawfile/database/knowledge/details/stage1_computer.json
 *        node docs/tools/verify_chapter.mjs --self-test   # 规则自检（纯内存，不读写业务数据）
 */
import fs from 'node:fs';
import { startLog } from './lib/log.mjs';

/** 规则版本号（会打印在校验日志首行，供审计追溯） */
const RULE_VERSION = 'v2.1 mermaid 围栏豁免';
/** 唯一享受豁免的围栏语言，严禁泛化 */
const MERMAID_LANG = 'mermaid';

const norm = (s) =>
  s
    .replace(/\[![\w]+\]/g, '')
    .replace(/\[\[#?([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_m, t, l) => (l === undefined ? t : l))
    .replace(/\[([^\]]*)\]\(([^)]*)\)/g, '$1')
    .replace(/[`*_~>|]/g, '')
    .replace(/\s+/g, '');

const stripListMarker = (line) => line.replace(/^\s*([-*+]|\d+[.)])\s+/, '');

const ALLOWED_TYPES = new Set(['header', 'text', 'image', 'code', 'warning']);
const LEVELS = new Set(['Basic', 'Medium', 'Hard']);
const REQUIRED_KEYS = [
  'id',
  'title',
  'category',
  'level',
  'tags',
  'summary',
  'images',
  'relatedProjectIds',
  'contentBlocks'
];

/**
 * 尝试用 JSON 中自 start 起的连续 code 块还原一段源码围栏（可加性拆解豁免的核心判定）。
 *
 * 判定规则：
 *   - N = 1：要求逐字节严格相等（原 v1.0 路径，不变）；
 *   - N > 1：要求 concat(C1..CN) 与源码围栏逐字节相等，拼接分隔符仅允许「单个 \n」或「空串」；
 *   - 返回最先成立的 { n, sep }，无法还原返回 null。
 * 纪律：不做 trim、不做空白归一化、不做子串匹配 —— 任何非恒等还原一律判 FAIL。
 */
function matchFenceRun(codeBlocks, start, fenceCode) {
  for (let n = 1; start + n <= codeBlocks.length; n++) {
    if (n === 1) {
      if (codeBlocks[start].content === fenceCode) {
        return { n: 1, sep: '' };
      }
      continue;
    }
    const parts = codeBlocks.slice(start, start + n).map((b) => b.content);
    if (parts.join('\n') === fenceCode) {
      return { n, sep: '\n' };
    }
    if (parts.join('') === fenceCode) {
      return { n, sep: '' };
    }
  }
  return null;
}

/**
 * 代码无损判定，供主流程与自检共用。
 * v2.0 严格路径：非 mermaid 围栏逐字 / 可加性还原，禁止多余 code 块。
 * v2.1 新增豁免：language === 'mermaid' 的围栏不要求 code 块，改按 image 块数量判定（image ≥ 围栏数）。
 *
 * @param {object[]} codeBlocks  JSON 中 type === 'code' 的块
 * @param {object[]} fences      源文件围栏 { lang, code }
 * @param {object[]} imageBlocks JSON 中 type === 'image' 的块（v2.1）
 */
function evaluateCode(codeBlocks, fences, imageBlocks = []) {
  const errors = [];
  const notes = [];
  const splits = [];

  // ---- v2.1：mermaid 围栏豁免（仅此一种语言，严禁泛化） ----
  const mermaidFences = fences.filter((f) => f.lang === MERMAID_LANG);
  const strictFences = fences.filter((f) => f.lang !== MERMAID_LANG);
  const strictBlocks = codeBlocks.filter((b) => b.language !== MERMAID_LANG);
  const leftoverMermaid = codeBlocks.filter((b) => b.language === MERMAID_LANG);

  let mermaidPass = true;
  if (mermaidFences.length > 0) {
    if (imageBlocks.length < mermaidFences.length) {
      mermaidPass = false;
      errors.push(
        `mermaid 围栏豁免判定不通过：原文 ${mermaidFences.length} 段 mermaid 围栏，JSON 仅 ${imageBlocks.length} 个 image 块（要求 image 块数 ≥ mermaid 围栏数）`
      );
    } else {
      notes.push(
        `mermaid 豁免：原文 ${mermaidFences.length} 段 mermaid 围栏 → JSON ${imageBlocks.length} 个 image 块，数量判定 PASS`
      );
    }
  }
  if (leftoverMermaid.length > 0) {
    notes.push(
      `存在 ${leftoverMermaid.length} 个 language=mermaid 的 code 块（属豁免范围，未计入"多余块"；建议后续统一转为 image 块）`
    );
  }

  // ---- v2.0：严格路径（仅针对非 mermaid 围栏） ----
  let matched = 0;
  let cursor = 0;
  for (let i = 0; i < strictFences.length; i++) {
    const match = matchFenceRun(strictBlocks, cursor, strictFences[i].code);
    if (match === null) {
      const where =
        cursor < strictBlocks.length
          ? `（JSON 自第 ${cursor + 1} 个非 mermaid code 块起无法逐字节还原该段）`
          : '（JSON 已无剩余非 mermaid code 块）';
      errors.push(`第 ${i + 1} 段源码围栏无法逐字/可加性还原${where}：${strictFences[i].code.split('\n')[0].slice(0, 60)}`);
      continue;
    }
    matched++;
    for (let k = 0; k < match.n; k++) {
      const block = strictBlocks[cursor + k];
      if (block.language !== strictFences[i].lang) {
        errors.push(
          `第 ${i + 1} 段源码围栏的第 ${k + 1} 个拆解块 language 不一致: 源 ${strictFences[i].lang} vs JSON ${block.language}`
        );
      }
    }
    if (match.n > 1) {
      splits.push({
        fence: i + 1,
        from: cursor + 1,
        to: cursor + match.n,
        n: match.n,
        sep: match.sep === '\n' ? '\\n' : '空串'
      });
    }
    cursor += match.n;
  }
  if (cursor < strictBlocks.length) {
    errors.push(
      `JSON 中多出 ${strictBlocks.length - cursor} 个源码不存在的 code 块（第 ${cursor + 1}..${strictBlocks.length} 个，已排除 mermaid），禁止以"任意多块"通过校验`
    );
  }
  return {
    errors,
    notes,
    splits,
    matched,
    consumed: cursor,
    strictFences,
    strictBlocks,
    mermaidFences,
    imageBlocks,
    mermaidPass
  };
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      args[argv[i].slice(2)] = argv[i + 1];
      i++;
    }
  }
  return args;
}

/** 抽取源文件的围栏代码块与标题、正文行 */
function scanSource(markdown) {
  const lines = markdown.replace(/\r\n?/g, '\n').split('\n');
  const fences = [];
  const headings = [];
  const proseLines = [];
  let inFence = false;
  let fenceLang = '';
  let buf = [];
  let quoteDepth = 0;

  const openFence = (line) => /^\s*```(.*)$/.exec(line);
  const unquote = (line) => line.replace(/^\s*>\s?/, '');

  for (const raw of lines) {
    const line = quoteDepth > 0 ? unquote(raw) : raw;
    if (inFence) {
      if (/^\s*```\s*$/.test(line)) {
        fences.push({ lang: fenceLang, code: buf.join('\n') });
        buf = [];
        inFence = false;
        continue;
      }
      buf.push(line);
      continue;
    }
    const f = openFence(line);
    if (f && !/^\s*```\s*$/.test(line)) {
      inFence = true;
      fenceLang = f[1].trim() === '' ? 'text' : f[1].trim();
      continue;
    }
    if (/^\s*```\s*$/.test(line)) {
      // 未带语言标记的围栏：按 text 处理
      inFence = true;
      fenceLang = 'text';
      continue;
    }
    if (/^\s*>\s?/.test(raw) || /^\s*>$/.test(raw)) {
      quoteDepth = 1;
    } else if (raw.trim() !== '') {
      quoteDepth = 0;
    }
    const h = /^(#{1,6})\s+(.*?)\s*$/.exec(line);
    if (h) {
      headings.push({ level: h[1].length, text: h[2] });
      continue;
    }
    if (line.trim() === '' || /^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(line)) {
      continue;
    }
    proseLines.push(line);
  }
  if (inFence) {
    throw new Error('源文件围栏代码块未闭合');
  }
  return { fences, headings, proseLines };
}

function checkSchema(item, errors, notes) {
  const keys = Object.keys(item);
  for (const k of REQUIRED_KEYS) {
    if (!keys.includes(k)) {
      errors.push(`缺少字段: ${k}`);
    }
  }
  for (const k of keys) {
    if (!REQUIRED_KEYS.includes(k)) {
      errors.push(`出现契约外字段: ${k}`);
    }
  }
  for (const k of ['id', 'title', 'category', 'level', 'summary']) {
    if (typeof item[k] !== 'string' || item[k].length === 0) {
      errors.push(`字段 ${k} 必须为非空字符串`);
    }
  }
  if (!LEVELS.has(item.level)) {
    errors.push(`level 取值非法: ${item.level}`);
  }
  for (const k of ['tags', 'images', 'relatedProjectIds']) {
    if (!Array.isArray(item[k])) {
      errors.push(`字段 ${k} 必须为数组`);
    }
  }
  if (!Array.isArray(item.contentBlocks) || item.contentBlocks.length === 0) {
    errors.push('contentBlocks 必须为非空数组');
    return;
  }
  item.contentBlocks.forEach((b, i) => {
    const bk = Object.keys(b);
    if (!ALLOWED_TYPES.has(b.type)) {
      errors.push(`block[${i}] type 非法: ${b.type}`);
    }
    if (typeof b.content !== 'string' || b.content.length === 0) {
      errors.push(`block[${i}] content 必须为非空字符串`);
    }
    if (b.type === 'code') {
      if (typeof b.language !== 'string' || b.language.length === 0) {
        errors.push(`block[${i}] code 块必须携带 language`);
      }
    } else if (bk.includes('language')) {
      errors.push(`block[${i}] 非 code 块禁止携带 language`);
    }
    for (const k of bk) {
      if (!['type', 'content', 'language'].includes(k)) {
        errors.push(`block[${i}] 出现契约外字段: ${k}`);
      }
    }
  });
  if (item.images.length > 0) {
    notes.push(`images 非空: ${JSON.stringify(item.images)}（需确认原文确有图片引用）`);
  }
}

/**
 * 规则自检（--self-test）：纯内存合成用例，验证「可加性拆解豁免」既不误杀合法拆解，
 * 也不放宽为"任意多 code 块都 PASS"。不读取、不写入任何业务数据文件。
 */
function selfTest() {
  const mk = (content, language) => ({ type: 'code', language, content });
  const fen = (code, lang) => ({ code, lang });
  const mkImg = (content) => ({ type: 'image', content });
  const IMG = mkImg('database/images/diagrams/sample_diagram.png');
  const cases = [
    { name: '严格逐字（单块，v1.0 路径）', blocks: [mk('A\nB\nC', 'c')], fences: [fen('A\nB\nC', 'c')], expectPass: true, splits: 0 },
    { name: '可加性拆解（\\n 拼接，2 块）', blocks: [mk('A\nB', 'c'), mk('C', 'c')], fences: [fen('A\nB\nC', 'c')], expectPass: true, splits: 1 },
    { name: '可加性拆解（空串拼接）', blocks: [mk('A\nB\n', 'c'), mk('C', 'c')], fences: [fen('A\nB\nC', 'c')], expectPass: true, splits: 1 },
    {
      name: '可加性拆解（\\n 拼接，3 块）',
      blocks: [mk('A', 'c'), mk('B', 'c'), mk('C', 'c')],
      fences: [fen('A\nB\nC', 'c')],
      expectPass: true,
      splits: 1
    },
    {
      name: '多段源码 + 混合拆解',
      blocks: [mk('X', 'c'), mk('A\nB', 'c'), mk('C', 'c')],
      fences: [fen('X', 'c'), fen('A\nB\nC', 'c')],
      expectPass: true,
      splits: 1
    },
    // ---- v2.1：mermaid 围栏豁免 ----
    { name: 'v2.1 mermaid 围栏 + 1 image 块 → PASS', blocks: [], fences: [fen('graph TD\n A-->B', 'mermaid')], images: [IMG], expectPass: true, splits: 0 },
    { name: 'v2.1 mermaid 围栏 1 段 + 2 image 块（≥）→ PASS', blocks: [], fences: [fen('graph TD\n A-->B', 'mermaid')], images: [IMG, mkImg('x.png')], expectPass: true, splits: 0 },
    { name: 'v2.1 mermaid 2 段围栏 + 仅 1 image 块 → FAIL', blocks: [], fences: [fen('graph TD\n A-->B', 'mermaid'), fen('graph LR\n C-->D', 'mermaid')], images: [IMG], expectPass: false, splits: 0 },
    { name: 'v2.1 mermaid 围栏但 0 image 块 → FAIL', blocks: [], fences: [fen('graph TD\n A-->B', 'mermaid')], images: [], expectPass: false, splits: 0 },
    {
      name: 'v2.1 混合：mermaid 豁免 + C 严格均合规 → PASS',
      blocks: [mk('A\nB', 'c'), mk('C', 'c')],
      fences: [fen('graph TD\n A-->B', 'mermaid'), fen('A\nB\nC', 'c')],
      images: [IMG],
      expectPass: true,
      splits: 1
    },
    {
      name: 'v2.1 混合：mermaid 达标但 C 代码被篡改 → FAIL',
      blocks: [mk('A\nB', 'c'), mk('X', 'c')],
      fences: [fen('graph TD\n A-->B', 'mermaid'), fen('A\nB\nC', 'c')],
      images: [IMG],
      expectPass: false,
      splits: 0
    },
    { name: 'v2.1 非 mermaid 围栏不得用 image 豁免（bash）', blocks: [], fences: [fen('echo hi\nls -l', 'bash')], images: [IMG, mkImg('y.png')], expectPass: false, splits: 0 },
    { name: 'v2.1 非 mermaid 围栏不得用 image 豁免（asm）', blocks: [], fences: [fen('mov r0, #1', 'asm')], images: [IMG], expectPass: false, splits: 0 },
    // ---- 严格路径回归 ----
    { name: '不可还原（内容篡改）', blocks: [mk('A\nB', 'c'), mk('X', 'c')], fences: [fen('A\nB\nC', 'c')], expectPass: false, splits: 0 },
    { name: '不可还原（顺序错乱）', blocks: [mk('C', 'c'), mk('A\nB', 'c')], fences: [fen('A\nB\nC', 'c')], expectPass: false, splits: 0 },
    { name: '禁止宽松化（源码外的多余块）', blocks: [mk('A\nB\nC', 'c'), mk('D', 'c')], fences: [fen('A\nB\nC', 'c')], expectPass: false, splits: 0 },
    { name: 'language 不一致不得豁免', blocks: [mk('A\nB', 'text'), mk('C', 'c')], fences: [fen('A\nB\nC', 'c')], expectPass: false, splits: 1 },
    { name: '遗留形态 A：源 1 段 mermaid / JSON 0 块 0 图', blocks: [], fences: [fen('graph TD\n A-->B', 'mermaid')], expectPass: false, splits: 0 },
    {
      name: '遗留形态 B：源 1 段 mermaid / JSON 4 段 C 代码 0 图',
      blocks: [mk('#include <stdint.h>', 'C'), mk('void f(void) {}', 'C')],
      fences: [fen('graph TD\n A-->B', 'mermaid')],
      expectPass: false,
      splits: 0
    }
  ];
  let pass = 0;
  console.log(`[self-test] 规则版本 ${RULE_VERSION}`);
  for (const c of cases) {
    const r = evaluateCode(c.blocks, c.fences, c.images || []);
    const ok = (r.errors.length === 0) === c.expectPass && r.splits.length === c.splits;
    if (ok) {
      pass++;
    }
    console.log(
      `${ok ? '  PASS' : '  FAIL'} | ${c.name} | 期望 ${c.expectPass ? `PASS（errs=0, splits=${c.splits}）` : `FAIL（errs≥1, splits=${c.splits}）`} | 实际 errs=${r.errors.length}/splits=${r.splits.length}`
    );
    if (!ok) {
      for (const e of r.errors) {
        console.log(`         └ ${e}`);
      }
    }
  }
  console.log(`[self-test] ${pass}/${cases.length} 用例通过`);
  process.exit(pass === cases.length ? 0 : 1);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  startLog(args.log);
  const markdown = fs.readFileSync(args.chapter, 'utf8');
  const raw = fs.readFileSync(args.detail, 'utf8');
  const errors = [];
  const notes = [];

  let item = null;
  try {
    item = JSON.parse(raw);
  } catch (e) {
    console.log(`[verify] JSON.parse 失败: ${e.message}`);
    process.exit(1);
  }
  checkSchema(item, errors, notes);

  const { fences, headings, proseLines } = scanSource(markdown);
  const blocks = Array.isArray(item.contentBlocks) ? item.contentBlocks : [];
  const codeBlocks = blocks.filter((b) => b.type === 'code');
  const imageBlocks = blocks.filter((b) => b.type === 'image');
  const textBlocks = blocks.filter((b) => b.type === 'text' || b.type === 'warning');
  const headerBlocks = blocks.filter((b) => b.type === 'header');

  // C. 代码无损：非 mermaid 围栏严格逐字/可加性还原（v2.0）+ mermaid 围栏按 image 块数量豁免（v2.1）
  const codeJudge = evaluateCode(codeBlocks, fences, imageBlocks);
  const splitNotes = codeJudge.splits;
  for (const e of codeJudge.errors) {
    errors.push(e);
  }
  for (const n of codeJudge.notes) {
    notes.push(n);
  }

  const textHay = norm(textBlocks.map((b) => b.content).join('\n'));
  const fullHay = norm(blocks.map((b) => b.content).join('\n'));

  // D. 代码不得混入正文块
  for (let i = 0; i < fences.length; i++) {
    const codeNorm = norm(fences[i].code);
    if (codeNorm.length >= 12 && textHay.includes(codeNorm)) {
      errors.push(`第 ${i + 1} 个代码块被混入 text / warning 块`);
    }
  }

  // E. 标题覆盖
  const headerHay = norm(headerBlocks.map((b) => b.content).join('\n'));
  for (const h of headings) {
    if (h.level === 1) {
      continue;
    }
    if (!headerHay.includes(norm(h.text))) {
      errors.push(`标题未映射为 header 块: ${h.text}`);
    }
  }
  if (headings.filter((h) => h.level >= 2).length !== headerBlocks.length) {
    notes.push(
      `header 块数 ${headerBlocks.length} ≠ 源标题数 ${headings.filter((h) => h.level >= 2).length}（callout 内标题等特殊情形需人工确认）`
    );
  }

  // F. 正文覆盖
  const missing = [];
  for (const line of proseLines) {
    const trimmed = line.trim();
    if (/^\|[\s:|-]+\|$/.test(trimmed)) {
      continue;
    }
    if (/^\s*\|/.test(trimmed)) {
      const cells = trimmed.replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => norm(c));
      for (const cell of cells) {
        if (cell.length > 0 && !fullHay.includes(cell)) {
          missing.push(`表格单元格缺失: ${cell.slice(0, 40)}`);
        }
      }
      continue;
    }
    const target = norm(stripListMarker(trimmed));
    if (target.length === 0) {
      continue;
    }
    if (!fullHay.includes(target)) {
      missing.push(`正文行缺失: ${trimmed.slice(0, 60)}`);
    }
  }
  if (missing.length > 0) {
    for (const m of missing.slice(0, 20)) {
      errors.push(m);
    }
    if (missing.length > 20) {
      errors.push(`...另有 ${missing.length - 20} 行缺失未列出`);
    }
  }

  console.log(`[verify] 规则版本: ${RULE_VERSION}`);
  console.log(`[verify] detail : ${args.detail}`);
  const strictCount = codeJudge.matched - splitNotes.length;
  console.log(
    `[verify] 代码块 : 源 ${codeJudge.strictFences.length} / JSON ${codeJudge.strictBlocks.length}（非 mermaid；严格逐字 ${strictCount} 段 + 可加性拆解 ${splitNotes.length} 段，还原率 ${codeJudge.matched}/${codeJudge.strictFences.length}）`
  );
  console.log(
    `[verify] mermaid : 源 ${codeJudge.mermaidFences.length} 段围栏 / JSON ${codeJudge.imageBlocks.length} 个 image 块` +
      (codeJudge.mermaidFences.length > 0 ? `（v2.1 豁免判定 ${codeJudge.mermaidPass ? 'PASS' : 'FAIL'}：image ≥ 围栏数）` : '（原文无 mermaid 围栏，不适用豁免）')
  );
  for (const s of splitNotes) {
    console.log(`[verify] 拆解豁免: 源[${s.fence}] ← JSON[${s.from}..${s.to}] 共 ${s.n} 块，以「${s.sep}」拼接逐字节恒等`);
  }
  console.log(`[verify] 标题   : 源 ${headings.filter((h) => h.level >= 2).length} / header 块 ${headerBlocks.length}`);
  console.log(`[verify] 正文行 : ${proseLines.length} 行全部检索完毕`);
  const stat = {};
  for (const b of blocks) {
    stat[b.type] = (stat[b.type] || 0) + 1;
  }
  console.log(`[verify] 块统计 : ${blocks.length} ${JSON.stringify(stat)}`);
  for (const n of notes) {
    console.log(`[verify] 提示   : ${n}`);
  }
  if (errors.length > 0) {
    console.log(`[verify] 结果   : FAIL (${errors.length})`);
    for (const e of errors) {
      console.log(`  - ${e}`);
    }
    process.exit(1);
  }
  console.log('[verify] 结果   : PASS');
}

if (process.argv.slice(2).includes('--self-test')) {
  selfTest();
} else {
  main();
}
