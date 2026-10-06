/// The HTML report: one self-contained file that a developer opens next to
/// the test.
///
/// The page is static CSS plus a small script that builds the DOM from the
/// report JSON, which is embedded in a `<script type="application/json">`
/// element. The script only inserts data with `textContent` and
/// attributes, never as markup. No fonts, CDNs or frameworks are loaded.
library;

import 'dart:convert';

/// Renders a report JSON map (see `GpuReport.toJson`) as one self-contained
/// HTML page.
String renderHtmlReport(Map<String, Object?> report) {
  // Escaping every `<` keeps strings from the data (widget labels, file
  // paths) from closing the script element with `</script>` or opening an
  // HTML comment in it. `\u003c` is still valid JSON, so the script parses
  // the exact map back.
  final json = jsonEncode(report).replaceAll('<', r'\u003c');
  return _template.replaceFirst(_dataSlot, json);
}

const _dataSlot = '/*REPORT_JSON*/';

const _template = r'''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>GPU estimate</title>
<style>
:root {
  color-scheme: light dark;
  --bg: #ffffff; --ink: #1b1d21; --muted: #5c6370; --faint: #9aa0a9;
  --line: #e6e8eb; --track: #eef0f2; --accent: #2f5bd3; --accent-soft: #eaf0fd;
  --heat: #c2410c; --warn-soft: #fdf1ea;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #131416; --ink: #e8eaed; --muted: #a2a8b3; --faint: #6b717c;
    --line: #2a2d33; --track: #23262b; --accent: #7aa2ff; --accent-soft: #1c2540;
    --heat: #ff8a50; --warn-soft: #2e1f17;
  }
}
* { box-sizing: border-box; }
html { background: var(--bg); }
body { margin: 0 auto; max-width: 980px; padding: 32px 20px 64px; color: var(--ink); font: 15px/1.5 system-ui, sans-serif; font-variant-numeric: tabular-nums; }
h1 { font-size: 24px; margin: 0 0 4px; }
h2 { font-size: 17px; font-weight: 650; margin: 40px 0 6px; }
p { margin: 4px 0; }
button { font: inherit; color: inherit; }
.muted { color: var(--muted); }
.lede { color: var(--muted); font-size: 14px; margin: 0 0 12px; }
code { font: 13px ui-monospace, Menlo, monospace; }
.num { text-align: right; white-space: nowrap; }
table { border-collapse: collapse; width: 100%; font-size: 14px; }
th, td { text-align: left; padding: 6px 12px 6px 0; border-top: 1px solid var(--line); vertical-align: top; }
th { font-weight: 600; border-top: 0; }
.warn { padding: 8px 12px; margin: 8px 0; border-left: 3px solid var(--heat); border-radius: 0 8px 8px 0; background: var(--warn-soft); }
.ended { color: var(--heat); }
.bar { height: 6px; border-radius: 3px; background: var(--track); overflow: hidden; }
.bar > span { display: block; height: 100%; }

/* Hero: screenshot + per-device summary */
.hero { display: grid; grid-template-columns: 1fr; gap: 24px; margin-top: 24px; align-items: start; }
.hero.has-shot { grid-template-columns: 180px 1fr; }
.shot { margin: 0; }
.shot img { display: block; width: 100%; height: auto; border-radius: 14px; border: 1px solid var(--line); }
.shot figcaption { margin-top: 6px; color: var(--muted); font-size: 12px; text-align: center; }
.tabs { display: flex; flex-wrap: wrap; }
.tab { padding: 8px 14px; border: 1px solid var(--line); background: none; cursor: pointer; text-align: left; }
.tab + .tab { margin-left: -1px; }
.tab:first-child { border-radius: 10px 0 0 10px; }
.tab:last-child { border-radius: 0 10px 10px 0; }
.tab-name { display: block; font-weight: 600; }
.tab small { display: block; color: var(--muted); font-size: 12px; }
.tab[aria-selected="true"] { position: relative; border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); background: var(--accent-soft); }
.stats { display: flex; flex-wrap: wrap; gap: 8px 48px; margin-top: 20px; }
.stat-label { color: var(--muted); font-size: 13px; }
.big { display: block; font-size: 40px; line-height: 1.1; font-weight: 700; letter-spacing: -0.02em; }
.big.heat { color: var(--heat); }
.stat-sub { color: var(--muted); font-size: 13px; }
.device-line { margin-top: 12px; color: var(--muted); font-size: 13px; }

/* What causes it */
.cost { padding: 14px 0; border-top: 1px solid var(--line); }
.cost:first-child { border-top: 0; }
.cost-head { display: flex; flex-wrap: wrap; align-items: baseline; justify-content: space-between; gap: 2px 12px; }
.cost-name { font-weight: 600; }
.cost-where { margin-left: 8px; color: var(--muted); font: 13px ui-monospace, Menlo, monospace; }
.cost-nums { white-space: nowrap; }
.cost-extra { color: var(--heat); font-weight: 600; }
.cost-passes { margin-left: 10px; color: var(--muted); }
.cost .bar { margin-top: 8px; }
.cost .bar > span { background: var(--heat); }
.cost-fix { margin-top: 6px; color: var(--muted); font-size: 14px; }

/* Passes in order */
.pass { display: grid; grid-template-columns: 2em 1fr 200px; gap: 2px 12px; align-items: center; padding: 10px 0; border-top: 1px solid var(--line); }
.pass:first-child { border-top: 0; }
.pass-index { color: var(--faint); }
.pass-title { font-weight: 600; }
.pass-title .muted { font-weight: 400; }
.pass-bar { display: flex; align-items: center; gap: 8px; }
.pass-bar .bar { flex: 1; }
.pass-bar .bar > span { background: var(--accent); }
.pass.blit .bar > span { background: var(--faint); }
.pass-bar small { color: var(--muted); font-size: 12px; }
.pass-cause { grid-column: 2; color: var(--muted); font-size: 13px; }
.pass-size { grid-column: 3; text-align: right; color: var(--muted); font: 13px ui-monospace, Menlo, monospace; }

/* Frames while idle */
.verdict { font-size: 17px; font-weight: 600; }
.strip { display: grid; gap: 2px; }
.slot { height: 40px; border-radius: 2px; background: var(--track); }
.slot.changed { background: var(--accent); }
.slot.unchanged { background: var(--heat); }
.axis { display: flex; justify-content: space-between; margin-top: 6px; color: var(--muted); font-size: 12px; }
.legend { display: flex; flex-wrap: wrap; gap: 4px 18px; margin: 8px 0 16px; color: var(--muted); font-size: 13px; }
.legend i { display: inline-block; width: 10px; height: 10px; margin-right: 6px; border-radius: 2px; vertical-align: -1px; background: var(--track); }
.legend i.changed { background: var(--accent); }
.legend i.unchanged { background: var(--heat); }

@media (max-width: 700px) {
  .hero.has-shot { grid-template-columns: 1fr; }
  .shot { max-width: 160px; }
}
</style>
</head>
<body>
<h1 id="name"></h1>
<p class="muted" id="meta"></p>
<div id="warnings"></div>

<div class="hero" id="hero">
  <div>
    <div class="tabs" role="tablist" aria-label="Device" id="tabs"></div>
    <div class="stats" id="stats"></div>
    <p class="device-line" id="device-line"></p>
  </div>
</div>

<h2>What causes it</h2>
<p class="lede" id="costs-lede"></p>
<div id="costs"></div>

<h2>Passes in order</h2>
<p class="lede">Every render pass of one frame, in the order they finish. Hover a pass for what it does.</p>
<div id="passes"></div>

<section id="demand" hidden>
<h2>Frames while idle</h2>
<p class="verdict" id="verdict"></p>
<div class="strip" id="strip" role="img"></div>
<div class="axis"><span>0 ms</span><span id="axis-end"></span></div>
<p class="legend"><span><i class="changed"></i>changed</span><span><i class="unchanged"></i>drew the previous frame again</span><span><i></i>no frame</span></p>
<table id="sources"></table>
<p id="demand-fix"></p>
</section>

<script type="application/json" id="report-data">/*REPORT_JSON*/</script>
<script>
'use strict';
const report = JSON.parse(document.getElementById('report-data').textContent);
const frames = report.frames || [];
const byId = (id) => document.getElementById(id);

// Strings become text nodes, so data never turns into markup.
function h(tag, props, ...kids) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (v == null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, String(v));
  }
  for (const kid of kids.flat()) {
    if (kid != null && kid !== false) el.append(kid instanceof Node ? kid : String(kid));
  }
  return el;
}
function fill(id, ...kids) {
  const el = byId(id);
  el.replaceChildren();
  for (const kid of kids.flat()) {
    if (kid != null && kid !== false) el.append(kid instanceof Node ? kid : String(kid));
  }
  return el;
}
function bar(fraction) {
  const fillEl = h('span');
  fillEl.style.width = (Math.max(0, Math.min(1, fraction)) * 100).toFixed(2) + '%';
  return h('div', { class: 'bar' }, fillEl);
}
const row = (cells, cls) => h('tr', null, cells.map((c, i) => h('td', { class: i === 0 ? null : cls }, c)));
const x = (v) => (v < 10 ? v.toFixed(1) : v.toFixed(0)) + '×';
const num = (v) => String(+v.toFixed(1));
const size = (s) => Math.round(s[0]) + '×' + Math.round(s[1]);
const plural = (n, one, many) => n + ' ' + (n === 1 ? one : many);
const backendName = { metal: 'Metal', vulkan: 'Vulkan', gles: 'OpenGL ES' };

// `BackdropFilter (lib/main.dart:51)` -> name + source location.
function splitLabel(label) {
  const m = /^(.*) \(([^()]*(?:\.dart|:\d+))\)$/.exec(label);
  return m ? { name: m[1], where: m[2] } : { name: label, where: null };
}

// Header
document.title = report.name + ' · GPU estimate';
byId('name').textContent = report.name;
byId('meta').textContent = 'Estimated by impeeler for Flutter ' + report.flutter + '. Confirm GPU time on a device.';

// Warnings: only what makes a number untrustworthy. One line per warning,
// naming the devices only when it does not hold for all of them.
const warnings = new Map();
const warn = (text, device) => warnings.set(text, (warnings.get(text) || new Set()).add(device));
for (const f of frames) {
  const approx = (f.passes || []).filter((p) => p.approximate).length;
  if (approx) warn(approx + ' pass' + (approx === 1 ? '' : 'es') + ' with a guessed size (shader filters). Measure on a device before acting on their size.', f.device.name);
  for (const o of f.missingPictureOrigins || []) warn('Draws not counted: a picture recorded with Canvas(PictureRecorder()) in ' + o + '.', f.device.name);
  for (const t of f.unmodeledLayers || []) warn((t.startsWith('(') ? 'A custom layer' : 'Custom layer ' + t) +
    ' pushes effects the model cannot read; counted as a plain container.', f.device.name);
}
for (const [text, devices] of warnings) {
  const where = devices.size === frames.length ? '' : ' (' + [...devices].join(', ') + ')';
  byId('warnings').append(h('p', { class: 'warn' }, text + where));
}

// Hero: screenshot of the first device's frame, if the test captured one.
if (report.screenshot && frames.length) {
  byId('hero').classList.add('has-shot');
  byId('hero').prepend(h('figure', { class: 'shot' },
    h('a', { href: report.screenshot },
      h('img', { src: report.screenshot, alt: 'Screenshot on ' + frames[0].device.name })),
    h('figcaption', null, frames[0].device.name)));
}

// Device picker; everything below it is scoped to the selected device.
const tabs = frames.map((f, i) => h('button', {
  class: 'tab', role: 'tab', type: 'button', onclick: () => select(i),
},
  h('span', { class: 'tab-name' }, f.device.name),
  h('small', null, plural(f.renderPasses, 'pass', 'passes') + ' · ' + x(1 + f.traffic.extraScreenEquivalents))));
byId('tabs').append(...tabs);

function select(i) {
  const f = frames[i];
  tabs.forEach((t, j) => t.setAttribute('aria-selected', String(i === j)));
  renderSummary(f);
  renderCosts(f);
  renderPasses(f);
}

function renderSummary(f) {
  const d = f.device, backend = d.gpu && (backendName[d.gpu.backend] || d.gpu.backend);
  const stat = (label, big, cls, sub) => h('div', null,
    h('span', { class: 'stat-label' }, label),
    h('span', { class: 'big' + (cls ? ' ' + cls : '') }, big),
    h('span', { class: 'stat-sub' }, sub));
  fill('stats',
    stat('Render passes', f.renderPasses, '', 'a plain frame is 1'),
    stat('Memory traffic', x(1 + f.traffic.extraScreenEquivalents), 'heat', 'of a plain frame'));
  byId('device-line').textContent = size(d.physicalSize) + ' px' + (backend ? ' · ' + backend : '');
}

// What causes it
function fix(label, roles) {
  const r = new Set(roles);
  if (/^(Opacity|FadeTransition|AnimatedOpacity)\b/.test(label)) return 'Fade a single child that overlaps nothing, or put the alpha in the paint.';
  if (/^ShaderMask\b/.test(label)) return 'A shader mask is always a layer: keep the masked child small.';
  if (/antiAliasWithSaveLayer/.test(label)) return 'Use Clip.antiAlias or Clip.hardEdge.';
  if (r.has('advancedBlend') || r.has('blendSourceSnapshot')) return 'Advanced blend mode: use srcOver, or bake the effect into an image.';
  if (/^(BackdropFilter|shared by BackdropGroup)/.test(label)) return 'Each backdrop stops the frame: clip it to the area that shows it, share one BackdropGroup, or use a translucent color over static content.';
  if (r.has('blurDownsample')) return 'A blur over a subtree: a blurred BoxShadow is cheaper for a glow.';
  if (/saveLayer in a picture/.test(label)) return 'A painter calls saveLayer: give it tight bounds or remove it.';
  return '';
}
function renderCosts(f) {
  byId('costs-lede').textContent = 'Extra passes and memory traffic each widget adds to ' + f.device.name + '.';
  const centers = f.costCenters || [];
  if (!centers.length) {
    fill('costs', h('p', { class: 'muted' }, 'Nothing beyond the plain frame.'));
    return;
  }
  const surface = f.traffic.surfaceBytes || 1;
  const whole = surface * (1 + f.traffic.extraScreenEquivalents);
  fill('costs', centers.map((c) => {
    const { name, where } = splitLabel(c.label);
    const fixText = fix(c.label, c.roles);
    return h('div', { class: 'cost' },
      h('div', { class: 'cost-head' },
        h('span', null, h('span', { class: 'cost-name' }, name), where && h('span', { class: 'cost-where' }, where)),
        h('span', { class: 'cost-nums' },
          h('span', { class: 'cost-extra' }, '+' + x(c.extraBytes / surface)),
          h('span', { class: 'cost-passes' }, plural(c.renderPasses, 'pass', 'passes')))),
      bar(c.extraBytes / whole),
      fixText && h('p', { class: 'cost-fix' }, fixText));
  }));
}

// Passes in order
function renderPasses(f) {
  const screen = f.device.physicalSize[0] * f.device.physicalSize[1];
  fill('passes', (f.passes || []).map((p, i) => {
    const role = (f.roles || {})[p.role] || { title: p.role, explanation: '' };
    const area = screen ? p.size[0] * p.size[1] / screen : 0;
    const notes = [p.isBlit && 'blit, not a render pass', p.approximate && 'size guessed'].filter(Boolean);
    return h('div', { class: 'pass' + (p.isBlit ? ' blit' : '') },
      h('span', { class: 'pass-index' }, i + 1),
      h('span', { class: 'pass-title', title: role.explanation }, role.title,
        notes.length ? h('span', { class: 'muted' }, ' (' + notes.join(', ') + ')') : ''),
      h('span', { class: 'pass-bar' }, bar(area), h('small', null, Math.round(area * 100) + '%')),
      h('span', { class: 'pass-cause' },
        p.cause || '',
        p.endedBy && h('span', { class: 'ended' }, (p.cause ? ' · ' : '') + 'ended early by ', h('code', null, p.endedBy))),
      h('span', { class: 'pass-size' }, size(p.size)));
  }));
}

// Frames while idle: measured on the first device, whatever is selected.
const fd = report.frameDemand;
if (fd) {
  byId('demand').hidden = false;
  const fps = Math.round(fd.framesDrawn * 1000 / fd.windowMs);
  byId('verdict').textContent = fd.verdict === 'idle'
    ? 'None: the screen draws nothing while nobody touches it.'
    : fps + ' frames per second while nothing is touched (' + fd.unchangedFrames + ' of ' + fd.framesDrawn +
      ' drew exactly the previous frame). Every frame repeats the passes above.' +
      (fd.stillRequesting ? ' It does not stop on its own.' : '');

  // One cell per vsync slot. A frame at `ms` lands in the slot that ends there.
  const slots = Math.max(1, Math.round(fd.refreshRate * fd.windowMs / 1000));
  const cells = Array.from({ length: slots }, () => h('div', { class: 'slot' }));
  for (const fr of fd.frames || []) {
    const i = Math.min(slots - 1, Math.max(0, Math.round(fr.ms * fd.refreshRate / 1000) - 1));
    cells[i].className = 'slot ' + (fr.changed ? 'changed' : 'unchanged');
    cells[i].title = num(fr.ms) + ' ms · ' + (fr.changed ? 'changed' : 'unchanged') +
      (fr.renderPasses != null ? ' · ' + plural(fr.renderPasses, 'render pass', 'render passes') : '');
  }
  const strip = byId('strip');
  strip.style.gridTemplateColumns = 'repeat(' + slots + ', 1fr)';
  strip.setAttribute('aria-label', fd.framesDrawn + ' of ' + slots + ' vsync slots drew a frame, ' + fd.unchangedFrames + ' unchanged');
  strip.replaceChildren(...cells);
  byId('axis-end').textContent = fd.windowMs + ' ms';

  const sources = fd.sources || [];
  const tickers = (fd.tickers || []).filter((t) => t.active && !t.muted);
  if (fd.verdict !== 'idle' && (sources.length || tickers.length)) {
    byId('sources').append(
      h('thead', null, h('tr', null, h('th', null, 'Requested by'), h('th', null, 'Where'), h('th', { class: 'num' }, 'Frames'))),
      h('tbody', null,
        sources.map((s) => row([s.owner, h('code', null, s.appFrame || s.description || ''), s.frames + (s.unchangedFrames ? ' (' + s.unchangedFrames + ' unchanged)' : '')], null)),
        tickers.map((t) => row(['Ticker of ' + t.owner, h('code', null, t.ownerLocation || ''), ''], null))));
    byId('demand-fix').textContent = 'Stop what does not change anything, mute hidden tickers with TickerMode, or run decorative animations at a lower fixed rate (fixed_ticker).';
  }
}

if (frames.length) select(0);
</script>
</body>
</html>
''';
