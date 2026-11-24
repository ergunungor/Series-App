"""Egzersiz havuzu: yerel (yapay zekasız) getirme ve eşleştirme.

Amaç: her istekte ~1300 egzersizi yapay zekaya göndermemek.
- build_catalog_text: kullanıcıya uygun, küçük ve çeşitli bir alt küme üretir.
- find_candidates / match_exact: bir egzersiz adını havuzdaki kayıtlarla eşleştirir.

Sinir ağı / gömme modeli KULLANILMAZ: Türkçe kalitesi düşük, bellek maliyeti
yüksek olduğu için yapılandırılmış filtre + sözcük eşleştirme tercih edildi.
"""

import json
import os
import re
from difflib import SequenceMatcher
from functools import lru_cache
from typing import Dict, Iterable, List, Optional, Set, Tuple

# ---------------------------------------------------------------- yükleme

@lru_cache(maxsize=1)
def _load() -> Tuple[List[dict], Dict[str, dict]]:
    path = os.path.join(os.path.dirname(__file__), "exercises.json")
    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)

    # Sözcük sıklığı: nadir/garip sözcük içeren adlar (yazım hatası, çok özel varyasyon) geriye itilir
    freq: Dict[str, int] = {}
    for ex in raw:
        for w in _tokens((ex.get("name") or "")):
            freq[w] = freq.get(w, 0) + 1

    items: List[dict] = []
    for ex in raw:
        name = (ex.get("name") or "").strip()
        if not name or ex.get("id") is None:
            continue
        items.append(
            {
                "id": str(ex["id"]),
                "name": name,
                "target": ex.get("target") or "",
                "equipment": ex.get("equipment") or "",
                "body_part": ex.get("body_part") or "",
                "tokens": _tokens(name),
                "norm": _normalize(name),
                "rank": _rank(name, ex.get("equipment") or "", freq),
                "slot": classify(name, ex.get("target") or ""),
            }
        )
    return items, {it["id"]: it for it in items}


def all_exercises() -> List[dict]:
    return _load()[0]


def get_by_id(exercise_id) -> Optional[dict]:
    if exercise_id is None:
        return None
    key = str(exercise_id).strip()
    by_id = _load()[1]
    if key in by_id:
        return by_id[key]
    if key.isdigit() and key.zfill(4) in by_id:  # 25 -> "0025"
        return by_id[key.zfill(4)]
    return None


# ------------------------------------------------------------ normalizasyon

_SYNONYMS = {
    "db": "dumbbell", "dumbell": "dumbbell", "dumbbells": "dumbbell",
    "bb": "barbell", "barbells": "barbell",
    "kb": "kettlebell", "kettlebells": "kettlebell",
    "pushup": "push up", "pullup": "pull up", "situp": "sit up",
    "chinup": "chin up", "pressup": "push up",
}


def _normalize(name: str) -> str:
    s = name.lower()
    s = re.sub(r"\((male|female)\)", " ", s)
    s = re.sub(r"[-_/]", " ", s)
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    words = []
    for w in s.split():
        w = _SYNONYMS.get(w, w)
        # basit çoğul eki: "curls" -> "curl" ("press", "glutes" gibi istisnalar)
        if len(w) > 3 and w.endswith("s") and not w.endswith(("ss", "us")):
            w = w[:-1]
        words.extend(w.split())  # sözlükten iki sözcük gelebilir ("push up")
    return " ".join(words)


def _tokens(name: str) -> Set[str]:
    return set(_normalize(name).split())


# ------------------------------------------------------------ sıralama

# Ev tipi kullanıcıların elinde olmayan ya da çok nadir ekipmanlar.
_EXOTIC = {
    "tire", "hammer", "skierg machine", "upper body ergometer", "wheel roller",
    "sled machine", "bosu ball", "olympic barbell", "roller", "medicine ball",
    "stability ball", "assisted", "weighted",
}


# Yaygın, tanınan temel hareket sözcükleri: bunları içeren adlar öne alınır.
_COMMON = {
    "squat", "push-up", "pull-up", "chin-up", "curl", "press", "row", "deadlift",
    "lunge", "plank", "crunch", "raise", "extension", "fly", "dip", "bridge",
    "thrust", "sit-up", "pulldown", "shrug", "burpee", "twist", "kickback",
    "pullover", "step-up", "wall sit", "mountain climber", "jumping jack",
}


