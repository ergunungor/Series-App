import os
import json
import google.generativeai as genai
from dotenv import load_dotenv
from .schemas import UserOnboardingData

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

# En güncel modeli kullanıyoruz
model = genai.GenerativeModel('gemini-3.6-flash')

def generate_workout_program(data: UserOnboardingData):
    # Boş liste ve özel karakter güvenlik önlemleri
    interests_str = ", ".join(data.specific_interests) if data.specific_interests else "Genel Vücut"
    restrictions_str = ", ".join(data.health_restrictions) if data.health_restrictions else "Yok"

    prompt = f"""
    Sen dünya çapında uzman bir fitness ve kalistenik koçusun. 
    Kullanıcı Profili:
    - Yaş: {data.age}
    - Tecrübe: {data.experience}
    - Ana Hedef: {data.primary_goal}
    - Odaklanmak İstediği Alanlar: {interests_str}
    - Sağlık Kısıtlamaları/Sakatlıklar: {restrictions_str}
    - Antrenman Yeri: {data.logistics.location}
    - Haftalık Gün Sayısı: {data.logistics.days_per_week} gün
    - Maksimum Süre: {data.logistics.max_duration_min} dakika
    - Zihinsel Engel: {data.mental_blocker or 'Yok'}

    Kullanıcının sağlık kısıtlamalarına KESİNLİKLE dikkat et. Bu profile uygun {data.logistics.days_per_week} günlük bir antrenman programı oluştur.
    
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
              "name": "Hareket ismi",
              "sets": 3,
              "reps": "8-12 veya 30 sn",
              "rest_seconds": 60,
              "notes": "Varsa form veya sağlık kısıtlaması için özel not"
            }}
          ]
        }}
      ]
    }}
    """

    response = model.generate_content(
        prompt,
        generation_config={"response_mime_type": "application/json"}
    )
    
    # Gelen metni temizleyip JSON objesine dönüştürüyoruz
    clean_text = response.text.strip()
    return json.loads(clean_text)