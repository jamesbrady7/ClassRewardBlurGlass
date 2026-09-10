# 把 PNG 截图画成低分辨率 ASCII 地图，用于无视觉环境核验布局。
import sys, os
sys.path.insert(0, os.getcwd())
from PySide6.QtGui import QGuiApplication, QImage
app = QGuiApplication([])

PALETTE = [
    (' ', (255, 255, 255)), ('.', (240, 243, 248)), (':', (232, 237, 243)),
    ('-', (152, 161, 176)), ('=', (91, 100, 114)), ('#', (31, 41, 55)),
    ('T', (15, 168, 143)), ('t', (12, 143, 122)), ('s', (227, 246, 241)),
    ('R', (224, 96, 80)), ('r', (252, 232, 230)), ('P', (231, 106, 158)),
    ('p', (253, 233, 240)), ('B', (76, 141, 229)), ('b', (232, 241, 253)),
    ('V', (139, 111, 232)), ('v', (239, 234, 251)), ('A', (232, 169, 60)),
    ('a', (252, 243, 224)), ('G', (34, 160, 107)), ('g', (226, 245, 236)),
]

def closest(r, g, b):
    best, bc = None, 1e9
    for ch, (pr, pg, pb) in PALETTE:
        d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if d < bc:
            bc, best = d, ch
    return best

def ascii_map(path, cols=92, rows=42):
    img = QImage(path)
    if img.isNull():
        print('cannot load', path); return
    W, H = img.width(), img.height()
    cw, chh = W / cols, H / rows
    lines = []
    for ry in range(rows):
        row = []
        for cx in range(cols):
            x0, x1 = int(cx * cw), int((cx + 1) * cw)
            y0, y1 = int(ry * chh), int((ry + 1) * chh)
            # 平均采样
            tot = [0, 0, 0]; n = 0
            for yy in range(y0, y1, 2):
                for xx in range(x0, x1, 2):
                    c = img.pixelColor(xx, yy)
                    tot[0] += c.red(); tot[1] += c.green(); tot[2] += c.blue(); n += 1
            if n:
                r, g, b = tot[0] / n, tot[1] / n, tot[2] / n
                row.append(closest(r, g, b))
            else:
                row.append(' ')
        lines.append(''.join(row))
    return lines

if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else '_shots2'
    files = sys.argv[2:]
    if not files:
        files = ['00_roster', '01_groups', '02_random', '03_batch',
                 '04_shop_all', '05_shop_legend', '06_analysis_open', '07_analysis_closed']
    for f in files:
        p = os.path.join(src, f + '.png')
        if not os.path.exists(p):
            print('missing', p); continue
        print('\n===== ' + f + ' =====')
        for ln in ascii_map(p):
            print(ln)
