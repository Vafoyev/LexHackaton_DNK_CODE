package platform

import (
	"encoding/json"
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

func WriteError(w http.ResponseWriter, r *http.Request, statusCode int, errCode string, message string, details interface{}) {
	reqID := GetRequestID(r)
	if reqID == "" {
		reqID = uuid.NewString()
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
