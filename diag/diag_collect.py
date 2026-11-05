# -*- coding: utf-8 -*-
r"""
班级激励助手 · 学校电脑环境诊断工具

双击运行后：
  1. 收集 Windows / CPU / 内存 / 显卡 / 显示器 / DPI 缩放 / 桌面合成 / 动效 / 电源方案
  2. 收集应用进程（含 onefile 的父子进程）、可移动磁盘、最近的程序错误日志
  3. 查找并打包应用旁边的 _run.log（新版会包含 [sys] / [drag] / [resize] 诊断日志）
  4. 截一张当前屏幕，全部打包成 zip 到桌面，带回开发机分析

只读取信息，不会上传任何内容；不复制学生名单数据（class_reward_data.json）。
可选：若检测到残留的「班级激励助手」进程，会询问是否结束，方便弹出 U 盘。

命令行（自动化测试用）：
  diag_collect.exe --silent --out C:\Temp\diag_out
"""
import ctypes
import datetime
import getpass
import os
import platform
import shutil
import socket
import subprocess
import sys
import tempfile
import zipfile
from ctypes import wintypes

TOOL_VERSION = "1.0 (2026-11-03)"
CREATE_NO_WINDOW = 0x08000000
APP_NAME_MARKERS = ("班级激励助手", "ClassRewardHelper")


# ============================================================
# 基础工具
# ============================================================
def decode_console(b):
    if not b:
        return ""
    for enc in ("utf-8", "gbk", "mbcs"):
        try:
            return b.decode(enc)
        except Exception:
            pass
    return b.decode("utf-8", "replace")


def run_ps(script, timeout=35):
    """跑 PowerShell（强制 UTF-8 输出），返回文本；失败返回错误文本。"""
    try:
        cmd = [
            "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
            "-Command",
            "$OutputEncoding=[Console]::OutputEncoding=[Text.Encoding]::UTF8; " + script,
        ]
        cp = subprocess.run(cmd, capture_output=True, timeout=timeout,
                            creationflags=CREATE_NO_WINDOW)
        out = cp.stdout.decode("utf-8", "replace").strip()
        err = cp.stderr.decode("utf-8", "replace").strip()
        return out if out else err
    except subprocess.TimeoutExpired:
        return "(PowerShell 超时)"
    except Exception as e:
        return "(PowerShell 执行失败: %r)" % (e,)


def run_cmd(args, timeout=20):
    try:
        cp = subprocess.run(args, capture_output=True, timeout=timeout,
                            creationflags=CREATE_NO_WINDOW)
        out = decode_console(cp.stdout).strip()
        err = decode_console(cp.stderr).strip()
        return out if out else err
    except Exception as e:
        return "(命令执行失败: %r)" % (e,)


def mb(text, flags=0):
    try:
        if sys.stdout and not getattr(sys, "frozen", False):
            print(text, flush=True)
    except Exception:
        pass
    try:
        ctypes.windll.user32.MessageBoxW(None, text, "班级激励助手 · 环境诊断",
                                         flags | 0x1000)  # MB_SYSTEMMODAL
    except Exception:
        pass


def desktop_dir():
    try:
        buf = ctypes.create_unicode_buffer(260)
        # CSIDL_DESKTOPDIRECTORY = 0x0010
        if ctypes.windll.shell32.SHGetFolderPathW(None, 0x0010, None, 0, buf) == 0:
            p = buf.value
            if p:
                return p
    except Exception:
        pass
    return os.path.join(os.path.expanduser("~"), "Desktop")


def enable_dpi_awareness():
    """让显示器枚举拿到物理像素和真实缩放，而不是被系统虚拟化。"""
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)  # PER_MONITOR_AWARE
        return
    except Exception:
        pass
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass


# ============================================================
# 显示器 / DPI / 虚拟桌面
# ============================================================
class RECT(ctypes.Structure):
    _fields_ = [("left", wintypes.LONG), ("top", wintypes.LONG),
                ("right", wintypes.LONG), ("bottom", wintypes.LONG)]


class MONITORINFOEXW(ctypes.Structure):
    _fields_ = [("cbSize", wintypes.DWORD),
                ("rcMonitor", RECT),
                ("rcWork", RECT),
                ("dwFlags", wintypes.DWORD),
                ("szDevice", wintypes.WCHAR * 32)]


MONITORENUMPROC = ctypes.WINFUNCTYPE(
    ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p,
    ctypes.POINTER(RECT), ctypes.c_ssize_t)


