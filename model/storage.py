# ============================================================
# 文件功能：负责把应用程序的数据读写到本地的 JSON 文件中
# 对应Tab：全部（底层存储）
# 依赖库：json, os, shutil（Python内置）
# 使用方法：storage = StorageManager(); data = storage.load()
# ============================================================
import json, os, shutil
from datetime import datetime
from typing import Optional
from .entities import AppData, DATA_VERSION, get_default_klass

class StorageManager:
    """数据存储管理器。像一个"文件柜管理员"，负责保存和读取数据。"""
    DEFAULT_FILENAME = 'class_reward_data.json'

    def __init__(self, filepath=None):
        # 如果没指定路径，就放在model上级目录
        if filepath is None:
            filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', self.DEFAULT_FILENAME)
        self._filepath = filepath

    @property
    def filepath(self):
        """返回 JSON 文件路径"""
        return self._filepath

    def load(self):
        """从 JSON 文件加载数据，文件不存在或损坏就创建默认数据"""
        if os.path.exists(self._filepath):
            try:
                with open(self._filepath, 'r', encoding='utf-8') as f:
                    raw = json.load(f)
                # 把字典转成对象
                app_data = AppData.from_dict(raw)
                # 检查旧数据格式，补全缺失字段
                self._migrate_data(app_data)
                return app_data
            except (json.JSONDecodeError, KeyError, TypeError):
                # 文件损坏了，备份它
                backup_name = self._filepath + '.backup.' + datetime.now().strftime('%Y%m%d_%H%M%S')
                try: shutil.copy2(self._filepath, backup_name)
                except: pass
        # 创建默认数据
        return self._create_default()

    def save(self, app_data):
        """保存数据到 JSON 文件（先写临时文件再替换，防止断电损坏）"""
        try:
            data_dict = app_data.to_dict()
            tmp_path = self._filepath + '.tmp'
            with open(tmp_path, 'w', encoding='utf-8') as f:
                json.dump(data_dict, f, ensure_ascii=False, indent=2)
            os.replace(tmp_path, self._filepath)
            return True
        except (IOError, OSError):
            return False

    def export_data(self, app_data, filepath):
        """导出数据到指定文件"""
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(app_data.to_dict(), f, ensure_ascii=False, indent=2)
            return True
        except (IOError, OSError):
            return False

    def import_data(self, filepath):
        """从指定文件导入数据"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                raw = json.load(f)
            app_data = AppData.from_dict(raw)
            app_data.version = DATA_VERSION
            self._migrate_data(app_data)
            return app_data
        except (json.JSONDecodeError, KeyError, TypeError, IOError):
            return None

    def _create_default(self):
        """创建默认数据（第一次使用程序时）"""
        app_data = AppData()
        app_data.classes = [get_default_klass()]
        return app_data

    def _migrate_data(self, app_data):
        """兼容旧数据：自动补上缺失的字段"""
        app_data.version = DATA_VERSION
        for klass in app_data.classes:
            # 补全小组字段
            for group in klass.groups:
                if not hasattr(group, 'direct_points'): group.direct_points = 0
            # 补全学生字段
            for student in klass.students:
                if not hasattr(student, 'double_points_until'): student.double_points_until = 0
                if not hasattr(student, 'items'): student.items = []
            # 补全奖品字段
            for reward in klass.rewards:
                if not hasattr(reward, 'category') or not reward.category: reward.category = '普通'
                if not hasattr(reward, 'description'): reward.description = ''
                if not hasattr(reward, 'blind_box_excluded'): reward.blind_box_excluded = False