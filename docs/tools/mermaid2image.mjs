/**
 * EmbedLab mermaid → PNG 渲染器
 *
 * 职责：把 `docs/chapters/*.md` 中的 ```mermaid 围栏批量渲染为
 *      `entry/src/main/resources/rawfile/database/images/diagrams/{id}_diagram.png`，
 *      并回写 `docs/pipeline/diagrams_manifest.json` 的字节数与宽高。
 *
 * 关键设计：
 *  1. **config 注入**：通过 `-c <config.json>` 注入 themeVariables.fontSize / flowchart / sequence 配置，
 *     让"源头字号"变大（默认 16px → 20px），避免只靠放大 scale 导致包体膨胀。
 *  2. **字号熔断降级**：若目标字号导致渲染失败，按 20 → 18 → 17 依次降级并上报实际生效值。
 *  3. **体积熔断**：单张 > 200 KB 时自动以 scale 1.8 → 1.6 重渲该张；仍超则报 FAIL 并停止。
 *  4. **渲染层归一化**：原文边标签若含未加引号的括号（mermaid 11 会解析失败），渲染前统一加引号；
 *     **源 `.md` 永不修改**（引号不参与显示，观感不变）。
 *  5. 幂等可重跑：同名覆盖，不改文件名、不改任何 details/*.json、不改 index.json。
 *
 * 用法：
 *   node docs/tools/mermaid2image.mjs                       # 按 manifest 全量重渲（默认字号 20、scale 2）
 *   node docs/tools/mermaid2image.mjs --only stage7_mqtt    # 只渲指定 id（逗号分隔）
 *   node docs/tools/mermaid2image.mjs --font-size 18        # 覆盖起始字号
 *   node docs/tools/mermaid2image.mjs --dry-run             # 只列出将要渲染的清单
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const ROOT = process.cwd();
const CH_DIR = path.join(ROOT, 'docs', 'chapters');
const OUT_DIR = path.join(ROOT, 'entry/src/main/resources/rawfile/database/images/diagrams');
const STATE_PATH = path.join(ROOT, 'docs/migration_state.json');
const MANIFEST_PATH = path.join(ROOT, 'docs/pipeline/diagrams_manifest.json');
const CONFIG_PATH = path.join(ROOT, 'docs/pipeline/mermaid_config.json');
const TMP_DIR = path.join(process.env.TEMP || process.env.TMP || '/tmp', 'embedlab_mermaid');

/** 体积熔断阈值：200 KB */
const MAX_BYTES = 204800;
/** 字号熔断降级序列 */
const FONT_FALLBACK = [20, 18, 17];
/** 体积超限时的降级序列：先试 padding 12（观感更松），再降 scale（字号优化 v2 裁决） */
const PADDING_FALLBACK = [12];
const SCALE_FALLBACK = [1.8, 1.6];
/** 全局布局间距（字号优化 v3 裁决：30/40 → 50/50，与 mermaid 默认一致，避免与字号叠加改变宽高比） */
const NODE_SPACING = 50;
const RANK_SPACING = 50;
/** 逐图字号覆盖（v3 裁决：宽度被 1568 上限钳制或纵向被 50/50 拉长，字号 +25% 只能单方向消化，
 *  故这两张单独降为 18px —— 与已批准的 stage6_concurrency 处理方式一致） */
const FONT_OVERRIDE = { stage6_concurrency: 18, stage2_cpu: 18 };

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) {
        args[key] = true;
      } else {
        args[key] = next;
        i++;
      }
    }
  }
  return args;
}

/** 生成 mmdc 的 -c 配置对象（字号与 padding 为变量；useMaxWidth 固定 true —— 字号优化 v2 裁决：
 *  保持 mermaid-cli ~800px 布局钳制，避免宽图横向铺开导致端侧"按宽适配"时相对字号反而变小） */
function buildConfig(fontSize, padding = 8) {
  return {
    theme: 'neutral',
    themeVariables: {
      fontSize: `${fontSize}px`,
      fontFamily: 'sans-serif'
    },
    flowchart: {
      nodeSpacing: NODE_SPACING,
      rankSpacing: RANK_SPACING,
      padding,
      useMaxWidth: true
    },
    sequence: {
      actorFontSize: fontSize,
      noteFontSize: fontSize,
      messageFontSize: Math.max(12, fontSize - 2)
    }
  };
}

/** 渲染层归一化：给含特殊字符的边标签加引号（不修改源文件） */
function normalizeMermaid(source) {
  return source.replace(/\|([^|\r\n]*)\|/g, (_m, label) => `|"${label.replace(/"/g, '#quot;')}"|`);
}

/** 从章节 md 中提取首个 mermaid 围栏 */
function extractMermaid(markdown) {
  const m = /```mermaid\r?\n([\s\S]*?)\r?\n```/.exec(markdown);
  return m ? m[1] : null;
}

