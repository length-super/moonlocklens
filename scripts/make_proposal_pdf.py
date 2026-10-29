"""Generate the single-page application draft. Run with ReportLab installed."""
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from xml.sax.saxutils import escape
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output/pdf/submission-proposal.pdf"
OUT.parent.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))
FONT = "STSong-Light"
W, H = A4
c = canvas.Canvas(str(OUT), pagesize=A4)
c.setTitle("MoonLockLens - 项目申报草稿")
c.setAuthor("MoonLockLens contributors")
c.setFillColor(colors.HexColor("#0e233d"))
c.rect(0, H-148, W, 148, fill=1, stroke=0)
c.setFillColor(colors.HexColor("#52d9bc"))
c.setFont("Helvetica-Bold", 11)
c.drawString(42, H-39, "MOONBIT HACKATHON 2026 / OCTOBER")
c.setFillColor(colors.white)
c.setFont("Helvetica-Bold", 30)
c.drawString(42, H-81, "MoonLockLens")
c.setFont(FONT, 15)
c.drawString(43, H-111, "Linux 任务等待与文件争用诊断")
c.setFont(FONT, 10)
c.drawString(43, H-133, "项目申报说明  /  2026-10-29  /  MIT")

y = H-179


def wrap(text, width, size):
    line = ""
    result = []
    for ch in text:
        if pdfmetrics.stringWidth(line+ch, FONT, size) > width:
            result.append(line)
            line = ch
        else:
            line += ch
    if line:
        result.append(line)
    return result


def section(title, body):
    global y
    c.setFillColor(colors.HexColor("#087d72"))
    c.setFont(FONT, 12)
    c.drawString(43, y, title)
    y -= 21
    parts = re.split(r"([\x20-\x7e]+)", body)
    rich = ''.join('<font name="Helvetica">'+escape(p)+'</font>' if p.isascii() else escape(p) for p in parts if p)
    p = Paragraph(rich, ParagraphStyle("body", fontName=FONT, fontSize=10.5, leading=16, textColor=colors.HexColor("#203249"), wordWrap="CJK"))
    _, h = p.wrap(W-86, H)
    p.drawOn(c, 43, y-h+10)
    y -= h
    y -= 9


section("01  项目名称", "MoonLockLens——Linux 任务等待与文件争用诊断工具，当前版本 0.4.0。")
section("02  项目简介", "从任务 PID 或文件路径出发，关联子进程、锁请求与外部阻塞者，通过连续采样、现场保存和离线报告，帮助开发与运维定位卡住的任务。")
section("03  项目方向与通用性", "基础软件与开发者工具。适用于使用 POSIX/FLOCK/OFD 文件锁的构建、批处理和多进程程序，无需修改被观察程序；Linux 采集，Windows/Linux 回放，提供 MoonBit 库与 Node CLI。")
section("04  三个完整使用场景", "构建与 CI：共享缓存争用导致流水线停滞，按文件采样找到阻塞证据并输出阈值结果。定时任务：备份或导入重叠时，从任务树定位等待者及外部持锁者，核对处理后的变化。故障复盘：多进程程序间歇卡住时保存会话，离线还原等待链并分享 Markdown/JSON 报告。")
section("05  核心功能", "有界解析 stat/wchan/locks；任务身份保护、直接/传递等待链、文件字节区间查询；文件级观察、同任务前后比较、文本/JSON/Markdown 回放；CI 阈值区分通过、违规与证据不足。双后端各 30 项核心测试及真实 Linux 锁竞争验证通过。")
section("06  原创性质", "原创 MIT 项目。解析、关联、时间线及报告在 MoonBit 实现，Node.js 仅负责宿主读取、时钟和命令行输出；AI 辅助开发。")
section("07  移植与参考说明", "非移植项目。参考 Linux procfs 文档，以 util-linux lslocks 作为独立测试对照，未复制实现；来源与许可见 THIRD_PARTY.md。wchan 为线索，采样跨度非精确等待时长。")
section("08  仓库与提交记录", "github.com/length-super/moonlocklens；已保留至少 10 条真实提交，覆盖核心、实测、发布及三项功能扩展。发布账号 length-super，模块 length-super/moonlocklens@0.4.0。公开 CI、安装与版本结果见 docs/release.md；尚未正式报名或取得审核结论。")
assert y > 44, y
c.setStrokeColor(colors.HexColor("#dbe4ed"))
c.line(43, 44, W-43, 44)
c.setFont(FONT, 8.5)
c.setFillColor(colors.HexColor("#60758d"))
c.drawString(43, 29, "完整方案与证据：github.com/length-super/moonlocklens / docs/acceptance-review.md")
c.linkURL("https://github.com/length-super/moonlocklens", (43, 20, W-43, 42), relative=0)
c.showPage()
c.save()
print(OUT)
