import json
import re
from typing import Optional

from .llm import generate_json
from .schemas import UserOnboardingData
from . import exercise_catalog as catalog

# Eşleştirme eşikleri (exercise_catalog._score ölçeği, 0-1)
AUTO_MATCH_SCORE = 0.99      # birebir aynı ad: yapay zekaya sormadan eşleştir
CANDIDATE_MIN_SCORE = 0.5    # bunun altı aday sayılmaz


# ------------------------------------------------------------------ üretim

_PROGRAM_SCHEMA = (
    '{"program_name":"","description":"2 cümle","workouts":[{"day_number":1,"name":"",'
    '"estimated_duration_min":0,"exercises":[{"id":"","sets":3,"reps":"8-12",'
    '"duration_seconds":null,"rest_seconds":60,"notes":""}]}]}'
)

_DURATION_RULE = (
    'Süreli hareketlerde (plank, tutuş, kardiyo aralığı vb.) "reps": null ve '
    '"duration_seconds": saniye yaz.'
)


def generate_workout_program(data: UserOnboardingData):
    interests = data.specific_interests or []
    restrictions = ", ".join(data.health_restrictions) if data.health_restrictions else "Yok"
    equipment = ", ".join(data.logistics.equipment) if data.logistics.equipment else "Yok"

    catalog_text = catalog.build_catalog_text(
        locations=data.logistics.location,
        equipment=data.logistics.equipment or [],
        interests=interests,
        include_stretches=any(k in (data.primary_goal or "").lower() for k in ("esneklik", "rehabilitasyon")),
    )

    allowed = catalog.allowed_equipment(data.logistics.location, data.logistics.equipment or [])
    per_day = max(4, min(8, round(data.logistics.max_duration_min / 8)))

    gym_rule = ""
    if allowed is None:
        gym_rule = (
            "\nKullanıcı spor salonunda: barbell, dambıl, kablo ve makine hareketlerini öncelikle seç; "
            "vücut ağırlığı hareketleri günde en fazla 1-2 tane olsun."
        )

    prompt = f"""{data.age} yaşında, {data.gender}, deneyim: {data.experience}, hedef: {data.primary_goal}.
Odak bölgeler: {", ".join(interests) or "Tüm vücut"}. Sağlık kısıtları: {restrictions}.
Yer: {", ".join(data.logistics.location)}. Ekipman: {equipment}.
Haftada {data.logistics.days_per_week} gün, en fazla {data.logistics.max_duration_min} dk. Zihinsel engel: {data.mental_blocker or "Yok"}.

{data.logistics.days_per_week} günlük antrenman programı hazırla. Her güne {per_day} hareket koy (bir günde aynı hareketi tekrarlama).
Odak bölgelere ağırlık ver ama programı dengeli tut: her gün farklı kas grupları çalışsın, aynı bölge ardışık günlerde tekrar etmesin.
Sağlık kısıtlarına aykırı hareket seçme.{gym_rule}
Hareketleri yalnızca aşağıdaki listeden seç ve "id" alanına listedeki id'yi yaz (satır: id|ad|ekipman; kas grubuna göre gruplu).
{_DURATION_RULE}
Sadece şu şemada JSON döndür:
{_PROGRAM_SCHEMA}

LİSTE:
{catalog_text}"""

    min_per_day = max(3, per_day - 2)

    def attempt(model_type: str) -> dict:
        raw = generate_json(prompt, model_type=model_type)
        return _finalize_exercises(raw, allow_custom=False, allowed_equipment=allowed)

    def is_complete(program: dict) -> bool:
        workouts = program.get("workouts", [])
        return len(workouts) == data.logistics.days_per_week and all(
            len(w.get("exercises", [])) >= min_per_day for w in workouts
        )

    result = attempt(data.model_type)
    if not is_complete(result) and data.model_type != "pro":
        # Küçük model eksik gün/hareket üretti: bir kez büyük modelle dene
        print("⚠️ Program eksik üretildi, büyük modelle yeniden deneniyor.")
        try:
            better = attempt("pro")
            if is_complete(better):
                result = better
        except Exception as e:
            print(f"⚠️ Yeniden deneme başarısız: {e}")
    return sanitize_program_data(result)


