"""Task 1: SEIQRD state-transition diagram.

Run from ws/new/code:
    python task1_state_diagram.py
Writes ws/docs/SEIQRD_状态转移图.png
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "Arial Unicode MS"]
plt.rcParams["axes.unicode_minus"] = False

BLUE = "#2f6db3"
ORANGE = "#c8781a"
PURPLE = "#7a4b9b"
EDGE = "#3d4a5a"
STATE = "#eef3fa"

out = Path(__file__).resolve().parents[2] / "docs" / "SEIQRD_状态转移图.png"

fig, ax = plt.subplots(figsize=(13, 7.4), dpi=200)
ax.set_xlim(0, 13)
ax.set_ylim(0, 7.4)
ax.axis("off")

boxes = {
    "S": (0.7, 3.9, 1.45, 1.05, "易感者"),
    "E": (2.85, 3.9, 1.45, 1.05, "潜伏者"),
    "I": (5.0, 3.9, 1.45, 1.05, "未隔离感染者"),
    "Q": (7.15, 5.25, 1.45, 1.05, "隔离收治者"),
    "R": (9.25, 3.9, 1.45, 1.05, "康复者"),
    "D": (7.15, 2.15, 1.45, 1.05, "未安全处理遗体"),
    "M": (9.35, 1.95, 1.55, 1.05, "累计死亡"),
}


def draw_box(x, y, w, h, letter, label, dashed=False):
    patch = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.06,rounding_size=0.08",
        linewidth=1.4,
        edgecolor=EDGE,
        facecolor="#faf7ef" if dashed else STATE,
        linestyle="--" if dashed else "-",
        zorder=3,
    )
    ax.add_patch(patch)
    ax.text(x + w / 2, y + h / 2 + 0.13, letter, ha="center", va="center",
            fontsize=19, fontweight="bold", color="#1f2a36", zorder=4)
    ax.text(x + w / 2, y + h / 2 - 0.26, label, ha="center", va="center",
            fontsize=9.5, color="#33404f", zorder=4)


for letter, (x, y, w, h, label) in boxes.items():
    draw_box(x, y, w, h, letter, label, dashed=(letter == "M"))


def arrow(p1, p2, color=EDGE, lw=1.5, rad=0.0, dashed=False, label=None,
          label_pos=None, label_color=None, fs=10):
    patch = FancyArrowPatch(
        p1, p2,
        arrowstyle="-|>",
        mutation_scale=14,
        linewidth=lw,
        color=color,
        linestyle="--" if dashed else "-",
        connectionstyle=f"arc3,rad={rad}",
        shrinkA=0, shrinkB=0,
        zorder=2,
    )
    ax.add_patch(patch)
    if label:
        ax.text(*(label_pos if label_pos else ((p1[0] + p2[0]) / 2,
                                               (p1[1] + p2[1]) / 2)),
                label, ha="center", va="center", fontsize=fs,
                color=label_color if label_color else color, zorder=5,
                bbox=dict(boxstyle="round,pad=0.08", fc="white",
                          ec="none", alpha=0.85))


# Solid transitions.
arrow((2.15, 4.42), (2.85, 4.42), label=r"$\Lambda$", label_pos=(2.5, 4.62))
arrow((4.30, 4.42), (5.00, 4.42), label=r"$\sigma E$", label_pos=(4.65, 4.62))
arrow((6.45, 4.55), (7.20, 5.45), label=r"$\alpha I$", label_pos=(6.65, 5.05))
arrow((6.45, 4.42), (9.25, 4.42), label=r"$\gamma I$", label_pos=(7.85, 4.62))
arrow((6.45, 4.20), (7.20, 2.80), label=r"$\mu I$", label_pos=(6.62, 3.45))
arrow((8.60, 5.40), (9.28, 4.80), label=r"$\gamma_Q Q$", label_pos=(9.0, 5.35))
arrow((7.60, 5.25), (7.60, 3.20), label=r"$\mu_Q Q$", label_pos=(7.85, 4.20))
arrow((7.88, 2.15), (7.88, 1.35), color=PURPLE, lw=1.7,
      label=r"$\nu D$", label_pos=(8.18, 1.75), label_color=PURPLE)
ax.add_patch(FancyBboxPatch((7.20, 0.55), 1.35, 0.48,
                            boxstyle="round,pad=0.05,rounding_size=0.06",
                            linewidth=1.1, edgecolor=PURPLE,
                            facecolor="white", zorder=3))
ax.text(7.875, 0.79, "安全安葬", ha="center", va="center",
        fontsize=10, color=PURPLE, zorder=4)

# Three infection feedback channels.
arrow((5.72, 4.95), (1.42, 4.95), color=BLUE, lw=1.7, dashed=True,
      label=r"$\beta_c I$", label_pos=(3.55, 5.12), label_color=BLUE)
arrow((7.60, 6.30), (1.42, 5.12), color=ORANGE, lw=1.7, dashed=True,
      label=r"$\beta_h Q$", label_pos=(4.45, 5.80), label_color=ORANGE)
arrow((7.15, 2.62), (1.42, 3.78), color=PURPLE, lw=1.7, dashed=True,
      rad=0.18, label=r"$\beta_f D$", label_pos=(3.65, 2.85),
      label_color=PURPLE)

# Annotation.
ax.text(6.5, 7.05, "SEIQRD 三通道传播模型状态转移图（时间单位：天）",
        ha="center", va="center", fontsize=15.5, fontweight="bold")
ax.text(
    6.5, 0.18,
    r"实线：状态转移；虚线：三类等效感染反馈；"
    r"$\Lambda=S/N(\beta_c I+\beta_h Q+\beta_f D)$；"
    r"$M$ 为累计死亡辅助量，$D\subset M$。",
    ha="center", va="center", fontsize=9.5, color="#33404f",
)

fig.subplots_adjust(left=0.01, right=0.99, top=0.95, bottom=0.03)
fig.savefig(out, dpi=300, facecolor="white", bbox_inches="tight")
print(f"Saved {out}")
