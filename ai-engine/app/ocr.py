"""
LexGuard AI — Document OCR & Vision Parsing Module
Vazifasi: Skan qilingan PDF, rasmlar (PNG, JPG, TIFF) va matnli hujjatlarni
optik belgilarni aniqlash (OCR) va qat'iy yuridik bandlarga (Clause Segmentation)
ajratish moduli.
"""

import os
import re
import io
import logging
from typing import List, Dict, Any, Tuple

logger = logging.getLogger("ai-engine-ocr")

class DocumentOCRProcessor:
    def __init__(self):
        self._tesseract_available = None

    def _check_tesseract(self) -> bool:
        if self._tesseract_available is not None:
            return self._tesseract_available
        try:
            import pytesseract
            # Test if tesseract binary can be executed
            pytesseract.get_tesseract_version()
            self._tesseract_available = True
        except Exception:
            self._tesseract_available = False
            logger.info("pytesseract binary topilmadi, to'g'ridan-to'g'ri pdf/text parser ishlatiladi.")
        return self._tesseract_available

    def process_document(self, file_bytes: bytes, mime_type: str = "application/pdf") -> Dict[str, Any]:
        """
        Hujjat baytlarini qabul qilib, to'liq matn va bandlar ro'yxatini qaytaradi.
        """
        full_text = ""
        clauses = []
        confidence_score = 0.95

        mime_type_lower = (mime_type or "").lower()
        is_image_magic = (
            file_bytes.startswith(b"\x89PNG\r\n\x1a\n")
            or file_bytes.startswith(b"\xff\xd8\xff")
            or file_bytes.startswith(b"BM")
            or file_bytes.startswith(b"II*\x00")
            or file_bytes.startswith(b"MM\x00*")
            or (len(file_bytes) >= 12 and file_bytes[:4] == b"RIFF" and file_bytes[8:12] == b"WEBP")
        )

        if "pdf" in mime_type_lower or file_bytes.startswith(b"%PDF"):
            full_text, confidence_score = self._extract_from_pdf(file_bytes)
        elif is_image_magic or any(img_type in mime_type_lower for img_type in ["image", "png", "jpeg", "jpg", "tiff", "bmp", "webp"]):
            full_text, confidence_score = self._extract_from_image(file_bytes)
        elif "docx" in mime_type_lower or file_bytes.startswith(b"PK\x03\x04"):
            full_text, confidence_score = self._extract_from_docx(file_bytes)
        else:
            # Plain text fallback
            try:
                full_text = file_bytes.decode("utf-8")
                confidence_score = 1.0
            except UnicodeDecodeError:
                full_text = file_bytes.decode("latin-1", errors="replace")
                confidence_score = 0.80

        clauses = self.segment_clauses(full_text)

        return {
            "full_text": full_text,
            "clauses": clauses,
            "confidence_score": confidence_score
        }

    def _extract_from_pdf(self, file_bytes: bytes) -> Tuple[str, float]:
        pages_text = []
        confidence = 0.95
        has_text = False

        # 1. Try pdfplumber
        try:
            import pdfplumber
            with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                for idx, page in enumerate(pdf.pages):
                    txt = page.extract_text() or ""
                    if txt.strip():
                        pages_text.append(f"--- [Sahifa {idx + 1}] ---\n" + txt)
                        has_text = True
        except Exception as e:
            logger.warning(f"pdfplumber orqali o'qishda xatolik: {e}")

        # 2. If no text found and tesseract is available, try OCR on pages
        if not has_text:
            if self._check_tesseract():
                try:
                    import pypdfium2
                    from PIL import Image
                    import pytesseract

                    pdf = pypdfium2.PdfDocument(file_bytes)
                    for idx, page in enumerate(pdf):
                        pil_image = page.render(scale=2.0).to_pil()
                        ocr_txt = pytesseract.image_to_string(pil_image, lang="uzb+rus+eng")
                        if ocr_txt.strip():
                            pages_text.append(f"--- [OCR Sahifa {idx + 1}] ---\n" + ocr_txt)
                    confidence = 0.88
                except Exception as e:
                    logger.warning(f"pypdfium2 OCR da xatolik: {e}")
                    confidence = 0.75
            else:
                # Text extraction fallback
                confidence = 0.70

        result_text = "\n\n".join(pages_text).strip()
        if not result_text:
            result_text = "[PDF hujjat skanerlangan rasm ko'rinishida yoki bo'sh]"
            confidence = 0.60

        return result_text, confidence

    def _extract_from_image(self, file_bytes: bytes) -> Tuple[str, float]:
        if not self._check_tesseract():
            return "[Rasm yuklandi. Tesseract OCR o'rnatilmaganligi sababli matn chiqarilmadi]", 0.50

        try:
            from PIL import Image
            import pytesseract
            img = Image.open(io.BytesIO(file_bytes))
            for lang in ("uzb+rus+eng", "rus+eng", "eng"):
                try:
                    text = pytesseract.image_to_string(img, lang=lang)
                    return text.strip(), 0.90
                except Exception:
                    continue
            return pytesseract.image_to_string(img).strip(), 0.85
        except Exception as e:
            logger.error(f"Rasm OCR da xatolik: {e}")
            return f"[OCR xatoligi: {str(e)}]", 0.40

    def _extract_from_docx(self, file_bytes: bytes) -> Tuple[str, float]:
        try:
            import docx
            doc = docx.Document(io.BytesIO(file_bytes))
            paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
            for table in doc.tables:
                for row in table.rows:
                    row_text = " | ".join(cell.text.strip() for cell in row.cells if cell.text.strip())
                    if row_text:
                        paragraphs.append(row_text)
            return "\n\n".join(paragraphs), 0.98
        except Exception as e:
            logger.error(f"DOCX o'qishda xatolik: {e}")
            return "", 0.0

    def segment_clauses(self, full_text: str) -> List[Dict[str, Any]]:
        """
        Shartnoma matnini yuridik bandlarga (1.1, 1.2, 1-modda, 2-band kabi) ajratadi.
        """
        if not full_text:
            return []

        clauses = []
        lines = full_text.split("\n")
        
        current_clause_id = "clause-0"
        current_clause_num = "KIRISH"
        current_lines = []
        page_num = 1
        clause_counter = 1

        clause_header_pattern = re.compile(
            r'^(?:(?:\d+[\.\)]\s*){1,3}|(?:[0-9]+[-.][0-9]+)|(?:(?:modda|band|bob|qism)[\s.:]+[0-9]+)|(?:[0-9]+[-–]modda))',
            re.IGNORECASE
        )

        for line in lines:
            line_str = line.strip()
            if not line_str:
                continue

            page_match = re.search(r'\[(?:OCR\s+)?Sahifa\s+(\d+)\]', line_str, re.IGNORECASE)
            if page_match:
                page_num = int(page_match.group(1))
                continue

            if clause_header_pattern.match(line_str) and len(line_str) < 120:
                # Flush previous clause
                if current_lines:
                    clause_text = " ".join(current_lines).strip()
                    if len(clause_text) > 10:
                        clauses.append({
                            "clause_id": current_clause_id,
                            "clause_number": current_clause_num,
                            "text": clause_text,
                            "page_number": page_num
                        })
                current_clause_id = f"clause-{clause_counter}"
                current_clause_num = line_str.split()[0] if line_str.split() else f"{clause_counter}-band"
                current_lines = [line_str]
                clause_counter += 1
            else:
                current_lines.append(line_str)

        # Flush final clause
        if current_lines:
            clause_text = " ".join(current_lines).strip()
            if len(clause_text) > 5:
                clauses.append({
                    "clause_id": current_clause_id,
                    "clause_number": current_clause_num,
                    "text": clause_text,
                    "page_number": page_num
                })

        # Agar bandlarga ajralmagan bo'lsa (masalan oddiy matn bo'lsa), xatboshilar bo'yicha ajratish
        if len(clauses) <= 1 and len(full_text) > 100:
            clauses = []
            paragraphs = [p.strip() for p in full_text.split("\n\n") if p.strip()]
            for i, p in enumerate(paragraphs, 1):
                clauses.append({
                    "clause_id": f"clause-{i}",
                    "clause_number": f"{i}-band",
                    "text": p,
                    "page_number": 1
                })

        return clauses

# Singleton instance
ocr_processor = DocumentOCRProcessor()
