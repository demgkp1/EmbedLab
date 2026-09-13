/**
 * EmbedLab index.json 归一化追加器（阶段一写盘层 · 幂等）
 *
 * 契约：
 *  1. 读取磁盘上的 index.json 真实内容；
 *  2. 按 id 去重（同 id 以最后一次写入为准）；
 *  3. 按章节号升序排序（章节号从 title 提取），同号再按 id 中文序；
 *  4. 写回文件。
 *
 * 用法：
 *   node docs/tools/append_index.mjs --meta docs/tools/meta/{id}.meta.json --index entry/src/main/resources/rawfile/database/knowledge/index.json
 *   node docs/tools/append_index.mjs --normalize-only --index entry/src/main/resources/rawfile/database/knowledge/index.json
 */
import fs from 'node:fs';
import crypto from 'node:crypto';

/** 从标题中提取章节号；无法提取时排在最后 */
function extractChapterNo(title) {
  const s = String(title || '').trim();
  const m = s.match(/^(?:第\s*)?(\d+)(?:\s*[章节.、]|\s|$)/);
  if (m) return Number(m[1]);
  const n = Number.parseInt(s, 10);
  return Number.isFinite(n) ? n : Number.MAX_SAFE_INTEGER;
}

/** 去重 + 按章节号升序归一化 */
function normalizeIndex(items) {
  const dedup = new Map();
  for (const item of items) {
    if (item && item.id) dedup.set(item.id, item);
  }
  return Array.from(dedup.values()).sort((a, b) => {
    const na = extractChapterNo(a.title);
    const nb = extractChapterNo(b.title);
    if (na !== nb) return na - nb;
    return String(a.id).localeCompare(String(b.id), 'zh-Hans-CN');
  });
}

function parseArgs(argv) {
  const args = { flags: new Set() };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--normalize-only') {
      args.flags.add('normalize-only');
      continue;
    }
    if (a.startsWith('--')) {
      args[a.slice(2)] = argv[i + 1];
      i++;
    }
  }
  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.index) {
    throw new Error('用法: --index <index.json> [--meta <meta.json> | --normalize-only]');
  }

  const before = fs.readFileSync(args.index, 'utf8');
  const index = JSON.parse(before);
  if (!Array.isArray(index.items)) {
    throw new Error('index.json 结构异常: items 不是数组');
  }

  const originalCount = index.items.length;
  let added = null;

  if (!args.flags.has('normalize-only')) {
    if (!args.meta) {
      throw new Error('缺少 --meta（或使用 --normalize-only）');
    }
    const meta = JSON.parse(fs.readFileSync(args.meta, 'utf8'));
    added = {
      id: meta.id,
      title: meta.title,
      category: meta.category,
      level: meta.level,
      tags: meta.tags,
      summary: meta.summary
    };
    const existed = index.items.some((it) => it.id === added.id);
    index.items.push(added);
    console.log(`[index] ${existed ? '覆盖已存在条目' : '追加新条目'} id=${added.id}`);
  }

  index.items = normalizeIndex(index.items);
  const after = JSON.stringify(index, null, 2) + '\n';
  const changed = after !== before;
  if (changed) {
    fs.writeFileSync(args.index, after, 'utf8');
  }

  const order = index.items.map((it) => extractChapterNo(it.title));
  const ascending = order.every((n, i) => i === 0 || order[i - 1] <= n);
  console.log(
    `[index] items ${originalCount} -> ${index.items.length} | 变更=${changed ? 'Y' : 'N'} | 章节号升序=${ascending ? 'Y' : 'N'}`
  );
  console.log(`[index] 章节顺序: ${order.join(', ')}`);
  console.log(`[index] sha256=${crypto.createHash('sha256').update(after).digest('hex').slice(0, 16)}`);
}

// 作为库被 run_pipeline.mjs import 时不执行 CLI 逻辑
if (process.argv.slice(2).includes('--index')) {
  main();
}

export { extractChapterNo, normalizeIndex };