def collect_monitors():
    lines = []
    try:
        user32 = ctypes.windll.user32
        user32.EnumDisplayMonitors.argtypes = [
            ctypes.c_void_p, ctypes.c_void_p, MONITORENUMPROC, ctypes.c_ssize_t]
        user32.GetMonitorInfoW.argtypes = [ctypes.c_void_p, ctypes.POINTER(MONITORINFOEXW)]

        shcore = None
        try:
            shcore = ctypes.windll.shcore
            shcore.GetDpiForMonitor.argtypes = [
                ctypes.c_void_p, ctypes.c_int,
                ctypes.POINTER(ctypes.c_uint), ctypes.POINTER(ctypes.c_uint)]
            shcore.GetDpiForMonitor.restype = ctypes.c_long
        except Exception:
            shcore = None

        idx = [0]

        def cb(hmon, hdc, lprc, data):
            mi = MONITORINFOEXW()
            mi.cbSize = ctypes.sizeof(MONITORINFOEXW)
            if user32.GetMonitorInfoW(hmon, ctypes.byref(mi)):
                idx[0] += 1
                dpi_x, dpi_y = 96, 96
                if shcore is not None:
                    dx = ctypes.c_uint()
                    dy = ctypes.c_uint()
                    try:
                        if shcore.GetDpiForMonitor(hmon, 0, ctypes.byref(dx),
                                                   ctypes.byref(dy)) == 0:
                            dpi_x, dpi_y = dx.value, dy.value
                    except Exception:
                        pass
                r, w = mi.rcMonitor, mi.rcWork
                primary = bool(mi.dwFlags & 1)
                lines.append(
                    "#%d device=%s primary=%s  monitor=(%d,%d)-(%d,%d) %dx%d  "
                    "work=(%d,%d)-(%d,%d) %dx%d  dpi=%dx%d  scale=%.0f%%"
                    % (idx[0], mi.szDevice.strip("\x00"), "YES" if primary else "no",
                       r.left, r.top, r.right, r.bottom,
                       r.right - r.left, r.bottom - r.top,
                       w.left, w.top, w.right, w.bottom,
                       w.right - w.left, w.bottom - w.top,
                       dpi_x, dpi_y, dpi_x / 96.0 * 100.0))
            return 1

        proc = MONITORENUMPROC(cb)
        user32.EnumDisplayMonitors(None, None, proc, 0)
        try:
            vx = user32.GetSystemMetrics(76)
            vy = user32.GetSystemMetrics(77)
            vw = user32.GetSystemMetrics(78)
            vh = user32.GetSystemMetrics(79)
            lines.append("virtual_desktop=(%d,%d) %dx%d" % (vx, vy, vw, vh))
        except Exception:
            pass
    except Exception as e:
        lines.append("显示器枚举失败: %r" % (e,))
    return "\n".join(lines) if lines else "（未枚举到显示器）"


# ============================================================
# 主题 / 合成 / 动效 / 高对比度
# ============================================================
def collect_display_settings():
    lines = []
    try:
        b = ctypes.c_int()
        if ctypes.windll.dwmapi.DwmIsCompositionEnabled(ctypes.byref(b)) == 0:
            lines.append("DwmIsCompositionEnabled=%d" % b.value)
    except Exception as e:
        lines.append("DwmIsCompositionEnabled 读取失败: %r" % (e,))

    try:
        import winreg
        k = winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")
        for name in ("EnableTransparency", "AppsUseLightTheme", "SystemUsesLightTheme"):
            try:
                lines.append("%s=%s" % (name, winreg.QueryValueEx(k, name)[0]))
            except Exception:
                lines.append("%s=(不存在)" % name)
        winreg.CloseKey(k)
    except Exception as e:
        lines.append("主题注册表读取失败: %r" % (e,))

    try:
        v = ctypes.c_int()
        if ctypes.windll.user32.SystemParametersInfoW(
                0x1042, 0, ctypes.byref(v), 0):  # SPI_GETCLIENTAREAANIMATION
            lines.append("ClientAreaAnimation=%d" % v.value)
    except Exception:
        pass

    try:
        class HIGHCONTRASTW(ctypes.Structure):
            _fields_ = [("cbSize", wintypes.UINT),
                        ("dwFlags", wintypes.DWORD),
                        ("lpszDefaultScheme", wintypes.LPWSTR)]
        hc = HIGHCONTRASTW()
        hc.cbSize = ctypes.sizeof(HIGHCONTRASTW)
        if ctypes.windll.user32.SystemParametersInfoW(
                0x0042, hc.cbSize, ctypes.byref(hc), 0):  # SPI_GETHIGHCONTRAST
            lines.append("HighContrast=%s" % ("ON" if (hc.dwFlags & 1) else "off"))
    except Exception:
        pass

    try:
        lines.append("powercfg: " + run_cmd(["powercfg", "/getactivescheme"]).replace("\n", " | "))
    except Exception:
        pass
    return "\n".join(lines)


