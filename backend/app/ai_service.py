import os
import json
import re
import google.generativeai as genai
from dotenv import load_dotenv
from .schemas import UserOnboardingData

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

def get_generative_models(model_type: str):
    """
    İsteğe göre ana ve yedek modelleri döndürür.
    Pro: 3.7-flash (Ana) -> 3.5-flash-lite (Yedek)
    Flash: 3.6-flash (Ana) -> 3.1-flash-lite (Yedek)
    """
    if model_type == "pro":
        primary = genai.GenerativeModel('gemini-3.7-flash')
        fallback = genai.GenerativeModel('gemini-3.5-flash-lite')
    else:
        primary = genai.GenerativeModel('gemini-3.6-flash')
        fallback = genai.GenerativeModel('gemini-3.1-flash-lite')
        
    return primary, fallback

def generate_with_fallback(content, generation_config, model_type="flash"):
    """Seçilen model tipine göre önce ana modeli dener, kota hatası alırsa yedeğe geçer."""
    primary_model, fallback_model = get_generative_models(model_type)
    
    try:
        return primary_model.generate_content(content, generation_config=generation_config)
    except Exception as e:
        error_msg = str(e)
        if "429" in error_msg or "Quota" in error_msg:
            print(f"⚠️ Ana model limiti doldu! Yedek model devreye giriyor... (Model Tipi: {model_type})")
            return fallback_model.generate_content(content, generation_config=generation_config)
        
        raise e

def get_ai_exercise_catalog():
    file_path = os.path.join(os.path.dirname(__file__), 'exercises.json')
    with open(file_path, 'r', encoding='utf-8') as f:
        all_exercises = json.load(f)
    
    ai_catalog = [{"id": ex.get("id"), "name": ex.get("name"), "target": ex.get("target"), "equipment": ex.get("equipment")} for ex in all_exercises]
    return json.dumps(ai_catalog)

def generate_workout_program(data: UserOnboardingData):
    interests_str = ", ".join(data.specific_interests) if data.specific_interests else "Genel Vücut"
    restrictions_str = ", ".join(data.health_restrictions) if data.health_restrictions else "Yok"
    ai_catalog_str = get_ai_exercise_catalog()

    prompt = f"""
    Sen dünya çapında uzman bir fitness ve kalistenik koçusun. 
    Kullanıcı Profili:
    - Yaş: {data.age}
    - Cinsiyet: {data.gender}
    - Tecrübe: {data.experience}
    - Ana Hedef: {data.primary_goal}
    - Odaklanmak İstediği Alanlar: {interests_str}
    - Sağlık Kısıtlamaları/Sakatlıklar: {restrictions_str}
    - Antrenman Yeri: {", ".join(data.logistics.location)}
    - Evdeki Ekipmanlar: {", ".join(data.logistics.equipment) if data.logistics.equipment else "Yok"}
    - Haftalık Gün Sayısı: {data.logistics.days_per_week} gün
    - Maksimum Süre: {data.logistics.max_duration_min} dakika
    - Zihinsel Engel: {data.mental_blocker or 'Yok'}

    Kullanıcının sağlık kısıtlamalarına KESİNLİKLE dikkat et. Bu profile uygun {data.logistics.days_per_week} günlük bir antrenman programı oluştur.
    
    ÇOK ÖNEMLİ KURAL (KATI KISITLAMA):
    Kullanacağın tüm egzersizleri SADECE aşağıdaki JSON listesinden (Katalogdan) seçeceksin. 
    Kendi kafandan, başka bir kaynaktan veya listede olmayan hiçbir egzersizi KESİNLİKLE uydurma. Kullanıcının alet durumuna dikkat ederek seçim yap.
    
    ZORUNLU KURAL (SANIYELİ SETLER & CORE):
    Eğer programda Plank, Wall Sit, statik tutuşlar, kardiyo interval süreleri veya saniyeye dayalı herhangi bir hareket varsa, "reps" alanını KESİNLİKLE `null` yap ve "duration_seconds" alanına saniye cinsinden değeri mutlaka yaz.
    
    KULLANABİLECEĞİN EGZERSİZLER LİSTESİ (KATALOG):
    {ai_catalog_str}

    Yanıtını SADECE aşağıdaki JSON formatında ver, başına veya sonuna markdown (```json) veya ekstra metin EKLEME:
    {{
      "program_name": "Programın havalı ve amaca uygun ismi",
      "description": "Kullanıcıyı motive edecek 2 cümlelik açıklama",
      "workouts": [
        {{
          "day_number": 1,
          "name": "Push Day veya Üst Vücut vb.",
          "estimated_duration_min": {data.logistics.max_duration_min},
          "exercises": [
            {{
              "id": "0025", 
              "name": "Barbell Bench Press",
              "sets": 3,
              "reps": "8-12",
              "duration_seconds": null,
              "rest_seconds": 60,
              "notes": "Formuna dikkat et"
            }}
          ]
        }}
      ]
    }}
    """

    response = generate_with_fallback(
        prompt,
        generation_config={"response_mime_type": "application/json"},
        model_type=data.model_type 
    )
    
    return sanitize_program_data(json.loads(response.text.strip()))

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

