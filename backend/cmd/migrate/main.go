package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/lexguard/backend/internal/platform"
)

func main() {
	action := "up"
	if len(os.Args) > 1 {
		action = os.Args[1]
	}

	cfg := platform.LoadConfig()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	conn, err := pgx.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("[FATAL] Bazaga ulanishda xatolik: %v", err)
	}
	defer conn.Close(ctx)

	switch action {
	case "up":
		fmt.Println("[INFO] Migratsiyalar qo'llanmoqda (0001_init.sql)...")
		sqlPath := findFile("migrations/0001_init.sql")
		data, err := os.ReadFile(sqlPath)
		if err != nil {
			log.Fatalf("[FATAL] 0001_init.sql fayli topilmadi: %v", err)
		}
		if _, err := conn.Exec(ctx, string(data)); err != nil {
			log.Fatalf("[FATAL] Migratsiyani bajarishda xatolik: %v", err)
		}
		fmt.Println("[SUCCESS] 19 ta jadval va indekslar muvaffaqiyatli yaratildi!")

	case "seed":
		fmt.Println("[INFO] Curated Lex.uz normativ bazasi va demo ma'lumotlar yuklanmoqda (seed.sql)...")
		sqlPath := findFile("seeds/seed.sql")
		data, err := os.ReadFile(sqlPath)
		if err != nil {
			log.Fatalf("[FATAL] seeds/seed.sql fayli topilmadi: %v", err)
		}
		if _, err := conn.Exec(ctx, string(data)); err != nil {
			log.Fatalf("[FATAL] Seed yuklashda xatolik: %v", err)
		}
		fmt.Println("[SUCCESS] Qonunlar bazasi (FK, O'RQ-547/1115/1125) va demo foydalanuvchilar yuklandi!")

	case "reset":
		fmt.Println("[WARNING] Baza tozalanmoqda va qayta tiklanmoqda...")
		_, _ = conn.Exec(ctx, `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`)
		// Then run up and seed
		mainWithArgs([]string{"migrate", "up"})
		mainWithArgs([]string{"migrate", "seed"})

	default:
		fmt.Printf("Noma'lum buyruq: %s. Mavjud buyruqlar: up, seed, reset\n", action)
	}
}

func mainWithArgs(args []string) {
	os.Args = args
	main()
}

func findFile(relPath string) string {
	candidates := []string{
		relPath,
		filepath.Join("backend", relPath),
		filepath.Join("..", relPath),
		filepath.Join("/Users/baxrom/ish_full/LexHackaton_DNK_CODE/backend", relPath),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			return c
		}
	}
	return relPath
}
