"""
LexGuard AI — Ixtiyoriy LLM/SLM qatlami (OpenAI-compatible: vLLM, Ollama, llama.cpp, OpenAI ...).

Standart holatda O'CHIRILGAN (LLM_PROVIDER=none): tahlil to'liq deterministik ishlaydi.
Yoqilganda LLM:
  - refine(): qoida topgan xavf uchun tushuntirish va redline ni sayqallaydi;
  - triage(): hech qanday qoida mos kelmagan bandda BM25 topgan nomzod moddalar ichidan xavf bor-yo'qligini baholaydi.

Anti-hallyutsinatsiya (citation guard): model javobida ruxsat etilgan moddalar ro'yxatidan (zanjir + nomzodlar)
tashqaridagi har qanday modda havolasi uchrasa, javob TASHLAB YUBORILADI va qoidaviy natija saqlanadi.
LLM qoida tasdig'isiz RED darajasini bera olmaydi (triage natijasi YELLOW bilan cheklanadi).

Fine-tuned LoRA adapter (models/lexguard-slm-lora) ni vLLM/Ollama orqali serve qilib, shu yerga ulash mumkin:
  LLM_PROVIDER=openai_compat LLM_BASE_URL=http://localhost:8001/v1 LLM_MODEL=lexguard-slm
"""

import json
import logging
import re
from typing import Any, Dict, List, Optional, Set

import httpx

from app import config
from app.text_utils import normalize_text

logger = logging.getLogger("ai-engine-llm")

SYSTEM_PROMPT = (
    "Siz O'zbekiston Respublikasi qonunchiligi bo'yicha shartnomalarni tahlil qiluvchi yuridik yordamchisiz.\n"
    "QOIDALAR:\n"
    "1. FAQAT 'RUXSAT ETILGAN MODDALAR' ro'yxatidagi normalarga tayaning. Ro'yxatda yo'q modda yoki qonunni HECH QACHON keltirmang.\n"
    "2. Javob qisqa, aniq va o'zbek tilida bo'lsin. Yakuniy qaror inson (yurist) zimmasida ekanini unutmang.\n"
    "3. Faqat JSON qaytaring, boshqa matn yozmang."
)

_LAW_KEY = {
    "FK-UZ-1": "fk", "FK-UZ-2": "fk", "MK-2022": "mk", "670-I": "670i", "221-I": "221i",
    "ORQ-547": "orq547", "ORQ-482": "orq482", "ORQ-792": "orq792", "ORQ-850": "orq850", "ORQ-684": "orq684",
}

# "FK 707-modda", "MK 130-modda", "O'RQ-547 15-modda", "670-I 25-modda" va yalang "707-modda"
_CITATION_RE = re.compile(r"(?:\b(fk|mk|orq-?\d+|\d+-i)\s*[-,]?\s*)?\b(\d{1,4})\s*-\s*modda")
_JSON_RE = re.compile(r"\{.*\}", re.DOTALL)


def _code_key(code: str) -> Optional[tuple]:
    """'FK-UZ-2 707-modda' -> ('fk', '707')."""
    m = re.match(r"^(\S+)\s+(\d+)-modda$", code.strip())
    if not m:
        return None
    law = _LAW_KEY.get(m.group(1))
    return (law, m.group(2)) if law else None


def citations_allowed(text: str, allowed_codes: Set[str]) -> bool:
    """Matndagi barcha modda havolalari ruxsat etilgan moddalar ichida ekanini tekshiradi."""
    allowed_pairs = {k for k in (_code_key(c) for c in allowed_codes) if k}
    allowed_numbers = {n for _, n in allowed_pairs}
    for m in _CITATION_RE.finditer(normalize_text(text).replace("'", "")):
        law, num = m.group(1), m.group(2)
        if law:
            law_key = re.sub(r"[^a-z0-9]", "", law)
            if (law_key, num) not in allowed_pairs:
                return False
        elif num not in allowed_numbers:
            return False
    return True


def _parse_json(raw: str) -> Optional[Dict[str, Any]]:
    m = _JSON_RE.search(raw or "")
    if not m:
        return None
    try:
        data = json.loads(m.group(0))
        return data if isinstance(data, dict) else None
    except json.JSONDecodeError:
        return None


class LLMRefiner:
    """Interfeys (va no-op amalga oshirish)."""

    is_local = True

    def refine(self, clause_text: str, finding, allowed_codes: Set[str]) -> Optional[Dict[str, str]]:
        return None

    def triage(self, clause_text: str, related_norms: List[Dict[str, Any]], graph) -> Optional[Dict[str, Any]]:
        return None