function pngSize(file) {
  const b = fs.readFileSync(file);
  if (b.slice(1, 4).toString() !== 'PNG') {
    throw new Error(`${file} 不是合法 PNG`);
  }
  return { bytes: b.length, width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

/** 调用 mmdc 渲染一次 */
function runMmdc(id, source, fontSize, scale, padding = 8) {
  fs.mkdirSync(TMP_DIR, { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(buildConfig(fontSize, padding), null, 2) + '\n', 'utf8');
  const mmdPath = path.join(TMP_DIR, `${id}.mmd`);
  fs.writeFileSync(mmdPath, normalizeMermaid(source), 'utf8');
  const outPath = path.join(OUT_DIR, `${id}_diagram.png`);
  if (fs.existsSync(outPath)) {
    fs.unlinkSync(outPath);
  }
  const cmd = `npx -y @mermaid-js/mermaid-cli -i "${mmdPath}" -o "${outPath}" -c "${CONFIG_PATH}" -t neutral -b white -s ${scale}`;
  const res = spawnSync(cmd, { cwd: ROOT, stdio: 'inherit', shell: true, timeout: 180000 });
  const ok = res.status === 0 && fs.existsSync(outPath);
  return { ok, outPath, status: res.status };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const only = args.only && args.only !== true ? new Set(String(args.only).split(',').map((s) => s.trim())) : null;
  const startFont = args['font-size'] && args['font-size'] !== true ? Number(args['font-size']) : FONT_FALLBACK[0];
  const baseScale = args.scale && args.scale !== true ? Number(args.scale) : 2;
  const startPadding = args.padding && args.padding !== true ? Number(args.padding) : 8;
  const dryRun = args['dry-run'] === true;

  const state = JSON.parse(fs.readFileSync(STATE_PATH, 'utf8'));
  const manifest = fs.existsSync(MANIFEST_PATH) ? JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8')) : null;
  const prevById = new Map();
  if (manifest && Array.isArray(manifest.items)) {
    for (const it of manifest.items) {
      prevById.set(it.id, it);
    }
  }

  const targets = [];
  for (const rec of state) {
    const md = fs.readFileSync(path.join(CH_DIR, rec.file), 'utf8');
    const src = extractMermaid(md);
    if (!src) {
      continue;
    }
    if (only && !only.has(rec.id)) {
      continue;
    }
    if (!only && !fs.existsSync(path.join(OUT_DIR, `${rec.id}_diagram.png`))) {
      continue; // 全量模式只重渲"当前交付清单"内的图，不擅自新增
    }
    targets.push({ chapter: rec.chapter, id: rec.id, src, fontOverride: FONT_OVERRIDE[rec.id] });
  }

  console.log(`[mermaid2image] 目标 ${targets.length} 张 | 起始字号 ${startFont}px | scale ${baseScale} | 阈值 ${MAX_BYTES} B`);
  if (dryRun) {
    for (const t of targets) {
      console.log(`  - ch${t.chapter} ${t.id}`);
    }
    return;
  }

  const results = [];
  let fatal = null;
  for (const t of targets) {
    let done = null;
    let usedFont = null;
    const font0 = t.fontOverride || startFont;
    const fonts = [font0, ...FONT_FALLBACK.filter((f) => f < font0)];
    for (const font of fonts) {
      const r = runMmdc(t.id, t.src, font, baseScale, startPadding);
      if (r.ok) {
        done = r;
        usedFont = font;
        break;
      }
      console.log(`[mermaid2image] ch${t.chapter} ${t.id} 字号 ${font}px 渲染失败（exit=${r.status}），降级重试`);
    }
    if (!done) {
      fatal = `ch${t.chapter} ${t.id} 在字号 ${fonts.join('/')}px 下均渲染失败`;
      break;
    }
    let dim = pngSize(done.outPath);
    let usedScale = baseScale;
    let usedPadding = startPadding;
    if (dim.bytes > MAX_BYTES) {
      // ① 先放宽 padding（观感更松，代价是图略大）
      for (const pad of PADDING_FALLBACK) {
        if (pad === usedPadding) {
          continue;
        }
        console.log(`[mermaid2image] ch${t.chapter} ${t.id} ${dim.bytes} B > ${MAX_BYTES} B，以 padding ${pad} 重渲`);
        const r = runMmdc(t.id, t.src, usedFont, usedScale, pad);
        if (!r.ok) {
          break;
        }
        dim = pngSize(r.outPath);
        usedPadding = pad;
        if (dim.bytes <= MAX_BYTES) {
          break;
        }
      }
      // ② 仍超则降 scale
      if (dim.bytes > MAX_BYTES) {
        for (const sc of SCALE_FALLBACK) {
          console.log(`[mermaid2image] ch${t.chapter} ${t.id} 仍 ${dim.bytes} B，以 scale ${sc} 重渲`);
          const r = runMmdc(t.id, t.src, usedFont, sc, usedPadding);
          if (!r.ok) {
            break;
          }
          dim = pngSize(r.outPath);
          usedScale = sc;
          if (dim.bytes <= MAX_BYTES) {
            break;
          }
        }
      }
      if (dim.bytes > MAX_BYTES) {
        fatal = `ch${t.chapter} ${t.id} 降 padding(${PADDING_FALLBACK.join('/')}) 与 scale(${SCALE_FALLBACK.join('/')}) 后仍为 ${dim.bytes} B > ${MAX_BYTES} B`;
        results.push({ ...t, ...dim, font: usedFont, scale: usedScale, padding: usedPadding, overLimit: true });
        break;
      }
    }
    const prev = prevById.get(t.id);
    results.push({
      chapter: t.chapter,
      id: t.id,
      font: usedFont,
      scale: usedScale,
      padding: usedPadding,
      ...dim,
      prev: prev ? { bytes: prev.bytes, width: prev.width, height: prev.height } : null,
      // 优化前 16px 基线：跨轮次稳定传递（优先沿用上一版 manifest 已记录的 baseline16px，
      // 避免多轮重渲后基线漂移成中间态）
      base: prev
        ? prev.baseline16px
          ? prev.baseline16px
          : prev.previous
            ? prev.previous
            : { bytes: prev.bytes, width: prev.width, height: prev.height }
        : null
    });
    console.log(
      `[mermaid2image] ch${String(t.chapter).padStart(2)} ${t.id.padEnd(24)} ${String(dim.bytes).padStart(7)} B  ${dim.width}x${dim.height}  font=${usedFont}px scale=${usedScale} padding=${usedPadding}` +
        (prev ? `  (was ${prev.bytes} B ${prev.width}x${prev.height})` : '')
    );
  }

  if (fatal) {
    console.log(`[mermaid2image] FATAL: ${fatal}`);
    process.exitCode = 2;
  }

  // ---- 回写 manifest（items 全量刷新 + 保留 deleted/summary 语义）----
  if (manifest && results.length > 0) {
    const byId = new Map(results.map((r) => [r.id, r]));
    const items = manifest.items.map((it) => {
      const r = byId.get(it.id);
      if (!r) {
        return it;
      }
      const base = r.base;
      const vsBaseline = base
        ? {
            aspectRatioDeltaPct: +(
              ((r.width / r.height - base.width / base.height) / (base.width / base.height)) *
              100
            ).toFixed(1),
            relativeFontBefore: +(16 / (base.width / 2)).toFixed(4),
            relativeFontAfter: +(r.font / (r.width / 2)).toFixed(4)
          }
        : null;
      if (vsBaseline) {
        vsBaseline.relativeFontDeltaPct = +(
          ((vsBaseline.relativeFontAfter - vsBaseline.relativeFontBefore) / vsBaseline.relativeFontBefore) *
          100
        ).toFixed(1);
      }
      return {
        chapter: it.chapter,
        id: it.id,
        out: it.out,
        bytes: r.bytes,
        width: r.width,
        height: r.height,
        referencedBy: it.referencedBy,
        source: `mermaid-cli 11.17.0 -t neutral -b white -s ${r.scale} -c mermaid_config.json (fontSize ${r.font}px, padding ${r.padding}, useMaxWidth true)`,
        previous: r.prev,
        baseline16px: base,
        aspectDeltaPct: r.prev
          ? {
              width: +(((r.width - r.prev.width) / r.prev.width) * 100).toFixed(1),
              height: +(((r.height - r.prev.height) / r.prev.height) * 100).toFixed(1)
            }
          : null,
        vsBaseline
      };
    });
    const liveBytes = items.reduce((s, i) => s + i.bytes, 0);
    const next = {
      ...manifest,
      generatedAt: new Date().toISOString(),
      renderParams: {
        renderer: '@mermaid-js/mermaid-cli 11.17.0',
        theme: 'neutral',
        background: 'white',
        scale: baseScale,
        configFile: 'docs/pipeline/mermaid_config.json',
        config: buildConfig(results[0].font, results[0].padding),
        edgeLabelQuoting: '渲染层归一化（源 .md 未改动）'
      },
      summary: {
        ...manifest.summary,
        liveImages: items.length,
        liveBytes,
        liveMB: +(liveBytes / 1048576).toFixed(2),
        maxBytes: Math.max(...items.map((i) => i.bytes)),
        overLimitCount: items.filter((i) => i.bytes > MAX_BYTES).length
      },
      items
    };
    fs.writeFileSync(MANIFEST_PATH, JSON.stringify(next, null, 2) + '\n', 'utf8');
    console.log(`[mermaid2image] manifest 已更新：${items.length} 条，合计 ${(liveBytes / 1024).toFixed(1)} KB，最大 ${(Math.max(...items.map((i) => i.bytes)) / 1024).toFixed(1)} KB`);
  }
}

main();
