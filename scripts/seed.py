#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
"""
MAAT Kiosk - Firestore Seeder
==============================

Populates Firestore with members, the weekly class schedule (Mon–Sat),
and random check-ins. All seeding logic lives here; the Flutter app only
reads data.

Usage examples:
  python seed.py                          # defaults: 40 members, up to 8 check-ins/class
  python seed.py --members 60             # custom member count
  python seed.py --max-checkins 12        # max check-ins per class
  python seed.py --min-checkins 2         # minimum check-ins per class
  python seed.py --wipe                   # wipe everything first, then seed
  python seed.py --wipe-checkins          # wipe only check-ins (keep members + classes)
  python seed.py --dry-run                # preview without writing to Firestore

Setup (one time):
  pip install firebase-admin
  # Download service account key from Firebase Console:
  # Project Settings → Service Accounts → Generate new private key
  # Save as scripts/service-account.json  (never commit this file!)
"""

import argparse
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# ── Dependencies check ────────────────────────────────────────────────────────

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("ERROR: firebase-admin not installed.\nRun: pip install firebase-admin")
    sys.exit(1)

# ── Name pools ────────────────────────────────────────────────────────────────

FIRST_NAMES = [
    "Anna", "Marco", "Sofia", "Luca", "Emma", "Noah", "Isabella", "James",
    "Valentina", "Carlos", "Yuki", "Rafael", "Camille", "Diego", "Priya",
    "Ethan", "Mia", "Kenji", "Laura", "Aleksei", "Hana", "Omar", "Chiara",
    "Lucas", "Amara", "Tomás", "Nadia", "Ryo", "Fatima", "Ben", "Elena",
    "Mateo", "Aisha", "Viktor", "Leila", "Hugo", "Zara", "Kai", "Mei",
    "Oscar", "Chloe", "Adrian", "Nina", "Felix", "Sara", "Leo", "Inés",
    "Max", "Luna", "David", "Maria", "Alex", "Julia", "Ryan", "Pierre",
    "Yuna", "Ahmed", "Katia", "Bruno", "Alicia", "Simone", "Tariq", "Hana",
]

LAST_NAMES = [
    "Rossi", "Lopez", "García", "Bianchi", "Martínez", "Williams", "Brown",
    "Smith", "Colombo", "Torres", "Tanaka", "Oliveira", "Dupont", "Hernández",
    "Patel", "Johnson", "Schneider", "Yamamoto", "Fernández", "Volkov",
    "Kim", "Hassan", "Romano", "Bernard", "Diallo", "Novák", "Kowalski",
    "Nakamura", "Al-Rashid", "Clarke", "Petrova", "Vargas", "Mensah",
    "Kovalenko", "Ahmadi", "Müller", "Okonkwo", "Andersen", "Chen",
    "Lindqvist", "Martin", "Silva", "Russo", "Weber", "Costa", "Moreau",
    "Fischer", "Sánchez", "Lee", "Wang", "Nguyen", "Kumar", "Santos",
    "Johansson", "Tremblay", "De Luca", "Ferreira", "Park", "Iwata",
]

PLANS = ["Unlimited", "3x / week", "2x / week", "1x / week", "Drop-in"]
# Probability weights (must sum to 100)
PLAN_WEIGHTS = [35, 25, 20, 10, 10]

AVATAR_COLORS = [
    "E87D3E", "30A046", "0066CC", "D70015", "4B44C8",
    "E07B00", "34AADC", "636366", "FF3B30", "30B0C7",
    "5856D6", "34C759", "FF9500", "AF52DE", "FF2D55",
    "007AFF", "FF6B6B", "1C1C1E", "00C7BE", "8E8E93",
    "FF6F00", "006400", "8B0000", "00008B", "8B008B",
    "2E8B57", "DC143C", "4682B4", "CD853F", "708090",
    "9370DB", "20B2AA", "B8860B", "2F4F4F", "C71585",
    "556B2F", "8B4513", "191970", "FF4500", "008080",
]

# ── Weekly schedule template ──────────────────────────────────────────────────
# Each row: (day_offset, id_suffix, name, instructor, h_start, m_start, h_end, m_end, tags, max_capacity)
# day_offset: 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri, 5=Sat  (Sunday = no classes)

