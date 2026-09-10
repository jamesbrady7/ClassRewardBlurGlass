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

from PySide6.QtCore import QObject, Signal, Slot, Property
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


@QmlElement
class RewardBridge(QObject):
    """QML 桥：持有 AppController，向 QML 暴露 UI 需要的形状。"""

    dataChanged = Signal()

    def __init__(self, controller=None, parent=None):
        super().__init__(parent)
        self._ctrl = controller or AppController()
        self._ctrl.subscribe(self._on_data)

    # ---- 内部 ----
    def _on_data(self):
        self.dataChanged.emit()

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
        out = []
        for it in (s.items or []):
            if it.used:
                continue
            out.append({'id': it.id, 'name': it.name,
                        'time': datetime.datetime.fromtimestamp(it.acquired_time).strftime('%Y-%m-%d'),
                        'isBlind': it.reward_id == 'r_blindbox'})
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
                 'desc': r.description, 'blindExcluded': r.blind_box_excluded}
                for r in cls.rewards]

    # ============================================================
    # 每日历史
    # ============================================================
    @Property('QVariantList', notify=dataChanged)
    def history(self):
        cls = self._cur()
        if not cls:
            return []
        all_tx = []
        for s in cls.students:
            for t in s.transactions:
                all_tx.append({'ts': t.timestamp, 'name': s.name,
                               'studentId': s.student_id, 'type': t.type,
                               'points': t.points, 'desc': t.description or ''})
        all_tx.sort(key=lambda x: x['ts'], reverse=True)
        by_date = {}
        for tx in all_tx:
            dk = datetime.datetime.fromtimestamp(tx['ts']).strftime('%Y-%m-%d')
            by_date.setdefault(dk, []).append(tx)
        return [{'date': d,
                 'entries': [{'time': datetime.datetime.fromtimestamp(t['ts']).strftime('%H:%M:%S'),
                              'name': t['name'], 'studentId': t['studentId'],
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
