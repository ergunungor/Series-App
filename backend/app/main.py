# yeni:
import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from supabase import create_client, Client
from dotenv import load_dotenv
from .schemas import UserOnboardingData
from .ai_service import generate_workout_program

# .env dosyasındaki gizli anahtarları yüklüyoruz
load_dotenv()

app = FastAPI(title="Series App Backend")

# Geliştirme aşamasında tüm origin'lere izin veriyoruz (Flutter web dev server
# her çalıştırmada farklı bir port kullanabiliyor). Production'a geçerken
# bunu gerçek domain'inle sınırlaman gerekecek.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# Supabase Bağlantısı
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
@app.get("/")
def root():
    return {"status": "online", "message": "Backend is running!"}
@app.post("/api/generate-program")
async def create_program(user_data: UserOnboardingData):
    try:
        # 1. AI servisine veriyi gönder ve JSON formatında programı al
        generated_program = generate_workout_program(user_data)
        
        # 2. 'programs' tablosuna ana programı kaydet
        program_insert = supabase.table('programs').insert({
            "user_id": user_data.user_id,
            "name": generated_program.get("program_name", "Özel Program"),
            "description": generated_program.get("description", "")
        }).execute()
        
        # Supabase'in oluşturduğu benzersiz Program ID'sini alıyoruz
        program_id = program_insert.data[0]['id']
        
        # 3. 'workouts' tablosuna antrenman günlerini ve egzersizleri kaydet
        workouts_data = []
        for workout in generated_program.get("workouts", []):
            workouts_data.append({
                "program_id": program_id,
                "day_number": workout.get("day_number"),
                "name": workout.get("name"),
                "estimated_duration_min": workout.get("estimated_duration_min"),
                "exercises": workout.get("exercises", []) # Bu kısım JSONB olarak tablona yazılacak
            })
            
        # Günleri tek bir sorguyla (batch insert) veritabanına yolluyoruz
        if workouts_data:
            supabase.table('workouts').insert(workouts_data).execute()
        
        return {
            "status": "success",
            "message": "Program başarıyla oluşturuldu ve Supabase'e kaydedildi.",
            "program_id": program_id,
            "data": generated_program
        }
        
    except Exception as e:
        print(f"API Hatası: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))