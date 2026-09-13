/**
 * EmbedLab 无人值守数据转换流水线（阶段 0-3 编排器）
 *
 * 阶段 0 预检：扫描 docs/chapters/*.md、index.json、details/、meta/，生成待转清单并写入 docs/pipeline/STATE.md
 * 阶段 1 单章循环：md2blocks -> verify_chapter -> append_index（每章结果落到 STATE.md 与 logs/）
 * 阶段 2 熔断：单章重试 1 次仍失败则记 FAIL 并继续；连续 3 章失败立即停机；append_index 失败按 CRITICAL 立即停机
 * 阶段 3 报告：汇总成功/失败/索引顺序
 *
 * 用法：
 *   node docs/tools/run_pipeline.mjs --precheck-only     # 仅阶段 0
 *   node docs/tools/run_pipeline.mjs                     # 全流程无人值守执行
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import { precheck } from './precheck.mjs';
import { extractChapterNo } from './append_index.mjs';

const ROOT = process.cwd();
const CH_DIR = path.join(ROOT, 'docs', 'chapters');
const META_DIR = path.join(ROOT, 'docs', 'tools', 'meta');
const INDEX = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/index.json');
const DETAIL_DIR = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/details');
const STATE_MD = path.join(ROOT, 'docs', 'pipeline', 'STATE.md');
const RUN_LOG = path.join(ROOT, 'docs', 'pipeline', 'RUN_LOG.md');
const LOG_DIR = path.join(ROOT, 'docs', 'pipeline', 'logs');
const STATE_JSON = path.join(ROOT, 'docs', 'migration_state.json');
const MAX_CONSECUTIVE_FAIL = 3;
const CHILD_TIMEOUT_MS = 180000;

const precheckOnly = process.argv.slice(2).includes('--precheck-only');
/** --only 3,4,5 —— 显式重跑指定章节（用于幂等性验证与台账重建，不触碰未列出的章节） */
const onlyArgIdx = process.argv.indexOf('--only');
const onlySet =
  onlyArgIdx >= 0 && process.argv[onlyArgIdx + 1]
    ? new Set(process.argv[onlyArgIdx + 1].split(',').map((s) => Number(s.trim())).filter((n) => Number.isFinite(n)))
    : null;

const sha256 = (text) => crypto.createHash('sha256').update(text).digest('hex');
const now = () => new Date().toISOString().replace('T', ' ').slice(0, 19);

/** 校验 meta 文件是否为合规的六字段元数据 */
function validateMeta(metaPath, row) {
  if (!fs.existsSync(metaPath)) {
    return `缺少 meta 文件: ${path.relative(ROOT, metaPath)}`;
  }
  let meta;
  try {
    meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
  } catch (e) {
    return `meta JSON 解析失败: ${e.message}`;
  }
  const keys = Object.keys(meta).sort().join(',');
  if (keys !== 'category,id,level,summary,tags,title') {
    return `meta 字段集合非法: ${keys}`;
  }
  if (meta.id !== row.id) return `meta.id 与状态机不一致: ${meta.id} ≠ ${row.id}`;
  if (meta.title !== row.title) return `meta.title 与状态机不一致: ${meta.title} ≠ ${row.title}`;
  if (meta.category !== row.category) return `meta.category 与状态机不一致: ${meta.category} ≠ ${row.category}`;
  if (!['Basic', 'Medium', 'Hard'].includes(meta.level)) return `meta.level 非法: ${meta.level}`;
  if (!Array.isArray(meta.tags) || meta.tags.length < 3 || meta.tags.some((t) => typeof t !== 'string' || t.length === 0)) {
    return 'meta.tags 必须为非空字符串数组（≥3 项）';
  }
  if (typeof meta.summary !== 'string' || meta.summary.length < 10) return 'meta.summary 过短或类型非法';
  return null;
}

function runChild(script, args) {
  const res = spawnSync(process.execPath, [path.join(ROOT, 'docs', 'tools', script), ...args], {
    cwd: ROOT,
    stdio: 'inherit',
    timeout: CHILD_TIMEOUT_MS
  });
  if (res.error) {
    return { ok: false, reason: res.error.message, code: -1 };
  }
  return { ok: res.status === 0, reason: res.status === 0 ? '' : `exit=${res.status}`, code: res.status };
}