def revise_workout_program(data):
    current = data.current_program or {}
    include_ids = [
        ex.get("id")
        for w in current.get("workouts", [])
        for ex in w.get("exercises", [])
        if ex.get("id")
    ]

    catalog_text = catalog.build_catalog_text(
        locations=["Spor Salonu"],  # revizyonda kullanıcı ekipman bilgisi yok: tüm havuz
        equipment=[],
        include_ids=include_ids,
        prompt_text=data.prompt,
        include_stretches=any(k in data.prompt.lower() for k in ("esne", "stretch", "mobilite", "hareketlilik")),
    )

    prompt = f"""Mevcut program:
{json.dumps(_compact_program(current), ensure_ascii=False, separators=(",", ":"))}

İstenen değişiklik: "{data.prompt}"

Programı bu isteğe göre güncelle; istenmeyen kısımları koru.
Yeni hareketleri yalnızca aşağıdaki listeden seç ve "id" alanına listedeki id'yi yaz (satır: id|ad|ekipman).
Mevcut programda id'si boş olan bir hareketi koruyorsan "id": "" bırak ve "name" alanını aynen yaz.
{_DURATION_RULE}
Sadece şu şemada JSON döndür ("name" yalnızca id'si boş olan hareketlerde yazılır):
{_PROGRAM_SCHEMA.replace('"exercises":[{"id":"",', '"exercises":[{"id":"","name":"",')}

LİSTE:
{catalog_text}"""

    result = generate_json(prompt, model_type=data.model_type)
    _restore_instructions(result, current)
    return sanitize_program_data(_finalize_exercises(result, allow_custom=True))


def _compact_program(program: dict) -> dict:
    """Yapay zekaya gereksiz alanları (talimat metni vb.) göndermeyiz."""
    workouts = []
    for w in program.get("workouts", []):
        exs = []
        for ex in w.get("exercises", []):
            item = {
                "id": ex.get("id") or "",
                "name": ex.get("name"),
                "sets": ex.get("sets"),
                "reps": ex.get("reps"),
                "duration_seconds": ex.get("duration_seconds"),
                "rest_seconds": ex.get("rest_seconds"),
            }
            exs.append({k: v for k, v in item.items() if v not in (None, "")} | {"id": item["id"]})
        workouts.append(
            {
                "day_number": w.get("day_number"),
                "name": w.get("name"),
                "estimated_duration_min": w.get("estimated_duration_min"),
                "exercises": exs,
            }
        )
    return {
        "program_name": program.get("program_name") or program.get("name"),
        "description": program.get("description"),
        "workouts": workouts,
    }


def _restore_instructions(result: dict, original: dict):
    """Yapay zeka çıktısında düşen 'instructions' alanını eski programdan geri koy."""
    by_name = {}
    for w in original.get("workouts", []):
        for ex in w.get("exercises", []):
            if ex.get("name") and ex.get("instructions"):
                by_name[ex["name"].strip().lower()] = ex["instructions"]
    for w in result.get("workouts", []):
        for ex in w.get("exercises", []):
            name = (ex.get("name") or "").strip().lower()
            if name in by_name and not ex.get("instructions"):
                ex["instructions"] = by_name[name]


def _finalize_exercises(program: dict, allow_custom: bool, allowed_equipment=None) -> dict:
    """id'leri havuza göre doğrular, adı havuzdaki adla doldurur.

    Havuzda olmayan (uydurulmuş) hareketler atılır; allow_custom=True ise
    kullanıcının kendi (id'siz) hareketleri korunur.
    """
    for w in program.get("workouts", []):
        kept = []
        for ex in w.get("exercises", []):
            found = catalog.get_by_id(ex.get("id"))
            if not found and ex.get("name"):
                found = catalog.match_exact(ex["name"])
            if found and allowed_equipment is not None and found["equipment"] not in allowed_equipment:
                print(f"⚠️ Ekipmana uymayan hareket atıldı: {found['name']} ({found['equipment']})")
                continue
            if found:
                ex["id"] = found["id"]
                ex["name"] = found["name"]
                kept.append(ex)
            elif allow_custom and ex.get("name"):
                ex["id"] = ""
                kept.append(ex)
            else:
                print(f"⚠️ Havuzda olmayan hareket atıldı: {ex.get('id')} / {ex.get('name')}")
        w["exercises"] = kept
    return program


