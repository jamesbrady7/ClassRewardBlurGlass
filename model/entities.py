# ============================================================
# 文件功能：定义整个应用程序的所有数据"容器"类
# 对应Tab：全部
# 依赖库：time, uuid, json（Python内置）
# 使用方法：其他模块通过 from model.entities import ... 导入
# ============================================================
# 
# 本文件存放所有"数据单元"的定义。
# 可以把这些类理解为 Excel 表格的一行：
#   Transaction = 一条积分变动记录
#   Student    = 一个学生的全部信息
#   Group      = 一个小组
#   Reward     = 积分商店的一个奖品
#   Klass      = 一个班级（含学生、小组、奖品）
#   AppData    = 整个软件的全部数据
# 
# ============================================================

import time         # 获取当前时间戳，作为记录的唯一ID
import uuid         # 生成随机唯一ID，确保每条记录不重复

# -----------------------------------------------------------
# 下面这6个名称是"加减分维度"的固定列表
# 意思是：每次给一个学生加分或扣分，都要选是哪个维度
# 比如"课堂表现好 +5分"、或者"作业没交 -2分"
# -----------------------------------------------------------
CATEGORY_DIMENSIONS = ['课堂', '考试', '听写', '背诵', '作业', '纪律']

# 数据格式的版本号，将来如果改了数据格式，可以靠这个号做兼容
DATA_VERSION = '4.3'


# ============================================================
# Transaction 类：记录学生的一次积分变动
# 比如：2024-01-15 课堂 +5分，这就是一行记录
# ============================================================
class Transaction:
    """
    一笔积分变动记录。
    属性说明：
      timestamp:   发生时间（浮点数，1970年1月1日起的秒数）
      type:        变动类型，只有5种：
                   'earn'     = 加分
                   'deduct'   = 扣分
                   'redeem'   = 兑换（花积分买奖品）
                   'use'      = 使用（消耗手中的奖品）
                   'blindbox' = 盲盒（随机抽奖品）
      points:      变动了多少分（永远是正数）
      description: 说明文字，比如"课堂"、"作业"等
      group_id:    当时所属的小组ID（可能为空）
    """
    def __init__(self, timestamp, tx_type, points, description='', group_id=''):
        # 下面5行是把传入参数保存到对象自己的属性里
        self.timestamp = timestamp
        self.type = tx_type
        self.points = points
        self.description = description
        self.group_id = group_id

    def to_dict(self):
        """把对象转换成字典（方便存JSON文件）"""
        return {
            'timestamp': self.timestamp,
            'type': self.type,
            'points': self.points,
            'description': self.description,
            'groupId': self.group_id,
        }

    @classmethod
    def from_dict(cls, d):
        """从字典还原对象（从JSON文件读出后恢复）"""
        return cls(
            timestamp=d.get('timestamp', 0),
            tx_type=d.get('type', 'earn'),
            points=d.get('points', 0),
            description=d.get('description', ''),
            group_id=d.get('groupId', ''),
        )


# ============================================================
# StudentItem 类：记录学生"背包"里拥有的一个奖品
# 比如：学生用10积分兑换了一张"免死金牌"
#      那么这个免死金牌就是 StudentItem
# ============================================================
class StudentItem:
    """
    学生拥有的一个奖品。
    属性说明：
      id:            这条记录的独立ID（uuid随机生成）
      reward_id:     对应奖品的ID（指向Reward.id）
      name:          奖品名称
      acquired_time: 获得时间
      used:          是否已经被使用（有些奖品可以用掉）
    """
    def __init__(self, item_id, reward_id, name, acquired_time, used=False):
        self.id = item_id
        self.reward_id = reward_id
        self.name = name
        self.acquired_time = acquired_time
        self.used = used

    def to_dict(self):
        """转成字典存JSON"""
        return {
            'id': self.id,
            'rewardId': self.reward_id,
            'name': self.name,
            'acquiredTime': self.acquired_time,
        }

    @classmethod
    def from_dict(cls, d):
        """从字典还原"""
        return cls(
            item_id=d.get('id', ''),
            reward_id=d.get('rewardId', ''),
            name=d.get('name', ''),
            acquired_time=d.get('acquiredTime', 0),
        )


