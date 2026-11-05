# ============================================================
# 文件功能：QML 桥接层（View-Model 适配器）—— 把 controller 的纯 Python API
#           翻译成 QML 可绑定的属性 / 可调用的槽，并把 Python 对象序列化为
#           纯 dict/list，QML 侧永不直接接触 model 对象。
# 对应Tab：全部
# 依赖库：PySide6, controller, model
#
# 架构：model + controller 保持纯 Python 不动（MVC 不破），本文件只做
#       「数据翻译 + 信号转发」。所有只读数据用 @Property(notify=dataChanged)，
#       所有操作用 @Slot；controller 每次 _notify 都会触发 dataChanged，
#       QML 的绑定随之刷新。
# ============================================================
import datetime
import os
import re

from PySide6.QtCore import (QObject, Signal, Slot, Property, QSettings,
                            QStandardPaths, QUrl)
from PySide6.QtQml import QmlElement

from controller.app_controller import AppController
from model.entities import CATEGORY_DIMENSIONS
from qml_theme import stripe_color

QML_IMPORT_NAME = "ClassReward"
QML_IMPORT_MAJOR_VERSION = 1

# 历史记录类型的显示名
_TX_LABEL = {'earn': '加分', 'deduct': '扣分', 'redeem': '兑换', 'use': '使用', 'blindbox': '盲盒', 'undo': '撤回'}


def _fmt_points(v):
    return f"+{v}" if v > 0 else str(v)


_DAY_FMT = '%Y-%m-%d'


def _day_of(ts):
    """时间戳 → 本地日期字符串；坏数据返回空串（调用方跳过）。"""
    try:
        return datetime.datetime.fromtimestamp(ts).strftime(_DAY_FMT)
    except Exception:
        return ''


def _student_sort_key(sid):
    """学号按数值升序：01 < 02 < 10；非纯数字学号排在后面按字典序。"""
    s = str(sid or '')
    return (0, int(s), s) if s.isdigit() else (1, 0, s)


def _ids_text(ids):
    # 学号之间用「英文逗号 + 空格」：01, 02, 03（用户指定）
    return ', '.join(sorted(ids, key=_student_sort_key))


