package middleware

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func okHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
}

func TestCORSAllowedOrigin(t *testing.T) {
	h := CORS([]string{"https://example.com"})(okHandler())
	req := httptest.NewRequest(http.MethodGet, "/api/runs", nil)
	req.Header.Set("Origin", "https://example.com")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://example.com" {
		t.Errorf("expected Access-Control-Allow-Origin to be echoed, got %q", got)
	}
	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}
}

func TestCORSDisallowedOrigin(t *testing.T) {
	h := CORS([]string{"https://example.com"})(okHandler())
	req := httptest.NewRequest(http.MethodGet, "/api/runs", nil)
	req.Header.Set("Origin", "https://evil.example")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("expected no CORS header for disallowed origin, got %q", got)
	}
}

func TestCORSEmptyAllowListBlocksEverything(t *testing.T) {
	h := CORS(nil)(okHandler())
	req := httptest.NewRequest(http.MethodGet, "/api/runs", nil)
	req.Header.Set("Origin", "https://example.com")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("expected empty allow-list to grant no origin, got %q", got)
	}
}

func TestCORSPreflightShortCircuits(t *testing.T) {
	called := false
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
	})
	h := CORS([]string{"https://example.com"})(next)
	req := httptest.NewRequest(http.MethodOptions, "/api/runs", nil)
	req.Header.Set("Origin", "https://example.com")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Errorf("expected 204 for OPTIONS preflight, got %d", rec.Code)
	}
	if called {
		t.Error("expected preflight to short-circuit before reaching the next handler")
	}
}

func TestAPIKeyAuthEmptyKeyIsNoop(t *testing.T) {
	h := APIKeyAuth("")(okHandler())
	req := httptest.NewRequest(http.MethodGet, "/api/runs", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected empty api key to allow all requests, got %d", rec.Code)
	}
}

func TestAPIKeyAuthHealthBypass(t *testing.T) {
	h := APIKeyAuth("secret")(okHandler())
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected /health to bypass api key check, got %d", rec.Code)
	}
}

func TestAPIKeyAuthRejectsMissingOrWrongKey(t *testing.T) {
	h := APIKeyAuth("secret")(okHandler())

	req := httptest.NewRequest(http.MethodGet, "/api/runs", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 with missing key, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodGet, "/api/runs", nil)
	req.Header.Set("X-API-Key", "wrong")
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 with wrong key, got %d", rec.Code)
	}
}

func TestAPIKeyAuthAcceptsCorrectKey(t *testing.T) {
	h := APIKeyAuth("secret")(okHandler())
	req := httptest.NewRequest(http.MethodGet, "/api/runs", nil)
	req.Header.Set("X-API-Key", "secret")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200 with correct key, got %d", rec.Code)
	}
}

func TestMaxBodyRejectsOversizedPayload(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "too large", http.StatusRequestEntityTooLarge)
			return
		}
		w.WriteHeader(http.StatusOK)
	})
	h := MaxBody(10)(next)

	req := httptest.NewRequest(http.MethodPost, "/api/runs", strings.NewReader("this payload is definitely over ten bytes"))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("expected oversized body to be rejected, got %d", rec.Code)
	}
}

func TestMaxBodyAllowsUnderLimit(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, err := io.ReadAll(r.Body); err != nil {
			http.Error(w, "too large", http.StatusRequestEntityTooLarge)
			return
		}
		w.WriteHeader(http.StatusOK)
	})
	h := MaxBody(1024)(next)

	req := httptest.NewRequest(http.MethodPost, "/api/runs", strings.NewReader("small payload"))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected under-limit body to pass through, got %d", rec.Code)
	}
}

func TestRateLimiterAllowsUpToLimit(t *testing.T) {
	rl := &RateLimiter{visitors: make(map[string]*visitorState), limit: 3, window: time.Minute}

	for i := 0; i < 3; i++ {
		if !rl.allow("1.2.3.4") {
			t.Fatalf("request %d should be allowed within the limit", i+1)
		}
	}
	if rl.allow("1.2.3.4") {
		t.Error("4th request should be blocked once the limit is reached")
	}
}

func TestRateLimiterTracksVisitorsIndependently(t *testing.T) {
	rl := &RateLimiter{visitors: make(map[string]*visitorState), limit: 1, window: time.Minute}

	if !rl.allow("1.1.1.1") {
		t.Fatal("first visitor's first request should be allowed")
	}
	if !rl.allow("2.2.2.2") {
		t.Error("a different visitor should have its own independent limit")
	}
	if rl.allow("1.1.1.1") {
		t.Error("first visitor's second request should be blocked")
	}
}

func TestRateLimiterResetsAfterWindow(t *testing.T) {
	rl := &RateLimiter{visitors: make(map[string]*visitorState), limit: 1, window: 20 * time.Millisecond}

	if !rl.allow("1.2.3.4") {
		t.Fatal("first request should be allowed")
	}
	if rl.allow("1.2.3.4") {
		t.Fatal("second request within the window should be blocked")
	}
	time.Sleep(30 * time.Millisecond)
	if !rl.allow("1.2.3.4") {
		t.Error("request after the window elapses should be allowed again")
	}
}

func TestClientIPStripsPort(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = "203.0.113.7:54321"
	if got := clientIP(req); got != "203.0.113.7" {
		t.Errorf("expected port to be stripped, got %q", got)
	}
}

func TestClientIPFallsBackWithoutPort(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.RemoteAddr = "not-a-valid-host-port"
	if got := clientIP(req); got != "not-a-valid-host-port" {
		t.Errorf("expected raw RemoteAddr fallback, got %q", got)
	}
}
