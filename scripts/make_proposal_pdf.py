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
c.drawString(43, H-111, "Linux 文件锁等待树诊断与离线重放")
c.setFont(FONT, 10)
c.drawString(43, H-133, "本地项目申报草稿  /  2026-10-23  /  MIT")

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
    y -= 14


section("01  真实问题", "构建缓存、后台任务和数据库工具卡住时，需要解释哪个文件的哪个字节区间、哪条等待链正在阻塞。单一 PID 清单不足以表达嵌套等待，OFD 锁也不能归给一个进程。")
section("02  独立贡献", "原创纯 MoonBit 核心：有界解析 /proc/locks，按内核缩进还原直接与传递等待；输出逐层源行 witness、等待规模排名和 inclusive 字节区间查询。已有 POSIX FFI 负责系统调用，lslocks 用作独立对照，本项目提供 MoonBit 可组合的诊断 API。")
section("03  可以运行的交付", "提供公开类型、结构化错误、Node CLI、synthetic 演示和回归测试；保留未知锁族、lease 状态、PID 0/-1 与 EOF。支持 Wasm-GC / JS 离线核心，Linux 只读 live 采集。源码、许可、调研、测试证据及实际归档消费材料均保留在本地项目。")
section("04  验证与演示", "两个后端各 13 项核心测试；check、build、格式和公开 API 验证；实际 ZIP 解包消费者通过。本机 Linux 实测 POSIX、FLOCK、OFD 三类锁竞争，与 Python fcntl / lslocks 对照通过。三分钟演示包含嵌套等待、边界字节相交和错误拒绝。")
section("05  范围与维护", "只观察快照，不解锁或杀进程；namespace 可见性有限，序号不是跨时间身份；区间重叠不是授予预测，等待树不是死锁证明。新差异进入回归，公共 API 按版本管理；AI 辅助开发，参赛者需掌握关键架构与边界。")
section("06  申报信息", "参赛者、队长 GitHub ID、队员、公开仓库和正式 namespace 待指定。当前未报名、未发布、未取得审核结果。十月报名与验收截止 2026-10-31；公开持续开发为后续参赛缺项，按用户要求本次先本地保存。")
assert y > 44, y
c.setStrokeColor(colors.HexColor("#dbe4ed"))
c.line(43, 44, W-43, 44)
c.setFont(FONT, 8.5)
c.setFillColor(colors.HexColor("#60758d"))
c.drawString(43, 29, "完整方案、生态分析与证据：本地项目根目录及 docs/acceptance-review.md")
c.showPage()
c.save()
print(OUT)
