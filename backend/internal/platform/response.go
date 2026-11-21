package platform

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/google/uuid"
)

type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data"`
	Error   *APIError   `json:"error"`
	Meta    APIMeta     `json:"meta"`
}

type APIError struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

type APIMeta struct {
	Timestamp string `json:"timestamp"`
	RequestID string `json:"request_id"`
}

func WriteJSON(w http.ResponseWriter, r *http.Request, statusCode int, data interface{}) {
	reqID := GetRequestID(r)
	if reqID == "" {
		reqID = uuid.NewString()
	}

	resp := APIResponse{
		Success: statusCode >= 200 && statusCode < 300,
		Data:    data,
		Error:   nil,
		Meta: APIMeta{
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			RequestID: reqID,
		},
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(resp)
}

// internalErrorMessage 500 javoblarida mijozga ko'rsatiladigan umumiy matn.
const internalErrorMessage = "Ichki server xatosi. Keyinroq urinib ko'ring"

func WriteError(w http.ResponseWriter, r *http.Request, statusCode int, errCode string, message string, details interface{}) {
	reqID := GetRequestID(r)
	if reqID == "" {
		reqID = uuid.NewString()
	}
	// 500: ichki xato matni (DB, fayl yo'li, SQL) mijozga chiqmaydi — faqat logga yoziladi.
	if statusCode == http.StatusInternalServerError {
		slog.Error("internal_error", slog.String("code", errCode), slog.String("detail", message), slog.String("req_id", reqID))
		message = internalErrorMessage
		details = nil
	}

	resp := APIResponse{
		Success: false,
		Data:    nil,
		Error: &APIError{
			Code:    errCode,
			Message: message,
			Details: details,
		},
		Meta: APIMeta{
			Timestamp: time.Now().UTC().Format(time.RFC3339),
			RequestID: reqID,
		},
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(resp)
}
