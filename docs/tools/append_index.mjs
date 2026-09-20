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

/**
 * level 取值白名单（Cleanup-4 追加，非 v2.1 变更）。
 *
 * 背景：index.json 是本工程唯一随 App 打包发布的知识索引资产，但此前
 *      全链路无任何脚本校验其 level 取值 —— meta 侧有 run_pipeline.validateMeta
 *      与 check_meta.mjs 把关，details 侧有 verify_chapter.mjs 的 LEVELS 把关，
 *      唯独 index.json 只被「复制写入」（见下方 added 构造）而无校验。
 *      配合 App 侧 Cleanup-3 的 KnowledgeLevel 联合类型 + DataSource.isLevel，
 *      本校验补齐「构建期前置拦截」这一环（C3 裁决）。
 * 契约：与 entry/src/main/ets/models/knowledge/KnowledgeMetadata.ets 的
 *      KnowledgeLevel 联合类型、以及 RawFileAssetDataSource.isLevel 保持同一集合；
 *      新增难度档位时三处必须同步修改。
 */
const LEVEL_WHITELIST = ['Basic', 'Medium', 'Hard'];

/**
 * 校验 index.items 全量条目的 level 取值（Cleanup-4 追加，非 v2.1 变更）。
 *
 * 设计取舍（D5 裁决：全量校验）：
 *  - 不区分「新追加」与「存量」，一律校验 —— 存量条目同样随包发布，
 *    同样受 KnowledgeLevel 约束，漏检会导致 App 侧整库 ERROR 态。
 *  - 本函数只做判定与错误收集，不修改 items、不改变调用方的控制流；
 *    失败时由调用方抛出，复用 run_pipeline.mjs 既有的 CRITICAL 熔断语义。
 * @param {object[]} items index.items 数组
 * @returns {string[]} 非法条目描述数组；全部合法时为空数组
 */
function collectInvalidLevels(items) {
  const invalid = [];
  for (const item of items) {
    if (!item || typeof item.id !== 'string') {
      invalid.push('<缺少 id 的条目>');
      continue;
    }
    if (!LEVEL_WHITELIST.includes(item.level)) {
      invalid.push(`${item.id}=${JSON.stringify(item.level)}`);
    }
  }
  return invalid;
}

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

  // Cleanup-4 追加（非 v2.1 变更）：level 白名单全量校验。
  // 位置说明：置于任何写盘动作之前，非法数据绝不落盘。
  //      本步同时覆盖「本轮新增条目」与「存量条目」（D5 裁决），
  //      且早于下方 push —— 新增条目的非法 level 在此先被捕获。
  const invalidLevels = collectInvalidLevels(index.items);
  if (invalidLevels.length > 0) {
    throw new Error(`index.json 存在 level 非法条目（合法值: ${LEVEL_WHITELIST.join(' / ')}）: ${invalidLevels.join(', ')}`);
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