# ============================================================
# 进程 / 磁盘 / 日志
# ============================================================
def collect_processes():
    ps = (
        "Get-CimInstance Win32_Process | "
        "Where-Object { ($_.Name -like '*班级*' -or $_.Name -like '*ClassReward*') "
        "-and $_.Name -notlike '*诊断*' } | "
        "Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CreationDate,CommandLine | "
        "Format-List"
    )
    out = run_ps(ps)
    extra = run_ps(
        "Get-Process | Where-Object { ($_.ProcessName -like '*班级*' -or "
        "$_.ProcessName -like '*ClassReward*') -and "
        "$_.ProcessName -notlike '*诊断*' } | "
        "Select-Object Id,ProcessName,Responding,StartTime,MainWindowTitle | Format-List")
    parts = []
    if out:
        parts.append("【CIM 进程详情】\n" + out)
    if extra:
        parts.append("【Get-Process】\n" + extra)
    return "\n\n".join(parts) if parts else "（未发现班级激励助手相关进程）"


def collect_drives():
    ps = (
        "Get-CimInstance Win32_LogicalDisk | "
        "Select-Object DeviceID,DriveType,VolumeName,FileSystem,Size,FreeSpace | "
        "Sort-Object DeviceID | Format-Table -AutoSize"
    )
    ps2 = (
        "Get-CimInstance Win32_DiskDrive | Select-Object Model,InterfaceType,Size,"
        "MediaType,SerialNumber | Format-List"
    )
    legend = ("DriveType: 0=未知 1=无根目录 2=可移动磁盘(U盘) 3=本地硬盘 "
              "4=网络 5=光驱 6=内存盘\n")
    return legend + run_ps(ps) + "\n\n--- 物理磁盘 ---\n" + run_ps(ps2)


