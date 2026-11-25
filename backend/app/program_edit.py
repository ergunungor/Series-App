"""Programı yapay zekaya baştan yazdırmadan düzenleme.

Yapay zeka yalnızca yapılacak değişikliklerin listesini ("işlemler") döndürür;
işlemleri burada kod uygular. Böylece istenmeyen hareketler, adlar, ısınma,
süperset ve notlar olduğu gibi kalır; istek de küçük olur.

Gün ve hareket numaraları her zaman ilk (değişiklik öncesi) numaralandırmaya
göredir; önce hepsi nesnelere çözülür, sonra sırayla uygulanır.
"""

import copy
from typing import Optional

EDIT_SCHEMA = """İşlemler (gün ve hareket numaraları yukarıdaki listedeki numaralardır):
{"op":"replace","day":1,"ex":2,"name":"","en":""}  hareketi başkasıyla değiştir (set/tekrar/mola korunur; istersen sets/reps/sec/rest de yaz)
{"op":"add","day":1,"after":3,"name":"","en":"","sets":3,"reps":"10","sec":null,"rest":60,"part":null}  harekete ekle ("after": 0 = başa, yazılmazsa sona)
{"op":"remove","day":1,"ex":4}  hareketi sil
{"op":"set","day":1,"ex":2,"sets":4,"reps":"8-10","sec":null,"rest":90,"drop":0,"part":null}  sadece verilen alanları değiştir; "ex" yazılmazsa o günün tüm hareketleri, "day" de yazılmazsa tüm program
{"op":"move","day":1,"ex":3,"to_day":2,"after":1}  hareketi taşı / sırasını değiştir
{"op":"superset","day":1,"ex":[5,6]}  art arda yapılacak hareketleri süperset yap
{"op":"unsuperset","day":1,"ex":5}  süpersetten çıkar
{"op":"add_day","after":2,"name":"","exercises":[{"name":"","en":"","sets":3,"reps":"10","sec":null,"rest":60}]}  yeni gün
{"op":"remove_day","day":3}
{"op":"rename_day","day":1,"name":""}
{"op":"rename_program","name":""}
"name": kullanıcının göreceği ad; "en": hareketin yaygın İngilizce spor salonu adı. "part": "warmup" (ısınma), "cooldown" (soğuma) ya da null. "sec": süreli hareketlerde saniye (o zaman "reps": null)."""


def render_program(program: dict) -> str:
    """Yapay zekaya gösterilen kısa, numaralı program metni."""
    lines = [f"Program: {program.get('program_name') or program.get('name') or ''}"]
    for d, w in enumerate(program.get("workouts") or [], start=1):
        lines.append(f"Gün {d}: {w.get('name') or ''}")
        for i, ex in enumerate(w.get("exercises") or [], start=1):
            work = f"{ex.get('duration_seconds')}sn" if ex.get("duration_seconds") else (ex.get("reps") or "")
            tags = []
            if ex.get("section") == "warmup":
                tags.append("ısınma")
            elif ex.get("section") == "cooldown":
                tags.append("soğuma")
            if ex.get("superset_group"):
                tags.append(f"süperset {ex['superset_group']}")
            if ex.get("drop_sets"):
                tags.append(f"dropset {ex['drop_sets']}")
            tag = f" [{', '.join(tags)}]" if tags else ""
            lines.append(f"  {i}. {ex.get('name')} {ex.get('sets')}x{work} mola {ex.get('rest_seconds', 60)}sn{tag}")
    return "\n".join(lines)


def _int(v, default=None):
    try:
        return int(v)
    except (TypeError, ValueError):
        return default


def _apply_fields(ex: dict, op: dict):
    if "sets" in op and _int(op["sets"]):
        ex["sets"] = _int(op["sets"])
    if op.get("sec"):
        ex["duration_seconds"] = _int(op["sec"])
        ex["reps"] = None
    elif op.get("reps") not in (None, ""):
        ex["reps"] = str(op["reps"])
        ex["duration_seconds"] = None
    if "rest" in op and _int(op["rest"]) is not None:
        ex["rest_seconds"] = _int(op["rest"])
    if "drop" in op:
        drops = _int(op["drop"], 0) or 0
        if drops:
            ex["drop_sets"] = drops
        else:
            ex.pop("drop_sets", None)
    if "part" in op:
        if op["part"] in ("warmup", "cooldown"):
            ex["section"] = op["part"]
        else:
            ex.pop("section", None)


def _new_exercise(spec: dict) -> dict:
    ex = {
        "id": "",
        "name": (spec.get("name") or spec.get("en") or "Hareket").strip(),
        "english_name": spec.get("en"),
        "sets": 3,
        "reps": "10",
        "duration_seconds": None,
        "rest_seconds": 60,
        "_new": True,
    }
    _apply_fields(ex, spec)
    return ex


