# ============================================================
# 文件功能：批量导入学生对话框
# 对应Tab：花名册
# 依赖库：PyQt5
# 使用方法：dialog = ImportStudentDialog(controller, parent)
# ============================================================
# 这个窗口让用户可以粘贴CSV格式的学生数据（学号,姓名 每行一个）
from PyQt5.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QTextEdit, QComboBox, QFileDialog)
from model.style_config import get_config

class ImportStudentDialog(QDialog):
    """批量导入学生：粘贴"学号,姓名"数据或上传CSV文件，选择目标小组，一键导入"""
    def __init__(self, controller, parent=None):
        super().__init__(parent); self.ctrl = controller
        self._data = []  # 解析后的 (学号, 姓名) 列表
        self.setWindowTitle("批量导入学生"); self.setMinimumSize(450, 350)
        self._build()

    def _build(self):
        lo = QVBoxLayout(self); lo.setSpacing(10)
        lo.addWidget(QLabel("粘贴CSV数据或选择文件（每行格式：学号,姓名）:"))
        self._txt = QTextEdit(); self._txt.setPlaceholderText("01,李小乐\n02,赵小琪"); lo.addWidget(self._txt)
        br = QHBoxLayout()
        fb = QPushButton("选择文件"); fb.clicked.connect(self._on_file); br.addWidget(fb)
        pb = QPushButton("解析预览"); pb.clicked.connect(self._on_parse); br.addWidget(pb); br.addStretch()
        lo.addLayout(br)
        lo.addWidget(QLabel("目标小组:"))
        self._gp = QComboBox(); self._gp.addItem("无小组","")
        cls = self.ctrl.current_class()
        if cls:
            for g in cls.groups: self._gp.addItem(g.name, g.id)
        lo.addWidget(self._gp)
        self._preview = QLabel(""); lo.addWidget(self._preview)
        bl = QHBoxLayout(); bl.addStretch()
        ib = QPushButton("开始导入"); ib.clicked.connect(self._on_import); ib.setStyleSheet(get_config().accent_btn()); bl.addWidget(ib)
        lo.addLayout(bl)

    def _on_file(self):
        path, _ = QFileDialog.getOpenFileName(self, "选择CSV文件", "", "CSV (*.csv *.txt);;All (*)")
        if path:
            with open(path, 'r', encoding='utf-8') as f: self._txt.setText(f.read())
            self._on_parse()

    def _on_parse(self):
        text = self._txt.toPlainText()
        lines = text.strip().split('\n')
        self._data = []
        for line in lines:
            parts = line.replace('\t',',').split(',')
            if len(parts) >= 2:
                sid = parts[0].strip().strip('"').strip("'")
                name = parts[1].strip().strip('"').strip("'")
                if sid and name: self._data.append((sid, name))
        self._preview.setText(f"解析到 {len(self._data)} 条数据")

    def _on_import(self):
        if not self._data: return
        gid = self._gp.currentData()
        imp, skp = self.ctrl.import_students(self._data, gid)
        from PyQt5.QtWidgets import QMessageBox
        QMessageBox.information(self, "导入完成", f"成功: {imp}人, 跳过: {skp}人")
        self.accept()