def collect_app_files():
    """应用的 exe/数据文件元信息：用来确认学校跑的是哪个构建。"""
    lines = []
    seen = set()
    for d in app_candidate_dirs():
        for name in ("班级激励助手.exe", "ClassRewardHelper.exe",
                     "class_reward_data.json"):
            p = os.path.join(d, name)
            if not os.path.isfile(p):
                continue
            k = os.path.normcase(os.path.realpath(p))
            if k in seen:
                continue
            seen.add(k)
            try:
                st = os.stat(p)
                lines.append(
                    "%s\n    size=%d  修改时间=%s"
                    % (p, st.st_size,
                       datetime.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")))
            except Exception as e:
                lines.append("%s  (读取失败: %r)" % (p, e))
    return "\n".join(lines) if lines else "（未在候选目录中找到应用 exe / 数据文件）"


def collect_wmi():
    queries = [
        ("操作系统", "Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture,LastBootUpTime,InstallDate | Format-List"),
        ("计算机", "Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,SystemFamily,TotalPhysicalMemory,NumberOfProcessors,NumberOfLogicalProcessors | Format-List"),
        ("CPU", "Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed,CurrentClockSpeed | Format-List"),
        ("显卡", "Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate,VideoModeDescription,Status | Format-List"),
    ]
    out = []
    for title, q in queries:
        out.append("--- %s ---\n%s" % (title, run_ps(q)))
    return "\n\n".join(out)


def collect_event_errors():
    ps = (
        "$since=(Get-Date).AddDays(-3); "
        "Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=$since} "
        "-MaxEvents 120 -ErrorAction SilentlyContinue | "
        "Where-Object { $_.Message -match '班级激励|ClassReward|Qt|PySide' } | "
        "Select-Object TimeCreated,ProviderName,Id,Message | Format-List"
    )
    out = run_ps(ps)
    return out if out else "（最近 3 天没有匹配的程序错误日志）"


def app_candidate_dirs():
    dirs = []
    base = os.path.dirname(sys.executable) if getattr(sys, "frozen", False) \
        else os.path.dirname(os.path.abspath(__file__))
    for d in (base, os.path.dirname(base), os.getcwd(), desktop_dir()):
        if d and os.path.isdir(d):
            dirs.append(os.path.abspath(d))
    # 从正在运行的应用进程路径里再找
    ps = ("Get-CimInstance Win32_Process | Where-Object { $_.Name -like '*班级*' -or "
          "$_.Name -like '*ClassReward*' } | Select-Object -ExpandProperty ExecutablePath")
    for line in run_ps(ps).splitlines():
        p = line.strip().strip('"')
        if p and os.path.isfile(p):
            d = os.path.dirname(p)
            if os.path.isdir(d):
                dirs.append(os.path.abspath(d))
    # 去重（大小写不敏感）
    seen = set()
    out = []
    for d in dirs:
        k = os.path.normcase(d)
        if k not in seen:
            seen.add(k)
            out.append(d)
    return out


def copy_app_logs(report_dir, runlog):
    log_dir = os.path.join(report_dir, "logs")
    os.makedirs(log_dir, exist_ok=True)
    found = []
    seen = set()
    for d in app_candidate_dirs():
        for name in ("_run.log", "_run.log.1"):
            p = os.path.join(d, name)
            if not os.path.isfile(p):
                continue
            rp = os.path.normcase(os.path.realpath(p))
            if rp in seen:
                continue
            seen.add(rp)
            try:
                size = os.path.getsize(p)
                tag = d.replace(":", "").replace("\\", "_").replace("/", "_")
                dst = os.path.join(log_dir, "%s__%s" % (tag, name))
                shutil.copy2(p, dst)
                found.append("%s  (%d 字节)  ←  %s" % (dst, size, p))
            except Exception as e:
                runlog.append("复制日志失败 %s: %r" % (p, e))
    if not found:
        found.append("（没有找到 _run.log；如果学校跑的是旧版 exe，新版诊断日志不会被记录）")
    return "\n".join(found)


def capture_screenshot(report_dir, runlog):
    out_png = os.path.join(report_dir, "screen.png")
    ps1 = os.path.join(report_dir, "_shot.ps1")
    png_for_ps = out_png.replace("'", "''")
    script = (
        "Add-Type -AssemblyName System.Windows.Forms\n"
        "Add-Type -AssemblyName System.Drawing\n"
        "$b=[System.Windows.Forms.SystemInformation]::VirtualScreen\n"
        "$bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height\n"
        "$g=[System.Drawing.Graphics]::FromImage($bmp)\n"
        "$g.CopyFromScreen($b.Left,$b.Top,0,0,$bmp.Size)\n"
        "$bmp.Save('%s',[System.Drawing.Imaging.ImageFormat]::Png)\n"
        "$g.Dispose(); $bmp.Dispose()\n" % png_for_ps
    )
    try:
        with open(ps1, "w", encoding="utf-8-sig") as f:
            f.write(script)
        cp = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1],
            capture_output=True, timeout=40, creationflags=CREATE_NO_WINDOW)
        if cp.returncode != 0 or not os.path.isfile(out_png):
            runlog.append("截图失败: %s %s"
                          % (decode_console(cp.stderr), decode_console(cp.stdout)))
            return "screen.png（截图失败）"
        runlog.append("截图成功: %s" % out_png)
        return "screen.png (%d 字节)" % os.path.getsize(out_png)
    except Exception as e:
        runlog.append("截图异常: %r" % (e,))
        return "screen.png（截图异常）"
    finally:
        try:
            os.remove(ps1)
        except Exception:
            pass


# ============================================================
# 可选：结束残留应用进程（方便弹 U 盘）
# ============================================================
def kill_leftover_processes(runlog):
    ps = (
        "Get-Process | Where-Object { ($_.ProcessName -like '*班级激励助手*' -or "
        "$_.ProcessName -like '*ClassRewardHelper*') -and $_.Id -ne %d -and "
        "$_.ProcessName -notlike '*诊断*' } | "
        "ForEach-Object { Write-Output ('KILL ' + $_.Id + ' ' + $_.ProcessName); "
        "Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }"
        % os.getpid()
    )
    out = run_ps(ps, timeout=20)
    runlog.append("结束残留进程输出: " + (out or "(无输出)"))
    return out


def ask_kill_leftovers(runlog):
    btn = ctypes.windll.user32.MessageBoxW(
        None,
        "检测到「班级激励助手」可能仍在运行。\n\n"
        "如果它已经无法正常退出（窗口关了但 U 盘提示占用），\n"
        "是否结束这些残留进程？\n\n"
        "（只结束本软件，不会删除数据。结束后就能弹出 U 盘。）",
        "班级激励助手 · 环境诊断",
        0x00000004 | 0x00000030 | 0x00000100 | 0x1000)  # YESNO | WARNING | DEFBUTTON2 | SYSTEMMODAL
    if btn == 6:  # IDYES
        return True
    return False


