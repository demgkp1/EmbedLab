/**
 * EmbedLab 阶段 2 数据改写器：mermaid code 块 → image 块，并同步 images[] 字段
 *
 * 契约（架构师裁决）：
 *   1. 输出目录：entry/src/main/resources/rawfile/database/images/diagrams/
 *   2. 命名：{id}_diagram.png
 *   3. JSON 引用："content": "database/images/diagrams/{id}_diagram.png"
 *   4. images: string[] = 该章所有 image 块的 content（去重，顺序与 contentBlocks 中 image 块出现顺序一致）
 *
 * 行为：
 *   - 对每章，把 contentBlocks 中 type==='code' 且 language==='mermaid' 的块**原位**替换为
 *     { "type": "image", "content": "database/images/diagrams/{id}_diagram.png" }（删除 language 键）；
 *   - 其余块（text / header / warning / 非 mermaid code）一律原样保留；
 *   - 必先校验对应 PNG 文件存在，缺失则该章报错跳过（严禁写入指向不存在资产的路径）；
 *   - 幂等：已转换或无需转换时输出 变更=N，不重写文件。
 *
 * 用法：
 *   node docs/tools/apply_diagram_images.mjs --dry-run
 *   node docs/tools/apply_diagram_images.mjs
 */
import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();
const DETAIL_DIR = path.join(ROOT, 'entry/src/main/resources/rawfile/database/knowledge/details');
const PNG_DIR = path.join(ROOT, 'entry/src/main/resources/rawfile/database/images/diagrams');
const STATE = path.join(ROOT, 'docs/migration_state.json');

const dryRun = process.argv.slice(2).includes('--dry-run');
const state = JSON.parse(fs.readFileSync(STATE, 'utf8'));

let converted = 0;
let imagesUpdated = 0;
let unchanged = 0;
const problems = [];
const rows = [];

for (const rec of state) {
  const detailPath = path.join(DETAIL_DIR, `${rec.id}.json`);
  if (!fs.existsSync(detailPath)) {
    problems.push(`ch${rec.chapter} ${rec.id}: detail 文件缺失`);
    continue;
  }
  const before = fs.readFileSync(detailPath, 'utf8');
  const item = JSON.parse(before);
  const relPath = `database/images/diagrams/${rec.id}_diagram.png`;
  const absPath = path.join(PNG_DIR, `${rec.id}_diagram.png`);

  let mermaidBlocks = 0;
  item.contentBlocks = item.contentBlocks.map((b) => {
    if (b.type === 'code' && b.language === 'mermaid') {
      mermaidBlocks++;
      if (!fs.existsSync(absPath)) {
        problems.push(`ch${rec.chapter} ${rec.id}: mermaid 块存在但缺少位图 ${relPath}（已跳过该块替换）`);
        return b;
      }
      // 原位替换为 image 块：仅保留 type / content 两键
      return { type: 'image', content: relPath };
    }
    return b;
  });

  // images[] = 所有 image 块 content 去重（保持出现顺序）
  const imageContents = [];
  for (const b of item.contentBlocks) {
    if (b.type === 'image' && typeof b.content === 'string' && !imageContents.includes(b.content)) {
      imageContents.push(b.content);
    }
  }
  const imagesChanged = JSON.stringify(item.images) !== JSON.stringify(imageContents);
  item.images = imageContents;

  const after = JSON.stringify(item, null, 2) + '\n';
  const changed = after !== before;
  if (changed) {
    if (!dryRun) {
      fs.writeFileSync(detailPath, after, 'utf8');
    }
    if (mermaidBlocks > 0) converted++;
    else imagesUpdated++;
  } else {
    unchanged++;
  }
  rows.push({
    chapter: rec.chapter,
    id: rec.id,
    mermaidBlocks,
    imageBlocks: item.contentBlocks.filter((b) => b.type === 'image').length,
    images: item.images.length,
    changed
  });
}

console.log(`| 章节 | id | mermaid→image | image 块 | images[] | 变更 |`);
console.log(`| ---: | :--- | ---: | ---: | ---: | :--- |`);
for (const r of rows) {
  console.log(`| ${r.chapter} | ${r.id} | ${r.mermaidBlocks} | ${r.imageBlocks} | ${r.images} | ${r.changed ? 'Y' : 'N'} |`);
}
console.log('');
console.log(
  `[apply] ${dryRun ? 'DRY-RUN ' : ''}完成 mermaid 转换章节 ${converted}｜仅 images 更新 ${imagesUpdated}｜无变化 ${unchanged}｜总计 ${rows.length}`
);
if (problems.length > 0) {
  console.log(`[apply] 异常 ${problems.length} 项：`);
  for (const p of problems) {
    console.log(`  - ${p}`);
  }
  process.exit(1);
}
