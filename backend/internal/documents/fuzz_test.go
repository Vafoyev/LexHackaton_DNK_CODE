package documents_test

import (
	"testing"

	"github.com/lexguard/backend/internal/documents"
	"github.com/lexguard/backend/internal/privacy"
)

func FuzzClauseChunking(f *testing.F) {
	redactor := privacy.NewRedactor()

	// Seed corpus
	f.Add("1.1. Oddiy shartnoma bandi.\n2.1. Ikkinchi band.")
	f.Add("")
	f.Add("### Ko'chmas mulk \n JSHSHIR: 30101901234567")
	f.Add("\x00\x01\x02\xFF\xFE\xFD")

	f.Fuzz(func(t *testing.T, input string) {
		clauses := documents.ChunkClauses(input, redactor)
		// Property: must not crash, and total clauses must be >= 0
		if len(clauses) < 0 {
			t.Errorf("Manfiy bandlar soni!")
		}
		for _, c := range clauses {
			if c.RawText == "" && len(input) > 0 {
				t.Errorf("Bo'sh clause raw_text topildi")
			}
		}
	})
}
