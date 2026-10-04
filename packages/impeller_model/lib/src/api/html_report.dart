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
:root { color-scheme: light dark; }
body { margin: 0 auto; max-width: 960px; padding: 24px 16px 48px; font: 15px/1.45 system-ui, sans-serif; font-variant-numeric: tabular-nums; }
h1 { font-size: 22px; margin: 0 0 4px; }
h2 { font-size: 17px; margin: 28px 0 8px; }
p { margin: 4px 0; }
.muted { color: GrayText; }
table { border-collapse: collapse; width: 100%; }
th, td { text-align: left; padding: 6px 12px 6px 0; border-top: 1px solid color-mix(in srgb, CanvasText 15%, transparent); vertical-align: top; }
th { font-weight: 600; border-top: 0; }
.num { text-align: right; white-space: nowrap; }
code { font: 13px ui-monospace, Menlo, monospace; }
.warn { padding: 8px 12px; border-left: 3px solid #d9480f; margin: 8px 0; }
</style>
</head>
<body>
<h1 id="name"></h1>
<p class="muted" id="meta"></p>
<div id="warnings"></div>

<h2>Cost per device</h2>
<table id="devices"></table>

<h2>What causes it</h2>
<p class="muted">Each widget's extra passes and memory traffic, as a multiple of one plain frame.</p>
<table id="costs"></table>

<section id="demand" hidden>
<h2>Frames while idle</h2>
<p id="verdict"></p>
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
    if (k === 'class') el.className = v; else el.setAttribute(k, String(v));
  }
  for (const kid of kids.flat()) {
    if (kid != null && kid !== false) el.append(kid instanceof Node ? kid : String(kid));
  }
  return el;
}
const row = (cells, cls) => h('tr', null, cells.map((c, i) => h('td', { class: i === 0 ? null : cls }, c)));
const x = (v) => (v < 10 ? v.toFixed(1) : v.toFixed(0)) + '×';

// Header
document.title = report.name + ' · GPU estimate';
byId('name').textContent = report.name;
byId('meta').append(
  'Estimated by impeller_model for Flutter ' + report.flutter + '. A plain frame is 1 pass and 1×. Confirm GPU time on a device.',
  report.screenshot ? h('span', null, ' ', h('a', { href: report.screenshot }, 'Screenshot')) : '');

// Warnings: only what makes a number untrustworthy. One line per warning,
// naming the devices only when it does not hold for all of them.
const warnings = new Map();
const warn = (text, device) => warnings.set(text, (warnings.get(text) || new Set()).add(device));
for (const f of frames) {
  const approx = (f.passes || []).filter((p) => p.approximate).length;
  if (approx) warn(approx + ' pass' + (approx === 1 ? '' : 'es') + ' with a guessed size (shader filters). Measure on a device before acting on their size.', f.device.name);
  for (const o of f.missingPictureOrigins || []) warn('Draws not counted: a picture recorded with Canvas(PictureRecorder()) in ' + o + '.', f.device.name);
  for (const t of f.unmodeledLayers || []) warn('Custom layer ' + t + ' pushes effects the model cannot read; counted as a plain container.', f.device.name);
}
for (const [text, devices] of warnings) {
  const where = devices.size === frames.length ? '' : ' (' + [...devices].join(', ') + ')';
  byId('warnings').append(h('p', { class: 'warn' }, text + where));
}

// Cost per device
byId('devices').append(
  h('thead', null, h('tr', null, h('th', null, 'Device'), h('th', { class: 'num' }, 'Render passes'), h('th', { class: 'num' }, 'Memory traffic'))),
  h('tbody', null, frames.map((f) => row([f.device.name, f.renderPasses, x(1 + f.traffic.extraScreenEquivalents)], 'num'))));

// What causes it: one row per widget, one column per device.
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
const centers = new Map();
frames.forEach((f, i) => {
  const plain = f.traffic.surfaceBytes || 1;
  for (const c of f.costCenters || []) {
    const e = centers.get(c.label) || { label: c.label, roles: new Set(), cells: [], worst: 0 };
    (c.roles || []).forEach((r) => e.roles.add(r));
    const share = c.extraBytes / plain;
    e.cells[i] = c.renderPasses + ' · +' + x(share);
    e.worst = Math.max(e.worst, share);
    centers.set(c.label, e);
  }
});
const sorted = [...centers.values()].sort((a, b) => b.worst - a.worst);
if (sorted.length) {
  byId('costs').append(
    h('thead', null, h('tr', null, h('th', null, 'Widget'), frames.map((f) => h('th', { class: 'num' }, f.device.name)), h('th', null, 'Fix'))),
    h('tbody', null, sorted.map((e) => h('tr', null,
      h('td', null, h('code', null, e.label)),
      frames.map((_, i) => h('td', { class: 'num' }, e.cells[i] || '–')),
      h('td', null, fix(e.label, e.roles))))));
} else {
  byId('costs').replaceWith(h('p', null, 'Nothing beyond the plain frame.'));
}

// Frames while idle
const fd = report.frameDemand;
if (fd) {
  byId('demand').hidden = false;
  const fps = Math.round(fd.framesDrawn * 1000 / fd.windowMs);
  byId('verdict').textContent = fd.verdict === 'idle'
    ? 'None: the screen draws nothing while nobody touches it.'
    : fps + ' frames per second while nothing is touched (' + fd.unchangedFrames + ' of ' + fd.framesDrawn +
      ' drew exactly the previous frame). Every frame repeats the passes above.';
  const sources = fd.sources || [];
  const tickers = (fd.tickers || []).filter((t) => t.active && !t.muted);
  if (fd.verdict !== 'idle' && (sources.length || tickers.length)) {
    byId('sources').append(
      h('thead', null, h('tr', null, h('th', null, 'Requested by'), h('th', null, 'Where'), h('th', { class: 'num' }, 'Frames'))),
      h('tbody', null,
        sources.map((s) => row([s.owner, h('code', null, s.appFrame || ''), s.frames + (s.unchangedFrames ? ' (' + s.unchangedFrames + ' unchanged)' : '')], null)),
        tickers.map((t) => row(['Ticker of ' + t.owner, h('code', null, t.ownerLocation || ''), ''], null))));
    byId('demand-fix').textContent = 'Stop what does not change anything, mute hidden tickers with TickerMode, or run decorative animations at a lower fixed rate (fixed_ticker).';
  }
}
</script>
</body>
</html>
''';