def apply_edits(program: dict, ops: list) -> dict:
    """İşlemleri programın bir kopyasına uygular ve yeni programı döndürür."""
    result = copy.deepcopy(program)
    days = result.setdefault("workouts", [])
    # Numaralar ilk listeye göre: nesnelere önceden çözülür.
    orig_days = list(days)
    orig_ex = [list(w.get("exercises") or []) for w in orig_days]
    next_group = max(
        [_int(e.get("superset_group"), 0) or 0 for w in days for e in (w.get("exercises") or [])] + [0]
    ) + 1

    def day_at(n) -> Optional[dict]:
        n = _int(n)
        return orig_days[n - 1] if n and 1 <= n <= len(orig_days) else None

    def ex_at(d, n) -> Optional[dict]:
        d, n = _int(d), _int(n)
        if not d or not n or not (1 <= d <= len(orig_ex)):
            return None
        lst = orig_ex[d - 1]
        return lst[n - 1] if 1 <= n <= len(lst) else None

    def owner(ex) -> Optional[dict]:
        for w in days:
            if any(e is ex for e in w.get("exercises") or []):
                return w
        return None

    def insert(w: dict, ex: dict, after):
        lst = w.setdefault("exercises", [])
        if after is None:
            lst.append(ex)
            return
        a = _int(after, None)
        if a == 0:
            lst.insert(0, ex)
            return
        ref = ex_at(orig_days.index(w) + 1, a) if w in orig_days else None
        if ref is not None and any(e is ref for e in lst):
            lst.insert(next(i for i, e in enumerate(lst) if e is ref) + 1, ex)
        else:
            lst.insert(min(a, len(lst)) if a is not None else len(lst), ex)

    def remove_obj(ex):
        w = owner(ex)
        if w is not None:
            w["exercises"] = [e for e in w["exercises"] if e is not ex]

    for op in ops or []:
        if not isinstance(op, dict):
            continue
        kind = op.get("op")
        if kind == "replace":
            ex = ex_at(op.get("day"), op.get("ex"))
            if ex is None:
                continue
            keep = {k: ex[k] for k in ("sets", "reps", "duration_seconds", "rest_seconds",
                                       "superset_group", "drop_sets", "section") if k in ex}
            ex.clear()
            ex.update(keep)
            ex.update({"id": "", "name": (op.get("name") or op.get("en") or "Hareket").strip(),
                       "english_name": op.get("en"), "_new": True})
            _apply_fields(ex, op)
        elif kind == "add":
            w = day_at(op.get("day"))
            if w is not None:
                insert(w, _new_exercise(op), op.get("after"))
        elif kind == "remove":
            ex = ex_at(op.get("day"), op.get("ex"))
            if ex is not None:
                remove_obj(ex)
        elif kind == "set":
            if op.get("day") is None:
                targets = [e for w in days for e in w.get("exercises") or []]
            elif op.get("ex") is None:
                w = day_at(op.get("day"))
                targets = list(w.get("exercises") or []) if w else []
            else:
                exs = op["ex"] if isinstance(op["ex"], list) else [op["ex"]]
                targets = [e for e in (ex_at(op.get("day"), n) for n in exs) if e is not None]
            for ex in targets:
                _apply_fields(ex, op)
        elif kind == "move":
            ex = ex_at(op.get("day"), op.get("ex"))
            dest = day_at(op.get("to_day") or op.get("day"))
            if ex is not None and dest is not None:
                remove_obj(ex)
                insert(dest, ex, op.get("after"))
        elif kind == "superset":
            exs = [ex_at(op.get("day"), n) for n in (op.get("ex") or [])]
            exs = [e for e in exs if e is not None]
            if len(exs) >= 2:
                w = owner(exs[0])
                if w is not None:
                    # Art arda dursunlar: ilkinden sonra sırayla yerleştir.
                    for e in exs[1:]:
                        remove_obj(e)
                    pos = next(i for i, e in enumerate(w["exercises"]) if e is exs[0])
                    for k, e in enumerate(exs[1:], start=1):
                        w["exercises"].insert(pos + k, e)
                    for e in exs:
                        e["superset_group"] = next_group
                    next_group += 1
        elif kind == "unsuperset":
            ex = ex_at(op.get("day"), op.get("ex"))
            if ex is not None:
                ex.pop("superset_group", None)
        elif kind == "add_day":
            w = {"name": op.get("name") or f"Gün {len(days) + 1}",
                 "exercises": [_new_exercise(s) for s in (op.get("exercises") or []) if isinstance(s, dict)]}
            ref = day_at(op.get("after"))
            if ref is not None and ref in days:
                days.insert(days.index(ref) + 1, w)
            elif _int(op.get("after")) == 0:
                days.insert(0, w)
            else:
                days.append(w)
        elif kind == "remove_day":
            w = day_at(op.get("day"))
            if w is not None and w in days and len(days) > 1:
                days.remove(w)
        elif kind == "rename_day":
            w = day_at(op.get("day"))
            if w is not None and op.get("name"):
                w["name"] = op["name"]
        elif kind == "rename_program":
            if op.get("name"):
                result["program_name"] = op["name"]

    for d, w in enumerate(days, start=1):
        w["day_number"] = d
    return result


def new_exercises(program: dict) -> list:
    """apply_edits'in eklediği / değiştirdiği hareketler (eşleştirme için)."""
    return [e for w in program.get("workouts") or [] for e in w.get("exercises") or [] if e.get("_new")]