# Herkesin tanıdığı temel hareketler: sıralamada öne alınır.
_STAPLES = {
    "barbell bench press", "barbell incline bench press", "dumbbell bench press",
    "dumbbell incline bench press", "push-up", "dumbbell fly", "pull-up", "chin-up",
    "cable pulldown", "barbell bent over row", "dumbbell bent over row", "cable seated row",
    "dumbbell lateral raise", "cable lateral raise", "barbell curl", "dumbbell biceps curl",
    "dumbbell hammer curl", "cable curl", "cable pushdown", "barbell lying triceps extension",
    "triceps dip", "chest dip", "barbell full squat", "dumbbell squat", "barbell front squat",
    "lever leg extension", "lever seated leg curl", "lever lying leg curl", "barbell deadlift",
    "barbell romanian deadlift", "dumbbell romanian deadlift", "walking lunge", "dumbbell lunge",
    "barbell lunge", "lever standing calf raise", "dumbbell standing calf raise", "crunch floor",
    "hanging leg raise", "russian twist", "barbell shrug", "dumbbell shrug",
    "dumbbell rear lateral raise", "dumbbell goblet squat", "lever chest press",
    "dumbbell seated shoulder press",
}

_LEG_TARGETS = {"quads", "glutes", "hamstrings", "adductors", "abductors"}
_DIRECT_SLOTS = {
    "pectorals", "lats", "upper back", "delts", "biceps", "triceps", "forearms", "traps",
    "abs", "calves", "spine", "cardiovascular system",
}


def classify(name: str, target: str) -> Optional[str]:
    """Hareketi bir 'yuva'ya (kas grubu ya da bacak hareket kalıbı) atar. Veri setinde
    temel bacak hareketleri (squat, deadlift) 'glutes' hedefinde olduğu için bacaklar
    kalıba göre ayrılır."""
    n = name.lower()
    if target in _LEG_TARGETS:
        if "jump" in n or "jerk" in n or "plyo" in n:
            return None
        if any(w in n for w in ("lunge", "step-up", "split squat", "bulgarian")):
            return "lunge"
        if any(w in n for w in ("deadlift", "good morning", "hip thrust", "glute bridge", "hip extension")):
            return "hinge"
        if "leg curl" in n:
            return "leg_curl"
        if "leg extension" in n:
            return "leg_ext"
        if "squat" in n or "leg press" in n or "hack" in n:
            return "squat"
        return None
    if target in _DIRECT_SLOTS:
        return target
    return None


def _rank(name: str, equipment: str, freq: Dict[str, int]) -> float:
    """Düşük = temel/yaygın hareket. Uzun adlı varyasyonlar sona gider."""
    n = name.lower()
    score = float(len(n.split()))
    if not any(w in n for w in _COMMON):
        score += 3
    if re.search(r"\bv\. ?\d", n):
        score += 3
    if "(female)" in n:
        score += 2
    if equipment in _EXOTIC:
        score += 2
    score += 2 * sum(1 for w in _tokens(name) if freq.get(w, 0) < 3)
    if n in _STAPLES:
        score -= 6
    return score


# ------------------------------------------------------------ kullanıcı eşlemesi

# Anket seçenekleri -> veri setindeki "target" değerleri
_INTEREST_TARGETS = {
    "karın": ["abs"],
    "kol": ["biceps", "triceps"],
    "bacak": ["quads", "hamstrings", "adductors", "abductors"],
    "sırt": ["lats", "upper back", "traps", "spine"],
    "göğüs": ["pectorals"],
    "omuz": ["delts"],
    "kalça / glute": ["glutes"],
    "kalça": ["glutes"],
    "baldır": ["calves"],
    "ön kol": ["forearms"],
    "core / bel": ["abs", "spine", "serratus anterior"],
}

