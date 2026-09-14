from pydantic import BaseModel
from typing import List, Optional

class Logistics(BaseModel):
    location: List[str]
    equipment: Optional[List[str]] = []
    days_per_week: int
    max_duration_min: int

class UserOnboardingData(BaseModel):
    user_id: str
    age: int
    gender: Optional[str] = "Belirtilmedi" # YENİ: Cinsiyet eklendi
    experience: str
    primary_goal: str
    specific_interests: List[str]
    health_restrictions: List[str]
    logistics: Logistics
    mental_blocker: Optional[str] = None
    model_type: Optional[str] = "flash" # YENİ: Model tipi (Varsayılan: Flash)

class SaveProgramRequest(BaseModel):
    user_id: str
    program: dict

class ReviseProgramRequest(BaseModel):
    user_id: str
    current_program: dict
    prompt: str
    model_type: Optional[str] = "pro" # YENİ: Model tipi (Varsayılan: Pro)