"""Program iskeleti: gün bölünmesi, kas dağılımı ve set/tekrar/dinlenme.

Bunlar kuralla belirlenir (küçük modellerde tutarlı değil, hep aynı 3x8-12 çıkıyordu).
Yapay zeka yalnızca her kas grubunun aday listesinden hareket seçer ve ipucu yazar.
"""

from typing import Dict, Iterable, List, Optional, Set, Tuple

from . import exercise_catalog as catalog

Plan = List[Tuple[str, int]]  # [(kas grubu, hareket sayısı)]

# Gün şablonları: öncelik sırasıyla (kas grubu, hareket sayısı)
_TEMPLATES: Dict[str, Tuple[Tuple[str, str], Plan]] = {
    "FULL_A": (("Tüm Vücut", ""), [("squat", 1), ("pectorals", 1), ("lats", 1), ("delts", 1), ("abs", 1)]),
    "FULL_B": (("Tüm Vücut", ""), [("hinge", 1), ("upper back", 1), ("pectorals", 1), ("biceps", 1), ("triceps", 1), ("abs", 1)]),
    "FULL_C": (("Tüm Vücut", ""), [("lunge", 1), ("lats", 1), ("delts", 1), ("calves", 1), ("triceps", 1), ("pectorals", 1), ("abs", 1)]),
    "PUSH": (("İtiş Günü", "Göğüs, Omuz, Arka Kol"), [("pectorals", 3), ("delts", 2), ("triceps", 2)]),
    "PULL": (("Çekiş Günü", "Sırt, Ön Kol"), [("lats", 2), ("upper back", 2), ("biceps", 2), ("traps", 1)]),
    "LEGS": (("Bacak Günü", "Bacak, Kalça, Baldır"), [("squat", 2), ("hinge", 1), ("leg_curl", 1), ("leg_ext", 1), ("calves", 1), ("abs", 1)]),
    "UPPER": (("Üst Vücut", "Göğüs, Sırt, Omuz, Kol"), [("pectorals", 2), ("lats", 2), ("delts", 1), ("biceps", 1), ("triceps", 1)]),
    "LOWER": (("Alt Vücut", "Bacak, Kalça, Baldır"), [("squat", 2), ("hinge", 2), ("lunge", 1), ("calves", 1), ("abs", 1)]),
    "CORE": (("Karın & Kardiyo", ""), [("abs", 3), ("cardiovascular system", 2), ("spine", 1)]),
}

# Anket odak bölgeleri (veri seti hedefleri) -> plan yuvaları
_TARGET_TO_SLOTS = {
    "quads": ["squat", "leg_ext"],
    "hamstrings": ["hinge", "leg_curl"],
    "glutes": ["hinge", "lunge"],
    "adductors": ["squat"],
    "abductors": ["lunge"],
}


def interest_slots(targets: Iterable[str]) -> List[str]:
    out: List[str] = []
    for t in targets:
        for slot in _TARGET_TO_SLOTS.get(t, [t]):
            if slot not in out:
                out.append(slot)
    return out


# Prompt'ta yuvaları açıklayan kısa not
SLOT_LEGEND = (
    "squat=diz baskın bacak (squat/leg press), hinge=kalça menteşesi (deadlift/RDL/hip thrust), "
    "lunge=tek bacak (lunge/step-up), leg_curl=arka bacak curl, leg_ext=ön bacak extension, "
    "upper back=sırt (kürek/row), lats=latissimus (barfiks/pulldown)"
)

# Şablonlarda bulunmayan odak bölgelerin ekleneceği gün türleri
_HOME_KEYS = {
    "forearms": ("PULL", "UPPER", "FULL_A", "FULL_B"),
    "spine": ("LEGS", "LOWER", "FULL_B", "CORE"),
    "leg_curl": ("LEGS", "LOWER", "FULL_B"),
    "leg_ext": ("LEGS", "LOWER", "FULL_A"),
    "lunge": ("LEGS", "LOWER", "FULL_C"),
    "hinge": ("LEGS", "LOWER", "FULL_B"),
    "squat": ("LEGS", "LOWER", "FULL_A"),
    "serratus anterior": ("PUSH", "UPPER", "FULL_A", "CORE"),
    "traps": ("PULL", "UPPER", "FULL_B"),
    "cardiovascular system": ("CORE", "FULL_A", "FULL_C"),
}


