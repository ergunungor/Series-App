import os
import json
import google.generativeai as genai
from dotenv import load_dotenv
from .schemas import UserOnboardingData

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# YENİ: Senin belirlediğin versiyonlara göre Dinamik Model Seçici
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
    - Cinsiyet: {data.gender}  # YENİ EKLENDİ
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

    Yanıtını SADECE JSON formatında ver, başına veya sonuna markdown (```json) EKLEME.
    """

    response = generate_with_fallback(
        prompt,
        generation_config={"response_mime_type": "application/json"},
        model_type=data.model_type # YENİ EKLENDİ
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
    prompt = """... (Mevcut prompt içeriğin aynı kalacak) ..."""

    if text:
        prompt += f"\n\nKULLANICININ YAZDIĞI PROGRAM:\n{text}"
        content = [prompt]
    elif file_bytes and mime_type:
        content = [prompt, {"mime_type": mime_type, "data": file_bytes}]
    else:
        raise ValueError("Ne metin ne dosya verildi.")

    # YENİ: İçe aktarma (Parse) işlemi hızlı olduğu için flash modelini sabit kullanıyoruz
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

import re
def sanitize_program_data(data: dict):
    # (Mevcut sanitize_program_data içeriğin tamamen aynı kalacak)
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
    
    Yanıtını SADECE aşağıdaki JSON şemasında ver, başına sonuna ekstra metin ekleme.
    """

    response = generate_with_fallback(
        prompt,
        generation_config={"response_mime_type": "application/json"},
        model_type=data.model_type # YENİ: Revize için Pro modeli buradan tetikleniyor
    )
    
    return sanitize_program_data(json.loads(response.text.strip()))