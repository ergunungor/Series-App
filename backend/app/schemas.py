from pydantic import BaseModel
from typing import List, Optional

class Logistics(BaseModel):
    location: List[str]
    days_per_week: int
    max_duration_min: int

class UserOnboardingData(BaseModel):
    user_id: str
    age: int
    experience: str
    primary_goal: str
    specific_interests: List[str]
    health_restrictions: List[str]
    logistics: Logistics
    mental_blocker: Optional[str] = None