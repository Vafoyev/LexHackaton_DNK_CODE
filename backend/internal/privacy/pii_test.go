package privacy_test

import (
	"strings"
	"testing"

	"github.com/lexguard/backend/internal/privacy"
)

func TestPIIRedaction(t *testing.T) {
	redactor := privacy.NewRedactor()

	input := `
		Ushbu shartnoma fuqaro Alisher Qodirov (JSHSHIR: 30101901234567, Pasport: AA 1234567, Tel: +998 90 123-45-67, Email: alisher@example.com)
		va "Smart Tech" MCHJ (STIR: 309876543, Hisob raqam: 20208000100000123456) o'rtasida tuzildi.
		To'lov karta: 8600 1234 5678 9012 orqali amalga oshiriladi.
	`

	res := redactor.Redact(input)

	if res.MaskedCount < 6 {
		t.Fatalf("Kamida 6 ta PII maskalanishi kerak edi, lekin %d ta topildi", res.MaskedCount)
	}

	// Verify that raw sensitive data is NOT present in redacted text
	if strings.Contains(res.RedactedText, "30101901234567") {
		t.Errorf("JSHSHIR maskalanmadi!")
	}
	if strings.Contains(res.RedactedText, "AA 1234567") {
		t.Errorf("Pasport maskalanmadi!")
	}
	if strings.Contains(res.RedactedText, "309876543") {
		t.Errorf("STIR maskalanmadi!")
	}
	if strings.Contains(res.RedactedText, "alisher@example.com") {
		t.Errorf("Email maskalanmadi!")
	}
	if strings.Contains(res.RedactedText, "8600 1234 5678 9012") {
		t.Errorf("Karta raqami maskalanmadi!")
	}

	// Verify placeholders
	if !strings.Contains(res.RedactedText, "[JSHSHIR_") {
		t.Errorf("Placeholder [JSHSHIR_ topilmadi")
	}
	if !strings.Contains(res.RedactedText, "[PASSPORT_") {
		t.Errorf("Placeholder [PASSPORT_ topilmadi")
	}
	if !strings.Contains(res.RedactedText, "[STIR_") {
		t.Errorf("Placeholder [STIR_ topilmadi")
	}
	if !strings.Contains(res.RedactedText, "[EMAIL_") {
		t.Errorf("Placeholder [EMAIL_ topilmadi")
	}
}

func TestExternalLLMGate(t *testing.T) {
	gate := privacy.NewExternalLLMGate()

	// Case 1: External AI disabled platform-wide
	allowed, err := gate.CanTransmitToExternalLLM(privacy.ClassificationInternal, true, false)
	if allowed || err == nil {
		t.Errorf("External AI o'chirilgan holatda ruxsat berilmasligi kerak")
	}

	// Case 2: Restricted classification
	allowed, err = gate.CanTransmitToExternalLLM(privacy.ClassificationRestricted, true, true)
	if allowed || err == nil {
		t.Errorf("RESTRICTED hujjat hech qachon tashqi LLM ga chiqmasligi kerak (O'RQ-547)")
	}

	// Case 3: No Consent
	allowed, err = gate.CanTransmitToExternalLLM(privacy.ClassificationInternal, false, true)
	if allowed || err == nil {
		t.Errorf("Roziliksiz tashqi LLM ga ma'lumot uzatilmasligi kerak")
	}

	// Case 4: Valid consent and allowed classification
	allowed, err = gate.CanTransmitToExternalLLM(privacy.ClassificationInternal, true, true)
	if !allowed || err != nil {
		t.Errorf("To'g'ri rozilik bilan ruxsat berilishi kerak edi: %v", err)
	}
}
