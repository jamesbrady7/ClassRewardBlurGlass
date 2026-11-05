# -*- mode: python ; coding: utf-8 -*-
# PyInstaller onefile 打包配置（PySide6 + QML 毛玻璃版）
#
# 用法：
#   pyinstaller ClassRewardHelperGlass.spec --noconfirm
#
# 产物：dist/ClassRewardHelper.exe（单文件；运行时自动解包 QML / 字体 / 图标）
# 数据：首次运行会在 exe 同目录生成 class_reward_data.json 与 _run.log

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('qml', 'qml'),          # QML 界面 + qml/assets
        ('assets', 'assets'),    # MiSans 字体 / 应用图标
    ],
    hiddenimports=[
        'PySide6.QtCore',
        'PySide6.QtGui',
        'PySide6.QtQml',
        'PySide6.QtQuick',
        'PySide6.QtQuickControls2',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='ClassRewardHelper',
    icon='assets/app_icon.ico',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
