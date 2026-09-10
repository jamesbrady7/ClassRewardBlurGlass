# 生成演示数据 _demo_data.json（仅用于截图验证 UI，不影响真实数据）
import os, sys, time, random
sys.path.insert(0, os.getcwd())
from model.entities import (AppData, Klass, Student, Group, Reward,
                            Transaction, StudentItem, CATEGORY_DIMENSIONS,
                            get_default_rewards)
from model.storage import StorageManager

random.seed(11)
now = time.time()
dims = CATEGORY_DIMENSIONS

k = Klass('三年级四班')
groups = [Group('探索组'), Group('智慧组'), Group('梦想组'), Group('先锋组')]
k.groups = groups
k.rewards = get_default_rewards()
for nm, cost, cat in [
    ('座位自由券', 4, '普通'), ('课堂发言券', 6, '普通'),
    ('迟到免罚券', 12, '稀有'), ('课间点歌券', 12, '稀有'),
    ('当小班长一天', 20, '史诗'), ('免一次值日', 18, '史诗'),
    ('心愿实现卡', 25, '传说'), ('期末免考券', 30, '传说'),
]:
    k.rewards.append(Reward(nm, cost, cat))

sids = ['%02d' % i for i in range(1, 16)]
names = ['陈果', '林小满', '王浩然', '张曦', '李思远', '周子涵', '吴明轩',
         '郑乐瑶', '孙一诺', '黄嘉豪', '徐可欣', '高子墨', '罗小雨', '沈星辰', '许诺']

students = []
for idx, (sid, name) in enumerate(zip(sids, names)):
    g = groups[idx % len(groups)]
    s = Student(student_id=sid, name=name, group_id=g.id)
    txs = []
    cur = 0
    d = 0
    # 有界随机游走：累计始终落在 0..9（<10），制造高低起伏与正负交替
    while d < 20:
        d += 1
        if random.random() < 0.34:
            continue
        step = random.choice([-2, -1, 1, 1, 2, 3])
        nv = max(0, min(9, cur + step))
        eff = nv - cur
        if eff == 0:
            continue
        ts = now - d * 86400 - random.randint(0, 2500)
        cat = dims[(idx + d) % 6]
        txs.append(Transaction(ts, 'earn' if eff > 0 else 'deduct', abs(eff), cat, g.id))
        cur = nv
    s.earned_points = sum(t.points if t.type == 'earn' else -t.points for t in txs)
    s.transactions = txs
    students.append(s)
k.students = students

# 给可用分最高的 3 个学生放进背包（兑换免死金牌）
buddies = sorted(range(len(students)), key=lambda i: students[i].earned_points, reverse=True)[:3]
for i in buddies:
    s = students[i]
    rw = next(r for r in k.rewards if r.name == '免死金牌')
    s.redeemed_points += rw.cost
    s.items.append(StudentItem('demo_it' + s.student_id, rw.id, rw.name, now))
    s.transactions.append(Transaction(now - 3600, 'redeem', rw.cost, '兑换 ' + rw.name, s.group_id))

data = AppData()
data.classes = [k]
StorageManager(os.path.join(os.getcwd(), '_demo_data.json')).save(data)
print('seeded students=', len(k.students), 'rewards=', len(k.rewards))