WEEKLY_TEMPLATE = [
    # ── Monday (4 classes) ────────────────────────────────────────────────────
    (0, "mon_1", "BJJ Fundamentals",      "Lauren S.",  7,  0,  8,  0, ["BJJ", "Beginner", "Gi"],              20),
    (0, "mon_2", "Muay Thai Basics",       "Carlos R.",  9, 30, 10, 30, ["Muay Thai", "Striking", "Beginner"],  20),
    (0, "mon_3", "Open Mat",               "Lauren S.", 12,  0, 13, 30, ["Open Mat", "All Levels"],             30),
    (0, "mon_4", "BJJ / Grappling",        "Ana V.",    18, 15, 19, 15, ["BJJ", "Advanced", "Gi"],              15),

    # ── Tuesday (4 classes) ───────────────────────────────────────────────────
    (1, "tue_1", "Wrestling / Takedowns",  "Ana V.",     7, 30,  8, 30, ["Wrestling", "Takedowns", "All Levels"], 18),
    (1, "tue_2", "BJJ / Grappling",        "Mike T.",    9, 30, 10, 30, ["BJJ", "Intermediate", "Gi"],          15),
    (1, "tue_3", "Muay Thai Advanced",     "Carlos R.", 17,  0, 18,  0, ["Muay Thai", "Striking", "Advanced"],  16),
    (1, "tue_4", "No-Gi Grappling",        "Mike T.",   18, 15, 19, 15, ["No-Gi", "Grappling", "Intermediate"], 20),

    # ── Wednesday (5 classes) ─────────────────────────────────────────────────
    (2, "wed_1", "BJJ Fundamentals",       "Lauren S.",  7,  0,  8,  0, ["BJJ", "Beginner", "Gi"],              20),
    (2, "wed_2", "Open Mat",               "Mike T.",   12,  0, 13, 30, ["Open Mat", "All Levels"],             30),
    (2, "wed_3", "Muay Thai Basics",       "Carlos R.", 17,  0, 18,  0, ["Muay Thai", "Striking", "Beginner"],  20),
    (2, "wed_4", "BJJ / Grappling",        "Ana V.",    18, 15, 19, 15, ["BJJ", "Intermediate", "Gi"],          15),
    (2, "wed_5", "MMA Conditioning",       "Lauren S.", 19, 30, 20, 30, ["MMA", "Conditioning", "All Levels"],  25),

    # ── Thursday (4 classes) ──────────────────────────────────────────────────
    (3, "thu_1", "Muay Thai Basics",       "Carlos R.",  9, 30, 10, 30, ["Muay Thai", "Striking", "Beginner"],  20),
    (3, "thu_2", "No-Gi Grappling",        "Mike T.",   12,  0, 13,  0, ["No-Gi", "Grappling", "Intermediate"], 20),
    (3, "thu_3", "BJJ Advanced",           "Lauren S.", 17,  0, 18,  0, ["BJJ", "Advanced", "Gi"],              15),
    (3, "thu_4", "Wrestling / Takedowns",  "Ana V.",    18, 15, 19, 15, ["Wrestling", "Takedowns", "All Levels"], 18),

    # ── Friday (5 classes) ────────────────────────────────────────────────────
    (4, "fri_1", "BJJ Fundamentals",       "Lauren S.",  7,  0,  8,  0, ["BJJ", "Beginner", "Gi"],              20),
    (4, "fri_2", "Muay Thai Advanced",     "Carlos R.",  9, 30, 10, 30, ["Muay Thai", "Striking", "Advanced"],  16),
    (4, "fri_3", "Open Mat",               "Mike T.",   12,  0, 13, 30, ["Open Mat", "All Levels"],             30),
    (4, "fri_4", "BJJ / Grappling",        "Ana V.",    17,  0, 18,  0, ["BJJ", "Advanced", "Gi"],              15),
    (4, "fri_5", "MMA Conditioning",       "Lauren S.", 18, 15, 19, 15, ["MMA", "Conditioning", "All Levels"],  25),

    # ── Saturday (1 class) ────────────────────────────────────────────────────
    (5, "sat_1", "Open Mat",               "Mike T.",   10,  0, 12,  0, ["Open Mat", "All Levels"],             30),

    # Sunday: no classes
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def week_monday() -> datetime:
    """Returns midnight of this week's Monday (local time, UTC offset zeroed)."""
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    return today - timedelta(days=today.weekday())


def avatar_url(first: str, last: str, color: str) -> str:
    name = f"{first}+{last}".replace(" ", "+")
    return f"https://ui-avatars.com/api/?name={name}&background={color}&color=fff&size=256&bold=true"


def generate_members(n: int) -> list[dict]:
    """Generate n unique member documents."""
    random.shuffle(FIRST_NAMES)
    random.shuffle(LAST_NAMES)
    members = []
    used = set()
    color_pool = AVATAR_COLORS * (n // len(AVATAR_COLORS) + 2)
    random.shuffle(color_pool)

    i = 0
    attempts = 0
    while i < n and attempts < n * 10:
        attempts += 1
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES)
        full = f"{first} {last}"
        if full in used:
            continue
        used.add(full)
        plan = random.choices(PLANS, weights=PLAN_WEIGHTS)[0]
        # Random join date: 1–5 years ago
        days_ago = random.randint(30, 5 * 365)
        joined = (datetime.now() - timedelta(days=days_ago)).strftime("%Y-%m-%d")
        members.append({
            "id": f"mem_{i + 1:03d}",
            "firstName": first,
            "lastName": last,
            "plan": plan,
            "memberSince": joined,
            "profilePicture": avatar_url(first, last, color_pool[i]),
        })
        i += 1

    if len(members) < n:
        print(f"WARNING: Only generated {len(members)} unique members (requested {n}).")
    return members


def generate_classes(monday: datetime, week_idx: int = 0) -> list[dict]:
    """Generate class documents for one week. week_idx is embedded in the ID
    so classes across multiple weeks never collide (cls_w00_mon_1, cls_w01_mon_1…)."""
    classes = []
    for day_offset, id_suffix, name, instructor, hs, ms, he, me, tags, max_cap in WEEKLY_TEMPLATE:
        start = monday + timedelta(days=day_offset, hours=hs, minutes=ms)
        end   = monday + timedelta(days=day_offset, hours=he, minutes=me)
        classes.append({
            "id": f"cls_w{week_idx:02d}_{id_suffix}",
            "name": name,
            "instructor": instructor,
            "startTime": start,
            "endTime": end,
            "tags": tags,
            "maxCapacity": max_cap,
            "attendeeCount": 0,
        })
    return classes


def generate_classes_for_weeks(base_monday: datetime, num_weeks: int) -> list[dict]:
    """Generate classes for num_weeks consecutive weeks starting from base_monday."""
    all_classes = []
    for i in range(num_weeks):
        week_monday = base_monday + timedelta(weeks=i)
        all_classes.extend(generate_classes(week_monday, week_idx=i))
    return all_classes


def generate_checkins(
    members: list[dict],
    classes: list[dict],
    min_per_class: int,
    max_per_class: int,
) -> list[dict]:
    """Randomly assign members to classes as check-ins."""
    checkins = []
    for cls in classes:
        max_possible = min(max_per_class, cls["maxCapacity"], len(members))
        count = random.randint(min(min_per_class, max_possible), max_possible)
        chosen = random.sample(members, count)
        start: datetime = cls["startTime"]
        for i, member in enumerate(chosen):
            # Stagger check-in times: 45 min before class, +3 min per person
            checked_in_at = start - timedelta(minutes=45 - i * 3)
            checkins.append({
                "memberId": member["id"],
                "classId": cls["id"],
                "memberName": f"{member['firstName']} {member['lastName']}",
                "memberProfilePicture": member["profilePicture"],
                "checkedInAt": checked_in_at,
                "status": "confirmed",
            })
    return checkins


# ── Firestore batch writer ────────────────────────────────────────────────────

def batch_write(db, collection: str, docs: list[dict], id_field: str = "id", dry_run: bool = False):
    """Write docs to Firestore in batches of 499 (Firestore limit is 500)."""
    if dry_run:
        print(f"  [dry-run] Would write {len(docs)} docs to '{collection}'")
        return

    BATCH_SIZE = 499
    col_ref = db.collection(collection)
    total = len(docs)
    written = 0

    for start in range(0, total, BATCH_SIZE):
        chunk = docs[start: start + BATCH_SIZE]
        batch = db.batch()
        for doc in chunk:
            data = {k: v for k, v in doc.items() if k != id_field}
            ref = col_ref.document(doc[id_field]) if id_field in doc else col_ref.document()
            batch.set(ref, data)
        batch.commit()
        written += len(chunk)
        print(f"  ✓ {written}/{total} written to '{collection}'")


def wipe_collection(db, collection: str, dry_run: bool = False):
    """Delete every document in a collection (in batches)."""
    if dry_run:
        print(f"  [dry-run] Would wipe '{collection}'")
        return
    col_ref = db.collection(collection)
    deleted = 0
    while True:
        docs = list(col_ref.limit(400).stream())
        if not docs:
            break
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        deleted += len(docs)
    print(f"  ✓ Wiped {deleted} docs from '{collection}'")


def update_attendee_counts(db, classes: list[dict], checkins: list[dict], dry_run: bool = False):
    """Set attendeeCount on each class to the actual number of check-ins."""
    counts: dict[str, int] = {}
    for ci in checkins:
        counts[ci["classId"]] = counts.get(ci["classId"], 0) + 1

    if dry_run:
        for cls in classes:
            c = counts.get(cls["id"], 0)
            print(f"  [dry-run] {cls['id']} attendeeCount → {c}")
        return

    BATCH_SIZE = 499
    items = [(cls["id"], counts.get(cls["id"], 0)) for cls in classes]
    for start in range(0, len(items), BATCH_SIZE):
        chunk = items[start: start + BATCH_SIZE]
        batch = db.batch()
        for class_id, count in chunk:
            batch.update(db.collection("classes").document(class_id), {"attendeeCount": count})
        batch.commit()
    print(f"  ✓ Updated attendeeCount for {len(items)} classes")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="MAAT Kiosk — Firestore database seeder",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--members",       type=int, default=30,  help="Number of members to seed (default: 30)")
    parser.add_argument("--weeks",         type=int, default=9,   help="Number of weeks to seed from this Monday (default: 9 ≈ 2 months)")
    parser.add_argument("--min-checkins",  type=int, default=2,   help="Min check-ins per class (default: 2)")
    parser.add_argument("--max-checkins",  type=int, default=8,   help="Max check-ins per class (default: 8)")
    parser.add_argument("--wipe",          action="store_true",    help="Wipe members + classes + check-ins before seeding")
    parser.add_argument("--wipe-checkins", action="store_true",    help="Wipe only check-ins before seeding")
    parser.add_argument("--dry-run",       action="store_true",    help="Preview what would be written, without touching Firestore")
    parser.add_argument("--key",           default="scripts/service-account.json",
                        help="Path to service account JSON key (default: scripts/service-account.json)")
    args = parser.parse_args()

    # ── Firebase init ──────────────────────────────────────────────────────────
    key_path = Path(args.key)
    if not key_path.exists():
        print(f"ERROR: Service account key not found at '{key_path}'")
        print("  Download from Firebase Console > Project Settings > Service Accounts")
        sys.exit(1)

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(key_path))
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    # ── Summary ────────────────────────────────────────────────────────────────
    monday = week_monday()
    end_date = monday + timedelta(weeks=args.weeks) - timedelta(days=1)
    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}MAAT Kiosk Seeder")
    print(f"  From          : {monday.strftime('%A %d %B %Y')}")
    print(f"  To            : {end_date.strftime('%A %d %B %Y')}  ({args.weeks} weeks)")
    print(f"  Members       : {args.members}")
    print(f"  Check-ins     : {args.min_checkins}–{args.max_checkins} per class")
    print(f"  Classes       : {len(WEEKLY_TEMPLATE) * args.weeks} ({len(WEEKLY_TEMPLATE)}/week × {args.weeks} weeks)")
    if args.wipe:
        print("  Wipe mode     : members + classes + check-ins")
    elif args.wipe_checkins:
        print("  Wipe mode     : check-ins only")
    print()

    # ── Generate data ──────────────────────────────────────────────────────────
    print("Generating data…")
    members = generate_members(args.members)
    classes = generate_classes_for_weeks(monday, args.weeks)
    checkins = generate_checkins(members, classes, args.min_checkins, args.max_checkins)
    # Assign auto-generated IDs to check-ins (no fixed id field needed)
    for i, ci in enumerate(checkins):
        ci["_auto_id"] = True  # flag for batch_write to use auto doc ID

    print(f"  {len(members)} members")
    print(f"  {len(classes)} classes")
    print(f"  {len(checkins)} check-ins total")
    print()

    # ── Wipe ──────────────────────────────────────────────────────────────────
    if args.wipe:
        print("Wiping existing data…")
        wipe_collection(db, "check_ins", args.dry_run)
        wipe_collection(db, "classes",   args.dry_run)
        wipe_collection(db, "members",   args.dry_run)
        print()
    elif args.wipe_checkins:
        print("Wiping check-ins…")
        wipe_collection(db, "check_ins", args.dry_run)
        print()

    # ── Write members (merge — safe to re-run) ─────────────────────────────────
    print("Writing members…")
    batch_write(db, "members", members, id_field="id", dry_run=args.dry_run)
    print()

    # ── Write classes ──────────────────────────────────────────────────────────
    print("Writing classes…")
    batch_write(db, "classes", classes, id_field="id", dry_run=args.dry_run)
    print()

    # ── Write check-ins (auto IDs) ─────────────────────────────────────────────
    print("Writing check-ins…")
    if args.dry_run:
        print(f"  [dry-run] Would write {len(checkins)} docs to 'check_ins'")
    else:
        BATCH_SIZE = 499
        total = len(checkins)
        written = 0
        for start in range(0, total, BATCH_SIZE):
            chunk = checkins[start: start + BATCH_SIZE]
            batch = db.batch()
            for ci in chunk:
                data = {k: v for k, v in ci.items() if k != "_auto_id"}
                batch.set(db.collection("check_ins").document(), data)
            batch.commit()
            written += len(chunk)
            print(f"  ✓ {written}/{total} written to 'check_ins'")
    print()

    # ── Update attendeeCount on each class ─────────────────────────────────────
    print("Updating attendee counts…")
    update_attendee_counts(db, classes, checkins, args.dry_run)
    print()

    print("Done!" if not args.dry_run else "Dry run complete - nothing was written.")


if __name__ == "__main__":
    main()
