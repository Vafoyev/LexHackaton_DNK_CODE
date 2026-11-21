package privacy

import (
	"fmt"
	"regexp"
	"sync"
)

type PIIEntity struct {
	Type        string `json:"type"`
	Placeholder string `json:"placeholder"`
	Original    string `json:"original,omitempty"` // only kept in-memory
	StartOffset int    `json:"start_offset"`
	EndOffset   int    `json:"end_offset"`
}

type RedactionResult struct {
	OriginalText string      `json:"original_text"`
	RedactedText string      `json:"redacted_text"`
	Entities     []PIIEntity `json:"entities"`
	MaskedCount  int         `json:"masked_count"`
}

type Redactor struct {
	reJshshir  *regexp.Regexp
	rePassport *regexp.Regexp
	reStir     *regexp.Regexp
	rePhone    *regexp.Regexp
	reEmail    *regexp.Regexp
	reCard     *regexp.Regexp
	reAccount  *regexp.Regexp
	mu         sync.RWMutex
}

func NewRedactor() *Redactor {
	return &Redactor{
		// JSHSHIR: 14 consecutive digits
		reJshshir: regexp.MustCompile(`\b\d{14}\b`),
		// Passport/ID: AA1234567, AB 1234567
		rePassport: regexp.MustCompile(`\b[A-Z]{2}\s*\d{7}\b`),
		// STIR/INN: 9 digits
		reStir: regexp.MustCompile(`\b\d{9}\b`),
		// Uzbekistan and international phone numbers
		rePhone: regexp.MustCompile(`(?:\+?998[\s\-]?)?(?:\(?\d{2}\)?[\s\-]?)?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}\b`),
		// Email
		reEmail: regexp.MustCompile(`[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}`),
		// Bank card: 16 digits
		reCard: regexp.MustCompile(`\b(?:\d{4}[\s\-]?){3}\d{4}\b`),
		// Bank account: 20 digits
		reAccount: regexp.MustCompile(`\b2020\d{16}\b|\b\d{20}\b`),
	}
}

func (r *Redactor) Redact(text string) RedactionResult {
	r.mu.Lock()
	defer r.mu.Unlock()

	entities := make([]PIIEntity, 0)
	counters := make(map[string]int)

	redactPattern := func(re *regexp.Regexp, entityType string, currentText string) string {
		return re.ReplaceAllStringFunc(currentText, func(match string) string {
			counters[entityType]++
			idx := counters[entityType]
			placeholder := fmt.Sprintf("[%s_%d]", entityType, idx)
			entities = append(entities, PIIEntity{
				Type:        entityType,
				Placeholder: placeholder,
				Original:    match,
			})
			return placeholder
		})
	}

	result := text
	result = redactPattern(r.reJshshir, "JSHSHIR", result)
	result = redactPattern(r.rePassport, "PASSPORT", result)
	result = redactPattern(r.reCard, "CARD", result)
	result = redactPattern(r.reAccount, "ACCOUNT", result)
	result = redactPattern(r.reStir, "STIR", result)
	result = redactPattern(r.reEmail, "EMAIL", result)
	result = redactPattern(r.rePhone, "PHONE", result)

	return RedactionResult{
		OriginalText: text,
		RedactedText: result,
		Entities:     entities,
		MaskedCount:  len(entities),
	}
}