# Serbest metin (revizyon isteği) için anahtar sözcükler
_KEYWORD_TARGETS = {
    "karın": ["abs"], "mekik": ["abs"], "core": ["abs", "spine"], "abs": ["abs"],
    "biceps": ["biceps"], "bicep": ["biceps"], "pazı": ["biceps"],
    "triceps": ["triceps"], "arka kol": ["triceps"], "kol": ["biceps", "triceps"],
    "bacak": ["quads", "hamstrings", "adductors", "abductors"],
    "quad": ["quads"], "ön bacak": ["quads"], "arka bacak": ["hamstrings"],
    "hamstring": ["hamstrings"], "squat": ["quads", "glutes"],
    "sırt": ["lats", "upper back", "traps", "spine"], "lat": ["lats"],
    "kürek": ["upper back", "lats"], "trapez": ["traps"], "bel": ["spine", "abs"],
    "göğüs": ["pectorals"], "chest": ["pectorals"], "şınav": ["pectorals", "triceps"],
    "omuz": ["delts"], "shoulder": ["delts"],
    "kalça": ["glutes"], "glute": ["glutes"], "popo": ["glutes"],
    "baldır": ["calves"], "calf": ["calves"],
    "ön kol": ["forearms"], "bilek": ["forearms"],
    "kardiyo": ["cardiovascular system"], "cardio": ["cardiovascular system"],
    "koşu": ["cardiovascular system"], "hiit": ["cardiovascular system"],
}

_EQUIPMENT_MAP = {
    "dambıl": {"dumbbell"},
    "direnç bandı": {"band", "resistance band"},
    "kettlebell": {"kettlebell"},
    "barfiks demiri": set(),  # barfiks hareketleri zaten "body weight"
    "atlama ipi": set(),
    "sadece vücut ağırlığı": set(),
}


def allowed_equipment(locations: Iterable[str], equipment: Iterable[str]) -> Optional[Set[str]]:
    """None = kısıt yok (spor salonu). Aksi halde izin verilen ekipman kümesi."""
    locs = [l.strip().lower() for l in (locations or [])]
    if any("salon" in l for l in locs):
        return None
    allowed = {"body weight"}
    for e in equipment or []:
        allowed |= _EQUIPMENT_MAP.get(e.strip().lower(), set())
    return allowed


def interest_targets(interests: Iterable[str]) -> List[str]:
    out: List[str] = []
    for i in interests or []:
        for t in _INTEREST_TARGETS.get(i.strip().lower(), []):
            if t not in out:
                out.append(t)
    return out


def keyword_targets(text: str) -> List[str]:
    t = (text or "").lower()
    out: List[str] = []
    for kw, targets in _KEYWORD_TARGETS.items():
        if kw in t:
            for x in targets:
                if x not in out:
                    out.append(x)
    return out


# ------------------------------------------------------------ katalog üretimi

# Spor salonu kullanıcısı için ekipman öncelik sırası (vücut ağırlığı en sonda)
_GYM_ORDER = ["barbell", "dumbbell", "cable", "leverage machine", "smith machine",
              "ez barbell", "kettlebell", "body weight"]


def pool_order(it: dict, gym: bool) -> tuple:
    """Kalite sırası: temel/yaygın hareketler önde. Salonda salon ekipmanı hafif öncelikli."""
    penalty = 0.0
    if gym:
        eq = it["equipment"]
        penalty = 0.7 * (_GYM_ORDER.index(eq) if eq in _GYM_ORDER else len(_GYM_ORDER) - 1)
    return (it["rank"] + penalty, it["name"])