# ============================================================
# Student 类：一个学生的全部信息
# 像一个"档案袋"，装了学号、姓名、分数、交易历史
# ============================================================
class Student:
    """
    学生数据。
    属性说明：
      id:                  内部唯一ID（程序自己生成的，不可见）
      student_id:          学号，比如 '01', '02'
      name:                姓名
      group_id:            所属小组的ID（空字符串=未分组）
      earned_points:       总共获得过的分数
      redeemed_points:     已经花掉（兑换）的分数
      double_points_until: 双倍积分卡有效期截止时间戳
      items:               背包里的奖品列表（list of StudentItem）
      transactions:        所有积分变动记录（list of Transaction）
    """
    def __init__(self, student_id, name, group_id='',
                 earned_points=0, redeemed_points=0,
                 double_points_until=0, sid=''):
        # 如果没有指定内部ID，就用时间戳+随机数生成一个
        if not sid:
            sid = 's' + str(int(time.time() * 1000)) + uuid.uuid4().hex[:6]
        self.id = sid
        self.student_id = student_id
        self.name = name
        self.group_id = group_id
        self.earned_points = earned_points
        self.redeemed_points = redeemed_points
        self.double_points_until = double_points_until
        self.items = []           # 背包里的奖品，初始为空
        self.transactions = []    # 积分变动记录，初始为空

    @property
    def available_points(self):
        """计算可用的分数 = 总得分 - 已花掉的分数"""
        return self.earned_points - self.redeemed_points

    def to_dict(self):
        """转字典存JSON"""
        return {
            'id': self.id,
            'studentId': self.student_id,
            'name': self.name,
            'groupId': self.group_id,
            'earnedPoints': self.earned_points,
            'redeemedPoints': self.redeemed_points,
            'doublePointsUntil': self.double_points_until,
            'items': [i.to_dict() for i in self.items],
            'transactions': [t.to_dict() for t in self.transactions],
        }

    @classmethod
    def from_dict(cls, d):
        """从字典还原"""
        s = cls(
            student_id=d.get('studentId', ''),
            name=d.get('name', ''),
            group_id=d.get('groupId', ''),
            earned_points=d.get('earnedPoints', 0),
            redeemed_points=d.get('redeemedPoints', 0),
            double_points_until=d.get('doublePointsUntil', 0),
            sid=d.get('id', ''),
        )
        # 还原背包中的奖品
        s.items = [StudentItem.from_dict(i) for i in d.get('items', [])]
        # 还原积分变动记录
        s.transactions = [Transaction.from_dict(t) for t in d.get('transactions', [])]
        return s


# ============================================================
# Group 类：一个小组
# ============================================================
class Group:
    """
    小组数据。
    属性：
      id:            唯一ID
      name:          小组名称，如"探索组"
      direct_points: 直接给小组的加分（不算学生个人分）
    """
    def __init__(self, name, direct_points=0, gid=''):
        if not gid:
            gid = 'g' + str(int(time.time() * 1000)) + uuid.uuid4().hex[:6]
        self.id = gid
        self.name = name
        self.direct_points = direct_points

    def to_dict(self):
        return {'id': self.id, 'name': self.name, 'directPoints': self.direct_points}

    @classmethod
    def from_dict(cls, d):
        return cls(name=d.get('name', ''), direct_points=d.get('directPoints', 0), gid=d.get('id', ''))


# ============================================================
# Reward 类：积分商店的一个奖品
# ============================================================
class Reward:
    """
    奖品数据。
    属性：
      id:                 唯一ID
      name:               奖品名称
      cost:               需要的积分
      category:           稀有度等级（普通/稀有/史诗/传说）
      description:        奖品说明
      blind_box_excluded: 如果为True，这个奖品不会出现在盲盒抽奖池中
    """
    def __init__(self, name, cost, category='普通',
                 description='', blind_box_excluded=False, rid=''):
        if not rid:
            rid = 'r' + str(int(time.time() * 1000)) + uuid.uuid4().hex[:4]
        self.id = rid
        self.name = name
        self.cost = cost
        self.category = category
        self.description = description
        self.blind_box_excluded = blind_box_excluded

    def to_dict(self):
        return {'id': self.id, 'name': self.name, 'cost': self.cost,
                'category': self.category, 'description': self.description,
                'blindBoxExcluded': self.blind_box_excluded}

    @classmethod
    def from_dict(cls, d):
        return cls(name=d.get('name', ''), cost=d.get('cost', 0),
                   category=d.get('category', '普通'),
                   description=d.get('description', ''),
                   blind_box_excluded=d.get('blindBoxExcluded', False),
                   rid=d.get('id', ''))


# ============================================================
# Klass 类：一个班级（包含学生、小组、奖品）
# ============================================================
class Klass:
    """
    一个班级，"Klass"是为了避免和Python关键字class冲突。
    属性：
      id:       唯一ID
      name:     班级名称
      groups:   班级下的小组列表
      students: 班级下的学生列表
      rewards:  班级的积分商店奖品列表
    """
    def __init__(self, name='一年级一班', cid=''):
        if not cid:
            cid = 'c' + str(int(time.time() * 1000)) + uuid.uuid4().hex[:4]
        self.id = cid
        self.name = name
        self.groups = []
        self.students = []
        self.rewards = []

    # ---- 下面3个是根据ID查找对应数据的方法 ----
    def get_student_by_id(self, sid):
        """用内部ID找学生，找不到返回None"""
        for s in self.students:
            if s.id == sid:
                return s
        return None

    def get_group_by_id(self, gid):
        """用内部ID找小组"""
        for g in self.groups:
            if g.id == gid:
                return g
        return None

    def get_reward_by_id(self, rid):
        """用内部ID找奖品"""
        for r in self.rewards:
            if r.id == rid:
                return r
        return None

    def compute_group_points(self):
        """
        计算每个小组的总分。
        总分 = 小组直接加分 + 成员个人的贡献分。
        返回字典：{小组ID: 总分}
        """
        # 先拿到每个小组的直接加分
        gp = {g.id: g.direct_points for g in self.groups}
        # 遍历所有学生的所有积分记录，累加到对应小组
        for s in self.students:
            for t in s.transactions:
                if t.type == 'earn' and t.group_id:
                    gp[t.group_id] = gp.get(t.group_id, 0) + t.points
                elif t.type == 'deduct' and t.group_id:
                    gp[t.group_id] = gp.get(t.group_id, 0) - t.points
        return gp

    def to_dict(self):
        return {'id': self.id, 'name': self.name,
                'groups': [g.to_dict() for g in self.groups],
                'students': [s.to_dict() for s in self.students],
                'rewards': [r.to_dict() for r in self.rewards]}

    @classmethod
    def from_dict(cls, d):
        k = cls(name=d.get('name', ''), cid=d.get('id', ''))
        k.groups = [Group.from_dict(g) for g in d.get('groups', [])]
        k.students = [Student.from_dict(s) for s in d.get('students', [])]
        k.rewards = [Reward.from_dict(r) for r in d.get('rewards', [])]
        return k


