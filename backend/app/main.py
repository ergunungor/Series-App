import os
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from supabase import create_client, Client
from dotenv import load_dotenv
from .schemas import UserOnboardingData, SaveProgramRequest
from .ai_service import generate_workout_program, save_generated_program, parse_program_from_input

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

        # 2. Programı Supabase'e kaydet (artık ortak fonksiyon üzerinden)
        program_id = save_generated_program(supabase, user_data.user_id, generated_program)

        return {
            "status": "success",
            "message": "Program başarıyla oluşturuldu ve Supabase'e kaydedildi.",
            "program_id": program_id,
            "data": generated_program
        }

    except Exception as e:
        print(f"API Hatası: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/parse-program")
async def parse_program(
    text: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
):
    if not text and not file:
        raise HTTPException(status_code=400, detail="Metin veya dosya göndermelisin.")

    try:
        file_bytes = await file.read() if file else None
        mime_type = file.content_type if file else None

        parsed_program = parse_program_from_input(
            text=text,
            file_bytes=file_bytes,
            mime_type=mime_type,
        )

        return {
            "status": "success",
            "data": parsed_program,
        }

    except ValueError as e:
        # parse_program_from_input'un bilerek fırlattığı, kullanıcıya
        # gösterilebilecek hatalar (örn. "bu bir program değil").
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        print(f"Parse API Hatası: {str(e)}")
        raise HTTPException(status_code=500, detail="Program analiz edilirken bir hata oluştu.")

@app.post("/api/save-program")
async def save_program(request: SaveProgramRequest):
    try:
        program_id = save_generated_program(supabase, request.user_id, request.program)
        return {
            "status": "success",
            "message": "Program başarıyla kaydedildi.",
            "program_id": program_id,
        }
    except Exception as e:
        print(f"Save API Hatası: {str(e)}")
        raise HTTPException(status_code=500, detail="Program kaydedilirken bir hata oluştu.")