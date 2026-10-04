#!/usr/bin/env python3
"""Per-frame Impeller render passes and GPU time from a Metal System Trace.

Usage:
  python3 metal_passes.py t.trace [--gap-ms 1.0] [--top 5] [--run 1]

Record the trace first (macOS app, profile build):
  xcrun xctrace record --template 'Metal System Trace' --time-limit 3s \
      --output t.trace --launch -- build/macos/Build/Products/Profile/App.app

The script exports two tables with `xcrun xctrace export`:
  metal-application-encoders-list  one row per encoder: command buffer label,
                                   encoder label (CPU-side encoding interval)
  metal-gpu-intervals              GPU execution intervals per encoder
                                   (vertex/fragment/compute channels)
and joins them on the encoder id. Encoders of one Flutter frame are encoded in
a burst, so a gap longer than --gap-ms between encoder start times starts a
new frame. Instruments' own "Frame" column numbers command buffers, not
Flutter frames, so it is ignored.

Output: a summary (frames, encoders per frame, GPU busy time per frame), the
label counts of the most common frame, and the --top most expensive frames by
GPU busy time with their encoders in GPU execution order. GPU busy time is the
union of the frame's GPU intervals, so overlapping passes count once.
Standard library only.
"""

import argparse
import collections
import statistics
import subprocess
import sys
import xml.etree.ElementTree as ET


def export_table(trace, run, schema):
    xpath = f'/trace-toc/run[@number="{run}"]/data/table[@schema="{schema}"]'
    out = subprocess.run(
        ['xcrun', 'xctrace', 'export', '--input', trace, '--xpath', xpath],
        check=True, capture_output=True, text=True).stdout
    return ET.fromstring(out)


def rows(root):
    """Yields one dict per row: mnemonic -> (raw text, formatted text).

    xctrace interns values: the first occurrence carries id="N", later ones
    are <x ref="N"/>.
    """
    cols = [c.findtext('mnemonic') for c in root.iter('col')]
    interned = {}
    for row in root.iter('row'):
        out = {}
        for name, el in zip(cols, row):
            if 'ref' in el.attrib:
                out[name] = interned.get(el.attrib['ref'], (None, None))
                continue
            for sub in el.iter():
                if 'id' in sub.attrib:
                    interned[sub.attrib['id']] = (sub.text, sub.attrib.get('fmt'))
            out[name] = (el.text, el.attrib.get('fmt'))
        yield out


def union_ns(intervals):
    total, end = 0, None
    for s, e in sorted(intervals):
        if end is None or s > end:
            total += e - s
            end = e
        elif e > end:
            total += e - end
            end = e
    return total


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('trace')
    ap.add_argument('--gap-ms', type=float, default=1.0,
                    help='encoder start gap that separates frames (default 1.0)')
    ap.add_argument('--top', type=int, default=5,
                    help='how many of the most expensive frames to list')
    ap.add_argument('--run', type=int, default=1, help='trace run number')
    args = ap.parse_args()

    encoders = []
    for r in rows(export_table(args.trace, args.run,
                               'metal-application-encoders-list')):
        encoders.append({
            'start': int(r['start'][0]),
            'cmdbuffer': r['cmdbuffer-label'][1],
            'label': r['encoder-label'][1],
            'id': r['encoder-id'][1],
        })
    if not encoders:
        sys.exit('No encoders found. Was the app a profile build, and did it '
                 'render during the recording?')

    gpu = collections.defaultdict(list)
    for r in rows(export_table(args.trace, args.run, 'metal-gpu-intervals')):
        s = int(r['start'][0])
        gpu[r['encoder-id'][1]].append((s, s + int(r['duration'][0])))

    encoders.sort(key=lambda e: e['start'])
    frames, gap = [], args.gap_ms * 1e6
    for e in encoders:
        if not frames or e['start'] - frames[-1][-1]['start'] > gap:
            frames.append([])
        frames[-1].append(e)

    def gpu_ms(items):
        return union_ns([iv for e in items for iv in gpu.get(e['id'], [])]) / 1e6

    def signature(frame):
        return tuple(e['label'] for e in frame)

    passes = [len(f) for f in frames]
    busy = [gpu_ms(f) for f in frames]
    print(f'frames: {len(frames)} (gap {args.gap_ms} ms), encoders: {len(encoders)}')
    print(f'encoders/frame: median {statistics.median(passes)}, max {max(passes)}')
    print(f'GPU busy ms/frame: median {statistics.median(busy):.3f}, '
          f'max {max(busy):.3f}')

    common, count = collections.Counter(map(signature, frames)).most_common(1)[0]
    print(f'\nmost common frame ({count} of {len(frames)} frames):')
    for label, n in collections.Counter(common).items():
        print(f'  {n} x {label}')

    print(f'\ntop {args.top} frames by GPU busy time:')
    ranked = sorted(range(len(frames)), key=lambda i: busy[i], reverse=True)
    for i in ranked[:args.top]:
        f = frames[i]
        print(f'  frame {i} @ {f[0]["start"] / 1e9:.3f} s: {len(f)} encoders, '
              f'GPU busy {busy[i]:.3f} ms')
        # Encoders are created ahead of execution; list them in GPU order.
        by_gpu_start = sorted(
            f, key=lambda e: min(gpu.get(e['id']) or [(e['start'], 0)]))
        for e in by_gpu_start:
            print(f'    {gpu_ms([e]):8.3f} ms  {e["cmdbuffer"]} | {e["label"]}')


if __name__ == '__main__':
    main()