def save_generated_program(supabase_client, user_id: str, generated_program: dict):
    program_insert = supabase_client.table('programs').insert({
        "user_id": user_id,
        "name": generated_program.get("program_name", "Özel Program"),
        "description": generated_program.get("description", "")
    }).execute()

    program_id = program_insert.data[0]['id']

    workouts_data = [{
        "program_id": program_id,
        "day_number": w.get("day_number"),
        "name": w.get("name"),
        "estimated_duration_min": w.get("estimated_duration_min"),
        "exercises": w.get("exercises", [])
    } for w in generated_program.get("workouts", [])]

    if workouts_data:
        supabase_client.table('workouts').insert(workouts_data).execute()

    return program_id


# ------------------------------------------------------------ program yükleme

_PARSE_PROMPT = """Verilen antrenman programını JSON'a çevir.

Kurallar:
- Programda yazanı kullan, hareket uydurma. Programdaki TÜM günleri ve her günün TÜM hareketlerini sırasıyla yaz; hiçbirini atlama, birleştirme ya da kısaltma.
- Isınma/soğuma hareketleri de o günün listesine girer (başta/sonda), "notes": "Isınma" ya da "Soğuma".
- Her öğe tek bir hareket olmalı. Aynı satırda ya da cümlede birden fazla farklı hareket geçiyorsa (nasıl yazılmış olursa olsun) her birini kendi set/tekrar/süresiyle ayrı öğe olarak yaz.
- "name": programda yazdığı ad. "en": aynı hareketin yaygın İngilizce spor salonu adı (örn. Şınav -> push-up, Barfiks -> pull-up).
- Süre (sn/saniye/sec/dk/dakika) varsa "reps": null ve süreyi saniye olarak "sec" alanına yaz (30 sn -> 30, 5 dk -> 300). Yoksa "reps" kullan ("8-12", "max", "20 adım", "40 m" gibi metin olabilir).
- "rest": dinlenme saniyesi (yazmıyorsa 60).
- Süperset: "süperset/superset/SS", "A1/A2", "5a/5b", "+" ya da "ara vermeden/arka arkaya" ile bağlanan hareketlere aynı tam sayıyı "ss" olarak ver (her süperset için yeni sayı). Süperset değilse alanı yazma.
- Dropset: "dropset/drop set" yazan harekette "drop" = ek düşürme sayısı (belirtilmemişse 2). Değilse alanı yazma.
- "notes": yalnızca programda hareketle ilgili ek bilgi varsa (örn. "her bacak", "son sette dropset"); yoksa alanı yazma.
- İçerik bir antrenman programı değilse sadece {"error": "not_a_program"} döndür.

Kısa ve boşluksuz JSON döndür, şu şemada:
{"program_name":"","description":"1 cümle","workouts":[{"name":"","min":45,"exercises":[{"name":"","en":"","sets":3,"reps":"8-12","sec":null,"rest":60}]}]}"""


def _expand_compact(program: dict):
    """Kısa alan adlarıyla gelen yapay zeka çıktısını uygulamanın şemasına açar."""
    for d, w in enumerate(program.get("workouts") or [], start=1):
        w.setdefault("day_number", d)
        w["estimated_duration_min"] = _to_int(w.pop("min", None) or w.get("estimated_duration_min"), 45)
        for ex in w.get("exercises") or []:
            if "en" in ex:
                ex["english_name"] = ex.pop("en")
            if "sec" in ex:
                ex["duration_seconds"] = ex.pop("sec")
            if "rest" in ex:
                ex["rest_seconds"] = _to_int(ex.pop("rest"), 60)
            if "ss" in ex:
                ex["superset_group"] = ex.pop("ss")
            if "drop" in ex:
                ex["drop_sets"] = ex.pop("drop")
            ex.setdefault("rest_seconds", 60)
            if ex.get("duration_seconds"):
                ex["reps"] = None


