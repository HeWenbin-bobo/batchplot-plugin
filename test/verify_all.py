#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""全功能回归判定（配合 test/run_all_net8.cmd 使用）。

读两个 accoreconsole 日志 + 产物目录，逐项打 PASS/FAIL。

判定原则：只认"可量化证据"——
  * 页尺寸 → PDF /MediaBox（AGENTS.md §5.5：CSV 的 OK、日志的 [crop] 都不可信）
  * 合并书签 → PDF /Outlines 存在且 /Title 条数 == 页数
  * 出图成功 → BPLOT_SUMMARY 的 OK/FAIL 计数
  * 引擎释放 → 同一会话第二次 BPLOT_SUMMARY 仍是 OK>0（修复前是 ePlotAlreadyStarted）
  * 拆分/改版次 → 产物文件存在 + 日志有对应成功行

退出码：0 = 全部通过；1 = 有失败项。
"""
import glob
import io
import os
import re
import sys

# Windows 控制台默认 GBK，中文日志直接 print 会变乱码
if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

TOL = 0.6  # mm

GOLDEN = [('Sheet001.pdf', 1189.0, 845.7),
          ('Sheet002.pdf', 594.1, 841.0),
          ('Sheet003.pdf', 841.0, 594.0)]


def read_log(path):
    """accoreconsole 日志是 UTF-16LE（带 BOM），容错读取。"""
    if not os.path.exists(path):
        return ''
    raw = open(path, 'rb').read()
    for enc in ('utf-16-le', 'utf-16', 'utf-8', 'gbk'):
        try:
            return raw.decode(enc, 'ignore')
        except Exception:
            pass
    return ''


def page_size_mm(path):
    data = open(path, 'rb').read()
    m = re.search(rb'/MediaBox\s*\[\s*([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)', data)
    if not m:
        return None
    x0, y0, x1, y1 = [float(v) for v in m.groups()]
    return ((x1 - x0) / 72 * 25.4, (y1 - y0) / 72 * 25.4)


RESULTS = []


def check(name, ok, detail=''):
    RESULTS.append((name, ok, detail))
    print('  %s %-42s %s' % ('PASS' if ok else 'FAIL', name, detail))


def main(argv):
    work = argv[1] if len(argv) > 1 else '.'
    log_a = read_log(os.path.join(work, 'a.log'))
    log_b = read_log(os.path.join(work, 'b.log'))
    out_a = os.path.join(work, 'outA')
    out_m = os.path.join(work, 'outM')
    out_b = os.path.join(work, 'outB')

    print('--- 场景 A：content.dwg ---')

    # 1. 部署自检
    check('BPSELFTEST', 'BPSELFTEST 通过' in log_a or 'BPSELFTEST OK' in log_a,
          'PdfSharp 加载/保存/裁切' if 'BPSELFTEST' in log_a else '日志无 BPSELFTEST')

    # 2. 黄金页尺寸（3 框 1:100）
    pdfs = sorted(glob.glob(os.path.join(out_a, '*.pdf')))
    got = {os.path.basename(p): page_size_mm(p) for p in pdfs}
    for name, ew, eh in GOLDEN:
        size = got.get(name)
        if size is None:
            check('页尺寸 ' + name, False, '文件不存在')
        else:
            w, h = size
            check('页尺寸 ' + name, abs(w - ew) <= TOL and abs(h - eh) <= TOL,
                  '%.1fx%.1f (期望 %.1fx%.1f)' % (w, h, ew, eh))

    # 3. 出图计数 + 两次连跑（引擎释放）
    sums = re.findall(r'BPLOT_SUMMARY OK=(\d+) FAIL=(\d+)', log_a)
    check('BPLOTAUTO 第1次 OK=3', len(sums) >= 1 and sums[0][0] == '3', 'OK=%s FAIL=%s' % sums[0] if sums else '无摘要')
    second_ok = len(sums) >= 2 and sums[1][0] == '3'
    check('BPLOTAUTO 第2次 OK=3（引擎已释放）', second_ok,
          ('OK=%s' % sums[1][0]) if len(sums) >= 2 else '缺第二次摘要')
    check('无 ePlotAlreadyStarted', 'ePlotAlreadyStarted' not in log_a, '')

    # 4. BP1 单张快打
    check('BP1 出图', log_a.count('BPLOT_SUMMARY OK=3') >= 3,
          '共 %d 次 OK=3' % log_a.count('BPLOT_SUMMARY OK=3'))

    # 5. 合并 PDF（3 页 + 3 书签 + Info.Title）
    merged = glob.glob(os.path.join(out_m, '*_合并.pdf'))
    if not merged:
        check('BPLOTMERGE 合并 PDF', False, '未找到 *_合并.pdf')
    else:
        data = open(merged[0], 'rb').read()
        pages = len(re.findall(rb'/Type\s*/Page[^s]', data))
        titles = len(re.findall(rb'/Title', data))
        check('BPLOTMERGE 页数=3', pages == 3, 'pages=%d' % pages)
        check('BPLOTMERGE 书签=3', titles >= 3, 'title entries=%d' % titles)
        check('BPLOTMERGE 有 /Outlines', b'/Outlines' in data, '')

    print('--- 场景 B：blk.dwg ---')

    # 6. BPSPLIT 产物
    dwgs = glob.glob(os.path.join(out_b, '*.dwg'))
    check('BPSPLIT 拆分 DWG', len(dwgs) >= 2, '%d 个 .dwg' % len(dwgs))

    # 7. BPREV 改版次/日期
    check('BPREV 改 BANCI', 'BANCI: A -> B' in log_b, '')
    check('BPREV 改 RIQI', 'RIQI: 2024.01.01 -> 2025.06.30' in log_b, '')

    fails = [r for r in RESULTS if not r[1]]
    print('')
    print('合计 %d 项，失败 %d 项' % (len(RESULTS), len(fails)))
    return 0 if not fails else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