function blockStats(detailPath) {
  try {
    const item = JSON.parse(fs.readFileSync(detailPath, 'utf8'));
    const stat = {};
    for (const b of item.contentBlocks) {
      stat[b.type] = (stat[b.type] || 0) + 1;
    }
    return { total: item.contentBlocks.length, stat };
  } catch (e) {
    return { total: 0, stat: { error: e.message } };
  }
}

function renderStateMd({ phase, results, ledger, stopped, stopReason, pendingList, indexItems, pre }) {
  const lines = [];
  lines.push('# EmbedLab 数据转换流水线 · STATE');
  lines.push('');
  lines.push('> 本文件由 `docs/tools/run_pipeline.mjs` 依据磁盘真实状态自动生成，严禁手工伪造。');
  lines.push('');
  lines.push(`- 生成时间：${now()}`);
  lines.push(`- 章节源目录：\`docs/chapters/*.md\`（${pre.files.length} 个文件）`);
  lines.push('- 索引：`entry/src/main/resources/rawfile/database/knowledge/index.json`');
  lines.push('- 详情：`entry/src/main/resources/rawfile/database/knowledge/details/*.json`');
  lines.push('- 元数据：`docs/tools/meta/*.meta.json`');
  lines.push('- 状态机：`docs/migration_state.json`');
  lines.push(`- 熔断阈值：连续 ${MAX_CONSECUTIVE_FAIL} 章失败立即停机`);
  lines.push('');
  lines.push('## 一、阶段 0 预检（本次运行）');
  lines.push('');
  lines.push(`- 扫描章节文件：${pre.files.length}`);
  lines.push(`- index.json 条目：${indexItems.length}`);
  lines.push(`- 磁盘已完成章节：${pre.rows.length - pendingList.length}`);
  lines.push(`- 本次待转清单：${pendingList.length} 章${pendingList.length > 0 ? ' → ' + pendingList.map((p) => p.chapter).join(', ') : '（无，幂等空转）'}`);
  lines.push('');
  lines.push('| 章节 | 文件 | id | detail | index | meta | 磁盘结论 |');
  lines.push('| ---: | :--- | :--- | :---: | :---: | :---: | :--- |');
  for (const r of pre.rows) {
    const verdict = r.inIndex && r.hasDetail ? 'DONE' : 'PENDING';
    lines.push(
      `| ${r.chapter} | ${r.file} | ${r.id} | ${r.hasDetail ? 'Y' : 'N'} | ${r.inIndex ? 'Y' : 'N'} | ${r.hasMeta ? 'Y' : 'N'} | ${verdict} |`
    );
  }
  lines.push('');
  lines.push('## 二、阶段 1 单章执行结果（累计台账）');
  lines.push('');
  const ledgerEntries = Object.values(ledger).sort((a, b) => a.chapter - b.chapter);
  if (ledgerEntries.length === 0) {
    lines.push(phase === 'precheck' ? '_预检模式：台账为空（尚无单章执行记录）。_' : '_无待转章节，本次未执行任何转换（幂等空转）。_');
  } else {
    lines.push(
      phase === 'precheck'
        ? '_预检模式：下表为累计台账（最近一次各章执行结果）。_'
        : `_本次运行转换 ${results.filter((r) => r.status === 'SUCCESS').length} 章；下表为累计台账（最近一次各章执行结果）。_`
    );
    lines.push('');
    lines.push('| 章节 | id | md2blocks | verify | append_index | blocks | 最近更新 | 备注 |');
    lines.push('| ---: | :--- | :--- | :--- | :--- | ---: | :--- | :--- |');
    for (const r of ledgerEntries) {
      lines.push(
        `| ${r.chapter} | ${r.id} | ${r.md2blocks} | ${r.verify} | ${r.appendIndex} | ${r.blocks} | ${r.updatedAt} | ${r.note || '-'} |`
      );
    }
  }
  lines.push('');
  lines.push('## 三、阶段 2 熔断与异常');
  lines.push('');
  lines.push(`- 是否触发熔断：${stopped ? '是' : '否'}`);
  lines.push(`- 停机原因：${stopReason || '无'}`);
  const failed = results.filter((r) => r.status === 'FAIL');
  lines.push(`- 本次失败章节：${failed.length === 0 ? '无' : failed.map((r) => `${r.chapter}(${r.note})`).join('；')}`);
  lines.push('');
  lines.push('## 四、阶段 3 统计与验收');
  lines.push('');
  const doneRows = pre.rows.filter((r) => r.inIndex && r.hasDetail);
  const order = indexItems.map((i) => extractChapterNo(i.title));
  const ascending = order.every((n, i) => i === 0 || order[i - 1] <= n);
  const ids = indexItems.map((i) => i.id);
  lines.push(`- 磁盘已完成：${doneRows.length}/${pre.rows.length} 章`);
  lines.push(`- index.json：${indexItems.length} 条，章节号顺序 ${order.join(', ')}`);
  lines.push(`- 章节号严格升序：${ascending ? 'PASS' : 'FAIL'}`);
  lines.push(`- 重复 id：${ids.length - new Set(ids).size === 0 ? 'PASS（无重复）' : 'FAIL'}`);
  lines.push(`- index sha256：${sha256(fs.readFileSync(INDEX, 'utf8'))}`);
  const auditPath = path.join(ROOT, 'docs', 'pipeline', 'audit.json');
  if (fs.existsSync(auditPath)) {
    const a = JSON.parse(fs.readFileSync(auditPath, 'utf8'));
    const failedIds = a.failed.map((f) => f.chapter).join(', ');
    lines.push(
      `- 全书质检审计（verify_chapter × ${a.total}）：PASS ${a.pass}/${a.total}${failedIds ? `，未通过：${failedIds}（详见 docs/pipeline/AUDIT.md）` : ''}，生成于 ${String(a.generatedAt).replace('T', ' ').slice(0, 19)}`
    );
  } else {
    lines.push('- 全书质检审计：尚未执行（`node docs/tools/audit_all.mjs`）');
  }
  lines.push('');
  lines.push('### 证据日志');
  lines.push('');
  lines.push(`- 单章日志目录：\`docs/pipeline/logs/\`（\`{id}.md2blocks.log\` / \`{id}.verify.log\`）`);
  lines.push('- 运行历史：`docs/pipeline/RUN_LOG.md`');
  lines.push('');
  return lines.join('\n');
}

