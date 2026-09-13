/**
 * EmbedLab 迁移状态机推进器（阶段二状态层）
 *
 * 职责：读取 docs/migration_state.json，把指定章节置为 done，并输出下一个 pending 章节。
 * 用法：node docs/tools/mark_done.mjs --chapter 2 --state docs/migration_state.json
 */
import fs from 'node:fs';

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

const args = parseArgs(process.argv.slice(2));
if (!args.chapter || !args.state) {
  throw new Error('用法: --chapter <n> --state <migration_state.json>');
}

const target = Number(args.chapter);
const state = JSON.parse(fs.readFileSync(args.state, 'utf8'));
const record = state.find((s) => s.chapter === target);
if (!record) {
  throw new Error(`状态文件中不存在第 ${target} 章`);
}

record.status = 'done';
delete record.note;
fs.writeFileSync(args.state, JSON.stringify(state, null, 2) + '\n', 'utf8');

const done = state.filter((s) => s.status === 'done').length;
const next = state.find((s) => s.status === 'pending');
console.log(`[state] 第 ${target} 章 -> done（${record.file} / ${record.id}）`);
console.log(`[state] 进度 ${done}/${state.length}`);
console.log(
  `[state] 下一章 ${next ? `第 ${next.chapter} 章 -> ${next.file} (${next.id})` : '无（全部完成）'}`
);
