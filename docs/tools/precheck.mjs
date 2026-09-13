/**
 * EmbedLab 流水线预检（阶段 0）
 *
 * 职责：以磁盘为唯一事实来源，扫描章节文件、index.json、details 目录，计算待转差集。
 * 用法：node docs/tools/precheck.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const CH_DIR = path.join(ROOT, 'docs', 'chapters');
const INDEX = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/index.json');
const DETAIL_DIR = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/details');
const META_DIR = path.join(ROOT, 'docs', 'tools', 'meta');
const STATE = path.join(ROOT, 'docs', 'migration_state.json');

export function precheck() {
  const files = fs.existsSync(CH_DIR)
    ? fs.readdirSync(CH_DIR).filter((f) => f.endsWith('.md')).sort()
    : [];
  const state = JSON.parse(fs.readFileSync(STATE, 'utf8'));
  const index = JSON.parse(fs.readFileSync(INDEX, 'utf8'));
  const indexIds = new Set(index.items.map((i) => i.id));
  const detailIds = new Set(
    fs.existsSync(DETAIL_DIR)
      ? fs.readdirSync(DETAIL_DIR).filter((f) => f.endsWith('.json')).map((f) => f.replace(/\.json$/, ''))
      : []
  );
  const metaIds = new Set(
    fs.existsSync(META_DIR)
      ? fs.readdirSync(META_DIR).filter((f) => f.endsWith('.meta.json')).map((f) => f.replace(/\.meta\.json$/, ''))
      : []
  );

  const rows = state.map((r) => ({
    chapter: r.chapter,
    file: r.file,
    id: r.id,
    title: r.title,
    category: r.category,
    fileExists: files.includes(r.file),
    inIndex: indexIds.has(r.id),
    hasDetail: detailIds.has(r.id),
    hasMeta: metaIds.has(r.id)
  }));

  const pending = rows.filter((r) => !r.inIndex || !r.hasDetail);
  return { files, rows, pending, indexIds, detailIds, metaIds, index };
}

if (process.argv.slice(2).includes('--print')) {
  const { files, rows, pending } = precheck();
  console.log(`[precheck] 章节文件 ${files.length} 个`);
  console.log(`[precheck] 已完成 ${rows.length - pending.length} 章 / 待转 ${pending.length} 章`);
  for (const p of pending) {
    console.log(
      `  ch${String(p.chapter).padStart(2, '0')} | ${p.file} | ${p.id} | meta=${p.hasMeta ? 'Y' : 'N'} | ${p.title} | ${p.category}`
    );
  }
}