def estimate_minutes(exercises: list) -> int:
    """Set, süre ve molalardan antrenman süresini kabaca hesaplar (5'e yuvarlı)."""
    total = 0
    for ex in exercises:
        sets = _to_int(ex.get("sets"), 3) or 1
        work = _to_int(ex.get("duration_seconds"), 0) or 40
        work *= 1 + _to_int(ex.get("drop_sets"), 0)
        rest = _to_int(ex.get("rest_seconds"), 60)
        total += sets * (work + rest)
    return max(10, int(round(total / 60 / 5.0)) * 5)


def _fill_missing_instructions(program: dict):
    """Havuzla eşleşmeyen hareketler için (GIF'i olmayanlar) kısa bir tarif ister.
    Eşleşenlerin tarifi uygulamada havuzdan geldiği için onlara gerek yok."""
    missing = [
        ex for w in program.get("workouts") or [] for ex in w.get("exercises") or []
        if not ex.get("id") and not ex.get("instructions")
    ]
    if not missing:
        return
    names = {str(i): ex.get("english_name") or ex.get("name") for i, ex in enumerate(missing)}
    prompt = (
        "Her hareket için nasıl yapıldığını anlatan 1-2 kısa Türkçe cümle yaz.\n"
        f"{json.dumps(names, ensure_ascii=False)}\n"
        'Sadece JSON döndür: {"0": "...", "1": "..."}'
    )
    answers = generate_json(prompt, model_type="flash")
    for i, ex in enumerate(missing):
        text = answers.get(str(i))
        if isinstance(text, str) and text.strip():
            ex["instructions"] = text.strip()


def _to_int(value, default):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def program_from_structured_json(data: dict) -> Optional[dict]:
    """Hareket kimlikleri (exercise_id) zaten içeren hazır program JSON'unu
    ("schedule": [{ "warmup": [...], "items": [...] }]) yapay zekasız çevirir.
    Tanınmayan bir yapıysa None döner."""
    schedule = data.get("schedule")
    if not isinstance(schedule, list) or not schedule:
        return None

    workouts = []
    for d, day in enumerate(schedule, start=1):
        if not isinstance(day, dict):
            continue
        entries = [("warmup", e) for e in (day.get("warmup") or [])]
        entries += [("main", e) for e in (day.get("items") or [])]

        exercises = []
        for kind, e in entries:
            if not isinstance(e, dict):
                continue
            ex_id = e.get("exercise_id") or e.get("fallback_exercise_id")
            item = catalog.get_by_id(ex_id)
            name = e.get("display_name_tr") or e.get("exercise_name") or (item or {}).get("name") or "Hareket"
            notes = [n for n in (e.get("notes_tr"),) if n]
            if e.get("per_side"):
                notes.append("Her taraf için")
            if e.get("exercise_id_note"):
                notes.append(e["exercise_id_note"])

            ex = {
                "name": name,
                "sets": _to_int(e.get("sets") or e.get("repeats"), 3),
                "reps": str(e.get("reps") or ""),
                "duration_seconds": None,
                "rest_seconds": _to_int(e.get("rest_sec") or e.get("recovery_sec"), 30 if kind == "warmup" else 60),
                "notes": " · ".join(notes) or None,
            }
            if item:
                ex["id"] = item["id"]
            if e.get("distance_m"):
                ex["reps"] = f"{e['distance_m']} m"
                if e.get("effort"):
                    ex["notes"] = " · ".join(filter(None, [ex["notes"], f"Efor: {e['effort']}"]))
            if e.get("superset_group") not in (None, ""):
                ex["superset_group"] = e["superset_group"]
            if e.get("drop_sets"):
                ex["drop_sets"] = e["drop_sets"]
            exercises.append(ex)

        if not exercises:
            continue
        title = day.get("title_tr") or day.get("title") or f"Gün {d}"
        day_name = day.get("day_tr")
        workouts.append({
            "day_number": len(workouts) + 1,
            "name": f"{day_name}: {title}" if day_name and day_name not in title else title,
            "estimated_duration_min": _to_int(day.get("est_duration_min"), 45),
            "exercises": exercises,
        })

    if not workouts:
        return None
    return {
        "program_name": data.get("program_name") or "Programım",
        "description": f"{len(workouts)} günlük program",
        "workouts": workouts,
    }