def _layout(days: int, beginner: bool) -> List[str]:
    if days <= 1:
        return ["FULL_A"]
    if days == 2:
        return ["FULL_A", "FULL_B"]
    if days == 3:
        return ["FULL_A", "FULL_B", "FULL_C"] if beginner else ["PUSH", "PULL", "LEGS"]
    if days == 4:
        return ["UPPER", "LOWER", "UPPER", "LOWER"]
    if days == 5:
        return ["PUSH", "PULL", "LEGS", "UPPER", "LOWER"]
    if days == 6:
        return ["PUSH", "PULL", "LEGS", "PUSH", "PULL", "LEGS"]
    return ["PUSH", "PULL", "LEGS", "PUSH", "PULL", "LEGS", "CORE"]


def _scale(plan: Plan, total: int, protected: Iterable[str] = ()) -> Plan:
    """Hareket sayısını günlük hedefe getirir.

    Fazlalık en kalabalık hedeften düşülür; odak bölgeler (protected) daha geç
    kısılır. Eksik varsa baştan dağıtılır.
    """
    keep = set(protected)
    counts = [[t, c] for t, c in plan]
    while sum(c for _, c in counts) > total and counts:
        candidates = [item for item in counts if item[1] > 1]
        if not candidates:
            counts.pop()
            continue
        # en büyük ağırlık; eşitlikte sondaki
        target = max(
            reversed(candidates),
            key=lambda item: item[1] - (0.5 if item[0] in keep else 0),
        )
        target[1] -= 1
    while sum(c for _, c in counts) < total and counts:
        # eksik hareketler en az hareketi olan yuvaya gider: aynı kalıptan üç çeşit çıkmasın
        min(counts, key=lambda item: item[1])[1] += 1
    return [(t, c) for t, c in counts]


def build_plan(
    days: int,
    experience: str,
    interest_targets: Iterable[str],
    per_day: int,
) -> List[dict]:
    """[{"name", "targets": [(kas grubu, sayı)]}] — odak bölgeler 1 hareket fazla alır."""
    beginner = (experience or "").strip().lower().startswith("başlang")
    keys = _layout(max(1, min(7, days)), beginner)
    interests = interest_slots(interest_targets)

    plans = []
    for key in keys:
        name, template = _TEMPLATES[key]
        plan = [list(x) for x in template]
        covered = {t for t, _ in plan}
        for t in interests:
            if t in covered:
                for item in plan:
                    if item[0] == t:
                        item[1] += 1
        plans.append({"key": key, "name": name, "plan": [tuple(x) for x in plan]})

    # Hiçbir günde bulunmayan odak bölgeler (ön kol, bel vb.) uygun günlere eklenir
    present = {t for p in plans for t, _ in p["plan"]}
    for t in interests:
        if t in present:
            continue
        homes = _HOME_KEYS.get(t, ())
        targets_days = [p for p in plans if p["key"] in homes] or plans[:2]
        for p in targets_days[:3]:
            p["plan"].append((t, 1))

    seen: Dict[str, int] = {}
    total_per_name: Dict[str, int] = {}
    for p in plans:
        total_per_name[p["name"][0]] = total_per_name.get(p["name"][0], 0) + 1
    out = []
    for p in plans:
        base, detail = p["name"]
        n = seen.get(base, 0)
        seen[base] = n + 1
        name = base
        if total_per_name[base] > 1:
            name += f" {'ABCDEFG'[n % 7]}"
        if detail:
            name += f" ({detail})"
        out.append({"name": name, "targets": _scale(p["plan"], per_day, interests)})
    return out


# ------------------------------------------------------------ set / tekrar

