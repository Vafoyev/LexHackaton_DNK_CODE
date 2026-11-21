"""
LexGuard AI — AI Engine konfiguratsiyasi.
Barcha yo'llar paket joylashuviga nisbatan hisoblanadi (Docker va lokal ishga tushirishda bir xil ishlaydi).
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = Path(os.getenv("LEXGUARD_DATA_DIR", BASE_DIR / "data"))
CORPUS_PATH = Path(os.getenv("LEXGUARD_CORPUS_PATH", DATA_DIR / "uzbek_legal_corpus_unified.json"))

# BM25 natijasi shu ball dan yuqori bo'lsa, modda "bog'liq norma" sifatida qaytariladi
RELATED_NORM_MIN_SCORE = float(os.getenv("RELATED_NORM_MIN_SCORE", "18.0"))

# Ixtiyoriy LLM (OpenAI-compatible: vLLM, Ollama, llama.cpp, OpenAI va h.k.)
# LLM_PROVIDER=none (default) | openai_compat
LLM_PROVIDER = os.getenv("LLM_PROVIDER", "none").lower()
LLM_BASE_URL = os.getenv("LLM_BASE_URL", "http://localhost:11434/v1").rstrip("/")
LLM_API_KEY = os.getenv("LLM_API_KEY", "")
LLM_MODEL = os.getenv("LLM_MODEL", "lexguard-slm")
LLM_TIMEOUT_SEC = float(os.getenv("LLM_TIMEOUT_SEC", "20"))

# CORS: vergul bilan ajratilgan origin ro'yxati. Bo'sh bo'lsa faqat dev rejimida "*"
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]
APP_ENV = os.getenv("APP_ENV", "development")
