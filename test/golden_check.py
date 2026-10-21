#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""PDF 页尺寸校验（黄金基线回归的判定核心）。

用法：
    python golden_check.py <pdf目录> <期望1> [期望2 ...]

期望格式：`1189.0x845.7`（mm）。顺序对应按文件名排序的 PDF。
比对容差默认 0.6mm（AutoCAD 打印/裁切取整误差）。

**为什么只认 /MediaBox**：AGENTS.md 5.5 明确记录——CSV 的 `OK`、CSV 纸张列的
`->1189x845.7mm`、日志的 `[crop]` 三个信号都不能证明裁切真的生效。
2026-10 就是靠读 /MediaBox 才发现 PdfSharp 1.50 无法解析 AutoCAD 2025 的 PDF
（当时 CSV 全 OK、日志全 [crop]，但页尺寸仍是整张纸）。

退出码：0 = 全部符合；1 = 有不符合或缺文件。
"""
import glob
import os
import re
import sys

if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

TOL = 0.6  # mm


def page_size_mm(path):
    """读第一个 /MediaBox，换算成 mm。返回 (w, h) 或 None。"""
    data = open(path, 'rb').read()
    m = re.search(rb'/MediaBox\s*\[\s*([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)', data)
    if not m:
        return None
    x0, y0, x1, y1 = [float(v) for v in m.groups()]
    return ((x1 - x0) / 72 * 25.4, (y1 - y0) / 72 * 25.4)


def main(argv):
    if len(argv) < 3:
        sys.stderr.write(__doc__)
        return 2
    pdf_dir = argv[1]
    expected = []
    for token in argv[2:]:
        w, h = token.lower().split('x')
        expected.append((float(w), float(h)))

    files = sorted(glob.glob(os.path.join(pdf_dir, '*.pdf')))
    if not files:
        sys.stderr.write('NO PDF in %s\n' % pdf_dir)
        return 1
    if len(files) != len(expected):
        sys.stderr.write('PDF 数量 %d != 期望数量 %d\n' % (len(files), len(expected)))
        return 1

    fails = 0
    for path, (ew, eh) in zip(files, expected):
        size = page_size_mm(path)
        name = os.path.basename(path)
        if size is None:
            print('  FAIL %s  (读不到 /MediaBox)' % name)
            fails += 1
            continue
        w, h = size
        ok = abs(w - ew) <= TOL and abs(h - eh) <= TOL
        if not ok:
            fails += 1
        print('  %s %s  %.1fx%.1f  期望 %.1fx%.1f'
              % ('OK  ' if ok else 'FAIL', name, w, h, ew, eh))
    return 0 if fails == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
