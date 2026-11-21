package documents

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/lexguard/backend/internal/privacy"
)

type DocumentInfo struct {
	ID                 string                     `json:"id"`
	OrganizationID     string                     `json:"organization_id"`
	UserID             string                     `json:"user_id"`
	Filename           string                     `json:"filename"`
	FileSize           int64                      `json:"file_size"`
	MimeType           string                     `json:"mime_type"`
	SHA256             string                     `json:"sha256"`
	StoragePath        string                     `json:"storage_path"`
	DataClassification privacy.DataClassification `json:"data_classification"`
	ParseConfidence    float64                    `json:"parse_confidence"`
	CreatedAt          time.Time                  `json:"created_at"`
	Clauses            []ClauseInfo               `json:"clauses,omitempty"`
}

type ClauseInfo struct {
	ID           string              `json:"id"`
	DocumentID   string              `json:"document_id"`
	ClauseNumber string              `json:"clause_number"`
	Title        string              `json:"title"`
	RawText      string              `json:"raw_text"`
	RedactedText string              `json:"redacted_text"`
	PIIEntities  []privacy.PIIEntity `json:"pii_entities"`
	StartOffset  int                 `json:"start_offset"`
	EndOffset    int                 `json:"end_offset"`
}

// SniffMimeType checks magic bytes of file
func SniffMimeType(buf []byte, filename string) (string, error) {
	if len(buf) >= 4 && bytes.HasPrefix(buf, []byte("%PDF")) {
		return "application/pdf", nil
	}
	if len(buf) >= 4 && bytes.HasPrefix(buf, []byte("PK\x03\x04")) {
		ext := strings.ToLower(filepath.Ext(filename))
		if ext == ".docx" {
			return "application/vnd.openxmlformats-officedocument.wordprocessingml.document", nil
		}
	}
	detected := http.DetectContentType(buf)
	if strings.HasPrefix(detected, "text/") {
		return "text/plain", nil
	}
	return "", fmt.Errorf("ruxsat etilmagan fayl turi: faqat PDF, DOCX yoki TXT qabul qilinadi (%s)", detected)
}

// ExtractText extracts plain text from DOCX, PDF, or TXT
func ExtractText(data []byte, mimeType string) (string, float64, error) {
	switch mimeType {
	case "text/plain":
		return string(data), 1.0, nil

	case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		return extractTextFromDOCX(data)

	case "application/pdf":
		return extractTextFromPDF(data)

	default:
		return "", 0.0, errors.New("noma'lum yoki qo'llab-quvvatlanmaydigan MIME turi")
	}
}

func extractTextFromDOCX(data []byte) (string, float64, error) {
	r, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", 0.0, fmt.Errorf("DOCX arxivini ochishda xatolik: %w", err)
	}

	var docXML io.ReadCloser
	for _, f := range r.File {
		if f.Name == "word/document.xml" {
			rc, err := f.Open()
			if err != nil {
				return "", 0.0, err
			}
			docXML = rc
			break
		}
	}
	if docXML == nil {
		return "", 0.0, errors.New("DOCX fayl ichida word/document.xml topilmadi")
	}
	defer docXML.Close()

	// Parse XML elements (w:p and w:t)
	decoder := xml.NewDecoder(docXML)
	var sb strings.Builder
	var inText bool

	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", 0.0, err
		}

		switch elem := token.(type) {
		case xml.StartElement:
			if elem.Name.Local == "t" {
				inText = true
			} else if elem.Name.Local == "p" {
				sb.WriteString("\n")
			}
		case xml.EndElement:
			if elem.Name.Local == "t" {
				inText = false
			}
		case xml.CharData:
			if inText {
				sb.Write(elem)
			}
		}
	}

	rawText := strings.TrimSpace(sb.String())
	if rawText == "" {
		return "", 0.5, errors.New("DOCX hujjatdan matn ajratib olinmadi")
	}
	return rawText, 0.98, nil
}

