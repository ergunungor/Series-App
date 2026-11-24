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


def _pick_diverse(candidates: List[dict], quota: int, gym: bool = False) -> List[dict]:
    """Önce temel hareketler, ekipmanlar arasında dönüşümlü: çeşitlilik sağlar."""
    groups: Dict[str, List[dict]] = {}
    for c in sorted(candidates, key=lambda x: (x["rank"], x["name"])):
        groups.setdefault(c["equipment"], []).append(c)
    # en yaygın (en iyi sıralı) ekipman önce gelsin
    if gym:
        order = sorted(groups, key=lambda k: (_GYM_ORDER.index(k) if k in _GYM_ORDER else len(_GYM_ORDER), groups[k][0]["rank"]))
    else:
        order = sorted(groups, key=lambda k: groups[k][0]["rank"])
    picked: List[dict] = []
    i = 0
    while len(picked) < quota and any(i < len(groups[k]) for k in order):
        for k in order:
            if i < len(groups[k]) and len(picked) < quota:
                picked.append(groups[k][i])
        i += 1
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
    pool = [
        e for e in all_exercises()
        if (equipment is None or e["equipment"] in equipment)
        and e["equipment"] not in _SKIP_EQUIPMENT
        and (include_stretches or "stretch" not in e["name"])
    ]
    pool = _dedupe_gender(pool)

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


def format_catalog(items: List[dict]) -> str:
    """Kas grubuna göre gruplu, sıkıştırılmış metin: 'id|ad|ekipman'."""
    groups: Dict[str, List[dict]] = {}
    for it in items:
        groups.setdefault(it["target"] or "other", []).append(it)
    lines = []
    for target in sorted(groups):
        lines.append(f"[{target}]")
        for it in sorted(groups[target], key=lambda x: (x["rank"], x["name"])):
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
    return format_catalog(items)


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
