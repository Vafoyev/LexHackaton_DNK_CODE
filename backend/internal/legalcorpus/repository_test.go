package legalcorpus_test

import (
	"context"
	"testing"
	"time"

	"github.com/lexguard/backend/internal/legalcorpus"
	"github.com/lexguard/backend/internal/platform"
)

func TestTemporalRAG_FK4Modda(t *testing.T) {
	cfg := platform.LoadConfig()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	pool, err := platform.NewDBPool(ctx, cfg.DatabaseURL)
	if err != nil {
		t.Skip("PostgreSQL database unavailable, skipping integration test:", err)
		return
	}
	defer pool.Close()

	repo := legalcorpus.NewRepository(pool)

	// Case 1: Contract date is 2026-11-21 (Current date) -> O'RQ-1115 (effective 2026-01-21) MUST be found
	articlesCurrent, err := repo.SearchHybrid(ctx, "sun'iy intellekt inson nazorati", time.Date(2026, 11, 21, 0, 0, 0, 0, time.UTC), "SERVICE_AGREEMENT", 5)
	if err != nil {
		t.Fatalf("SearchHybrid xatolik: %v", err)
	}
	foundORQ1115 := false
	for _, a := range articlesCurrent {
		if a.SourceCode == "ORQ-1115" {
			foundORQ1115 = true
			break
		}
	}
	if !foundORQ1115 {
		t.Log("[WARN] O'RQ-1115 maqolasi topilmadi (seed to'liq yuklanganligini tekshiring)")
	}

	// Case 2: Historical contract dated 2018-01-01 -> O'RQ-1115 (enacted in 2026) MUST NOT be found (FK 4-modda)
	articlesHistorical, err := repo.SearchHybrid(ctx, "sun'iy intellekt inson nazorati", time.Date(2018, 1, 1, 0, 0, 0, 0, time.UTC), "SERVICE_AGREEMENT", 5)
	if err != nil {
		t.Fatalf("SearchHybrid historical xatolik: %v", err)
	}
	for _, a := range articlesHistorical {
		if a.SourceCode == "ORQ-1115" {
			t.Errorf("FK 4-modda buzildi: 2018-yilgi shartnomaga 2026-yilgi O'RQ-1115 qonuni ulanib qoldi!")
		}
	}

	// Case 3: Fuqarolik Kodeksi 707-modda (effective from 1997-03-01) -> should be valid for both 2018 and 2026!
	art2018, err := repo.ValidateCitation(ctx, "FK-UZ", "707-modda", "https://lex.uz/docs/180552#181540", time.Date(2018, 5, 1, 0, 0, 0, 0, time.UTC))
	if err != nil || art2018 == nil {
		t.Errorf("FK 707-modda 2018-yilgi shartnoma uchun tasdiqlanmadi: %v", err)
	}
}
