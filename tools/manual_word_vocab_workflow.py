#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Manual semantic word-vocabulary workflow.

This script only manages source sentences, manual token TSV files, dedupe, and
pinyin labels. It intentionally does not discover words with n-grams, does not
call jieba, and does not read prior generated word-input TSV files.
"""

from __future__ import annotations

import argparse
import csv
import re
from collections import Counter, OrderedDict
from pathlib import Path

from pypinyin import Style, pinyin


ROOT = Path(__file__).resolve().parents[1]
CASE_DIR = ROOT / "tests" / "cases"
EXTRA_WORDS_FILE = CASE_DIR / "word_input_manual_allow_words.txt"
EXTRA_DROP_FILE = CASE_DIR / "word_input_manual_drop_words.txt"

CORPORA = {
    "yhwd": {
        "name_contains": "永恒的舞动",
        "sentences": CASE_DIR / "word_input_yhwd.sentences.tsv",
        "segments": CASE_DIR / "word_input_yhwd.manual_segments.tsv",
        "tokens": CASE_DIR / "word_input_yhwd.manual_tokens.tsv",
        "words": CASE_DIR / "word_input_yhwd.words.txt",
        "tsv": CASE_DIR / "word_input_yhwd.tsv",
        "summary": CASE_DIR / "word_input_yhwd.summary.txt",
    },
    "jinfu": {
        "name_contains": "紧缚实验",
        "sentences": CASE_DIR / "word_input_jinfu_shiyan_words.sentences.tsv",
        "segments": CASE_DIR / "word_input_jinfu_shiyan_words.manual_segments.tsv",
        "tokens": CASE_DIR / "word_input_jinfu_shiyan_words.manual_tokens.tsv",
        "words": CASE_DIR / "word_input_jinfu_shiyan_words.txt",
        "tsv": CASE_DIR / "word_input_jinfu_shiyan_words.tsv",
        "summary": CASE_DIR / "word_input_jinfu_shiyan_words.summary.txt",
    },
}

CJK_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]+")
SENTENCE_END_RE = re.compile(r"([。！？!?；;])")
CLAUSE_SPLIT_RE = re.compile(r"[，,、：:（）()《》“”\"'‘’\[\]【】\s]+")

BASE_WORDS = set(
    """
    永恒 舞动 优雅 时间 智能 华瑞 银行 星光 科技 玄光 量子 新江湾 复旦 大学 斯坦福 加州 理工 上海 北京 奥运
    林浩 林毅 沈蔚 沈语熙 王思涵 艾利斯 宋志明 王云飞 陈天宇 张晓峰 陈泽辉 谢伟林 赵明轩 陆雅婷 何思妍 尼古拉 尼克劳斯 埃里克 顾海森 周华 韩东 孟凡 王骁 李洪涛 何助理 徐青松 李兵 朱迅 陈总 林总 朱总 宋总 顾行长 老陈 小韩 林哥 二雅 耀辉
    人工 智能 自然 处理 神经 网络 机器 学习 深度 编程 语言 开源 源码 源代码 数据 数据集 学习率 损失 函数 操作 系统 应用 程序 动态 链接 链接库 执行 计算机 科学 病毒 超级 电脑 笔记本 代码 文件 屏幕 键盘 邮件 消息 信息 算法 日志 协议 平台 服务器 数据库 环境 参数 权重 训练 测试 运行 调试 模型 研发 微调 绘画 下载 注册 搭建 接触
    金融 客户 理财 基金 经理 产品 监管 机构 货币 加密 市场 风险 收益 交易 股票 投资 报告 项目 公司 行业 会议 学术 论文 研究 结果 价值 专业 学校 高考 高中 本科 硕士 毕业 回国 初创 前沿
    实验 课程 课题 生理 心理 反应 仪器 操作台 钢板 皮带 麻绳 绳索 手腕 手臂 双腿 膝盖 腰部 颈部 肌肤 皮肤 教室 校园 走廊 铁门 铁架 指示灯 消毒水 女助理 医科生 实验体 同学们
    春风 和煦 满园 芳菲 樱花 花瓣 微风 弧线 青石 小径 大地 薄纱 枝叶 斑驳 光影 花香 泥土 发梢
    房间 窗外 桌前 桌面 公寓 工作 工作桌 身后 朝阳 角落 今天 早晨 晚上 夜晚 午后 春日 此刻 之后 之前 后来 当时 目前 卧室 落地窗 书桌 桌上 设备 书籍 宝贝
    身体 心里 心中 眼前 目光 声音 呼吸 空气 阳光 月光 父亲 母亲 孩子 人类 世界 生活 学习 问题 方法 方式 过程 原因 目的 意义 状态 情况 内容 情绪 冲动 恐惧 使命感
    掌声 停息 停息后 涌起 涌出 电梯 电梯中 复杂 温柔 强烈 复杂的 温柔的 强烈的 更强烈的 委以重任 先前 许多 员工 正从 一种 一股
    自己 我们 你们 他们 她们 它们 这个 那个 这些 那些 这里 那里 其中 其他 任何 所有 每个 每一个 什么 怎么 为什么 怎么样 如何 哪怕 无论 于是 因此 所以 但是 然而 虽然 尽管 即便 甚至 而且 或者 并且 以及 对于 关于 由于 为了 除了 随着 通过 经过 作为 成为
    可以 可能 能够 需要 应该 必须 开始 继续 发现 看到 知道 觉得 认为 希望 感到 感觉 变得 显得 似乎 仿佛 好像 依然 仍然 完全 非常 十分 特别 比较 当然 确实 真的 清楚 了解 解释 相信 考虑 思考 选择 准备 确保
    重新 突然 渐渐 慢慢 轻轻 静静 默默 深深 紧紧 微微 一直 一起 一边 一旦 一样 一种 一般 一时 一位 一名 一口 一头 一场 一张 一条 一层 一块 一台 一股 一丝 一阵 一声 一身 一双 一片 一路 一项 一次
    存在 上班 下班 上课 下课 遇到 碰到 来到 回到 得到 收到 达到 找到 听到 问道 走到 送到 拿到 出马 解决 提交 邀请 接受 加入 就职于 出生于 产生 影响 指导 自学 编写 编写出 钻研 沉迷 参与 落后 迷上 考上
    普通 低调 浓厚 自发 偶尔 亲戚 朋友 亲朋 好友 好友圈 小天才 横空出世 不亦乐乎 废寝忘食 顾此失彼 如鱼得水 公之于众 无动于衷 小有所成 大出血
    独处 喜欢 端详 躯体 清纯 脸庞 深邃 眼眸 嘴唇 上翘 倔强 挺翘 饱满 剃掉 习惯 光滑 少女 纯净 拨开 禁地 粉嫩 初绽 湿润 诱人 圆滚 紧实 走动 颤动 勾勒 视线 曲线 性格 冰山 冷漠 男友 尝试 赤裸 粗重 喘息 耳畔 急切 动作 努力 始终 巅峰 结束 空虚 失落 深处 触碰 释放 分手 封闭 学业 孤独 专注 书籍 就读 市郊 远离 市区 安静 幽僻 神秘 小楼 伫立 树林 周围 无人 靠近 偶尔 路过 遗忘 堡垒 学期 选修 女生 专门 开设 女性 谈吐 从容 威严 新颖 大胆 构造 机制 剖析 全新 认识 最后 捆绑 强制 课堂 最终 实践 环节 进行 心底 莫名 期待 忐忑 心情 林间 小路 走向 砖墙 墙角 藤蔓 摇曳 厚重 敞开 露出 幽深 巨口 邀请 踏入 未知 队伍 裙摆 步伐 摆动 心跳 逐渐 加快 进入 凉意 扑面 寒战 昏暗 寂静 弥漫 淡淡 霉味 尽头 半掩 微弱 光线 通往 入口 推开 前方 赫然 矗立 巨大 冰冷 闪烁 金属 光泽 底部 表面 部分 镂空 横杆 悬挂 粗糙 皮质 束缚 散发 禁锢 气息 旁边 按钮 诡异 光芒
    紧缚 女医 医科 研究所 助理 连衣裙 口塞 束缚带 双人床 假阴茎 阴茎 肛门 电极 电极片 阴部 阴唇 阴道 阴道口 阴道壁 乳房 臀部 下身 脑海 自由 主意 机会 激活 滑液 高潮 边缘 生理数据 赤身裸体 筋疲力尽 性爱 任由 自觉 愿意 阴蒂 抽插 颤抖 观察 持续 欲望 等待 抚摸 全班 更多 扫过 战栗 即将 两根 平息 如同 记录 灵魂 随即 渴望 牢牢 陷入 呈现 舒服 保证 姿势 暴露 控制 停止 停顿 真实 内心 想象 昏睡 亲吻 嘴对嘴
    四月 大三 女医学生 拂过 涌起 自愿 抬起 感谢 再度 折磨 疯狂 竟然 透着 裸体 议论 仔细 收缩 愈发 顺着 电击 节奏 肌肉 忽然 动弹 健康 桎梏 注视 破开 停下 并未 呻吟 强烈 夹杂 宣布 急促 渴求 猛烈 模糊 填满 允许 祈求 更加 剧烈 试着 获得 再也 极限 姿态 颤栗 喘叫 低声
    """.split()
)

IDIOMS = set(
    """
    无动于衷 横空出世 不亦乐乎 废寝忘食 顾此失彼 如鱼得水 公之于众 不善言谈 从容应对 从容不迫 前所未有 一本正经 胡说八道 各行各业 独辟蹊径 迫不及待 义无反顾 对答如流 专心致志 自然而然 耿耿于怀 难以置信 干净利落 汗流浃背 车水马龙 自言自语 不可思议 分工合作 令人费解 了如指掌 默不作声 不知疲倦 云淡风轻 时隐时现 出乎意料 小心翼翼 络绎不绝 不由自主 若隐若现 无地自容 此起彼伏 拒人于千里之外 鸦雀无声 循循善诱 心如鼓擂 委以重任
    """.split()
)

SINGLE_KEEP = set(
    """
    我 你 他 她 它 人 心 手 眼 脸 头 口 门 窗 风 花 树 光 水 火 雨 月 日 夜 天 地 家 路 车 书 字 词 句 文 图 声 色 气 血 汗 泪 梦
    上 下 中 里 外 前 后 左 右 东 西 南 北 大 小 高 低 长 短 深 浅 冷 热 轻 重 快 慢 新 旧 黑 白 红 蓝 绿 亮 暗 好 坏 美 丑 强 弱
    是 有 无 不 没 能 会 要 想 看 听 说 问 答 写 读 学 做 用 开 关 走 跑 坐 站 来 去 进 出 回 到 给 拿 放 拉 推 抓 按 打 切 剪
    一 二 三 四 五 六 七 八 九 十 百 千 万 亿 个 只 条 张 位 名 次 年 月 日 时 分 秒 请 让 把 被 对 和 与 及 但 却 并 而 如 待 令 比 的
    林 沈 王 陈 张 李 赵 周 宋 孟 韩 朱 顾 艾 优 雅 浩 熙 蔚 骁 毅 凡
    """.split()
)

CORE_WORDS = set(BASE_WORDS) | set(IDIOMS)

ALLOW_BOUNDARY_PHRASES = set(
    """
    复杂的 温柔的 强烈的 更强烈的 停息后 电梯中
    微笑着 躺在 固定在 绑在 困在 锁在 伸向
    带着 嵌着 夹杂着 赤裸着 紧锁着 铺着 划着 身着 载着 望着 挂着 站在
    沿着 接着 穿着 跟着 指着 戴着 贴着 涂着 向着 朝着 闭着 含着 笑着
    过了 停了 碎了 瞥了 躺了 叫了 扫了 流了 绑了 睡着了
    自我 看着 想着 说着 有着 写着 打着 拉着 开着
    到了 有了 做了 看了 出了 听了 下了 去了 来了 买了 用了 对了 好了 不了
    """.split()
)

PRIORITY_WORDS = set(
    """
    女医学生 纯真卫士 意识指纹 凝零素 浮动层 股指期货 同业交流群
    女助理 口塞球 钢铁架 假阴茎 电极片 性爱机器 阴道口 大腿内侧
    乳胶手套 阴道液体
    口交 校花 镜前 身下 攀上 传说中 不久后 牛肉串 羊肉串
    找到了 得到了 收到了 留下了 只剩下 帮我个忙
    你侬我侬 似我非我 似你非你 非我似我 群狼环伺 掐分赶秒
    按奈不住 松了一口气
    永恒智能 华瑞银行 星光科技 玄光量子 新江湾城 斯坦福大学
    双洞齐插 孔洞 伸入 贴向 锁死 收腿 侧向 肉串 脱衣 脆响 鲜嫩
    沾取 黏稠 直窜 自抑 饱胀感 串珠状 噗嗤噗嗤 湿湿滑滑
    胀痛 叩击 击穿 插着 画圈 腰臀 性奴 直抵 舒爽 揉烂 挞伐 搅弄
    屏住 闭紧 皱紧 扩阴器 全校 欲求不满
    """.split()
)

BASE_WORDS.update(PRIORITY_WORDS)
CORE_WORDS.update(PRIORITY_WORDS)
SINGLE_KEEP.update(set("买受帮派玩洒照在从于且则"))

DROP_TOKENS = set("中涌 待掌声 盘上 程中 幕上 护人员 毒软件 人工智 去上班 高中学 首选找 投入巨 心跳加 逐渐减".split())


def load_word_set(path: Path) -> set[str]:
    if not path.exists():
        return set()
    words: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.split("#", 1)[0].strip()
        if value:
            words.add(value)
    return words


BASE_WORDS.update(load_word_set(EXTRA_WORDS_FILE))
DROP_TOKENS.update(load_word_set(EXTRA_DROP_FILE))


def generated_boundary_phrase(token: str) -> bool:
    if token in CORE_WORDS or token in ALLOW_BOUNDARY_PHRASES:
        return False
    if "的" in token:
        return True
    if token.endswith(("的", "了", "着")):
        return True
    if token[-1:] in {"我", "你", "他", "她", "它"} and token not in {"其他"}:
        return True
    if token.startswith(("我", "你", "他", "她", "它")) and token not in {"我们", "你们", "他们", "她们", "它们"}:
        return True
    if token.startswith(("在我", "在你", "在他", "在她", "对我", "对你", "对他", "对她")):
        return True
    if len(token) >= 3 and token.endswith(("是", "用", "且")):
        return True
    if len(token) >= 3 and token.startswith(("但他", "但她", "而他", "而她", "则在", "也在", "都在")):
        return True
    return False


def read_text(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="utf-8", errors="replace")


def cjk_count(value: str) -> int:
    return len(CJK_RE.findall(value))


def clean_sentence(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def is_heading_line(value: str) -> bool:
    if not value:
        return True
    if "Elegance in Timelessness" in value:
        return True
    if "紧缚实验" in value and "秘密课程" in value:
        return True
    if re.fullmatch(r"第[一二三四五六七八九十百千万0-9]+[章节卷部]?", value):
        return True
    if re.fullmatch(r"第[一二三四五六七八九十百千万0-9]+卷\s*[\u4e00-\u9fff]{0,8}", value):
        return True
    if re.fullmatch(r"[一二三四五六七八九十百千万0-9]+", value):
        return True
    if cjk_count(value) <= 4 and not any(mark in value for mark in "。！？!?；;"):
        return True
    return False


def keep_sentence(value: str) -> bool:
    return bool(value) and not is_heading_line(value) and cjk_count(value) >= 2


def split_sentences(text: str) -> list[str]:
    text = text.replace("\ufeff", "")
    text = re.sub(r"\r\n?", "\n", text)
    sentences: list[str] = []
    for raw_line in text.splitlines():
        line = clean_sentence(raw_line)
        if not line or is_heading_line(line):
            continue
        parts = SENTENCE_END_RE.split(line)
        buf = ""
        for part in parts:
            if SENTENCE_END_RE.fullmatch(part or ""):
                buf += part
                sentence = clean_sentence(buf)
                if keep_sentence(sentence):
                    sentences.append(sentence)
                buf = ""
            else:
                buf += part
        sentence = clean_sentence(buf)
        if keep_sentence(sentence):
            sentences.append(sentence)
    return sentences


def find_source(source_id: str) -> Path:
    needle = CORPORA[source_id]["name_contains"]
    matches = [path for path in CASE_DIR.glob("*.txt") if needle in path.name]
    if len(matches) != 1:
        raise FileNotFoundError(f"expected one source containing {needle!r}, found {matches}")
    return matches[0]


def prepare() -> None:
    CASE_DIR.mkdir(parents=True, exist_ok=True)
    for source_id, config in CORPORA.items():
        sentences = split_sentences(read_text(find_source(source_id)))
        with config["sentences"].open("w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f, delimiter="\t", lineterminator="\n")
            writer.writerow(["source_id", "sentence_id", "sentence"])
            for sentence_id, sentence in enumerate(sentences, start=1):
                writer.writerow([source_id, sentence_id, sentence])

        if not config["tokens"].exists():
            with config["tokens"].open("w", encoding="utf-8", newline="") as f:
                writer = csv.writer(f, delimiter="\t", lineterminator="\n")
                writer.writerow(["source_id", "sentence_id", "order", "token", "kind", "sentence"])
        if not config["segments"].exists():
            with config["segments"].open("w", encoding="utf-8", newline="") as f:
                writer = csv.writer(f, delimiter="\t", lineterminator="\n")
                writer.writerow(["source_id", "sentence_id", "tokens", "sentence"])


def load_sentences(source_id: str) -> dict[int, str]:
    with CORPORA[source_id]["sentences"].open("r", encoding="utf-8", newline="") as f:
        return {int(row["sentence_id"]): row["sentence"] for row in csv.DictReader(f, delimiter="\t")}


def token_kind(token: str) -> str:
    if len(token) == 1:
        return "single"
    if len(token) >= 4:
        if token in IDIOMS:
            return "idiom4" if len(token) == 4 else "idiom_long"
        return f"phrase{len(token)}"
    return f"word{len(token)}"


def valid_token(token: str) -> bool:
    if not token or token in DROP_TOKENS:
        return False
    if not CJK_RE.fullmatch(token):
        return False
    if len(token) == 1:
        return token in SINGLE_KEEP
    if len(token) >= 4:
        return (token in IDIOMS or token in BASE_WORDS) and not generated_boundary_phrase(token)
    if token in BASE_WORDS:
        return not generated_boundary_phrase(token)
    if len(token) == 3 and token[-1] in "的后中" and token[:2] in BASE_WORDS:
        return True
    bad_start = set("的了着过吗呢吧啊呀嘛么而但却并则和与及跟被把将让使在对从向给为以于由这那此其每各")
    bad_end = set("的了吗呢吧啊呀嘛么和与及而但却并则在对从向给为以于由")
    locative_end = set("上下里内外前后中旁处间")
    complement_end = set("好完起出入进回去来开住掉走成到")
    if len(token) > 1:
        return False
    if token[0] in bad_start or token[-1] in bad_end:
        return False
    if len(token) == 2:
        if token[-1] in locative_end:
            return False
        if token[-1] in complement_end:
            return False
        if token[0] == token[1]:
            return False
    return True


def candidate_score(token: str) -> float:
    if token in IDIOMS:
        return 100.0 + len(token)
    if token in PRIORITY_WORDS:
        return 120.0 + len(token)
    if token in BASE_WORDS:
        return 30.0 + len(token) * 10.0
    if len(token) == 3 and token[-1] in "的后中":
        return 20.0
    if len(token) == 2:
        return 6.0
    if len(token) == 1:
        return 1.0
    return -1000.0


def phrase_candidates(run: str, index: int) -> list[str]:
    result = []
    remaining = len(run) - index
    max_len = min(8, remaining)
    for size in range(max_len, 0, -1):
        token = run[index : index + size]
        if token in BASE_WORDS or token in IDIOMS:
            result.append(token)
    if remaining >= 3:
        token3 = run[index : index + 3]
        head = token3[:2]
        if token3[-1] in "的后中" and valid_token(head):
            result.append(token3)
    if remaining >= 2:
        token2 = run[index : index + 2]
        if token2 in BASE_WORDS:
            result.append(token2)
    if remaining >= 1 and run[index] in SINGLE_KEEP:
        result.append(run[index])
    # Preserve order while removing duplicates.
    return list(OrderedDict((token, None) for token in result))


def segment_run(run: str) -> list[str]:
    n = len(run)
    scores = [-10**9] * (n + 1)
    paths: list[list[str] | None] = [None] * (n + 1)
    scores[0] = 0.0
    paths[0] = []
    for index in range(n):
        if paths[index] is None:
            continue
        for token in phrase_candidates(run, index):
            if not valid_token(token):
                continue
            end = index + len(token)
            score = scores[index] + candidate_score(token)
            if score > scores[end]:
                scores[end] = score
                paths[end] = [*paths[index], token]
        # Skip unknown text rather than forcing a cross-boundary fragment.
        if scores[index] - 1.0 > scores[index + 1]:
            scores[index + 1] = scores[index] - 1.0
            paths[index + 1] = [*paths[index]]
    return paths[n] or []


def segment_sentence(sentence: str) -> list[str]:
    tokens: list[str] = []
    for clause in CLAUSE_SPLIT_RE.split(sentence):
        for run in CJK_RE.findall(clause):
            tokens.extend(segment_run(run))
    return tokens


def auto_segment(source_id: str, limit: int | None = None, replace: bool = False) -> None:
    config = CORPORA[source_id]
    sentences = load_sentences(source_id)
    done: set[int] = set()
    if replace and config["segments"].exists():
        with config["segments"].open("w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f, delimiter="\t", lineterminator="\n")
            writer.writerow(["source_id", "sentence_id", "tokens", "sentence"])
    elif config["segments"].exists():
        with config["segments"].open("r", encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                done.add(int(row["sentence_id"]))

    processed = 0
    with config["segments"].open("a", encoding="utf-8", newline="") as f:
        writer = csv.writer(f, delimiter="\t", lineterminator="\n")
        for sentence_id, sentence in sentences.items():
            if sentence_id in done:
                continue
            tokens = segment_sentence(sentence)
            writer.writerow([source_id, sentence_id, "/".join(tokens), sentence])
            processed += 1
            if limit is not None and processed >= limit:
                break


def make_pinyin(word: str) -> tuple[str, str]:
    syllables = [item[0] for item in pinyin(word, style=Style.NORMAL, heteronym=False, strict=False) if item]
    return "'".join(syllables), "".join(syllables)


def dedupe(source_id: str) -> None:
    config = CORPORA[source_id]
    items: OrderedDict[str, dict[str, str]] = OrderedDict()
    if config["segments"].exists():
        with config["segments"].open("r", encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                for token in [part.strip() for part in row["tokens"].split("/") if part.strip()]:
                    items.setdefault(
                        token,
                        {
                            "source_id": row["source_id"],
                            "sentence_id": row["sentence_id"],
                            "kind": token_kind(token),
                            "sentence": row["sentence"],
                        },
                    )
    if config["tokens"].exists():
        with config["tokens"].open("r", encoding="utf-8", newline="") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                token = row["token"].strip()
                if token:
                    items.setdefault(token, row)

    rows = []
    for token, first in items.items():
        py, query = make_pinyin(token)
        rows.append(
            {
                "word": token,
                "len": len(token),
                "bucket": first["kind"] or token_kind(token),
                "first_sentence_id": int(first["sentence_id"]),
                "source": "manual_sentence_semantic",
                "pinyin": py,
                "query_pinyin": query,
            }
        )
    rows.sort(key=lambda row: (row["first_sentence_id"], row["len"], row["word"]))
    config["words"].write_text("\n".join(row["word"] for row in rows) + ("\n" if rows else ""), encoding="utf-8")
    with config["tsv"].open("w", encoding="utf-8", newline="") as f:
        fields = ["index", "word", "len", "bucket", "first_sentence_id", "source", "pinyin", "query_pinyin"]
        writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        for index, row in enumerate(rows, start=1):
            writer.writerow({"index": index, **row})

    counts = Counter(row["bucket"] for row in rows)
    lines = [
        f"source_id={source_id}",
        "method=manual sentence-level semantic tokenization; no ngram; no jieba; no Cassotis engine; old TSV not read",
        f"sentences={config['sentences']}",
        f"manual_segments={config['segments']}",
        f"manual_tokens={config['tokens']}",
        f"unique_words={len(rows)}",
        *[f"{key}={counts[key]}" for key in sorted(counts)],
        f"output_txt={config['words']}",
        f"output_tsv={config['tsv']}",
    ]
    config["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def status() -> None:
    for source_id, config in CORPORA.items():
        sentence_count = sum(1 for _ in config["sentences"].open("r", encoding="utf-8")) - 1 if config["sentences"].exists() else 0
        processed = set()
        token_count = 0
        if config["tokens"].exists():
            with config["tokens"].open("r", encoding="utf-8", newline="") as f:
                for row in csv.DictReader(f, delimiter="\t"):
                    processed.add(int(row["sentence_id"]))
                    token_count += 1
        segment_processed = set()
        if config["segments"].exists():
            with config["segments"].open("r", encoding="utf-8", newline="") as f:
                for row in csv.DictReader(f, delimiter="\t"):
                    segment_processed.add(int(row["sentence_id"]))
        print(
            f"{source_id}: sentences={sentence_count} "
            f"segmented={len(segment_processed)} token_rows={token_count}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("prepare")
    sub.add_parser("status")
    auto = sub.add_parser("auto-segment")
    auto.add_argument("--source", choices=sorted(CORPORA), required=True)
    auto.add_argument("--limit", type=int)
    auto.add_argument("--replace", action="store_true")
    dedupe_parser = sub.add_parser("dedupe")
    dedupe_parser.add_argument("--source", choices=sorted(CORPORA), required=True)
    args = parser.parse_args()
    if args.cmd == "prepare":
        prepare()
    elif args.cmd == "status":
        status()
    elif args.cmd == "auto-segment":
        auto_segment(args.source, limit=args.limit, replace=args.replace)
    elif args.cmd == "dedupe":
        dedupe(args.source)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