# ============================================================
# 主流程
# ============================================================
def build_report(report_dir, runlog, silent=False):
    host = socket.gethostname()
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines = []
    lines.append("班级激励助手 · 学校电脑环境诊断报告")
    lines.append("生成时间: %s" % now)
    lines.append("工具版本: %s" % TOOL_VERSION)
    lines.append("计算机: %s    用户: %s" % (host, getpass.getuser()))
    lines.append("Python: %s (%s)" % (platform.python_version(), platform.architecture()[0]))
    lines.append("")
    lines.append("=" * 72)
    lines.append("1. 系统基本")
    lines.append("=" * 72)
    lines.append("platform: %s" % platform.platform())
    lines.append("windows: %r" % (sys.getwindowsversion(),))
    lines.append("处理器架构: %s" % os.environ.get("PROCESSOR_ARCHITECTURE", "?"))
    lines.append("环境变量: GLASS_SYSTEM=%s  GLASS_DRAG=%s  GLASS_DRAG_HZ=%s  "
                 "QT_SCALE_FACTOR=%s"
                 % (os.environ.get("GLASS_SYSTEM", ""), os.environ.get("GLASS_DRAG", ""),
                    os.environ.get("GLASS_DRAG_HZ", ""),
                    os.environ.get("QT_SCALE_FACTOR", "")))
    lines.append("")
    lines.append("=" * 72)
    lines.append("2. 硬件 / 操作系统（WMI）")
    lines.append("=" * 72)
    lines.append(collect_wmi())
    lines.append("")
    lines.append("=" * 72)
    lines.append("3. 显示器 / DPI 缩放 / 虚拟桌面")
    lines.append("=" * 72)
    lines.append(collect_monitors())
    lines.append("")
    lines.append("=" * 72)
    lines.append("4. 桌面合成 / 主题 / 动效 / 电源")
    lines.append("=" * 72)
    lines.append(collect_display_settings())
    lines.append("")
    lines.append("=" * 72)
    lines.append("5. 磁盘 / 可移动设备")
    lines.append("=" * 72)
    lines.append(collect_drives())
    lines.append("")
    lines.append("=" * 72)
    lines.append("6. 班级激励助手相关进程")
    lines.append("=" * 72)
    proc_text = collect_processes()
    lines.append(proc_text)
    lines.append("")
    lines.append("=" * 72)
    lines.append("6.5 应用目录 / 构建信息")
    lines.append("=" * 72)
    lines.append(collect_app_files())
    lines.append("")
    lines.append("=" * 72)
    lines.append("7. 应用日志（_run.log）")
    lines.append("=" * 72)
    lines.append(copy_app_logs(report_dir, runlog))
    lines.append("")
    lines.append("=" * 72)
    lines.append("8. 最近 3 天的程序错误日志")
    lines.append("=" * 72)
    lines.append(collect_event_errors())
    lines.append("")
    lines.append("=" * 72)
    lines.append("9. 屏幕截图")
    lines.append("=" * 72)
    lines.append(capture_screenshot(report_dir, runlog))
    lines.append("")
    lines.append("=" * 72)
    lines.append("10. 工具运行日志")
    lines.append("=" * 72)
    lines.append("\n".join(runlog) if runlog else "（无）")
    lines.append("")
    report = "\n".join(lines)

    report_path = os.path.join(report_dir, "系统与硬件信息.txt")
    with open(report_path, "w", encoding="utf-8-sig") as f:
        f.write(report)

    readme = (
        "班级激励助手 · 学校电脑环境诊断包\n"
        "====================================\n\n"
        "包含内容：\n"
        "  · 系统与硬件信息.txt —— Windows / CPU / 内存 / 显卡 / 显示器 /\n"
        "      DPI 缩放 / 桌面合成 / 动效 / 电源方案 / 应用进程 / 最近错误日志\n"
        "  · logs\\ —— 应用目录里的 _run.log（新版 exe 会有 [sys]/[drag]/[resize] 日志）\n"
        "  · screen.png —— 收集时的屏幕截图\n\n"
        "隐私说明：不包含学生名单、积分记录，也不会上传任何内容。\n"
        "截图会包含当时的桌面内容；如果问题是「窗口抖动」这种动态现象，\n"
        "建议同时用手机录一小段视频，配合 logs\\ 里的 [resize] 日志最有用。\n"
        "把整个 zip 带回开发机即可定位问题。\n"
    )
    with open(os.path.join(report_dir, "说明.txt"), "w", encoding="utf-8-sig") as f:
        f.write(readme)
    return report_path, proc_text