# ============================================================
# AppData 类：整个软件的最顶层数据容器
# 可能管理多个班级（点击"新班级"按钮就新增一个）
# ============================================================
class AppData:
    """应用的根数据。属性：version（数据版本号）、classes（班级列表）"""
    def __init__(self, version=DATA_VERSION):
        self.version = version
        self.classes = []

    def get_class_by_id(self, cid):
        """用ID找班级"""
        for c in self.classes:
            if c.id == cid:
                return c
        return None

    def to_dict(self):
        return {'version': self.version,
                'classes': [c.to_dict() for c in self.classes]}

    @classmethod
    def from_dict(cls, d):
        data = cls(version=d.get('version', DATA_VERSION))
        data.classes = [Klass.from_dict(c) for c in d.get('classes', [])]
        return data


# ============================================================
# 下面两个函数生成默认数据（第一次使用时自动创建）
# ============================================================

def get_default_rewards():
    """
    生成默认的16个奖品列表。
    这是程序内置的奖品，用户后面可以自己添加或删除。
    """
    return [
        Reward('英语课换座券', 5, '普通', '换同桌体验，一节课的新鲜感。'),
        Reward('问题转移券', 5, '普通', '巧妙化解提问尴尬。'),
        Reward('听写预知券', 5, '普通', '提前知道3个词，满分更容易。'),
        Reward('水火救援券', 5, '普通', '英雄救美（同学）的好机会。'),
        Reward('夸夸券', 5, '普通', '让爸妈听到老师的表扬，全家开心。'),
        Reward('免死金牌', 10, '稀有', '一次"免罪"机会，护身符般存在。'),
        Reward('有福同享券', 10, '稀有', '和朋友分享快乐，友谊加倍。'),
        Reward('作业减半券', 10, '稀有', '少写一半作业，省时又省力。'),
        Reward('免背书券', 10, '稀有', '逃过一次背诵，轻松过关。'),
        Reward('班干部体验券', 10, '稀有', '当一天小干部，过把"官瘾"。'),
        Reward('谈心沟通券', 10, '稀有', '和老师一对一聊心事。'),
        Reward('小组加分券', 15, '史诗', '直接给小组加5分。'),
        Reward('心愿券', 15, '史诗', '打电话给爸妈，实现一个小愿望！'),
        Reward('作业免除券', 15, '史诗', '这次的英语作业不用做啦！'),
        Reward('双倍积分卡', 15, '史诗', '使用后一周内所有加分翻倍。'),
        Reward('提早下课券', 20, '传说', '提前5分钟下课！（需老师同意）'),
        Reward('盲盒券', 10, '稀有', '随机抽取一张奖励。', blind_box_excluded=True),
    ]


def get_default_klass():
    """
    生成一个带示例数据的默认班级。
    包含两个小组、两个学生及其积分记录。
    """
    k = Klass(name='一年级一班')
    k.groups = [Group('探索组'), Group('智慧组')]
    g1, g2 = k.groups[0].id, k.groups[1].id
    now = time.time()
    # 创建学生1：李小乐，20分（分到探索组，让花名册条纹与小组榜都有色彩）
    s1 = Student(student_id='01', name='李小乐', group_id=g1, earned_points=20)
    s1.transactions = [
        Transaction(now - 86400, 'earn', 20, '课堂', g1),
        Transaction(now - 172800, 'earn', 15, '听写', g1),
    ]
    # 创建学生2：赵小琪，15分，花掉了5分（智慧组）
    s2 = Student(student_id='02', name='赵小琪', group_id=g2, earned_points=15, redeemed_points=5)
    s2.items = [StudentItem('item1', 'r_rare1', '免死金牌', now)]
    s2.transactions = [
        Transaction(now - 172800, 'earn', 15, '作业', g2),
        Transaction(now - 86400, 'redeem', 5, '兑换免死金牌', g2),
    ]
    k.students = [s1, s2]
    k.rewards = get_default_rewards()
    return k