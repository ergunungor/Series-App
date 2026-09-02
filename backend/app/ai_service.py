import os
import json
import google.generativeai as genai
from dotenv import load_dotenv
from .schemas import UserOnboardingData

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

model = genai.GenerativeModel('gemini-3.6-flash') #[cite: 3]

def get_ai_exercise_catalog():
    """
    exercises.json dosyasını okuyup AI'ın token sınırını şişirmemek için 
    sadece ihtiyaç duyduğu hayati bilgileri filtreleyerek döndürür.
    """
    # JSON dosyasının bu script ile aynı klasörde olduğunu varsayıyoruz
    file_path = os.path.join(os.path.dirname(__file__), 'exercises.json')
    
    with open(file_path, 'r', encoding='utf-8') as f:
        all_exercises = json.load(f)
    
    ai_catalog = []
    for ex in all_exercises:
        ai_catalog.append({
            "id": ex.get("id"),
            "name": ex.get("name"),
            "target": ex.get("target"),
            "equipment": ex.get("equipment")
        })
    
    return json.dumps(ai_catalog)

def generate_workout_program(data: UserOnboardingData):
    interests_str = ", ".join(data.specific_interests) if data.specific_interests else "Genel Vücut" #[cite: 3]
    restrictions_str = ", ".join(data.health_restrictions) if data.health_restrictions else "Yok" #[cite: 3]
    
    # 1. Hafifletilmiş kataloğumuzu AI'a vermek üzere çekiyoruz
    ai_catalog_str = get_ai_exercise_catalog()

    prompt = f"""
    Sen dünya çapında uzman bir fitness ve kalistenik koçusun. 
    Kullanıcı Profili:
    - Yaş: {data.age}
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
    
    ÖZEL DURUM (SANIYELİ SETLER):
    Plank, statik tutuşlar veya dayanıklılık hareketleri gibi zamana dayalı egzersizlerde "reps" yerine "duration_seconds" (örneğin 45 saniye için 45) alanı kullanabilirsin. Normal tekrar bazlı hareketlerde ise "reps" (örn: "8-12") kullanmaya devam et.
    
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
            }},
            {{
              "id": "0456", 
              "name": "Plank",
              "sets": 3,
              "reps": null,
              "duration_seconds": 45,
              "rest_seconds": 45,
              "notes": "Core bölgesini sıkı tut"
            }}
          ]
        }}
      ]
    }}
    """

    response = model.generate_content(
        prompt,
        generation_config={"response_mime_type": "application/json"} #[cite: 3]
    )
    
    clean_text = response.text.strip() #[cite: 3]
    return json.loads(clean_text) #[cite: 3]