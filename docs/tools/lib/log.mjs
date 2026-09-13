/**
 * 流水线日志工具：把子脚本的 console 输出同时落到日志文件。
 * 说明：受限沙箱下 Node 子进程无法使用管道 stdio 捕获输出，故由子进程自行落盘日志。
 */
import fs from 'node:fs';
import path from 'node:path';

const buffer = [];
const original = console.log;

/** 开始记录：logPath 为空则退化为纯控制台输出 */
export function startLog(logPath) {
  if (!logPath) {
    return;
  }
  console.log = (...args) => {
    const line = args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' ');
    buffer.push(line);
    original(line);
  };
  process.on('exit', () => {
    try {
      fs.mkdirSync(path.dirname(logPath), { recursive: true });
      fs.writeFileSync(logPath, buffer.join('\n') + '\n', 'utf8');
    } catch (e) {
      original(`[log] 写日志失败: ${e.message}`);
    }
  });
}