def _pick_diverse(candidates: List[dict], quota: int, gym: bool = False) -> List[dict]:
    """Kalite sırasıyla (temel hareketler önde) en iyi `quota` hareket; tek bir ekipman
    türü listeyi doldurmasın diye ekipman başına üst sınır var."""
    cap = max(3, (quota * 6) // 10)
    per_equipment: Dict[str, int] = {}
    picked: List[dict] = []
    for c in sorted(candidates, key=lambda x: pool_order(x, gym)):
        eq = c["equipment"]
        limit = 3 if (gym and eq == "body weight") else cap
        if per_equipment.get(eq, 0) >= limit:
            continue
        per_equipment[eq] = per_equipment.get(eq, 0) + 1
        picked.append(c)
        if len(picked) >= quota:
            break
    return picked


def _dedupe_gender(items: List[dict]) -> List[dict]:
    seen: Set[str] = set()
    out = []
    for it in sorted(items, key=lambda x: x["rank"]):
        key = it["norm"]
        if key in seen:
            continue
        seen.add(key)
        out.append(it)
    return out


# Antrenman programında yeri olmayan, çok özel ekipmanlar (assisted/weighted hariç tutulmaz)
_SKIP_EQUIPMENT = {
    "tire", "hammer", "skierg machine", "upper body ergometer", "wheel roller",
    "sled machine", "bosu ball", "roller", "medicine ball", "stability ball",
}


# Antrenman programına uymayan (dövüş, yoga pozu vb.) hareketlerin ad sözcükleri
_ALWAYS_EXCLUDED_WORDS = ("boxing", "yoga", "battling")

# Programda anlamsız ya da tanınmayan (tek sözcüklü, ne olduğu belli olmayan) adlar
_OBSCURE_NAMES = {
    "quads", "sphinx", "elevator", "flag", "cocoons", "butt-ups", "bottoms-up",
    "body-up", "handstand", "elbow-to-knee", "inchworm",
}


def filtered_pool(
    equipment: Optional[Set[str]],
    include_stretches: bool = False,
    excluded_words: Iterable[str] = (),
) -> List[dict]:
    """Ekipmana uyan, esneme/çok özel ekipman ve istenmeyen sözcükler elenmiş havuz."""
    words = [w.lower() for w in excluded_words]
    pool = [
        e for e in all_exercises()
        if (equipment is None or e["equipment"] in equipment)
        and e["equipment"] not in _SKIP_EQUIPMENT
        and (include_stretches or "stretch" not in e["name"])
        and e["name"] not in _OBSCURE_NAMES
        and not any(w in e["name"] for w in _ALWAYS_EXCLUDED_WORDS)
        and not any(w in e["name"] for w in words)
    ]
    return _dedupe_gender(pool)


# Sağlık kısıtı -> o bölgeyi zorlayan hareketlerin ad sözcükleri
_RESTRICTION_WORDS = {
    "diz": ["jump", "lunge", "pistol", "jerk", "box", "step-up", "burpee", "skater", "split squat", "hack"],
    "bel/sırt": ["deadlift", "good morning", "hyperextension", "bent over", "bent-over", "pendlay", "t-bar", "stiff", "sumo", "jerk", "snatch", "clean"],
    "omuz": ["upright row", "behind", "overhead", "shoulder press", "military", "arnold", "snatch", "jerk", "clean", "dip", "handstand"],
    "bilek": ["wrist", "handstand", "planche"],
    "dirsek": ["lying extension", "skull", "dip", "french"],
    "kalça": ["sumo", "lunge", "split squat"],
    "boyun": ["neck", "shrug", "behind"],
    "ayak bileği": ["jump", "skater", "burpee", "calf raise"],
}


PULL_UP_BAR_WORDS = ["pull-up", "pull up", "chin", "hanging", "muscle", "chest dip"]


def restriction_words(restrictions: Iterable[str]) -> List[str]:
    out: List[str] = []
    for r in restrictions or []:
        for w in _RESTRICTION_WORDS.get(r.strip().lower(), []):
            if w not in out:
                out.append(w)
    return out


def candidates_by_slot(
    slots: Iterable[str],
    *,
    equipment: Optional[Set[str]],
    focus_slots: Iterable[str] = (),
    include_stretches: bool = False,
    excluded_words: Iterable[str] = (),
    quota: int = 14,
    focus_quota: int = 18,
) -> Dict[str, List[dict]]:
    """Her yuva (kas grubu / bacak kalıbı) için, temel hareketler önde ve ekipman
    bakımından çeşitli aday listesi."""
    pool = filtered_pool(equipment, include_stretches, excluded_words)
    by_slot: Dict[str, List[dict]] = {}
    for e in pool:
        if e["slot"]:
            by_slot.setdefault(e["slot"], []).append(e)
    focus = set(focus_slots)
    gym = equipment is None
    return {
        slot: sorted(
            _pick_diverse(by_slot.get(slot, []), focus_quota if slot in focus else quota, gym=gym),
            key=lambda it: pool_order(it, gym),
        )
        for slot in slots
    }


def select_exercises(
    *,
    equipment: Optional[Set[str]],
    focus_targets: Iterable[str] = (),
    include_ids: Iterable[str] = (),
    prompt_text: str = "",
    base_quota: int = 8,
    focus_quota: int = 18,
    cardio_quota: int = 4,
    include_stretches: bool = False,
) -> List[dict]:
    pool = filtered_pool(equipment, include_stretches)

    focus = list(focus_targets)
    by_target: Dict[str, List[dict]] = {}
    for e in pool:
        by_target.setdefault(e["target"], []).append(e)

    chosen: Dict[str, dict] = {}
    for target, items in by_target.items():
        if target == "cardiovascular system":
            quota = max(cardio_quota, focus_quota if target in focus else 0)
        else:
            quota = focus_quota if target in focus else base_quota
        for it in _pick_diverse(items, quota, gym=equipment is None):
            chosen[it["id"]] = it

    # Mevcut programdaki hareketler her zaman listede olsun
    for ex_id in include_ids:
        it = get_by_id(ex_id)
        if it:
            chosen[it["id"]] = it

    # Revizyon isteğindeki sözcüklerle adı örtüşen hareketler
    prompt_tokens = _tokens(prompt_text) if prompt_text else set()
    prompt_tokens -= {"i", "a", "the", "and", "or", "with", "to"}
    if prompt_tokens:
        scored = []
        for e in pool:
            overlap = len(e["tokens"] & prompt_tokens)
            if overlap:
                scored.append((-overlap, e["rank"], e))
        scored.sort(key=lambda x: (x[0], x[1]))
        for _, _, e in scored[:15]:
            chosen[e["id"]] = e

    return list(chosen.values())


def _gym_sort_key(it: dict):
    eq = it["equipment"]
    return (_GYM_ORDER.index(eq) if eq in _GYM_ORDER else len(_GYM_ORDER) - 1, it["rank"], it["name"])


def format_catalog(items: List[dict], gym: bool = False) -> str:
    """Kas grubuna göre gruplu, sıkıştırılmış metin: 'id|ad|ekipman'."""
    groups: Dict[str, List[dict]] = {}
    for it in items:
        groups.setdefault(it.get("slot") or it["target"] or "other", []).append(it)
    lines = []
    for target in sorted(groups):
        lines.append(f"[{target}]")
        for it in sorted(groups[target], key=lambda x: pool_order(x, gym)):
            lines.append(f"{it['id']}|{it['name']}|{it['equipment']}")
    return "\n".join(lines)


def build_catalog_text(
    *,
    locations: Iterable[str],
    equipment: Iterable[str],
    interests: Iterable[str] = (),
    include_ids: Iterable[str] = (),
    prompt_text: str = "",
    include_stretches: bool = False,
) -> str:
    focus = interest_targets(interests) + [
        t for t in keyword_targets(prompt_text) if t not in interest_targets(interests)
    ]
    items = select_exercises(
        equipment=allowed_equipment(locations, equipment),
        focus_targets=focus,
        include_ids=include_ids,
        prompt_text=prompt_text,
        include_stretches=include_stretches,
    )
    return format_catalog(items, gym=allowed_equipment(locations, equipment) is None)


# ------------------------------------------------------------ eşleştirme

def _score(norm_a: str, tokens_a: Set[str], item: dict) -> float:
    if not tokens_a or not item["tokens"]:
        return 0.0
    if tokens_a == item["tokens"]:
        return 1.0
    inter = len(tokens_a & item["tokens"])
    if not inter:
        return 0.0
    if tokens_a <= item["tokens"] or item["tokens"] <= tokens_a:
        # biri ötekinin alt kümesi ("plank" ~ "front plank"): yakın ama kesin değil
        return 0.5 + 0.45 * inter / len(tokens_a | item["tokens"])
    jaccard = inter / len(tokens_a | item["tokens"])
    seq = SequenceMatcher(None, norm_a, item["norm"]).ratio()
    return 0.6 * jaccard + 0.4 * seq


def find_candidates(name: str, limit: int = 5, min_score: float = 0.5) -> List[Tuple[dict, float]]:
    norm = _normalize(name)
    toks = set(norm.split())
    scored = []
    for it in all_exercises():
        s = _score(norm, toks, it)
        if s >= min_score:
            scored.append((it, s))
    scored.sort(key=lambda x: (-x[1], x[0]["rank"]))
    # (male)/(female) kopyalarını ele
    seen: Set[str] = set()
    out = []
    for it, s in scored:
        if it["norm"] in seen:
            continue
        seen.add(it["norm"])
        out.append((it, s))
        if len(out) >= limit:
            break
    return out


def match_exact(name: str) -> Optional[dict]:
    """Ad, havuzdaki bir hareketle (normalize sonrası) birebir aynıysa onu döndürür."""
    if not name:
        return None
    cands = find_candidates(name, limit=1, min_score=0.99)
    return cands[0][0] if cands else None