class OpenAICompatRefiner(LLMRefiner):
    def __init__(self, base_url: str, api_key: str, model: str, timeout: float = 20.0,
                 client: Optional[httpx.Client] = None):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.model = model
        self.client = client or httpx.Client(timeout=timeout)
        host = httpx.URL(self.base_url).host
        # use_local_slm_only so'ralganda tashqi (bulutli) LLM chaqirilmasligi uchun
        self.is_local = host in ("localhost", "127.0.0.1", "::1", "host.docker.internal")

    def _chat(self, user_prompt: str) -> str:
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        resp = self.client.post(
            f"{self.base_url}/chat/completions",
            headers=headers,
            json={
                "model": self.model,
                "temperature": 0,
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
            },
        )
        resp.raise_for_status()
        return resp.json()["choices"][0]["message"]["content"]

    def refine(self, clause_text: str, finding, allowed_codes: Set[str]) -> Optional[Dict[str, str]]:
        norms = "\n".join(f"- {n['code']}: {n['title']}. {n.get('summary', '')[:300]}" for n in finding.multi_hop_chain)
        prompt = (
            f"BAND MATNI:\n\"\"\"{clause_text}\"\"\"\n\n"
            f"RUXSAT ETILGAN MODDALAR:\n{norms}\n\n"
            f"ANIQLANGAN XAVF: {finding.issue_title} ({finding.risk_level})\n"
            f"JORIY TUSHUNTIRISH: {finding.issue_explanation}\n"
            f"JORIY TAVSIYA: {finding.suggested_redline}\n\n"
            "Vazifa: tushuntirish va tavsiya etilgan tahrirni (redline) aniqroq, bandga xos qilib qayta yozing. "
            "Mazmunni va moddalarni o'zgartirmang.\n"
            "Format: {\"explanation\": \"...\", \"redline\": \"...\"}"
        )
        try:
            data = _parse_json(self._chat(prompt))
        except (httpx.HTTPError, KeyError, ValueError) as e:
            logger.warning("LLM so'rovi muvaffaqiyatsiz: %s", e)
            return None
        if not data:
            return None
        explanation = str(data.get("explanation", "")).strip()
        redline = str(data.get("redline", "")).strip()
        if not explanation or not redline or len(redline) > 800 or len(explanation) > 1500:
            return None
        if not citations_allowed(explanation + " " + redline, allowed_codes):
            logger.warning("LLM ruxsat etilmagan modda keltirdi — javob rad etildi (%s).", finding.rule_code)
            return None
        return {"explanation": explanation, "redline": redline}

    def triage(self, clause_text: str, related_norms: List[Dict[str, Any]], graph) -> Optional[Dict[str, Any]]:
        if not related_norms:
            return None
        by_code = {n["code"]: n for n in related_norms}
        norms = "\n".join(f"- {n['code']}: {n['title']}. {n.get('snippet', '')[:300]}" for n in related_norms)
        prompt = (
            f"BAND MATNI:\n\"\"\"{clause_text}\"\"\"\n\n"
            f"RUXSAT ETILGAN MODDALAR:\n{norms}\n\n"
            "Vazifa: band ruxsat etilgan moddalardan biriga zid yoki yuridik jihatdan xavfli ekanini baholang. "
            "Agar aniq xavf bo'lmasa risky=false qaytaring.\n"
            "Format: {\"risky\": true|false, \"norm\": \"<ro'yxatdagi kod aynan>\", \"title\": \"...\", "
            "\"explanation\": \"...\", \"redline\": \"...\"}"
        )
        try:
            data = _parse_json(self._chat(prompt))
        except (httpx.HTTPError, KeyError, ValueError) as e:
            logger.warning("LLM triage so'rovi muvaffaqiyatsiz: %s", e)
            return None
        if not data or not data.get("risky"):
            return None
        norm = by_code.get(str(data.get("norm", "")).strip())
        if not norm or norm["id"] not in graph.nodes:
            return None
        explanation = str(data.get("explanation", "")).strip()
        redline = str(data.get("redline", "")).strip()
        if not explanation or not citations_allowed(explanation + " " + redline, set(by_code)):
            return None
        return {"node_id": norm["id"], "title": str(data.get("title", "")).strip(),
                "explanation": explanation, "redline": redline}


def get_refiner() -> Optional[LLMRefiner]:
    if config.LLM_PROVIDER == "openai_compat":
        logger.info("LLM yoqilgan: %s (%s)", config.LLM_MODEL, config.LLM_BASE_URL)
        return OpenAICompatRefiner(config.LLM_BASE_URL, config.LLM_API_KEY, config.LLM_MODEL, config.LLM_TIMEOUT_SEC)
    return None
