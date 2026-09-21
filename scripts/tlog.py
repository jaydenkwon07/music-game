#!/usr/bin/env python3
"""M6 time log (spec §4, Step 0a).

The M6 gate is a *measured* hours-per-room number, taken from this log and not
from memory. This CLI exists so logging costs seconds, not discipline.

    tlog.py start <category> <step> [--who owner|cc] [--note "..."]
    tlog.py stop  [--note "..."]
    tlog.py note  <category> <step> <minutes> [--who owner|cc] [--note "..."]
    tlog.py report

`start`/`stop` bracket a live session; `note` records a finished block whose
duration you already know (retrospective entries, owner calendar time added
after the fact). `report` prints totals by category and by step.

The currency that schedules the project is the OWNER's calendar time; Claude
Code wall-clock is logged as `--who cc` and reported apart, never mixed into the
schedule number (spec §4).

Stdlib only, on purpose: no dependency to install before a room can be timed.
The CSV at docs/m6-time-log.csv is the one source of truth; this only reads and
appends to it.
"""

from __future__ import annotations

import argparse
import csv
import sys
from datetime import datetime, timedelta
from pathlib import Path

LOG_PATH = Path(__file__).resolve().parent.parent / "docs" / "m6-time-log.csv"
FIELDS = ["date", "start", "end", "category", "step", "who", "note"]
CATEGORIES = [
    "pipeline", "debt", "geometry", "content", "light", "detail", "review", "decision",
]
WHO = ["owner", "cc"]


def _read() -> list[dict[str, str]]:
    if not LOG_PATH.exists():
        return []
    with LOG_PATH.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def _write(rows: list[dict[str, str]]) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)


def _open_row(rows: list[dict[str, str]]) -> dict[str, str] | None:
    ## An open session is a row with a start but no end.
    for row in rows:
        if row.get("start") and not row.get("end"):
            return row
    return None


def _minutes(row: dict[str, str]) -> float:
    if not (row.get("start") and row.get("end")):
        return 0.0
    fmt = "%Y-%m-%d %H:%M"
    start = datetime.strptime(f"{row['date']} {row['start']}", fmt)
    end = datetime.strptime(f"{row['date']} {row['end']}", fmt)
    if end < start:  # crossed midnight; assume the next day
        end += timedelta(days=1)
    return (end - start).total_seconds() / 60.0


def _validate(category: str, who: str) -> None:
    if category not in CATEGORIES:
        sys.exit(f"tlog: unknown category '{category}'. one of: {', '.join(CATEGORIES)}")
    if who not in WHO:
        sys.exit(f"tlog: unknown --who '{who}'. one of: {', '.join(WHO)}")


def cmd_start(args: argparse.Namespace) -> None:
    _validate(args.category, args.who)
    rows = _read()
    existing = _open_row(rows)
    if existing is not None:
        sys.exit(
            f"tlog: a session is already open "
            f"({existing['category']}:{existing['step']} since {existing['start']}). "
            f"close it with `tlog.py stop` first."
        )
    now = datetime.now()
    rows.append({
        "date": now.strftime("%Y-%m-%d"),
        "start": now.strftime("%H:%M"),
        "end": "",
        "category": args.category,
        "step": args.step,
        "who": args.who,
        "note": args.note or "",
    })
    _write(rows)
    print(f"tlog: started {args.category}:{args.step} ({args.who}) at {rows[-1]['start']}.")


def cmd_stop(args: argparse.Namespace) -> None:
    rows = _read()
    row = _open_row(rows)
    if row is None:
        sys.exit("tlog: no open session to stop.")
    row["end"] = datetime.now().strftime("%H:%M")
    if args.note:
        row["note"] = f"{row['note']}; {args.note}" if row["note"] else args.note
    _write(rows)
    print(f"tlog: stopped {row['category']}:{row['step']} — {_minutes(row):.0f} min.")


def cmd_note(args: argparse.Namespace) -> None:
    _validate(args.category, args.who)
    if args.minutes <= 0:
        sys.exit("tlog: minutes must be positive.")
    now = datetime.now()
    start = now - timedelta(minutes=args.minutes)
    rows = _read()
    rows.append({
        "date": start.strftime("%Y-%m-%d"),
        "start": start.strftime("%H:%M"),
        "end": now.strftime("%H:%M"),
        "category": args.category,
        "step": args.step,
        "who": args.who,
        "note": args.note or "",
    })
    _write(rows)
    print(f"tlog: logged {args.minutes:.0f} min to {args.category}:{args.step} ({args.who}).")


def _totals(rows: list[dict[str, str]], who: str) -> tuple[dict[str, float], dict[str, float]]:
    by_cat: dict[str, float] = {}
    by_step: dict[str, float] = {}
    for row in rows:
        if row.get("who") != who or not row.get("end"):
            continue
        mins = _minutes(row)
        by_cat[row["category"]] = by_cat.get(row["category"], 0.0) + mins
        key = f"{row['category']}:{row['step']}"
        by_step[key] = by_step.get(key, 0.0) + mins
    return by_cat, by_step


def _print_block(title: str, by_cat: dict[str, float], by_step: dict[str, float]) -> None:
    total = sum(by_cat.values())
    print(f"\n{title} — {total / 60.0:.1f}h")
    if not by_cat:
        print("  (nothing logged)")
        return
    for cat in CATEGORIES:
        if cat in by_cat:
            print(f"  {cat:<10} {by_cat[cat] / 60.0:5.1f}h")
    print("  by step:")
    for key in sorted(by_step, key=lambda k: -by_step[k]):
        print(f"    {key:<22} {by_step[key] / 60.0:5.1f}h")


def cmd_report(_args: argparse.Namespace) -> None:
    rows = _read()
    print(f"M6 time log — {LOG_PATH}")
    owner_cat, owner_step = _totals(rows, "owner")
    _print_block("OWNER calendar hours (the schedule number)", owner_cat, owner_step)
    cc_cat, cc_step = _totals(rows, "cc")
    _print_block("Claude Code hours (reference only, not the schedule)", cc_cat, cc_step)
    closed = sum(1 for r in rows if r.get("end"))
    opens = sum(1 for r in rows if r.get("start") and not r.get("end"))
    print(f"\nCoverage: {closed} closed entr{'y' if closed == 1 else 'ies'}, "
          f"{opens} open session{'' if opens == 1 else 's'}.")
    if opens:
        print("  (an open session is not counted until you `tlog.py stop`.)")


def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(prog="tlog.py", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("start", help="begin timing a session")
    s.add_argument("category")
    s.add_argument("step")
    s.add_argument("--who", default="owner")
    s.add_argument("--note", default="")
    s.set_defaults(func=cmd_start)

    s = sub.add_parser("stop", help="close the open session")
    s.add_argument("--note", default="")
    s.set_defaults(func=cmd_stop)

    s = sub.add_parser("note", help="log a finished block by minutes")
    s.add_argument("category")
    s.add_argument("step")
    s.add_argument("minutes", type=float)
    s.add_argument("--who", default="owner")
    s.add_argument("--note", default="")
    s.set_defaults(func=cmd_note)

    s = sub.add_parser("report", help="totals by category and step")
    s.set_defaults(func=cmd_report)

    args = p.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