def parse_program_from_input(text: str = None, file_bytes: bytes = None, mime_type: str = None):
    # Hazır yapılandırılmış JSON ise yapay zekaya gerek yok: hiçbir gün/hareket
    # kaybolmaz ve hareket kimlikleri aynen korunur.
    if text and text.lstrip().startswith("{"):
        try:
            structured = program_from_structured_json(json.loads(text))
        except (ValueError, TypeError):
            structured = None
        if structured:
            return sanitize_program_data(structured)

    prompt = _PARSE_PROMPT
    if text:
        prompt += f"\n\nPROGRAM:\n{text}"
        file_bytes, mime_type = None, None
    elif not (file_bytes and mime_type):
        raise ValueError("Ne metin ne dosya verildi.")

    model = "pro"  # ayrıştırmada eksiksizlik hızdan önemli
    result = generate_json(prompt, model_type=model, file_bytes=file_bytes, mime_type=mime_type)

    if result.get("error") == "not_a_program":
        raise ValueError("Yüklenen içerik bir antrenman programına benzemiyor.")
    _expand_compact(result)

    try:
        _match_to_pool(result)
    except Exception as e:  # eşleştirme isteğe bağlı: hata olursa tarifler olduğu gibi kalır
        print(f"⚠️ GIF eşleştirme atlandı: {e}")

    try:
        _fill_missing_instructions(result)
    except Exception as e:  # tarif isteğe bağlı
        print(f"⚠️ Tarif tamamlama atlandı: {e}")

    for w in result.get("workouts", []):
        for ex in w.get("exercises", []):
            ex.pop("english_name", None)

    result = sanitize_program_data(result)
    # Model süreyi genelde örnekteki gibi sabit yazıyor; setlerden hesapla.
    for w in result.get("workouts", []):
        w["estimated_duration_min"] = estimate_minutes(w.get("exercises", []))
    return result


_STD_EQUIPMENT = ["barbell", "dumbbell"]


def _standard_variant(query: str, cands: list):
    """Ad ekipman belirtmiyorsa ("bench press") aynı hareketin en yaygın ekipmanlı
    halini seçer: aday adı = sorgu + tek bir ekipman kelimesi. Barbell > dumbbell > ..."""
    q = set(catalog._normalize(query).split())
    if not q:
        return None
    best, best_rank = None, None
    for it, _ in cands:
        extra = set(it["norm"].split()) - q
        if not q <= set(it["norm"].split()) or len(extra) != 1:
            continue
        word = next(iter(extra))
        if word not in _STD_EQUIPMENT:
            continue
        rank = _STD_EQUIPMENT.index(word)
        if best is None or rank < best_rank:
            best, best_rank = it, rank
    # Dumbbell seçilecekse ama barbell'lı (daha uzun adlı) bir varyasyon da
    # varsa ("squat" -> "barbell full squat") yapay zekaya bırak.
    if best is not None and best_rank > 0:
        for it in catalog.all_exercises():
            toks = set(it["norm"].split())
            if "barbell" in toks and q <= toks:
                return None
    return best


