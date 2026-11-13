package controllers

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"rush-fracture/backend/internal/services"
)

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		slog.Error("failed to write response", "error", err)
	}
}

// decodes a json body into dst. reports false, having already answered the
// request, if the body is not valid json or is larger than the server allows.
func readJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	if err := json.NewDecoder(r.Body).Decode(dst); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			http.Error(w, "request body too large", http.StatusRequestEntityTooLarge)
		} else {
			http.Error(w, "invalid request body", http.StatusBadRequest)
		}
		return false
	}
	return true
}

// answers a failed request. the errors a service declares are safe to show
// and each has a status. anything else is logged here and the client is
// told nothing about it: database messages name tables and columns.
func writeError(w http.ResponseWriter, r *http.Request, err error) {
	status := http.StatusInternalServerError
	switch {
	case errors.Is(err, services.ErrNotFound), errors.Is(err, services.ErrUnknownUser):
		status = http.StatusNotFound
	case errors.Is(err, services.ErrUsernameTaken), errors.Is(err, services.ErrRunNotActive):
		status = http.StatusConflict
	case errors.Is(err, services.ErrBadUsername):
		status = http.StatusBadRequest
	case errors.Is(err, services.ErrTooManyEvents):
		status = http.StatusTooManyRequests
	}
	if status == http.StatusInternalServerError {
		slog.Error("request failed", "method", r.Method, "path", r.URL.Path, "error", err)
		http.Error(w, "internal server error", status)
		return
	}
	http.Error(w, err.Error(), status)
}
