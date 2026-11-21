package privacy

import (
	"errors"
)

type DataClassification string

const (
	ClassificationPublic       DataClassification = "PUBLIC"
	ClassificationInternal     DataClassification = "INTERNAL"
	ClassificationConfidential DataClassification = "CONFIDENTIAL"
	ClassificationRestricted   DataClassification = "RESTRICTED"
)

type ExternalLLMGate struct{}

func NewExternalLLMGate() *ExternalLLMGate {
	return &ExternalLLMGate{}
}

// CanTransmitToExternalLLM evaluates compliance with O'RQ-547 & O'RQ-1125
func (g *ExternalLLMGate) CanTransmitToExternalLLM(
	classification DataClassification,
	externalAIConsentGranted bool,
	isExternalAIEnabled bool,
) (bool, error) {
	// Rule 1: Platform-wide external AI toggle must be enabled
	if !isExternalAIEnabled {
		return false, errors.New("tashqi LLM moduli platforma tomonidan o'chirilgan (local fallback faol)")
	}

	// Rule 2: RESTRICTED classified documents may NEVER leave the boundary
	if classification == ClassificationRestricted {
		return false, errors.New("RESTRICTED toifasidagi hujjatlar O'RQ-547 ga muvofiq tashqi LLM ga uzatilishi qat'iyan taqiqlanadi")
	}

	// Rule 3: User/Organization must have explicitly granted EXTERNAL_AI consent
	if !externalAIConsentGranted {
		return false, errors.New("foydalanuvchi tashqi sun'iy intellektga ma'lumot uzatishga rozilik bermagan (CONSENT_REQUIRED)")
	}

	return true, nil
}