def zip_report(report_dir, out_dir):
    host = socket.gethostname()
    safe_host = "".join(c for c in host if c not in '\\/:*?"<>|').strip() or "PC"
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_path = os.path.join(out_dir, "班级激励助手_诊断_%s_%s.zip" % (safe_host, ts))
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _dirs, files in os.walk(report_dir):
            for fn in files:
                full = os.path.join(root, fn)
                arc = os.path.relpath(full, report_dir)
                z.write(full, arc)
    return zip_path


def main():
    silent = "--silent" in sys.argv
    out_dir = desktop_dir()
    if "--out" in sys.argv:
        try:
            out_dir = sys.argv[sys.argv.index("--out") + 1]
        except Exception:
            pass
    os.makedirs(out_dir, exist_ok=True)

    enable_dpi_awareness()

    if not silent:
        r = ctypes.windll.user32.MessageBoxW(
            None,
            "班级激励助手 · 学校电脑环境诊断\n\n"
            "将收集：系统版本、CPU/内存/显卡、显示器与 DPI 缩放、\n"
            "桌面透明/动画设置、应用进程、应用日志、当前屏幕截图。\n\n"
            "诊断包会保存到桌面，不会上传。\n"
            "点击「确定」开始（约 10–30 秒）。",
            "班级激励助手 · 环境诊断",
            0x00000001 | 0x00000040 | 0x1000)  # OKCANCEL | ICONINFORMATION | SYSTEMMODAL
        if r != 1:  # IDOK
            return 0

    report_dir = tempfile.mkdtemp(prefix="cr_diag_")
    runlog = []
    try:
        report_path, proc_text = build_report(report_dir, runlog, silent)

        # 收集完再问是否结束残留进程（报告里先保留"运行中"的证据）
        can_kill = False
        try:
            ps = ("Get-Process | Where-Object { ($_.ProcessName -like '*班级激励助手*' -or "
                  "$_.ProcessName -like '*ClassRewardHelper*') -and $_.Id -ne %d -and "
                  "$_.ProcessName -notlike '*诊断*' } | "
                  "Select-Object -ExpandProperty Id" % os.getpid())
            pids = [x.strip() for x in run_ps(ps, timeout=15).splitlines() if x.strip().isdigit()]
            can_kill = bool(pids)
        except Exception:
            can_kill = False

        killed = False
        kill_note = None
        if can_kill and not silent and ask_kill_leftovers(runlog):
            kill_note = kill_leftover_processes(runlog)
            killed = True
        elif can_kill and silent:
            kill_note = kill_leftover_processes(runlog)
            killed = True
        if kill_note is not None:
            with open(report_path, "a", encoding="utf-8-sig") as f:
                f.write("\n\n" + "=" * 72
                        + "\n附加：结束残留进程（便于弹出 U 盘）\n"
                        + "=" * 72 + "\n" + (kill_note or "(无输出)") + "\n")

        zip_path = zip_report(report_dir, out_dir)

        if not silent:
            extra = "\n\n已按你的确认结束残留进程，U 盘应该可以弹出了。" if killed else ""
            mb("诊断完成。\n\n诊断包已保存到：\n%s\n\n"
               "请先关闭这个提示框，再安全弹出 U 盘。\n"
               "把 zip 文件带回开发机即可分析。%s" % (zip_path, extra),
               0x00000040 | 0x1000)
        else:
            try:
                with open(os.path.join(out_dir, "_diag_last_zip.txt"), "w",
                          encoding="utf-8") as f:
                    f.write(zip_path)
            except Exception:
                pass
        return 0
    finally:
        shutil.rmtree(report_dir, ignore_errors=True)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        import traceback
        tb = traceback.format_exc()
        try:
            p = os.path.join(desktop_dir(), "班级激励助手_诊断_错误.txt")
            with open(p, "w", encoding="utf-8-sig") as f:
                f.write(tb)
        except Exception:
            p = ""
        try:
            ctypes.windll.user32.MessageBoxW(
                None,
                "诊断工具运行失败：\n\n%s\n\n错误日志：%s" % (tb, p),
                "班级激励助手 · 环境诊断", 0x00000010 | 0x1000)
        except Exception:
            pass
        sys.exit(1)
