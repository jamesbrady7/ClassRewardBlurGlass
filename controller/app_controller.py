# ============================================================
# 文件功能：应用程序的"大脑"——处理所有业务逻辑
# 对应Tab：全部
# 依赖库：time, random, uuid（Python内置）, model
# 使用方法：ctrl = AppController(storage); ctrl.point_change(sid, 5, True, '课堂')
# ============================================================
import time, random, uuid
from typing import Optional, Callable
from model.entities import (AppData, Klass, Student, Group, Reward, Transaction,
    StudentItem, CATEGORY_DIMENSIONS, get_default_klass, get_default_rewards)
from model.storage import StorageManager

def _get_week_start():
    """计算本周一零点的时间戳，用于统计"本周扣分达人"等"""
    import datetime
    now = datetime.datetime.now()
    days_since_monday = now.weekday()
    monday = now.replace(hour=0, minute=0, second=0, microsecond=0)
    monday = monday - datetime.timedelta(days=days_since_monday)
    return monday.timestamp()

class AppController:
    """中央控制器。所有业务操作（加分/扣分/兑换/抽奖）都通过它执行。"""
    MAX_STUDENTS = 50

    def __init__(self, storage=None):
        self._storage = storage or StorageManager()
        self._app_data = self._storage.load()
        self._current_class_id = None
        self._listeners = []
        if self._app_data.classes:
            self._current_class_id = self._app_data.classes[0].id

    # ---- 访问器 ----
    @property
    def app_data(self): return self._app_data

    @property
    def current_class_id(self): return self._current_class_id

    def set_current_class_id(self, cid):
        """切换班级"""
        self._current_class_id = cid; self._notify()

    def current_class(self):
        """获取当前班级对象"""
        if not self._current_class_id: return None
        return self._app_data.get_class_by_id(self._current_class_id)

    def subscribe(self, callback):
        """注册界面刷新回调"""
        self._listeners.append(callback)

    def _notify(self):
        """通知界面刷新"""
        for cb in self._listeners:
            try: cb()
            except: pass

    def save(self):
        """保存数据并通知"""
        self._storage.save(self._app_data); self._notify()

    # ---- 班级管理 ----
    def add_class(self, name):
        """新建班级"""
        klass = Klass(name=name); klass.groups.append(Group(name='默认组'))
        klass.rewards = get_default_rewards()
        self._app_data.classes.append(klass)
        self._current_class_id = klass.id; self.save(); return klass.id

    def rename_class(self, cid, new_name):
        """重命名班级"""
        k = self._app_data.get_class_by_id(cid)
        if k: k.name = new_name; self.save()

    def delete_class(self, cid):
        """删除班级"""
        self._app_data.classes = [c for c in self._app_data.classes if c.id != cid]
        if self._current_class_id == cid:
            self._current_class_id = self._app_data.classes[0].id if self._app_data.classes else None
        self.save()

    # ---- 学生管理 ----
    def add_student(self, sid, name, gid=''):
        """添加学生。sid=学号, name=姓名, gid=小组ID"""
        cls = self.current_class()
        if not cls or len(cls.students) >= self.MAX_STUDENTS: return None
        if sid.isdigit() and len(sid) == 1: sid = '0' + sid
        if any(s.student_id == sid for s in cls.students): return None
        s = Student(student_id=sid, name=name, group_id=gid)
        cls.students.append(s); self.save(); return s

    def delete_student(self, sid):
        """删除学生"""
        cls = self.current_class()
        if not cls: return False
        idx = next((i for i,s in enumerate(cls.students) if s.id==sid), -1)
        if idx>=0: del cls.students[idx]; self.save(); return True
        return False

    def move_student_group(self, sid, new_gid):
        """移动学生到另一个小组"""
        cls = self.current_class()
        if not cls: return False
        s = cls.get_student_by_id(sid)
        if s: s.group_id = new_gid or ''; self.save(); return True
        return False

    def import_students(self, data, gid=''):
        """批量导入学生。data=[(学号,姓名),...]。返回(成功,跳过)"""
        cls = self.current_class()
        if not cls: return 0, 0
        exist = {s.student_id for s in cls.students}; imp=skp=0
        for sid, name in data:
            if sid in exist: skp+=1; continue
            if len(cls.students)>=self.MAX_STUDENTS: break
            if sid.isdigit() and len(sid)==1: sid='0'+sid
            cls.students.append(Student(student_id=sid,name=name,group_id=gid))
            exist.add(sid); imp+=1
        if imp>0: self.save()
        return imp,skp

    # ---- 小组管理 ----
    def add_group(self, name, members=None):
        """新建小组"""
        cls = self.current_class()
        if not cls: return None
        g = Group(name=name); cls.groups.append(g)
        if members:
            for sid in members:
                s=cls.get_student_by_id(sid)
                if s and not s.group_id: s.group_id=g.id
        self.save(); return g

    def delete_group(self, gid):
        """删除小组（有成员时不能删）"""
        cls = self.current_class()
        if not cls: return False
        if any(s.group_id==gid for s in cls.students): return False
        cls.groups=[g for g in cls.groups if g.id!=gid]; self.save(); return True

    def rename_group(self, gid, name):
        """重命名小组"""
        cls=self.current_class()
        if cls:
            g=cls.get_group_by_id(gid)
            if g: g.name=name; self.save()

    def add_direct_group_points(self, gid, pts):
        """直接给小组加分"""
        cls=self.current_class()
        if cls:
            g=cls.get_group_by_id(gid)
            if g: g.direct_points+=pts; self.save()

    def subtract_direct_group_points(self, gid, pts):
        """直接给小组扣分"""
        cls=self.current_class()
        if cls:
            g=cls.get_group_by_id(gid)
            if g: g.direct_points-=pts; self.save()

    def compute_group_points(self):
        """计算所有小组总分"""
        cls=self.current_class()
        return cls.compute_group_points() if cls else {}

    # ---- 积分操作 ----
    def point_change(self, sid, delta, is_add, desc=''):
        """给学生加减分。sid=学生ID, delta=分值, is_add=True加分/False扣分"""
        cls=self.current_class()
        if not cls: return False
        s=cls.get_student_by_id(sid)
        if not s: return False
        val=abs(delta)
        if is_add:
            if s.double_points_until and time.time()<s.double_points_until: val*=2
            s.earned_points+=val
            s.transactions.append(Transaction(time.time(),'earn',val,desc or '教师加分',s.group_id))
        else:
            s.earned_points-=val
            s.transactions.append(Transaction(time.time(),'deduct',val,desc or '教师扣分',s.group_id))
        self.save(); return True

    def batch_point_operation(self, sids, delta, is_add, cat):
        """批量加减分。返回(成功数,失败数)"""
        sc=fc=0
        for sid in sids:
            if self.point_change(sid,delta,is_add,cat): sc+=1
            else: fc+=1
        return sc,fc

    def undo_last_operation(self, sid):
        """撤回学生的最后一次操作"""
        cls=self.current_class()
        if not cls: return None
        s=cls.get_student_by_id(sid)
        if not s: return None
        for i in range(len(s.transactions)-1,-1,-1):
            t=s.transactions[i]
            if t.type=='earn': s.earned_points-=t.points; del s.transactions[i]; s.transactions.append(Transaction(time.time(),'undo',0,'撤回上一步',s.group_id)); self.save(); return f'已撤销加分（{t.points}分）'
            elif t.type=='deduct': s.earned_points+=t.points; del s.transactions[i]; s.transactions.append(Transaction(time.time(),'undo',0,'撤回上一步',s.group_id)); self.save(); return f'已撤销扣分（{t.points}分）'
            elif t.type=='redeem':
                desc=t.description or ''
                idx=next((j for j,item in enumerate(s.items) if desc.find(item.name)!=-1 and not item.used),-1)
                if idx>=0: s.items.pop(idx); s.redeemed_points-=t.points; del s.transactions[i]; s.transactions.append(Transaction(time.time(),'undo',0,'撤回上一步',s.group_id)); self.save(); return f'已撤销兑换：{desc}（返还{t.points}分）'
                else: return '该奖励已被使用，无法撤销。'
        return '没有可撤回的操作'

    # ---- 积分商店 ----
    def add_reward(self, name, cost, cat='普通', desc=''):
        """添加奖品"""
        cls=self.current_class()
        if not cls: return None
        r=Reward(name=name,cost=cost,category=cat,description=desc)
        cls.rewards.append(r); self.save(); return r

    def delete_reward(self, rid):
        """删除奖品"""
        cls=self.current_class()
        if not cls: return False
        cls.rewards=[r for r in cls.rewards if r.id!=rid]; self.save(); return True

    def redeem_reward(self, sid, rid):
        """学生兑换奖品。成功返回None，失败返回错误信息"""
        cls=self.current_class()
        if not cls: return '数据错误'
        s=cls.get_student_by_id(sid); r=cls.get_reward_by_id(rid)
        if not s or not r: return '未找到学生或奖品'
        if s.available_points<r.cost: return '积分不足'
        s.redeemed_points+=r.cost
        s.items.append(StudentItem('item_'+str(int(time.time()*1000))+uuid.uuid4().hex[:4],r.id,r.name,time.time()))
        s.transactions.append(Transaction(time.time(),'redeem',r.cost,f'兑换 {r.name}'))
        self.save(); return None

    def buy_blind_box(self, sid):
        """购买盲盒。成功返回抽奖结果，失败返回错误信息"""
        cls=self.current_class()
        if not cls: return '数据错误'
        s=cls.get_student_by_id(sid)
        if not s: return '未找到学生'
        if s.available_points<10: return '积分不足'

        pool=[r for r in cls.rewards if not r.blind_box_excluded and r.id!='r_blindbox']
        if not pool: return '奖励池为空'

        # 加权随机抽奖
        weights={'传说':0.05,'史诗':0.10,'稀有':0.30,'普通':0.45}
        rand=random.random(); cum=0; selected=None
        for cat,prob in weights.items():
            cum+=prob
            if rand<=cum:
                items=[r for r in pool if r.category==cat]
                if items: selected=random.choice(items)
                break
        if not selected: selected=random.choice(pool)

        s.redeemed_points+=10
        s.transactions.append(Transaction(time.time(),'redeem',10,'购买盲盒券'))
        s.items.append(StudentItem('item_'+str(int(time.time()*1000))+uuid.uuid4().hex[:4],selected.id,selected.name,time.time()))
        s.transactions.append(Transaction(time.time(),'blindbox',0,f'盲盒抽取: {selected.name}'))
        self.save()
        return f'恭喜！抽到了 {selected.name} ({selected.category}级)'

    def use_item(self, sid, iid):
        """使用背包里的奖品"""
        cls=self.current_class()
        if not cls: return '数据错误'
        s=cls.get_student_by_id(sid)
        if not s: return '未找到学生'
        idx=next((i for i,item in enumerate(s.items) if item.id==iid),-1)
        if idx<0: return '物品不存在'
        item=s.items[idx]
        if item.used: return '物品已被使用'
        if item.reward_id=='r_blindbox':
            return self._use_blind_box(s,idx)
        if item.reward_id=='r_epic4':
            return self._use_double_card(s,idx)
        if item.reward_id=='r_legend':
            cnt=sum(1 for t in s.transactions if t.type=='use' and '提早下课券' in (t.description or ''))
            if cnt>=3: return '本学期已用完3次机会'
        if item.reward_id=='r_epic1':
            self.add_direct_group_points(s.group_id,5)
        s.items.pop(idx)
        s.transactions.append(Transaction(time.time(),'use',0,f'使用奖励: {item.name}'))
        self.save(); return f'成功使用 {item.name}'

    def _use_blind_box(self, s, idx):
        """使用盲盒券（内部方法）"""
        cls=self.current_class()
        pool=[r for r in cls.rewards if not r.blind_box_excluded and r.id!='r_blindbox']
        if not pool: return '奖励池为空'
        selected=random.choice(pool)
        s.items.pop(idx)
        s.items.append(StudentItem('item_'+str(int(time.time()*1000))+uuid.uuid4().hex[:4],selected.id,selected.name,time.time()))
        s.transactions.append(Transaction(time.time(),'blindbox',0,f'盲盒抽取: {selected.name}'))
        self.save(); return f'恭喜！抽到了 {selected.name} ({selected.category}级)'

    def _use_double_card(self, s, idx):
        """使用双倍积分卡（内部方法）"""
        if s.double_points_until and s.double_points_until>time.time(): return '已有双倍效果生效中'
        ws=_get_week_start()
        s.double_points_until=ws+7*24*60*60-1
        s.items.pop(idx)
        s.transactions.append(Transaction(time.time(),'use',0,'使用双倍积分卡'))
        self.save(); return '双倍积分卡生效！本周加分翻倍'

    # ---- 随机抽取 ----
    def random_pick_students(self, cnt):
        """随机抽取N个学生（低分学生更容易被抽到）"""
        cls=self.current_class()
        if not cls or not cls.students: return []
        sts=list(cls.students)
        if cnt>=len(sts): result=random.sample(sts,len(sts))
        else:
            w=[1.0/(abs(s.available_points)+1) for s in sts]
            picked=[]; picked_idx=set()
            for _ in range(cnt):
                avail=[(i,ww) for i,ww in enumerate(w) if i not in picked_idx]
                if not avail: break
                total=sum(ww for _,ww in avail)
                r=random.random()*total if total>0 else 0; cum=0
                for i,ww in avail:
                    cum+=ww
                    if r<cum or cum==total: picked.append(sts[i]); picked_idx.add(i); break
            result=picked
        return [{'id':s.id,'student_id':s.student_id,'name':s.name,'available':s.available_points} for s in result]

    def random_pick_groups(self, cnt):
        """随机抽取N个小组"""
        cls=self.current_class()
        if not cls or not cls.groups: return []
        grps=random.sample(cls.groups,min(cnt,len(cls.groups)))
        return [{'id':g.id,'name':g.name} for g in grps]

    # ---- 数据分析 ----
    def compute_category_scores(self):
        """计算每个学生在6个维度的得分"""
        cls=self.current_class()
        if not cls: return {}
        result={}
        for s in cls.students:
            scores={cat:0 for cat in CATEGORY_DIMENSIONS}
            for t in s.transactions:
                desc=t.description or ''
                for cat in CATEGORY_DIMENSIONS:
                    if cat in desc or desc==cat:
                        if t.type=='earn': scores[cat]+=t.points
                        elif t.type=='deduct': scores[cat]-=t.points
            result[s.id]={'student_id':s.student_id,'name':s.name,'scores':scores,'transactions':s.transactions}
        return result

    # ---- 每周统计 ----
    def get_weekly_stats(self):
        """获取本周扣分达人(>=3分)和进步之星(任意维度+2分)"""
        cls=self.current_class()
        if not cls: return [],[]
        import datetime as dt_mod
        now=dt_mod.datetime.now()
        ws_start=now.replace(hour=0,minute=0,second=0,microsecond=0)-dt_mod.timedelta(days=now.weekday())
        last_ws=ws_start-dt_mod.timedelta(days=7)
        ws_ts=ws_start.timestamp(); lws_ts=last_ws.timestamp()

        def get_dim_scores(s, start, end):
            sc={cat:0 for cat in CATEGORY_DIMENSIONS}
            for t in s.transactions:
                if start<=t.timestamp<end:
                    desc=t.description or ''
                    for cat in CATEGORY_DIMENSIONS:
                        if cat in desc or desc==cat:
                            if t.type=='earn': sc[cat]+=t.points
                            elif t.type=='deduct': sc[cat]-=t.points
            return sc

        dl=[]; el=[]
        for s in cls.students:
            dt=sum(t.points for t in s.transactions if t.type=='deduct' and t.timestamp>=ws_ts)
            if dt>=3: dl.append({'name':s.name,'student_id':s.student_id,'points':dt})
            tw=get_dim_scores(s,ws_ts,now.timestamp())
            lw=get_dim_scores(s,lws_ts,ws_ts)
            for cat in CATEGORY_DIMENSIONS:
                if tw.get(cat,0)-lw.get(cat,0)>=2:
                    el.append({'name':s.name,'student_id':s.student_id,'category':cat,'diff':tw[cat]-lw[cat]}); break
        return dl,el

    # ---- 导出/导入 ----
    def export_data(self, fp):
        return self._storage.export_data(self._app_data,fp)

    def import_data(self, fp):
        imported=self._storage.import_data(fp)
        if imported:
            self._app_data=imported
            self._current_class_id=self._app_data.classes[0].id if self._app_data.classes else None
            self._storage.save(self._app_data); self._notify(); return None
        return '导入失败：无效文件'