def parse_program_from_input(text: str = None, file_bytes: bytes = None, mime_type: str = None):
    prompt = """
    Sen bir fitness programı analiz uzmanısın. Sana verilen antrenman
    programını (metin, görsel veya PDF olabilir) analiz et ve aşağıdaki
    JSON formatına dönüştür.

    KURALLAR:
    - Programda ne yazıyorsa onu kullan, egzersiz uydurma.
    - Her egzersiz için "instructions" alanına, o hareketin nasıl yapılacağını
      anlatan kısa (1-2 cümle) bir talimat yaz.
    - ÇOK ÖNEMLİ (SÜRE BAZLI HAREKETLER): Eğer hareketin yanında "sn", "saniye", "sec", "dk", "dakika" gibi süre belirten bir ifade varsa, "reps" alanını KESİNLİKLE `null` yap ve süreyi saniyeye çevirerek "duration_seconds" alanına yaz (Örn: 30 sn -> duration_seconds: 30, reps: null). Süre yoksa normal hareketlerde "reps" kullan.
    - Eğer verilen içerik bir antrenman/egzersiz programı DEĞİLSE, SADECE
      şu JSON'u dön: {"error": "not_a_program"}

    Yanıtını SADECE aşağıdaki JSON formatında ver, markdown veya ekstra
    metin EKLEME:
    {
      "program_name": "Programın ismi (yoksa uygun bir isim öner)",
      "description": "2 cümlelik açıklama",
      "workouts": [
        {
          "day_number": 1,
          "name": "Gün adı",
          "estimated_duration_min": 45,
          "exercises": [
            {
              "name": "Egzersiz adı",
              "sets": 3,
              "reps": "8-12",
              "duration_seconds": null,
              "rest_seconds": 60,
              "instructions": "Kısa yapılış talimatı",
              "notes": null
            }
          ]
        }
      ]
    }
    """

    if text:
        prompt += f"\n\nKULLANICININ YAZDIĞI PROGRAM:\n{text}"
        content = [prompt]
    elif file_bytes and mime_type:
        content = [prompt, {"mime_type": mime_type, "data": file_bytes}]
    else:
        raise ValueError("Ne metin ne dosya verildi.")

    response = generate_with_fallback(
        content,
        generation_config={"response_mime_type": "application/json"},
        model_type="flash" 
    )

    clean_text = response.text.strip()
    result = json.loads(clean_text)

    if result.get("error") == "not_a_program":
        raise ValueError("Yüklenen içerik bir antrenman programına benzemiyor.")

    return sanitize_program_data(result)

def sanitize_program_data(data: dict):
    for workout in data.get("workouts", []):
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
                        
            name_lower = exercise.get("name", "").lower()
            if ("plank" in name_lower or "hold" in name_lower) and not exercise.get("duration_seconds") and not exercise.get("reps"):
                exercise["duration_seconds"] = 30
                
    return data

def revise_workout_program(data):
    ai_catalog_str = get_ai_exercise_catalog()

    prompt = f"""
    Sen dünya çapında uzman bir fitness koçusun.
    Kullanıcının mevcut antrenman programı (JSON formatında) aşağıdadır:
    {json.dumps(data.current_program, ensure_ascii=False)}

    Kullanıcının bu program üzerinde yapılmasını istediği değişiklik (Prompt):
    "{data.prompt}"

    Lütfen kullanıcının isteğini yerine getirerek programı güncelle. 
    ÇOK ÖNEMLİ KURAL: Yeni egzersiz eklerken veya değiştirirken SADECE aşağıdaki katalogdan seçim yap:
    {ai_catalog_str}

    ZORUNLU KURAL: Süreli egzersizlerde (Plank vs.) "reps" alanını null yap ve süreyi saniye olarak "duration_seconds" alanına yaz.
    
    Yanıtını SADECE aşağıdaki JSON şemasında ver, başına sonuna ekstra metin ekleme:
    {{
      "program_name": "Güncellenmiş Program İsmi",
      "description": "Değişiklikleri yansıtan yeni açıklama",
      "workouts": [
        {{
          "day_number": 1,
          "name": "Gün adı",
          "estimated_duration_min": 45,
          "exercises": [
            {{
              "id": "0025", 
              "name": "Egzersiz Adı",
              "sets": 3,
              "reps": "8-12",
              "duration_seconds": null,
              "rest_seconds": 60,
              "notes": "Not"
            }}
          ]
        }}
      ]
    }}
    """

    response = generate_with_fallback(
        prompt,
        generation_config={"response_mime_type": "application/json"},
        model_type=data.model_type 
    )
    
    return sanitize_program_data(json.loads(response.text.strip()))