@QmlElement
class RewardBridge(QObject):
    """QML 桥：持有 AppController，向 QML 暴露 UI 需要的形状。"""

    dataChanged = Signal()

    def __init__(self, controller=None, parent=None):
        super().__init__(parent)
        self._ctrl = controller or AppController()
        self._ctrl.subscribe(self._on_data)
        # 每日汇总的页内缓存：QML 里多处理解会多次读属性，
        # 每次 dataChanged 只重算一遍，预览窗十几个绑定不会各算一次。
        self._ledger_cache = None

    # ---- 内部 ----
    def _on_data(self):
        self._ledger_cache = None
        self.dataChanged.emit()

    def _ledger_days(self):
        if self._ledger_cache is None:
            self._ledger_cache = self._build_ledger(self._cur())
        return self._ledger_cache

    def _cur(self):
        return self._ctrl.current_class()

    # ============================================================
    # 班级
    # ============================================================
    @Slot(str)
    def addClass(self, name):
        name = (name or '').strip()
        if name:
            self._ctrl.add_class(name)

    @Slot(str, str)
    def renameClass(self, cid, new_name):
        new_name = (new_name or '').strip()
        if new_name:
            self._ctrl.rename_class(cid, new_name)

    @Slot(str, result=bool)
    def deleteClass(self, cid):
        cls = self._cur()
        if cls and cls.id == cid:
            self._ctrl.delete_class(cid)
            return True
        return False

    @Slot(str)
    def setCurrentClass(self, cid):
        if any(k.id == cid for k in self._ctrl.app_data.classes):
            self._ctrl.set_current_class_id(cid)

    @Property('QVariantList', notify=dataChanged)
    def classes(self):
        cur = self._ctrl.current_class_id
        return [{'id': k.id, 'name': k.name, 'current': k.id == cur}
                for k in self._ctrl.app_data.classes]

    @Property(str, notify=dataChanged)
    def currentClassName(self):
        k = self._cur()
        return k.name if k else ''

    # ============================================================
    # 花名册
    # ============================================================
    @Slot(str, str, str, result=bool)
    def addStudent(self, sid, name, gid):
        return bool(self._ctrl.add_student((sid or '').strip(), (name or '').strip(), gid))

    @Slot(str, result=bool)
    def deleteStudent(self, sid):
        return self._ctrl.delete_student(sid)

    @Slot(str, str, result=bool)
    def moveStudent(self, sid, gid):
        return self._ctrl.move_student_group(sid, gid)

    @Slot(str, int, bool, str, result=bool)
    def pointChange(self, sid, delta, isAdd, desc):
        return self._ctrl.point_change(sid, abs(delta), isAdd, desc)

    @Slot(str, result=str)
    def undoLast(self, sid):
        return self._ctrl.undo_last_operation(sid) or ''

    @Slot(result=str)
    def undoLastAny(self):
        """撤销全班最后一笔加/扣分（不限学生）"""
        self.dataChanged.emit()
        return self._ctrl.undo_last_any() or ''

    @Slot(str, str, result=str)
    def importStudents(self, csvText, gid):
        """解析「学号,姓名」多行文本，批量导入。返回 '成功X 跳过Y'。"""
        rows = []
        for line in (csvText or '').splitlines():
            line = line.strip()
            if not line:
                continue
            parts = [p.strip() for p in line.replace('，', ',').replace('\t', ',').split(',') if p.strip()]
            if len(parts) >= 2:
                rows.append((parts[0], parts[1]))
        if not rows:
            return '没有可导入的数据'
        imp, skp = self._ctrl.import_students(rows, gid)
        return f'成功导入 {imp} 人，跳过 {skp} 人'

    @Property('QVariantList', notify=dataChanged)
    def students(self):
        cls = self._cur()
        if not cls:
            return []
        out = []
        for s in cls.students:
            g = cls.get_group_by_id(s.group_id) if s.group_id else None
            gname = g.name if g else '未分组'
            out.append({'id': s.id, 'studentId': s.student_id, 'name': s.name,
                        'group': gname, 'groupId': s.group_id or '',
                        'groupColor': stripe_color(gname, s.student_id),
                        'earned': s.earned_points, 'available': s.available_points})
        return out

    # ============================================================
    # 小组榜
    # ============================================================
    @Slot(str, str, result=bool)
    def addGroup(self, name, membersCsv):
        members = [x for x in (membersCsv or '').split(',') if x]
        return bool(self._ctrl.add_group((name or '').strip(), members))

    @Slot(str, result=bool)
    def deleteGroup(self, gid):
        return self._ctrl.delete_group(gid)

    @Slot(str, str)
    def renameGroup(self, gid, name):
        self._ctrl.rename_group(gid, (name or '').strip())

    @Slot(str, int)
    def addGroupPoints(self, gid, pts):
        self._ctrl.add_direct_group_points(gid, abs(pts))

    @Slot(str, int)
    def subtractGroupPoints(self, gid, pts):
        self._ctrl.subtract_direct_group_points(gid, abs(pts))

    @Property('QVariantList', notify=dataChanged)
    def groups(self):
        cls = self._cur()
        if not cls:
            return []
        gp = cls.compute_group_points()
        out = []
        for g in cls.groups:
            members = [{'studentId': s.student_id, 'name': s.name}
                       for s in cls.students if s.group_id == g.id]
            out.append({'id': g.id, 'name': g.name, 'points': gp.get(g.id, 0), 'members': members})
        out.sort(key=lambda x: x['points'], reverse=True)
        return out

    # ============================================================
    # 随机抽取
    # ============================================================
    @Slot(int, result='QVariantList')
    def randomPickStudents(self, cnt):
        return self._ctrl.random_pick_students(max(1, cnt))

    @Slot(int, result='QVariantList')
    def randomPickGroups(self, cnt):
        return self._ctrl.random_pick_groups(max(1, cnt))

    # ============================================================
    # 批量操作
    # ============================================================
    @Slot(str, int, bool, str, result=str)
    def batchPointChange(self, idsCsv, delta, isAdd, cat):
        ids = [x for x in (idsCsv or '').split(',') if x]
        if not ids:
            return '请先选择学生'
        if not cat:
            return '请先选择分类'
        sc, fc = self._ctrl.batch_point_operation(ids, abs(delta), isAdd, cat)
        return f'成功 {sc} 人，失败 {fc} 人'

    # ============================================================
    # 积分商店
    # ============================================================
    @Slot(str, int, str, str, result=bool)
    def addReward(self, name, cost, cat, desc):
        return bool(self._ctrl.add_reward((name or '').strip(), abs(cost), cat, desc))

    @Slot(str, result=bool)
    def deleteReward(self, rid):
        return self._ctrl.delete_reward(rid)

    @Slot(str, str, result=str)
    def redeemReward(self, sid, rid):
        return self._ctrl.redeem_reward(sid, rid) or ''

    @Slot(str, result=str)
    def buyBlindBox(self, sid):
        return self._ctrl.buy_blind_box(sid)

    @Slot(str, str, result=str)
    def useItem(self, sid, iid):
        return self._ctrl.use_item(sid, iid)

    # ---- 带参数的数据：用 setter 设置激活对象，notify 触发属性刷新 ----
    _active_sid = ''

    @Slot(str)
    def openBackpack(self, sid):
        self._active_sid = sid
        self.dataChanged.emit()

    @Slot(str)
    def openHistory(self, sid):
        self._active_sid = sid
        self.dataChanged.emit()

    @Property('QVariantList', notify=dataChanged)
    def backpackItems(self):
        """激活学生的未使用背包奖品"""
        cls = self._cur()
        if not cls or not self._active_sid:
            return []
        s = cls.get_student_by_id(self._active_sid)
        if not s:
            return []
        # 分类要按 reward_id 反查奖励表 —— 物品本身只存 reward_id，不存分类
        cat_of = {r.id: (r.category or '') for r in (cls.rewards or [])}
        out = []
        for it in (s.items or []):
            if it.used:
                continue
            out.append({'id': it.id, 'name': it.name,
                        'time': datetime.datetime.fromtimestamp(it.acquired_time).strftime('%Y-%m-%d'),
                        'isBlind': it.reward_id == 'r_blindbox',
                        'category': cat_of.get(it.reward_id, '')})
        return out

    @Property('QVariantList', notify=dataChanged)
    def historyItems(self):
        """激活学生的积分历史（倒序）"""
        cls = self._cur()
        if not cls or not self._active_sid:
            return []
        s = cls.get_student_by_id(self._active_sid)
        if not s:
            return []
        txs = sorted(s.transactions, key=lambda t: t.timestamp, reverse=True)
        return [{'time': datetime.datetime.fromtimestamp(t.timestamp).strftime('%m-%d %H:%M'),
                 'typeLabel': _TX_LABEL.get(t.type, t.type),
                 'points': -t.points if t.type == 'deduct' else t.points,
                 'desc': t.description or ''} for t in txs]

    @Property('QVariantList', notify=dataChanged)
    def rewards(self):
        cls = self._cur()
        if not cls:
            return []
        return [{'id': r.id, 'name': r.name, 'cost': r.cost, 'category': r.category,
                 'blindExcluded': r.blind_box_excluded}
                for r in cls.rewards]

    # ============================================================
    # 每日历史
    # ============================================================
    @staticmethod
    def _category_order(cat):
        try:
            return CATEGORY_DIMENSIONS.index(cat)
        except ValueError:
            return len(CATEGORY_DIMENSIONS)

    @classmethod
    def _rows_from_student_totals(cls, totals):
        """{(维度, 学号): 当日累计分} → 按「维度 + 分值」分组，学号数值升序。"""
        buckets = {}
        for (cat, sid), pts in totals.items():
            if not pts:
                continue
            buckets.setdefault((cat, pts), []).append(sid)
        rows = []
        for (cat, pts), ids in buckets.items():
            rows.append({'category': cat, 'points': pts,
                         'ids': _ids_text(ids), 'count': len(ids)})
        rows.sort(key=lambda r: (cls._category_order(r['category']),
                                 r['category'], r['points']))
        return rows

    @staticmethod
    def _rows_from_group_totals(totals):
        """{(小组名, 分值)} → 小组直接分汇总行。小组分不并入学生学号。"""
        rows = [{'name': name, 'points': pts}
                for (name, pts) in totals.items() if pts]
        rows.sort(key=lambda r: (r['name'], r['points']))
        return rows

    def _build_ledger(self, cls):
        """按「日期 → 加分 / 扣分 / 小组直接分」汇总当前班级。

        学生：先按「学生 × 维度 × 日期」累计，再按「维度 + 分值」分组列学号；
        小组：只统计直接给小组的加减分，单独成块，不混进学生学号。
        """
        if not cls:
            return []

        def _rec(d):
            return day_map.setdefault(
                d, {'earn': {}, 'deduct': {}, 'g_earn': {}, 'g_deduct': {}})

        day_map = {}
        for s in (cls.students or []):
            for t in (s.transactions or []):
                if t.type not in ('earn', 'deduct'):
                    continue
                try:
                    pts = abs(int(t.points))
                except (TypeError, ValueError):
                    continue
                if pts <= 0:
                    continue
                d = _day_of(t.timestamp)
                if not d:
                    continue
                cat = (t.description or '').strip() or (
                    '加分' if t.type == 'earn' else '扣分')
                rec = _rec(d)
                key = (cat, s.student_id)
                rec[t.type][key] = rec[t.type].get(key, 0) + pts

        for g in (cls.groups or []):
            for t in (getattr(g, 'transactions', None) or []):
                if t.type not in ('earn', 'deduct'):
                    continue
                try:
                    pts = abs(int(t.points))
                except (TypeError, ValueError):
                    continue
                if pts <= 0:
                    continue
                d = _day_of(t.timestamp)
                if not d:
                    continue
                rec = _rec(d)
                bucket = rec['g_earn' if t.type == 'earn' else 'g_deduct']
                bucket[g.name] = bucket.get(g.name, 0) + pts

        out = []
        for d in sorted(day_map.keys(), reverse=True):
            rec = day_map[d]
            earn = self._rows_from_student_totals(rec['earn'])
            deduct = self._rows_from_student_totals(rec['deduct'])
            g_earn = self._rows_from_group_totals(rec['g_earn'])
            g_deduct = self._rows_from_group_totals(rec['g_deduct'])
            for r in g_earn:
                r['sign'] = '+'
            for r in g_deduct:
                r['sign'] = '-'
            if not (earn or deduct or g_earn or g_deduct):
                continue
            out.append({'date': d, 'earn': earn, 'deduct': deduct,
                        'groupEarn': g_earn, 'groupDeduct': g_deduct,
                        'hasEarn': bool(earn), 'hasDeduct': bool(deduct),
                        'hasGroup': bool(g_earn or g_deduct)})
        return out

    @Property('QVariantList', notify=dataChanged)
    def ledgerHistory(self):
        """加扣分历史：每个日期一张汇总卡（加分在前、扣分在后、小组分单列）。"""
        return self._ledger_days()

    @Property('QVariant', notify=dataChanged)
    def todayLedger(self):
        """今日汇总（截图/预览窗口用）。没有记录时 hasAny=False。"""
        cls = self._cur()
        today = datetime.date.today().strftime(_DAY_FMT)
        out = {'date': today, 'className': cls.name if cls else '',
               'earn': [], 'deduct': [], 'groupEarn': [], 'groupDeduct': [],
               'hasEarn': False, 'hasDeduct': False, 'hasGroup': False,
               'hasAny': False}
        for day in self._ledger_days():
            if day['date'] == today:
                out.update(day)
                out['className'] = cls.name if cls else ''
                out['hasAny'] = bool(day['hasEarn'] or day['hasDeduct']
                                     or day['hasGroup'])
                break
        return out

    @Slot(result='QVariant')
    def todayScoreSaveInfo(self):
        """今日分数截图的目标文件：桌面 / 「x班_英语今日分数_日期.png」。"""
        cls = self._cur()
        today = datetime.date.today().strftime(_DAY_FMT)
        cls_name = ((cls.name if cls else '') or '班级').strip()
        safe_cls = re.sub(r'[\\/:*?"<>|\r\n]+', '_', cls_name).strip() or '班级'
        filename = '%s_英语今日分数_%s.png' % (safe_cls, today)
        desktop = QStandardPaths.writableLocation(QStandardPaths.DesktopLocation)
        if not desktop:
            desktop = os.path.expanduser('~')
        path = os.path.join(desktop, filename)
        ledger = self.todayLedger
        return {'url': QUrl.fromLocalFile(path).toString(), 'path': path,
                'fileName': filename, 'hasData': bool(ledger.get('hasAny'))}

    @Property('QVariantList', notify=dataChanged)
    def history(self):
        """总览历史：全部流水（加扣分、兑换、使用道具、盲盒、撤回、小组直接分）。"""
        cls = self._cur()
        if not cls:
            return []
        all_tx = []
        for s in (cls.students or []):
            for t in (s.transactions or []):
                all_tx.append({'ts': t.timestamp, 'name': s.name,
                               'studentId': s.student_id, 'type': t.type,
                               'points': t.points, 'desc': t.description or '',
                               'isGroup': False})
        for g in (cls.groups or []):
            for t in (getattr(g, 'transactions', None) or []):
                all_tx.append({'ts': t.timestamp, 'name': '小组 · ' + g.name,
                               'studentId': '', 'type': t.type,
                               'points': t.points, 'desc': t.description or '',
                               'isGroup': True})
        all_tx.sort(key=lambda x: x['ts'], reverse=True)
        by_date = {}
        for tx in all_tx:
            dk = _day_of(tx['ts'])
            if not dk:
                continue
            by_date.setdefault(dk, []).append(tx)
        return [{'date': d,
                 'entries': [{'time': datetime.datetime.fromtimestamp(t['ts']).strftime('%H:%M:%S'),
                              'name': t['name'], 'studentId': t['studentId'],
                              'isGroup': t['isGroup'],
                              'typeLabel': _TX_LABEL.get(t['type'], t['type']),
                              'points': t['points'], 'desc': t['desc']} for t in entries]}
                for d, entries in sorted(by_date.items(), reverse=True)]

    # ============================================================
    # 每周统计
    # ============================================================
    @Property('QVariant', notify=dataChanged)
    def weeklyStats(self):
        dl, el = self._ctrl.get_weekly_stats()
        return {'deduct': dl, 'earn': el}

    # ============================================================
    # 数据分析
    # ============================================================
    @Property('QVariantList', constant=True)
    def categories(self):
        return CATEGORY_DIMENSIONS

    @Property('QVariantList', notify=dataChanged)
    def analysis(self):
        cls = self._cur()
        if not cls:
            return []
        scores_map = self._ctrl.compute_category_scores()
        out = []
        for s in cls.students:
            info = scores_map.get(s.id)
            if not info:
                continue
            out.append({
                'id': s.id, 'studentId': s.student_id, 'name': s.name,
                'scores': [info['scores'].get(cat, 0) for cat in CATEGORY_DIMENSIONS],
                'transactions': [{'ts': t.timestamp, 'type': t.type,
                                  'points': t.points, 'desc': t.description or ''}
                                 for t in info['transactions']],
            })
        return out

    # ============================================================
    # 导出 / 导入
    # ============================================================
    @Slot(str, result=bool)
    def exportData(self, path):
        return self._ctrl.export_data(path)

    @Slot(str, result=str)
    def importData(self, path):
        return self._ctrl.import_data(path) or ''


