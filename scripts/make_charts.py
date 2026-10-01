"""
Create README charts from the small results/*.csv files.
Run after run_all.sql:   python scripts/make_charts.py
"""
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

RESULTS = Path(__file__).resolve().parent.parent / "results"
CHARTS = RESULTS / "charts"
CHARTS.mkdir(exist_ok=True)
BLUE, RED, GREY = "#2b6cb0", "#c53030", "#718096"


def tidy(ax):
    ax.spines[["top", "right"]].set_visible(False)


# 1. Target tracker: KSI vs the Road Safety Strategy baseline and target
t = pd.read_csv(RESULTS / "target_tracking.csv")
fig, ax = plt.subplots(figsize=(8, 4.2))
ax.plot(t["yr"], t["ksi"] / 1000, marker="o", color=RED, linewidth=2, label="KSI casualties (adjusted)")
ax.axhline(t["ksi_baseline"].iloc[0] / 1000, color=GREY, linestyle="--", label="2022–24 baseline")
ax.axhline(t["ksi_2035_target"].iloc[0] / 1000, color=BLUE, linestyle=":", label="2035 target (−65%)")
ax.set_ylim(0, 33)
ax.set_xticks(t["yr"])
ax.set_ylabel("Thousands")
ax.set_title("Killed or seriously injured: moving away from the 2035 target")
ax.legend(frameon=False, loc="lower left")
tidy(ax)
fig.tight_layout()
fig.savefig(CHARTS / "target_tracker.png", dpi=150)

# 2. Speed limit vs fatality rate
s = pd.read_csv(RESULTS / "speed_limit_severity.csv")
fig, ax = plt.subplots(figsize=(8, 4))
bars = ax.bar(s["speed_limit"].astype(str) + " mph", s["fatal_per_1000"], color=BLUE)
ax.bar_label(bars, fmt="%.1f", fontsize=9)
ax.set_ylabel("Fatal collisions per 1,000")
ax.set_title("A collision on a 60 mph road is 8× more likely to be fatal than on a 20 mph road")
tidy(ax)
fig.tight_layout()
fig.savefig(CHARTS / "speed_limit_severity.png", dpi=150)

# 3. Hour of day: volume vs severity (two y-axes)
h = pd.read_csv(RESULTS / "hourly_profile.csv")
fig, ax1 = plt.subplots(figsize=(9, 4))
ax1.bar(h["hour"], h["collisions"] / 1000, color=BLUE, alpha=0.7, label="Collisions")
ax1.set_xlabel("Hour of day")
ax1.set_ylabel("Collisions (thousands)", color=BLUE)
ax2 = ax1.twinx()
ax2.plot(h["hour"], h["ksi_pct"], color=RED, marker="o", markersize=4, label="% fatal or serious")
ax2.set_ylabel("% fatal or serious", color=RED)
ax2.set_ylim(0, 35)
ax1.set_xticks(range(0, 24, 2))
ax1.set_title("Most collisions happen at rush hour, but night-time collisions are the most severe")
ax1.spines[["top"]].set_visible(False)
ax2.spines[["top"]].set_visible(False)
fig.tight_layout()
fig.savefig(CHARTS / "hourly_profile.png", dpi=150)

print(f"Charts saved to {CHARTS}")
