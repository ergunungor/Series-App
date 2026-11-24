"""Yapay zeka sağlayıcı katmanı.

LLM_PROVIDER ortam değişkeni ile seçilir:
- "gemini" (varsayılan): GEMINI_API_KEY
- "openai": OpenAI uyumlu herhangi bir uç (Groq, OpenRouter, Cerebras...)
    LLM_BASE_URL   örn. https://api.groq.com/openai/v1
    LLM_API_KEY
    LLM_MODEL_PRO  / LLM_MODEL_FLASH
"""

import json
import os
import re
import base64
from typing import Optional

import httpx
from dotenv import load_dotenv

load_dotenv()

PROVIDER = os.getenv("LLM_PROVIDER", "gemini").lower()


def _extract_json(text: str) -> dict:
    text = (text or "").strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Model yine de markdown / ek metin eklediyse ilk { ... son } aralığını al
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end > start:
        return json.loads(text[start : end + 1])
    raise ValueError("Yapay zeka geçerli bir JSON döndürmedi.")


# ------------------------------------------------------------------ Gemini

_gemini = None


def _gemini_models(model_type: str):
    global _gemini
    if _gemini is None:
        import google.generativeai as genai  # yalnızca gerektiğinde yüklenir

        genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
        _gemini = genai
    if model_type == "pro":
        return _gemini.GenerativeModel("gemini-3.7-flash"), _gemini.GenerativeModel("gemini-3.5-flash-lite")
    return _gemini.GenerativeModel("gemini-3.6-flash"), _gemini.GenerativeModel("gemini-3.1-flash-lite")


def _call_gemini(prompt: str, model_type: str, file_bytes, mime_type) -> str:
    primary, fallback = _gemini_models(model_type)
    content = [prompt]
    if file_bytes and mime_type:
        content.append({"mime_type": mime_type, "data": file_bytes})
    cfg = {"response_mime_type": "application/json"}
    opts = {"timeout": 35.0}
    try:
        return primary.generate_content(content, generation_config=cfg, request_options=opts).text
    except Exception as e:  # kota dolduysa yedek modele geç
        if "429" in str(e) or "Quota" in str(e):
            print(f"⚠️ Ana model limiti doldu, yedek modele geçiliyor ({model_type})")
            return fallback.generate_content(content, generation_config=cfg, request_options=opts).text
        raise


# ------------------------------------------------------- OpenAI uyumlu uç

def _call_openai_compatible(prompt: str, model_type: str, file_bytes, mime_type) -> str:
    base = os.getenv("LLM_BASE_URL", "https://api.groq.com/openai/v1").rstrip("/")
    key = os.getenv("LLM_API_KEY")
    if not key:
        raise RuntimeError("LLM_API_KEY tanımlı değil.")
    if model_type == "pro":
        model = os.getenv("LLM_MODEL_PRO", "llama-3.3-70b-versatile")
    else:
        model = os.getenv("LLM_MODEL_FLASH", "llama-3.1-8b-instant")

    if file_bytes and mime_type:
        if not mime_type.startswith("image/"):
            raise ValueError("Bu yapay zeka sağlayıcısı yalnızca metin ve görsel destekliyor (PDF yok).")
        data_uri = f"data:{mime_type};base64,{base64.b64encode(file_bytes).decode()}"
        user_content = [
            {"type": "text", "text": prompt},
            {"type": "image_url", "image_url": {"url": data_uri}},
        ]
        model = os.getenv("LLM_MODEL_VISION", model)
    else:
        user_content = prompt

    resp = httpx.post(
        f"{base}/chat/completions",
        headers={"Authorization": f"Bearer {key}"},
        json={
            "model": model,
            "messages": [{"role": "user", "content": user_content}],
            "response_format": {"type": "json_object"},
            "temperature": 0.4,
        },
        timeout=60.0,
    )
    if resp.status_code != 200:
        # main.py "429" içeren hata metnini kullanıcıya "yoğunluk" olarak gösteriyor
        raise RuntimeError(f"LLM hatası {resp.status_code}: {resp.text[:300]}")
    return resp.json()["choices"][0]["message"]["content"]


# ------------------------------------------------------------------ genel

def generate_json(
    prompt: str,
    model_type: str = "flash",
    file_bytes: Optional[bytes] = None,
    mime_type: Optional[str] = None,
) -> dict:
    if PROVIDER == "openai":
        text = _call_openai_compatible(prompt, model_type, file_bytes, mime_type)
    else:
        text = _call_gemini(prompt, model_type, file_bytes, mime_type)
    return _extract_json(text)