_COMPOUND = (
    "press", "squat", "deadlift", "row", "pull-up", "chin-up", "pulldown", "lunge",
    "dip", "thrust", "clean", "snatch", "push-up", "step-up", "pullover",
)
_ISOLATION = (
    "raise", "curl", "extension", "fly", "kickback", "shrug", "crunch", "twist",
    "calf", "wrist", "bend", "abduction", "adduction", "pullover",
)
_TIMED = ("plank", "wall sit", "hold", "isometric", "pose")


def is_compound(ex: dict) -> bool:
    n = ex["name"].lower()
    if any(w in n for w in _ISOLATION) and not any(w in n for w in ("press", "squat", "deadlift", "row")):
        return False
    return any(w in n for w in _COMPOUND)


def is_timed(ex: dict) -> bool:
    return ex["target"] == "cardiovascular system" or any(w in ex["name"].lower() for w in _TIMED)


# hedef -> (bileşik: sets, reps, dinlenme), (izolasyon: sets, reps, dinlenme)
_SCHEMES = {
    "strength": ((5, "3-5", 180), (3, "8-10", 90)),
    "hypertrophy": ((4, "6-10", 120), (3, "10-15", 60)),
    "fatloss": ((3, "10-12", 60), (3, "12-15", 45)),
    "endurance": ((3, "15-20", 45), (3, "15-20", 30)),
    "health": ((3, "10-12", 60), (2, "12-15", 45)),
    "general": ((3, "8-12", 90), (3, "10-15", 60)),
}


def goal_key(goal: Optional[str]) -> str:
    g = (goal or "").lower()
    for needle, key in (("güç", "strength"), ("kas", "hypertrophy"), ("yağ", "fatloss"),
                        ("dayan", "endurance"), ("esnek", "health"), ("sağlık", "health"), ("rehab", "health")):
        if needle in g:
            return key
    return "general"


def scheme_for(ex: dict, goal: Optional[str], experience: Optional[str]) -> dict:
    if is_timed(ex):
        seconds = 45 if ex["target"] == "cardiovascular system" else 40
        return {"sets": 3, "reps": None, "duration_seconds": seconds, "rest_seconds": 45}
    compound, iso = _SCHEMES[goal_key(goal)]
    sets, reps, rest = compound if is_compound(ex) else iso
    exp = (experience or "").lower()
    if exp.startswith("başlang"):
        sets = min(sets, 3)
        if reps == "3-5":  # yeni başlayan için ağır düşük tekrar yerine daha güvenli aralık
            reps = "5-8"
    elif exp.startswith(("ileri", "profesyonel")) and is_compound(ex):
        sets = min(sets + 1, 5)
    return {"sets": sets, "reps": reps, "duration_seconds": None, "rest_seconds": rest}


# ------------------------------------------------------------ birleştirme

def plan_targets(plan: List[dict]) -> List[str]:
    out: List[str] = []
    for d in plan:
        for t, _ in d["targets"]:
            if t not in out:
                out.append(t)
    return out


def plan_text(plan: List[dict]) -> str:
    lines = []
    for i, d in enumerate(plan, 1):
        parts = ", ".join(f"{t} ×{c}" for t, c in d["targets"])
        lines.append(f"{i}. {d['name']}: {parts}")
    return "\n".join(lines)


_FAMILIES = ("deadlift", "squat", "bench press", "curl", "raise", "press", "row", "pulldown",
             "extension", "fly", "lunge", "crunch", "dip", "shrug", "kickback", "pull-up")
_FAMILY_LIMIT = {"deadlift": 1, "squat": 1}


def _family(ex: dict) -> Optional[str]:
    n = ex["name"].lower()
    for f in _FAMILIES:
        if f in n:
            return f
    return None


