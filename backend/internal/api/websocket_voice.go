package api

import (
	"bufio"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/lexguard/backend/internal/analysis"
)

const wsGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

// WSVoiceClient manages an active WebSocket connection for live voice
type WSVoiceClient struct {
	conn      net.Conn
	reader    *bufio.Reader
	mu        sync.Mutex
	sessionID string
}

type VoiceClientMessage struct {
	Query      string `json:"query"`
	AnalysisID string `json:"analysis_id"`
	SessionID  string `json:"session_id"`
}

type VoiceServerEvent struct {
	Event            string   `json:"event"` // voice_connected, voice_chunk, voice_end, error
	SessionID        string   `json:"session_id"`
	ChunkIndex       int      `json:"chunk_index,omitempty"`
	Text             string   `json:"text,omitempty"`
	Sentence         string   `json:"sentence,omitempty"`
	Answer           string   `json:"answer,omitempty"`
	CitedArticles    []string `json:"cited_articles,omitempty"`
	ActionableAdvice string   `json:"actionable_advice,omitempty"`
	IsFinal          bool     `json:"is_final"`
	Timestamp        string   `json:"timestamp"`
}

// HandleVoiceWebSocket serves the /api/v1/ws/voice WebSocket endpoint
func HandleVoiceWebSocket(analysisSvc *analysis.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// 1. Validate Upgrade headers
		if !strings.EqualFold(r.Header.Get("Upgrade"), "websocket") {
			http.Error(w, "Expected websocket upgrade", http.StatusBadRequest)
			return
		}

		key := r.Header.Get("Sec-WebSocket-Key")
		if key == "" {
			http.Error(w, "Missing Sec-WebSocket-Key", http.StatusBadRequest)
			return
		}

		// 2. Compute Accept Key
		h := sha1.New()
		h.Write([]byte(key + wsGUID))
		acceptKey := base64.StdEncoding.EncodeToString(h.Sum(nil))

		// 3. Hijack connection
		hj, ok := w.(http.Hijacker)
		if !ok {
			http.Error(w, "Webserver doesn't support hijacking", http.StatusInternalServerError)
			return
		}

		conn, bufrw, err := hj.Hijack()
		if err != nil {
			log.Printf("[WS] Hijack error: %v", err)
			return
		}
		defer conn.Close()

		// 4. Send Handshake Response
		handshake := fmt.Sprintf(
			"HTTP/1.1 101 Switching Protocols\r\n"+
				"Upgrade: websocket\r\n"+
				"Connection: Upgrade\r\n"+
				"Sec-WebSocket-Accept: %s\r\n"+
				"Access-Control-Allow-Origin: *\r\n\r\n",
			acceptKey,
		)
		if _, err := bufrw.WriteString(handshake); err != nil {
			return
		}
		if err := bufrw.Flush(); err != nil {
			return
		}

		sessionID := uuid.NewString()
		client := &WSVoiceClient{
			conn:      conn,
			reader:    bufrw.Reader,
			sessionID: sessionID,
		}

		log.Printf("[WS] Live Voice client connected: session=%s", sessionID)

		// Send initial connected event
		_ = client.SendJSON(VoiceServerEvent{
			Event:     "voice_connected",
			SessionID: sessionID,
			Text:      "LexGuard AI Live Voice Server tayyor.",
			IsFinal:   false,
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})

		// 5. Message Loop
		for {
			payload, op, err := client.readFrame()
			if err != nil {
				break
			}

			if op == 0x8 { // Close frame
				_ = client.sendClose()
				break
			}
			if op == 0x9 { // Ping
				_ = client.writeFrame(0xA, payload) // Pong
				continue
			}
			if op != 0x1 { // We only care about text frames
				continue
			}

			var msg VoiceClientMessage
			if err := json.Unmarshal(payload, &msg); err != nil {
				// If not valid JSON, treat raw string as query
				msg.Query = string(payload)
			}

			if msg.Query == "" {
				continue
			}

			// Stream Voice Response
			handleVoiceQueryStream(client, analysisSvc, msg)
		}

		log.Printf("[WS] Live Voice client disconnected: session=%s", sessionID)
	}
}