function main() {
  fs.mkdirSync(path.dirname(STATE_MD), { recursive: true });
  fs.mkdirSync(LOG_DIR, { recursive: true });

  const ledgerPath = path.join(ROOT, 'docs', 'pipeline', 'results.json');
  const ledger = fs.existsSync(ledgerPath) ? JSON.parse(fs.readFileSync(ledgerPath, 'utf8')) : {};

  const pre = precheck();
  const stateJson = JSON.parse(fs.readFileSync(STATE_JSON, 'utf8'));
  const rowByNumber = new Map(pre.rows.map((r) => [r.chapter, r]));
  const baseList = onlySet ? pre.rows.filter((r) => onlySet.has(r.chapter)) : pre.pending;
  const pendingList = baseList
    .map((p) => ({ ...p, title: rowByNumber.get(p.chapter).title, category: rowByNumber.get(p.chapter).category }))
    .sort((a, b) => a.chapter - b.chapter);

  const readIndexItems = () => JSON.parse(fs.readFileSync(INDEX, 'utf8')).items;

  console.log(`[pipeline] 阶段 0 预检：章节 ${pre.files.length} 个，待转 ${pendingList.length} 章`);
  for (const p of pendingList) {
    console.log(`  - ch${String(p.chapter).padStart(2, '0')} ${p.id} meta=${p.hasMeta ? 'Y' : 'N'}`);
  }

  if (precheckOnly) {
    fs.writeFileSync(
      STATE_MD,
      renderStateMd({
        phase: 'precheck',
        results: [],
        ledger,
        stopped: false,
        stopReason: '',
        pendingList,
        indexItems: readIndexItems(),
        pre
      }),
      'utf8'
    );
    console.log(`[pipeline] 预检完成，已写入 ${path.relative(ROOT, STATE_MD)}`);
    return;
  }

  /** @type {any[]} */
  const results = [];
  let consecutiveFail = 0;
  let stopped = false;
  let stopReason = '';

  for (const row of pendingList) {
    const metaPath = path.join(META_DIR, `${row.id}.meta.json`);
    const detailPath = path.join(DETAIL_DIR, `${row.id}.json`);
    const chapterPath = path.join(CH_DIR, row.file);
    const md2blocksLog = path.join(LOG_DIR, `${row.id}.md2blocks.log`);
    const verifyLog = path.join(LOG_DIR, `${row.id}.verify.log`);
    const record = {
      chapter: row.chapter,
      id: row.id,
      md2blocks: '-',
      verify: '-',
      appendIndex: '-',
      blocks: 0,
      note: '',
      status: 'PENDING'
    };
    console.log(`\n[pipeline] ===== 第 ${row.chapter} 章 ${row.id} =====`);

    // 前置：meta 合规性（元数据缺失/非法时不得伪造产出）
    const metaErr = validateMeta(metaPath, row);
    if (metaErr) {
      record.note = metaErr;
      record.status = 'FAIL';
      results.push(record);
      consecutiveFail++;
      console.log(`[pipeline] FAIL(meta)：${metaErr}`);
      writeRunLog(row, record, pre);
      if (consecutiveFail >= MAX_CONSECUTIVE_FAIL) {
        stopped = true;
        stopReason = `连续 ${consecutiveFail} 章失败，触发熔断`;
        break;
      }
      continue;
    }

    // 步骤 1：md2blocks（失败重试 1 次）
    let step1 = runChild('md2blocks.mjs', [
      '--chapter', chapterPath,
      '--meta', metaPath,
      '--out', detailPath,
      '--log', md2blocksLog
    ]);
    if (!step1.ok) {
      console.log(`[pipeline] md2blocks 第 1 次失败（${step1.reason}），重试 1 次`);
      step1 = runChild('md2blocks.mjs', [
        '--chapter', chapterPath,
        '--meta', metaPath,
        '--out', detailPath,
        '--log', md2blocksLog
      ]);
    }
    if (!step1.ok) {
      record.md2blocks = `FAIL(${step1.reason})`;
      record.note = `md2blocks 重试后仍失败: ${step1.reason}`;
      record.status = 'FAIL';
      results.push(record);
      consecutiveFail++;
      console.log(`[pipeline] FAIL(md2blocks)：${record.note}`);
      writeRunLog(row, record, pre);
      if (consecutiveFail >= MAX_CONSECUTIVE_FAIL) {
        stopped = true;
        stopReason = `连续 ${consecutiveFail} 章失败，触发熔断`;
        break;
      }
      continue;
    }
    record.md2blocks = 'PASS';
    const stats = blockStats(detailPath);
    record.blocks = stats.total;

    // 步骤 2：verify_chapter
    const step2 = runChild('verify_chapter.mjs', ['--chapter', chapterPath, '--detail', detailPath, '--log', verifyLog]);
    if (!step2.ok) {
      record.verify = `FAIL(${step2.reason})`;
      record.note = `verify_chapter 未通过: ${step2.reason}，详见 docs/pipeline/logs/${row.id}.verify.log`;
      record.status = 'FAIL';
      results.push(record);
      consecutiveFail++;
      console.log(`[pipeline] FAIL(verify)：${record.note}`);
      writeRunLog(row, record, pre);
      if (consecutiveFail >= MAX_CONSECUTIVE_FAIL) {
        stopped = true;
        stopReason = `连续 ${consecutiveFail} 章失败，触发熔断`;
        break;
      }
      continue;
    }
    record.verify = 'PASS';

    // 步骤 3：append_index（失败 = CRITICAL，立即停机）
    const step3 = runChild('append_index.mjs', ['--meta', metaPath, '--index', INDEX]);
    if (!step3.ok) {
      record.appendIndex = `CRITICAL(${step3.reason})`;
      record.note = `index.json 写入失败: ${step3.reason}`;
      record.status = 'CRITICAL';
      results.push(record);
      stopped = true;
      stopReason = `CRITICAL：index.json 写入失败（第 ${row.chapter} 章）`;
      console.log(`[pipeline] CRITICAL：${record.note}`);
      writeRunLog(row, record, pre);
      break;
    }
    record.appendIndex = 'PASS';
    record.status = 'SUCCESS';
    record.note = `blocks=${stats.total} ${JSON.stringify(stats.stat)}`;
    consecutiveFail = 0;
    results.push(record);
    console.log(`[pipeline] 第 ${row.chapter} 章转换成功：${record.note}`);
    writeRunLog(row, record, pre);
  }

  // 合并本次运行结果到累计台账（STATE.md 据此渲染，重跑不会丢失历史）
  for (const r of results) {
    ledger[r.id] = { ...r, updatedAt: now() };
  }
  fs.writeFileSync(ledgerPath, JSON.stringify(ledger, null, 2) + '\n', 'utf8');

  // 同步状态机：把本轮成功章节标记 done
  for (const r of results.filter((x) => x.status === 'SUCCESS')) {
    const rec = stateJson.find((s) => s.chapter === r.chapter);
    if (rec) {
      rec.status = 'done';
      delete rec.note;
    }
  }
  fs.writeFileSync(STATE_JSON, JSON.stringify(stateJson, null, 2) + '\n', 'utf8');

  const indexItems = readIndexItems();
  fs.writeFileSync(
    STATE_MD,
    renderStateMd({ phase: 'run', results, ledger, stopped, stopReason, pendingList, indexItems, pre }),
    'utf8'
  );

  const success = results.filter((r) => r.status === 'SUCCESS');
  const failed = results.filter((r) => r.status === 'FAIL');
  const critical = results.filter((r) => r.status === 'CRITICAL');
  console.log('\n==================== 数据流水线执行摘要 ====================');
  console.log(`成功 ${success.length} 章：${success.map((r) => r.chapter).join(', ') || '无'}`);
  console.log(`失败 ${failed.length} 章：${failed.map((r) => `${r.chapter}(${r.note})`).join('；') || '无'}`);
  console.log(`CRITICAL ${critical.length} 章：${critical.map((r) => r.chapter).join(', ') || '无'}`);
  console.log(`熔断：${stopped ? '是 - ' + stopReason : '否'}`);
  console.log(`index.json 章节顺序：${indexItems.map((i) => extractChapterNo(i.title)).join(', ')}`);
  console.log(`STATE.md：${path.relative(ROOT, STATE_MD)}`);
  console.log('==========================================================');

  if (critical.length > 0) {
    process.exit(3);
  }
  if (stopped) {
    process.exit(2);
  }
}

function writeRunLog(row, record, pre) {
  const lines = [
    `- ${now()} | ch${String(row.chapter).padStart(2, '0')} | ${row.id} | ${record.status} | md2blocks=${record.md2blocks} verify=${record.verify} index=${record.appendIndex} blocks=${record.blocks} | ${record.note || '-'} | 磁盘完成 ${pre.rows.filter((r) => r.inIndex && r.hasDetail).length}/${pre.rows.length}`
  ];
  if (!fs.existsSync(RUN_LOG)) {
    fs.writeFileSync(
      RUN_LOG,
      '# 流水线运行历史（append-only）\n\n| 时间 | 章节 | id | 结果 | 步骤 | 明细 | 磁盘进度 |\n| :--- | ---: | :--- | :--- | :--- | :--- | :--- |\n',
      'utf8'
    );
  }
  fs.appendFileSync(
    RUN_LOG,
    `| ${now()} | ${row.chapter} | ${row.id} | ${record.status} | md2blocks=${record.md2blocks} / verify=${record.verify} / index=${record.appendIndex} | blocks=${record.blocks} ${record.note || ''} | ${pre.rows.filter((r) => r.inIndex && r.hasDetail).length}/${pre.rows.length} |\n`,
    'utf8'
  );
}

main();
