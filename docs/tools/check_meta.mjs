/**
 * meta 元数据合规性检查器
 * 用法：node docs/tools/check_meta.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const META_DIR = path.join(ROOT, 'docs', 'tools', 'meta');
const STATE = path.join(ROOT, 'docs', 'migration_state.json');

const state = JSON.parse(fs.readFileSync(STATE, 'utf8'));
const files = fs.existsSync(META_DIR) ? fs.readdirSync(META_DIR).filter((f) => f.endsWith('.meta.json')) : [];

let ok = 0;
const problems = [];

for (const rec of state) {
  const metaPath = path.join(META_DIR, `${rec.id}.meta.json`);
  if (!files.includes(`${rec.id}.meta.json`)) {
    problems.push(`ch${rec.chapter} ${rec.id}: 缺少 meta 文件`);
    continue;
  }
  let meta;
  try {
    meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
  } catch (e) {
    problems.push(`ch${rec.chapter} ${rec.id}: JSON 解析失败 ${e.message}`);
    continue;
  }
  const keys = Object.keys(meta).sort().join(',');
  if (keys !== 'category,id,level,summary,tags,title') {
    problems.push(`ch${rec.chapter} ${rec.id}: 字段集合非法 [${keys}]`);
    continue;
  }
  if (meta.id !== rec.id) problems.push(`ch${rec.chapter} ${rec.id}: id 不一致 ${meta.id}`);
  if (meta.title !== rec.title) problems.push(`ch${rec.chapter} ${rec.id}: title 不一致 ${meta.title}`);
  if (meta.category !== rec.category) problems.push(`ch${rec.chapter} ${rec.id}: category 不一致 ${meta.category}`);
  if (!['Basic', 'Medium', 'Hard'].includes(meta.level)) problems.push(`ch${rec.chapter} ${rec.id}: level 非法 ${meta.level}`);
  if (!Array.isArray(meta.tags) || meta.tags.some((t) => typeof t !== 'string' || !t.trim())) {
    problems.push(`ch${rec.chapter} ${rec.id}: tags 非法`);
  } else if (new Set(meta.tags).size !== meta.tags.length) {
    problems.push(`ch${rec.chapter} ${rec.id}: tags 存在重复项`);
  } else if (meta.tags.length < 5 || meta.tags.length > 12) {
    problems.push(`ch${rec.chapter} ${rec.id}: tags 数量 ${meta.tags.length} 超出 5~12`);
  }
  if (typeof meta.summary !== 'string' || meta.summary.length < 15 || meta.summary.length > 200) {
    problems.push(`ch${rec.chapter} ${rec.id}: summary 长度异常 (${typeof meta.summary === 'string' ? meta.summary.length : 'n/a'})`);
  }
  if (!problems.some((p) => p.startsWith(`ch${rec.chapter} `))) {
    ok++;
  }
}

console.log(`[meta] 合规 meta：${ok}/${state.length}`);
if (problems.length > 0) {
  console.log(`[meta] 异常 ${problems.length} 项：`);
  for (const p of problems) console.log(`  - ${p}`);
  process.exit(1);
}
console.log('[meta] 全部 meta 通过合规检查');
