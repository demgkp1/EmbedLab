/**
 * meta 回填器：对已完成章节（上一轮已导入 index.json 的条目）补齐 docs/tools/meta/{id}.meta.json，
 * 使流水线元数据目录与索引保持一一对应（内容直接取自 index.json，零臆造）。
 * 用法：node docs/tools/backfill_meta.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const META_DIR = path.join(ROOT, 'docs', 'tools', 'meta');
const INDEX = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/index.json');
const STATE = path.join(ROOT, 'docs', 'migration_state.json');

const index = JSON.parse(fs.readFileSync(INDEX, 'utf8'));
const state = JSON.parse(fs.readFileSync(STATE, 'utf8'));
fs.mkdirSync(META_DIR, { recursive: true });

let created = 0;
for (const rec of state) {
  const metaPath = path.join(META_DIR, `${rec.id}.meta.json`);
  if (fs.existsSync(metaPath)) {
    continue;
  }
  const item = index.items.find((i) => i.id === rec.id);
  if (!item) {
    console.log(`[backfill] ch${rec.chapter} ${rec.id}: index 中无条目，跳过`);
    continue;
  }
  const meta = {
    id: item.id,
    title: item.title,
    category: item.category,
    level: item.level,
    tags: item.tags,
    summary: item.summary
  };
  fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n', 'utf8');
  console.log(`[backfill] 由 index.json 回填 ch${rec.chapter} -> ${path.relative(ROOT, metaPath)}`);
  created++;
}
console.log(`[backfill] 新增 ${created} 个 meta 文件`);
