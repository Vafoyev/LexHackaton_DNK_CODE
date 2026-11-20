# 🤝 Tizimlararo API & Data Shartnomalari (API Contracts)

Ushbu hujjat Go Backend, Flutter Mobile va React Frontend o'rtasidagi ma'lumotlar almashinuvi formatini belgilaydi.

---

## 1. Asosiy API Standartlari
- **Base URL**: `http://localhost:8080/api/v1`
- **Format**: JSON (Request & Response)
- **Autentifikatsiya**: `Authorization: Bearer <JWT_TOKEN>`

## 2. Standart Response Formati
```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": {
    "timestamp": "2026-11-21T03:00:00Z",
    "request_id": "req_uuid"
  }
}
```

## 3. Shartnoma Tahlili Natijasi Sxemasi (`AnalysisResult`)
```json
{
  "contract_id": "c_12345",
  "filename": "ijara_shartnomasi.docx",
  "sha256": "abcdef...",
  "overall_risk_score": 78,
  "risk_level": "RED", // GREEN | YELLOW | RED
  "total_clauses": 24,
  "flagged_clauses": [
    {
      "clause_number": "4.2",
      "clause_text": "Ijara beruvchi istalgan vaqtda ogohlantirmasdan shartnomani bekor qilishi mumkin.",
      "risk_level": "RED",
      "law_reference": {
        "law_title": "O‘zbekiston Respublikasi Fuqarolik Kodeksi",
        "article": "550-modda",
        "lex_uz_url": "https://lex.uz/docs/111181#111900",
        "explanation": "Ijara shartnomasini bekor qilish uchun kamida 1 oy oldin yozma ogohlantirish talab qilinadi."
      },
      "suggested_amendment": "Ijara beruvchi shartnomani bekor qilishdan kamida 30 kun oldin Ijarachini yozma xabardor qilishi shart."
    }
  ]
}
```
