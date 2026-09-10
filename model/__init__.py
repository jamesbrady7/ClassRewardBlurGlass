# ============================================================
# 文件功能：model包的初始化文件，统一导出所有数据类和配置
# 对应Tab：全部
# 依赖库：无
# 使用方法：from model import StorageManager, StyleConfig
# ============================================================

# 导出数据实体类（学生、小组、奖品等"数据容器"）
from .entities import (
    AppData, Klass, Student, Group, Reward,
    Transaction, StudentItem,
    CATEGORY_DIMENSIONS, DATA_VERSION,
    get_default_klass, get_default_rewards,
)

# 导出数据存储管理器（负责读写JSON文件）
from .storage import StorageManager

# 导出样式配置（控制界面的颜色、字体、大小）
from .style_config import StyleConfig, get_config