func extractTextFromPDF(data []byte) (string, float64, error) {
	// Lightweight robust PDF stream text extractor
	var sb strings.Builder
	content := string(data)

	// Look for Text objects BT ... ET
	reBTET := regexp.MustCompile(`(?s)BT(.*?)ET`)
	matches := reBTET.FindAllStringSubmatch(content, -1)

	reTj := regexp.MustCompile(`\((.*?)\)\s*Tj`)
	reTJ := regexp.MustCompile(`\[(.*?)\]\s*TJ`)

	for _, m := range matches {
		block := m[1]
		tjMatches := reTj.FindAllStringSubmatch(block, -1)
		for _, tj := range tjMatches {
			sb.WriteString(tj[1] + " ")
		}

		tjArrayMatches := reTJ.FindAllStringSubmatch(block, -1)
		for _, tja := range tjArrayMatches {
			inner := tja[1]
			for _, sub := range reTj.FindAllStringSubmatch(inner, -1) {
				sb.WriteString(sub[1])
			}
			sb.WriteString(" ")
		}
		sb.WriteString("\n")
	}

	text := strings.TrimSpace(sb.String())
	if text == "" {
		// Fallback: simple text cleaner
		rePrintable := regexp.MustCompile(`[a-zA-Z0-9\s.,!?:;\-–—"'«»O‘o‘G‘g‘]{4,}`)
		found := rePrintable.FindAllString(content, -1)
		text = strings.Join(found, " ")
		return text, 0.75, nil
	}
	return text, 0.92, nil
}

// ChunkClauses splits text into structured legal clauses
func ChunkClauses(fullText string, redactor *privacy.Redactor) []ClauseInfo {
	lines := strings.Split(fullText, "\n")
	reClauseHeader := regexp.MustCompile(`^(?:(\d+(?:\.\d+)*)[.\s\)]+|([A-ZА-ЯЁO‘G‘\d\s]{3,40}\b\s*:\s*)|([0-9]+-modda[.\s]+)|([0-9]+-bob[.\s]+))`)

	clauses := make([]ClauseInfo, 0)
	var currentNum string
	var currentTitle string
	var currentLines []string
	startOffset := 0

	flush := func() {
		if len(currentLines) == 0 {
			return
		}
		raw := strings.TrimSpace(strings.Join(currentLines, "\n"))
		if raw == "" {
			return
		}
		if currentNum == "" {
			currentNum = fmt.Sprintf("0.%d", len(clauses)+1)
		}
		redaction := redactor.Redact(raw)

		endOffset := startOffset + len(raw)
		clauses = append(clauses, ClauseInfo{
			ID:           uuid.NewString(),
			ClauseNumber: currentNum,
			Title:        currentTitle,
			RawText:      raw,
			RedactedText: redaction.RedactedText,
			PIIEntities:  redaction.Entities,
			StartOffset:  startOffset,
			EndOffset:    endOffset,
		})
		startOffset = endOffset + 1
		currentLines = nil
		currentNum = ""
		currentTitle = ""
	}

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}

		if match := reClauseHeader.FindStringSubmatch(trimmed); match != nil {
			flush()
			if match[1] != "" {
				currentNum = match[1]
			} else if match[3] != "" {
				currentNum = strings.TrimSpace(match[3])
			} else {
				currentNum = fmt.Sprintf("%d", len(clauses)+1)
			}
			currentTitle = trimmed
			currentLines = append(currentLines, trimmed)
		} else {
			if len(currentLines) == 0 {
				currentNum = fmt.Sprintf("%d", len(clauses)+1)
			}
			currentLines = append(currentLines, trimmed)
		}
	}
	flush()

	// If no structured clauses were identified, create single general clause
	if len(clauses) == 0 && len(strings.TrimSpace(fullText)) > 0 {
		raw := strings.TrimSpace(fullText)
		redaction := redactor.Redact(raw)
		clauses = append(clauses, ClauseInfo{
			ID:           uuid.NewString(),
			ClauseNumber: "1.0",
			Title:        "Shartnoma to'liq matni",
			RawText:      raw,
			RedactedText: redaction.RedactedText,
			PIIEntities:  redaction.Entities,
			StartOffset:  0,
			EndOffset:    len(raw),
		})
	}

	return clauses
}

// ComputeSHA256 returns hex encoded SHA256 of data
func ComputeSHA256(data []byte) string {
	h := sha256.Sum256(data)
	return hex.EncodeToString(h[:])
}

// SaveFileToStorage stores file bytes in destination directory
func SaveFileToStorage(storageDir string, docID string, data []byte) (string, error) {
	if err := os.MkdirAll(storageDir, 0755); err != nil {
		return "", err
	}
	filename := fmt.Sprintf("%s.bin", docID)
	destPath := filepath.Join(storageDir, filename)
	if err := os.WriteFile(destPath, data, 0644); err != nil {
		return "", err
	}
	return destPath, nil
}