def assemble(
    plan: List[dict],
    ai_days: List[dict],
    pools: Dict[str, List[dict]],
    *,
    allowed_equipment: Optional[Set[str]],
    goal: Optional[str],
    experience: Optional[str],
    duration_min: int,
) -> List[dict]:
    """Yapay zekanın seçimlerini doğrular, eksikleri havuzdan tamamlar, set/tekrar ekler."""
    candidate_ids = {e["id"] for items in pools.values() for e in items}
    used: Set[str] = set()
    workouts = []

    for i, day in enumerate(plan):
        raw = ai_days[i].get("exercises", []) if i < len(ai_days) and isinstance(ai_days[i], dict) else []
        wanted = dict(day["targets"])
        picked: Dict[str, List[dict]] = {t: [] for t, _ in day["targets"]}
        notes: Dict[str, str] = {}
        in_day: Set[str] = set()
        families: Dict[str, int] = {}

        def family_ok(ex: dict, strict: bool) -> bool:
            f = _family(ex)
            return not strict or f is None or families.get(f, 0) < _FAMILY_LIMIT.get(f, 2)

        def take(slot: str, ex: dict):
            picked[slot].append(ex)
            in_day.add(ex["id"])
            f = _family(ex)
            if f:
                families[f] = families.get(f, 0) + 1

        for item in raw:
            if not isinstance(item, dict):
                continue
            ex = catalog.get_by_id(item.get("id"))
            if not ex or ex["id"] not in candidate_ids or ex["id"] in used or ex["id"] in in_day:
                continue
            slot = ex.get("slot")
            if slot not in wanted or len(picked[slot]) >= wanted[slot] or not family_ok(ex, True):
                continue
            take(slot, ex)
            note = item.get("note")
            if isinstance(note, str) and note.strip():
                notes[ex["id"]] = note.strip()

        def fill(avoid_global: bool, strict: bool):
            for t, count in day["targets"]:
                for ex in pools.get(t, []):
                    if len(picked[t]) >= count:
                        break
                    if ex["id"] in in_day or (avoid_global and ex["id"] in used) or not family_ok(ex, strict):
                        continue
                    take(t, ex)

        fill(avoid_global=True, strict=True)
        fill(avoid_global=True, strict=False)
        fill(avoid_global=False, strict=False)

        # Havuzu boş kalan yuvaların açığını gündeki diğer yuvalardan kapat
        need = sum(c for _, c in day["targets"])
        have = sum(len(v) for v in picked.values())
        if have < need:
            for t, _ in day["targets"]:
                for ex in pools.get(t, []):
                    if have >= need:
                        break
                    if ex["id"] in in_day:
                        continue
                    take(t, ex)
                    have += 1

        exercises = []
        for t, _ in day["targets"]:
            for ex in sorted(picked[t], key=lambda e: not is_compound(e)):  # bileşik önce
                used.add(ex["id"])
                item = {"id": ex["id"], "name": ex["name"]}
                item.update(scheme_for(ex, goal, experience))
                item["notes"] = notes.get(ex["id"], "")
                exercises.append(item)

        workouts.append(
            {
                "day_number": i + 1,
                "name": day["name"],
                "estimated_duration_min": duration_min,
                "exercises": exercises,
            }
        )
    return workouts


# Havuzu çok küçük kalan yuvanın (ör. barfiks demiri olmayan evde "lats") yerine geçecek komşu
_SIBLINGS = {"lats": "upper back", "upper back": "lats", "leg_curl": "hinge", "leg_ext": "squat",
             "lunge": "hinge", "traps": "upper back", "calves": "squat"}


def sibling_slots(plan: List[dict]) -> List[str]:
    out: List[str] = []
    for d in plan:
        for slot, _ in d["targets"]:
            sib = _SIBLINGS.get(slot)
            if sib and sib not in out:
                out.append(sib)
    return out


def repair_plan(plan: List[dict], pools: Dict[str, List[dict]], min_pool: int = 3) -> List[dict]:
    """Aday sayısı min_pool'dan az kalan yuvaları komşu yuvaya aktarır (sayılar birleşir)."""
    for d in plan:
        merged: Dict[str, int] = {}
        for slot, count in d["targets"]:
            if len(pools.get(slot, [])) < min_pool:
                sib = _SIBLINGS.get(slot)
                if sib and len(pools.get(sib, [])) >= min_pool:
                    slot = sib
            merged[slot] = merged.get(slot, 0) + count
        d["targets"] = list(merged.items())
    return plan
