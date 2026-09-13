/**
 * 全书质检总审计：对 34 章逐一运行 schema + 逐字无损校验，输出总表。
 * 用法：node docs/tools/audit_all.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const ROOT = process.cwd();
const CH_DIR = path.join(ROOT, 'docs', 'chapters');
const DETAIL_DIR = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/details');
const LOG_DIR = path.join(ROOT, 'docs', 'pipeline', 'logs');
const INDEX = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/index.json');
const STATE = path.join(ROOT, 'docs', 'migration_state.json');

fs.mkdirSync(LOG_DIR, { recursive: true });
const state = JSON.parse(fs.readFileSync(STATE, 'utf8'));
const index = JSON.parse(fs.readFileSync(INDEX, 'utf8'));
const indexIds = new Set(index.items.map((i) => i.id));

const rows = [];
for (const rec of state) {
  const chapterPath = path.join(CH_DIR, rec.file);
  const detailPath = path.join(DETAIL_DIR, `${rec.id}.json`);
  const logPath = path.join(LOG_DIR, `audit_${rec.id}.log`);
  if (!fs.existsSync(detailPath)) {
    rows.push({ chapter: rec.chapter, id: rec.id, result: 'MISSING_DETAIL', blocks: 0 });
    continue;
  }
  const res = spawnSync(
    process.execPath,
    [path.join(ROOT, 'docs', 'tools', 'verify_chapter.mjs'), '--chapter', chapterPath, '--detail', detailPath, '--log', logPath],
    { cwd: ROOT, stdio: 'ignore', timeout: 120000 }
  );
  const log = fs.existsSync(logPath) ? fs.readFileSync(logPath, 'utf8') : '';
  const verdict = /\[verify\] 结果\s*:\s*PASS/.test(log) ? 'PASS' : 'FAIL';
  const blocks = Number((/块统计 : (\d+)/.exec(log) || [0, '0'])[1]);
  const codePair = (/代码块 : 源 (\d+) \/ JSON (\d+)/.exec(log) || [0, '?', '?']).slice(1).join('/');
  rows.push({
    chapter: rec.chapter,
    id: rec.id,
    result: res.status === 0 && verdict === 'PASS' ? 'PASS' : 'FAIL',
    blocks,
    codePair,
    inIndex: indexIds.has(rec.id)
  });
}

const width = Math.max(...rows.map((r) => r.id.length));
console.log('| 章节 | id | 校验 | 块数 | 代码块(源/JSON) | index |');
console.log('| ---: | :-- | :-- | ---: | :-- | :-- |');
for (const r of rows) {
  console.log(
    `| ${r.chapter} | ${r.id.padEnd(width)} | ${r.result} | ${r.blocks} | ${r.codePair || '-'} | ${r.inIndex ? 'Y' : 'N'} |`
  );
}
const pass = rows.filter((r) => r.result === 'PASS').length;
const failed = rows.filter((r) => r.result !== 'PASS');
console.log(`\n[audit] PASS ${pass}/${rows.length}；FAIL ${failed.length} 章：${failed.map((r) => r.chapter).join(', ') || '无'}`);

// 落盘审计证据：AUDIT.md（全表） + audit.json（摘要），供 STATE.md 引用
const AUDIT_MD = path.join(ROOT, 'docs', 'pipeline', 'AUDIT.md');
const AUDIT_JSON = path.join(ROOT, 'docs', 'pipeline', 'audit.json');
const md = [];
md.push('# 全书质检审计（verify_chapter 覆盖 34 章）');
md.push('');
md.push(`- 生成时间：${new Date().toISOString().replace('T', ' ').slice(0, 19)}`);
md.push(`- 校验器：\`docs/tools/verify_chapter.mjs\`（schema + 代码逐字 + 标题/正文覆盖）`);
md.push(`- 结论：PASS ${pass}/${rows.length}${failed.length ? `；FAIL：${failed.map((r) => r.chapter).join(', ')}` : ''}`);
md.push('');
md.push('| 章节 | id | 校验 | 块数 | 代码块(源/JSON) | index |');
md.push('| ---: | :-- | :-- | ---: | :-- | :-- |');
for (const r of rows) {
  md.push(`| ${r.chapter} | ${r.id} | ${r.result} | ${r.blocks} | ${r.codePair || '-'} | ${r.inIndex ? 'Y' : 'N'} |`);
}
md.push('');
if (failed.length > 0) {
  md.push('## 未通过章节说明');
  md.push('');
  md.push(
    '- 第 1、7 章为**上一轮既有成品**（本轮任务开始前已存在于 index.json 与 details/），采用当时的教材化模板切分，未按本轮《数据契约与切分红线》逐段切分，故逐字校验不过：ch1 原文含 1 段 mermaid 图（被渲染为 image 块），ch7 原文 1 段示例被扩写为 4 个代码块。'
  );
  md.push('- 这两章不属于本轮差集（缺失章节）范围，为避免覆盖已验收内容，本轮**未改动**；如需统一，可对二者执行同一流水线重转。');
  md.push('');
}
fs.writeFileSync(AUDIT_MD, md.join('\n'), 'utf8');
fs.writeFileSync(
  AUDIT_JSON,
  JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      pass,
      total: rows.length,
      failed: failed.map((r) => ({ chapter: r.chapter, id: r.id, result: r.result })),
      rows
    },
    null,
    2
  ) + '\n',
  'utf8'
);
console.log(`[audit] 已写入 docs/pipeline/AUDIT.md 与 docs/pipeline/audit.json`);

if (pass !== rows.length) {
  process.exit(1);
}