def _match_to_pool(program: dict):
    """Programdaki hareketleri havuzla eşleştirir; eşleşirse "id" alanı dolar.

    1) Normalize edilmiş ad birebir aynıysa yapay zekaya sormadan eşleşir.
    2) Yakın ama kesin olmayan adaylar tek bir toplu yapay zeka çağrısına gider.
    3) Eşleşme yoksa "id" eklenmez; mevcut tarif metni aynen kalır.
    """
    uncertain = []  # (egzersiz, [aday kayıtlar])
    for w in program.get("workouts", []):
        for ex in w.get("exercises", []):
            if ex.get("id"):
                continue
            queries = [q for q in (ex.get("english_name"), ex.get("name")) if q]
            alias = next((a for a in map(catalog.alias_match, queries) if a), None)
            if alias:
                ex["id"] = alias["id"]
                continue
            best = []
            for q in queries:
                cands = catalog.find_candidates(q, limit=10, min_score=CANDIDATE_MIN_SCORE)
                if cands and cands[0][1] >= AUTO_MATCH_SCORE:
                    ex["id"] = cands[0][0]["id"]
                    best = []
                    break
                std = _standard_variant(q, cands)
                if std:
                    ex["id"] = std["id"]
                    best = []
                    break
                if cands and (not best or cands[0][1] > best[0][1]):
                    best = cands
            if not ex.get("id") and best:
                uncertain.append((ex, [c for c, _ in best]))

    if not uncertain:
        return

    items = [
        {"i": i, "ad": ex.get("english_name") or ex.get("name"), "adaylar": [c["name"] for c in cands]}
        for i, (ex, cands) in enumerate(uncertain)
    ]
    prompt = (
        "Her öğe için adaylardan AYNI hareket olanın sıra numarasını (0'dan başlar) yaz; "
        "yoksa null yaz. Aynı hareketin farklı yazılışı (kelime sırası, 'bench' gibi ek kelimeler) "
        "aynı sayılır. Ad ekipman belirtmiyorsa en yaygın/standart olanı seç (genelde barbell, "
        "ya da hareketin klasik hali). Ad eğim, tutuş ya da ekipman belirtiyorsa bunlar adayla "
        "uyuşmalı; farklı bir hareket ise null yaz.\n"
        f"{json.dumps(items, ensure_ascii=False, separators=(',', ':'))}\n"
        'Sadece JSON döndür: {"0": 2, "1": null, ...}'
    )
    answers = generate_json(prompt, model_type="flash")

    for i, (ex, cands) in enumerate(uncertain):
        choice = answers.get(str(i))
        if isinstance(choice, int) and 0 <= choice < len(cands):
            ex["id"] = cands[choice]["id"]


def normalize_supersets(exercises: list):
    """Süperset ve dropset alanlarını uygulamanın beklediği biçime getirir.

    Yalnızca art arda gelen, en az 2 hareketlik gruplar süperset sayılır; gruplar
    1, 2, ... diye yeniden numaralanır, set sayısı ilk hareketinkine eşitlenir ve
    mola yalnızca bloğun son hareketinde kalır.
    """
    def key(ex):
        raw = ex.get("superset_group")
        return None if raw in (None, "", 0, False) else str(raw)

    n, i, next_id = len(exercises), 0, 1
    while i < n:
        k = key(exercises[i])
        j = i
        while k is not None and j + 1 < n and key(exercises[j + 1]) == k:
            j += 1
        if k is not None and j > i:
            for idx in range(i, j + 1):
                ex = exercises[idx]
                ex["superset_group"] = next_id
                ex["sets"] = exercises[i].get("sets") or ex.get("sets") or 3
                if idx < j:
                    ex["rest_seconds"] = 0
            next_id += 1
        else:
            for idx in range(i, j + 1):
                exercises[idx].pop("superset_group", None)
        i = j + 1

    for ex in exercises:
        try:
            drops = max(0, min(4, int(ex.get("drop_sets") or 0)))
        except (TypeError, ValueError):
            drops = 0
        if drops:
            ex["drop_sets"] = drops
        else:
            ex.pop("drop_sets", None)


def sanitize_program_data(data: dict):
    for workout in data.get("workouts", []):
        normalize_supersets(workout.get("exercises", []))
        for exercise in workout.get("exercises", []):
            reps = exercise.get("reps")
            dur = exercise.get("duration_seconds")

            if not dur and reps and isinstance(reps, str):
                reps_lower = reps.lower()
                if any(kw in reps_lower for kw in ["sn", "saniye", "sec"]):
                    match = re.search(r'\d+', reps_lower)
                    if match:
                        exercise["duration_seconds"] = int(match.group())
                        exercise["reps"] = None

            name_lower = (exercise.get("name") or "").lower()
            if ("plank" in name_lower or "hold" in name_lower) and not exercise.get("duration_seconds") and not exercise.get("reps"):
                exercise["duration_seconds"] = 30

    return data