class PreviewPrefs(QObject):
    """今日分数预览窗口的持久化设置（目前只有「置顶」开关）。

    用 QSettings 存本机（Windows 注册表），退出软件 / 拔掉 U 盘再插上、
    甚至换到别的机器上启动，都还是上次选的那一档。
    """

    changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._s = QSettings()

    @Property(bool, notify=changed)
    def topmost(self):
        try:
            return bool(self._s.value('preview/topmost', True, type=bool))
        except Exception:
            return True

    @Slot(bool)
    def setTopmost(self, on):
        try:
            self._s.setValue('preview/topmost', bool(on))
            self._s.sync()
        except Exception:
            pass
        self.changed.emit()

    @Slot(QObject, bool)
    def applyTopmost(self, win, on):
        """用 SetWindowPos 切换置顶（不改 Qt flags，避免窗口重建/闪烁）。"""
        if win is None:
            return
        try:
            import ctypes
            u = ctypes.windll.user32
            u.SetWindowPos.argtypes = [
                ctypes.c_void_p, ctypes.c_void_p,
                ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                ctypes.c_uint]
            u.SetWindowPos.restype = ctypes.c_int
            u.SetWindowPos(
                ctypes.c_void_p(int(win.winId())),
                ctypes.c_void_p(-1 if on else -2),   # HWND_TOPMOST / NOTOPMOST
                0, 0, 0, 0,
                0x0001 | 0x0002 | 0x0010)            # NOSIZE | NOMOVE | NOACTIVATE
        except Exception:
            pass
