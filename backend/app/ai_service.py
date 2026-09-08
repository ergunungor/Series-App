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

def save_generated_program(supabase_client, user_id: str, generated_program: dict):
    """
    Gemini'nin ürettiği program JSON'unu Supabase'e (programs + workouts
    tablolarına) yazar. Hem anket akışı hem de (bir sonraki adımda ekleyeceğimiz)
    dosya/metin yükleme akışı bu fonksiyonu ortak kullanacak.
    """
    program_insert = supabase_client.table('programs').insert({
        "user_id": user_id,
        "name": generated_program.get("program_name", "Özel Program"),
        "description": generated_program.get("description", "")
    }).execute()

    program_id = program_insert.data[0]['id']

    workouts_data = []
    for workout in generated_program.get("workouts", []):
        workouts_data.append({
            "program_id": program_id,
            "day_number": workout.get("day_number"),
            "name": workout.get("name"),
            "estimated_duration_min": workout.get("estimated_duration_min"),
            "exercises": workout.get("exercises", [])
        })

    if workouts_data:
        supabase_client.table('workouts').insert(workouts_data).execute()

    return program_id

def parse_program_from_input(text: str = None, file_bytes: bytes = None, mime_type: str = None):
    """
    Kullanıcının yüklediği bir antrenman programını (serbest metin veya
    görsel/PDF) Gemini'ye gönderip bizim JSON şemamıza dönüştürür.

    generate_workout_program'dan farkı: exercises.json kataloğuna kısıtlama
    YOK (kullanıcının programındaki egzersizler ne ise onlar kullanılıyor),
    bunun yerine her egzersiz için "instructions" (yapılış talimatı) üretiliyor
    — çünkü bu egzersizler kataloğumuzda olmayabilir, GIF eşleştiremeyiz.
    """
    prompt = """
    Sen bir fitness programı analiz uzmanısın. Sana verilen antrenman
    programını (metin, görsel veya PDF olabilir) analiz et ve aşağıdaki
    JSON formatına dönüştür.

    KURALLAR:
    - Programda ne yazıyorsa onu kullan, egzersiz uydurma.
    - Her egzersiz için "instructions" alanına, o hareketin nasıl yapılacağını
      anlatan kısa (1-2 cümle) bir talimat yaz.
    - Zamana dayalı (plank gibi) hareketlerde "reps" yerine "duration_seconds"
      kullan, normal hareketlerde "reps" kullan (ikisi birden olmaz).
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

    response = model.generate_content(
        content,
        generation_config={"response_mime_type": "application/json"}
    )

    clean_text = response.text.strip()
    result = json.loads(clean_text)

    if result.get("error") == "not_a_program":
        raise ValueError("Yüklenen içerik bir antrenman programına benzemiyor.")

    return result