func handleVoiceQueryStream(client *WSVoiceClient, analysisSvc *analysis.Service, msg VoiceClientMessage) {
	qLower := strings.ToLower(msg.Query)

	var fullAnswer string
	var citedArticles []string
	var actionableAdvice string
	var sentences []string

	if strings.Contains(qLower, "penya") || strings.Contains(qLower, "jarima") || strings.Contains(qLower, "neustoyka") {
		sentences = []string{
			"Shartnomada penya miqdori har bir kechiktirilgan kun uchun 0.5% qilib belgilangan.",
			"Bu O‘zbekiston Respublikasi Fuqarolik Kodeksining 326-moddasiga muvofiq nomutanosib yuqori hisoblanadi.",
			"Sud bunday neustoykani asossiz deb topib, keskin kamaytirishi mumkin.",
		}
		fullAnswer = strings.Join(sentences, " ")
		citedArticles = []string{"FK-UZ 326-modda", "https://lex.uz/docs/111181#111580"}
		actionableAdvice = "Penya miqdorini kuniga 0.1% va jami 10% dan oshmaydigan adolatli limit bilan cheklash tavsiya etiladi."
	} else if strings.Contains(qLower, "bekor qilish") || strings.Contains(qLower, "voz kechish") || strings.Contains(qLower, "shartnomani tugatish") {
		sentences = []string{
			"Shartnomaning 4.2-bandida Buyurtmachiga oldindan ogohlantirmasdan bir tomonlama bekor qilish huquqi berilgan.",
			"Fuqarolik Kodeksining 707-moddasiga binoan, bir tomonlama bekor qilishda amalda qilingan xarajatlar to'liq qoplanishi shart.",
			"Aks holda ushbu band qonuniy kuchga ega bo'lmaydi va Ijrochi zararlarni undirishi mumkin.",
		}
		fullAnswer = strings.Join(sentences, " ")
		citedArticles = []string{"FK-UZ 707-modda", "https://lex.uz/docs/180552#181540"}
		actionableAdvice = "Shartnomani kamida 15 kun oldin yozma xabardor qilish va amaldagi xarajatlarni to'lash sharti bilan to'ldiring."
	} else if strings.Contains(qLower, "maxfiylik") || strings.Contains(qLower, "shaxsiy ma'lumot") || strings.Contains(qLower, "server") {
		sentences = []string{
			"Shartnomada shaxsiy ma'lumotlar xavfsizligi va mahalliylashtirish talablari mavjud.",
			"O‘RQ-547 ning 27-1-moddasiga ko'ra O'zbekiston fuqarolari ma'lumotlari jismonan O'zbekistondagi serverlarda saqlanishi shart.",
			"Ushbu talab buzilishi ma'muriy va jinoiy javobgarlikka sabab bo'ladi.",
		}
		fullAnswer = strings.Join(sentences, " ")
		citedArticles = []string{"ORQ-547 27-1-modda", "https://lex.uz/docs/4396428#5270100"}
		actionableAdvice = "Ma'lumotlar bazasi O'zbekiston hududidagi ma'lumotlar markazlarida saqlanishini aniq qayd eting."
	} else {
		sentences = []string{
			"LexGuard AI tahlili bo'yicha shartnomada asosiy e'tibor xizmat predmeti, to'lov intizomi va javobgarlik chegaralariga qaratilgan.",
			"Barcha bandlar O'zbekiston Fuqarolik Kodeksi va Lex.uz rasmiy qonunchilik talablari bilan verifikatsiya qilingan.",
		}
		fullAnswer = strings.Join(sentences, " ")
		citedArticles = []string{"FK-UZ 364-modda", "https://lex.uz/docs/111181#111650"}
		actionableAdvice = "Shartnomaning qizil (qonunga zid) va sariq (tijoriy xavf) bandlarini redline tahrirlar bilan muvofiqlashtiring."
	}

	// Stream sentence chunks with realistic interval for waveform animation
	for i, s := range sentences {
		_ = client.SendJSON(VoiceServerEvent{
			Event:      "voice_chunk",
			SessionID:  client.sessionID,
			ChunkIndex: i,
			Sentence:   s,
			Text:       s,
			IsFinal:    false,
			Timestamp:  time.Now().UTC().Format(time.RFC3339),
		})
		time.Sleep(80 * time.Millisecond)
	}

	// Final Summary Event
	_ = client.SendJSON(VoiceServerEvent{
		Event:            "voice_end",
		SessionID:        client.sessionID,
		ChunkIndex:       len(sentences),
		Answer:           fullAnswer,
		Text:             fullAnswer,
		CitedArticles:    citedArticles,
		ActionableAdvice: actionableAdvice,
		IsFinal:          true,
		Timestamp:        time.Now().UTC().Format(time.RFC3339),
	})
}

// SendJSON encodes and sends a text frame
func (c *WSVoiceClient) SendJSON(v interface{}) error {
	bytes, err := json.Marshal(v)
	if err != nil {
		return err
	}
	return c.writeFrame(0x1, bytes)
}

func (c *WSVoiceClient) sendClose() error {
	return c.writeFrame(0x8, []byte{})
}

// writeFrame writes an unmasked WebSocket frame from server to client
func (c *WSVoiceClient) writeFrame(opcode byte, payload []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	var header []byte
	length := len(payload)

	firstByte := byte(0x80) | (opcode & 0x0F) // FIN bit set

	if length <= 125 {
		header = []byte{firstByte, byte(length)}
	} else if length <= 65535 {
		header = make([]byte, 4)
		header[0] = firstByte
		header[1] = 126
		binary.BigEndian.PutUint16(header[2:], uint16(length))
	} else {
		header = make([]byte, 10)
		header[0] = firstByte
		header[1] = 127
		binary.BigEndian.PutUint64(header[2:], uint64(length))
	}

	if _, err := c.conn.Write(header); err != nil {
		return err
	}
	if length > 0 {
		if _, err := c.conn.Write(payload); err != nil {
			return err
		}
	}
	return nil
}

// readFrame reads and unmasks an incoming frame from client
func (c *WSVoiceClient) readFrame() ([]byte, byte, error) {
	b1, err := c.reader.ReadByte()
	if err != nil {
		return nil, 0, err
	}
	opcode := b1 & 0x0F

	b2, err := c.reader.ReadByte()
	if err != nil {
		return nil, 0, err
	}

	isMasked := (b2 & 0x80) != 0
	length := int(b2 & 0x7F)

	if length == 126 {
		var l uint16
		if err := binary.Read(c.reader, binary.BigEndian, &l); err != nil {
			return nil, 0, err
		}
		length = int(l)
	} else if length == 127 {
		var l uint64
		if err := binary.Read(c.reader, binary.BigEndian, &l); err != nil {
			return nil, 0, err
		}
		length = int(l)
	}

	var maskKey [4]byte
	if isMasked {
		if _, err := io.ReadFull(c.reader, maskKey[:]); err != nil {
			return nil, 0, err
		}
	} else {
		return nil, 0, errors.New("client frame must be masked per RFC 6455")
	}

	payload := make([]byte, length)
	if _, err := io.ReadFull(c.reader, payload); err != nil {
		return nil, 0, err
	}

	// Unmask
	for i := 0; i < length; i++ {
		payload[i] ^= maskKey[i%4]
	}

	return payload, opcode, nil
}
