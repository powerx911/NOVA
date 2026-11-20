#!/usr/bin/env python3
"""Deterministic company-economy analysis using the catalog's current balance data."""
from __future__ import annotations

import math
from pathlib import Path

SECTORS = [
    ("trade", 1200, 160, 30, 37.8),
    ("services", 2200, 220, 60, 47.0),
    ("logistics", 3800, 300, 85, 60.0),
    ("manufacturing", 6000, 410, 120, 76.8),
    ("tech", 9000, 550, 160, 97.8),
]


def old_ui_cost(founding: int, level: int) -> int:
    return math.ceil(founding * 0.30 * level**1.18)


def old_server_cost(gain: float, level: int) -> int:
    return math.ceil(gain * (20 + 2.5 * level))


def proposed_cost(gain: float, level: int) -> int:
    # Targets roughly one day of payback while preserving incremental-profit scaling.
    return math.ceil(gain * (8 + level))


def net_income(base: int, expense: int, gain: float, level: int) -> int:
    gross = base + (level - 1) * gain
    operating = expense * (1 + (level - 1) * 0.08)
    return max(15, round(gross - operating))


def duration_minutes(target_level: int) -> int:
    return round(8 * target_level**1.05)


def cumulative_hours_to_level(base: int, expense: int, gain: float, target: int) -> float:
    # Conservative sequential reinvestment model: each upgrade is funded by company profit.
    balance = 0.0
    hours = 0.0
    for level in range(1, target):
        cost = proposed_cost(gain, level)
        income = net_income(base, expense, gain, level)
        if balance < cost:
            hours += (cost - balance) / income
            balance = 0
        else:
            balance -= cost
        hours += duration_minutes(level + 1) / 60
        balance += net_income(base, expense, gain, level + 1) * duration_minutes(level + 1) / 60
    return hours


def main() -> None:
    lines = [
        "# تحليل اقتصاد الشركات v2",
        "",
        "هذا التقرير مبني على بيانات `src/data/catalog.ts` ومحاكاة حتمية لإعادة استثمار أرباح الشركة. لا يستخدم بيانات عشوائية.",
        "",
        "## السياسة الجديدة",
        "",
        "- دخل الشركة: دخل أساسي + زيادة قطاعية خطية لكل مستوى.",
        "- المصروف: نمو 8% لكل مستوى بدل 20%، حتى لا تلتهم التكاليف الزيادة في الدخل.",
        "- تكلفة الترقية: `ceil(الزيادة القطاعية × (8 + المستوى الحالي))`، بهدف استرداد يقارب يومًا من دخل الشركة.",
        "- مدة الترقية: `8 دقائق × المستوى المستهدف^1.05` لتقليل الانتظار مع الحفاظ على التدرج.",
        "- الهدف: استرداد تكلفة الترقية من الزيادة في صافي الربح خلال فترة معقولة، بدل ربطها بتكلفة التأسيس.",
        "",
        "## مقارنة المستوى 12",
        "",
        "| القطاع | تكلفة الواجهة القديمة | تكلفة الخادم القديمة | التكلفة الجديدة | صافي الدخل الجديد/ساعة | استرداد الترقية |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for name, founding, base, expense, gain in SECTORS:
        level = 12
        delta = gain - expense * 0.08
        cost = proposed_cost(gain, level)
        payback = cost / delta
        lines.append(
            f"| {name} | {old_ui_cost(founding, level):,} | {old_server_cost(gain, level):,} | {cost:,} | {net_income(base, expense, gain, level):,} | {payback:.1f} ساعة |"
        )
    lines += ["", "## محطات التقدم", "", "| القطاع | المستوى | التكلفة الجديدة | صافي الدخل/ساعة | مدة التطوير |", "|---|---:|---:|---:|---:|"]
    for name, _, base, expense, gain in SECTORS:
        for level in (1, 5, 12, 20, 50):
            lines.append(f"| {name} | {level} | {proposed_cost(gain, level):,} | {net_income(base, expense, gain, level):,} | {duration_minutes(level + 1)} دقيقة |")
    lines += ["", "## زمن الوصول التقديري للمستوى 12", "", "| القطاع | الوقت مع إعادة استثمار الأرباح |", "|---|---:|"]
    for name, _, base, expense, gain in SECTORS:
        lines.append(f"| {name} | {cumulative_hours_to_level(base, expense, gain, 12):.1f} ساعة |")
    lines += ["", "## نتيجة التدقيق", "", "المنحنى الجديد يفصل بين قيمة تأسيس الشركة وقيمة الترقية. لذلك لا تقفز تكلفة ترقية التقنية من بضعة آلاف إلى أكثر من 50 ألفًا عند المستوى 12، وتصبح الواجهة والخادم مبنيين على نفس المعادلات."]
    output = Path("docs/company-economy-v2-analysis.md")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
