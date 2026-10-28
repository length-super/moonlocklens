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
c.drawString(43, H-133, "本地项目申报草稿  /  2026-10-28  /  MIT")

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


section("01  真实问题", "构建、后台作业或数据库维护任务卡住时，用户需要从任务 PID 找到实际等待的子进程、锁请求和外部阻塞者，并记录后续是否恢复。")
section("02  独立贡献", "原创纯 MoonBit 核心：有界解析 stat/wchan/locks，关联当前任务树、锁请求和逐层阻塞证据；用 PID+starttime 区分身份，记录状态及阻塞证据变化。保留等待树、影响排名与字节区间 API。")
section("03  可以运行的交付", "0.3.0 提供免编译 Node 包和 Windows/Linux 启动器。diagnose/watch/report 串起任务诊断、连续采样、会话保存与文本/JSON/Markdown 回放。实际采集需要 Linux；库支持 Wasm-GC / JS，源码与申报材料保留在本地。")
section("04  验证与演示", "两个后端各 24 项核心测试，格式、构建、API 与 CLI 通过；实际 ZIP 消费和独立运行包通过。真实 Linux 父子任务被外部 FLOCK 阻塞，五帧观察验证第二帧释放后等待消失；保留 POSIX/FLOCK/OFD 独立对照。")
section("05  范围与维护", "只读有界采样，namespace 可见性有限；wchan 为线索，采样跨度非精确持续等待时长。序号不作跨帧身份；区间重叠非授予预测，等待树非死锁证明。AI 辅助开发，参赛者需掌握关键架构与边界。")
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
