package server

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"rush-fracture/backend/internal/config"
	"rush-fracture/backend/internal/repositories"
	"rush-fracture/backend/internal/services"
)

const testKey = "test-key"

// builds the whole api on an in-memory database. skipped when the binary
// was built without cgo, because then there is no sqlite to talk to.
func newAPI(t *testing.T, mutate func(*config.Config)) http.Handler {
	t.Helper()
	db, err := repositories.OpenDatabase(":memory:")
	if err != nil {
		t.Skipf("no sqlite driver in this build: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	if err := repositories.Migrate(db); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	cfg := config.Config{APIKey: testKey, RateLimitPerMin: 100000, MaxBodyBytes: 4096}
	if mutate != nil {
		mutate(&cfg)
	}
	return New(cfg, db)
}

type reply struct {
	code int
	body string
}

func (r reply) decode(t *testing.T, into any) {
	t.Helper()
	if err := json.Unmarshal([]byte(r.body), into); err != nil {
		t.Fatalf("response is not json: %v (%q)", err, r.body)
	}
}

func call(t *testing.T, api http.Handler, method, path, key string, body any) reply {
	t.Helper()
	var payload bytes.Buffer
	switch v := body.(type) {
	case nil:
	case string:
		payload.WriteString(v)
	default:
		if err := json.NewEncoder(&payload).Encode(v); err != nil {
			t.Fatalf("encode: %v", err)
		}
	}
	req := httptest.NewRequest(method, path, &payload)
	if key != "" {
		req.Header.Set("X-API-Key", key)
	}
	rec := httptest.NewRecorder()
	api.ServeHTTP(rec, req)
	return reply{code: rec.Code, body: rec.Body.String()}
}

func want(t *testing.T, r reply, code int, what string) {
	t.Helper()
	if r.code != code {
		t.Fatalf("%s: expected %d, got %d (%q)", what, code, r.code, strings.TrimSpace(r.body))
	}
}

func createUser(t *testing.T, api http.Handler, name string) string {
	t.Helper()
	r := call(t, api, "POST", "/api/users", testKey, map[string]string{"username": name})
	want(t, r, http.StatusCreated, "create user")
	var user struct {
		ID string `json:"id"`
	}
	r.decode(t, &user)
	return user.ID
}

func startRun(t *testing.T, api http.Handler, userID string) string {
	t.Helper()
	r := call(t, api, "POST", "/api/runs/start", testKey, map[string]string{"user_id": userID})
	want(t, r, http.StatusCreated, "start run")
	var run struct {
		ID string `json:"id"`
	}
	r.decode(t, &run)
	return run.ID
}

func TestHealthNeedsNoKey(t *testing.T) {
	api := newAPI(t, nil)
	want(t, call(t, api, "GET", "/health", "", nil), http.StatusOK, "health without a key")
}

func TestEverythingElseNeedsTheKey(t *testing.T) {
	api := newAPI(t, nil)
	for _, path := range []string{"/api/users/abc", "/api/runs/abc", "/api/stats/abc", "/api/runs/abc/events", "/ws"} {
		want(t, call(t, api, "GET", path, "", nil), http.StatusUnauthorized, path+" with no key")
		want(t, call(t, api, "GET", path, "wrong", nil), http.StatusUnauthorized, path+" with a wrong key")
		want(t, call(t, api, "GET", path, testKey+"x", nil), http.StatusUnauthorized, path+" with a longer key")
	}
	want(t, call(t, api, "POST", "/api/users", "", map[string]string{"username": "a"}), http.StatusUnauthorized, "create with no key")
}

func TestUsers(t *testing.T) {
	api := newAPI(t, nil)
	id := createUser(t, api, "  rook  ")

	r := call(t, api, "GET", "/api/users/"+id, testKey, nil)
	want(t, r, http.StatusOK, "get user")
	var user struct {
		Username string `json:"username"`
	}
	r.decode(t, &user)
	if user.Username != "rook" {
		t.Errorf("expected the name to be trimmed, got %q", user.Username)
	}

	dup := call(t, api, "POST", "/api/users", testKey, map[string]string{"username": "rook"})
	want(t, dup, http.StatusConflict, "duplicate username")
	if strings.Contains(strings.ToLower(dup.body), "constraint") || strings.Contains(dup.body, "users.") {
		t.Errorf("a database message reached the client: %q", dup.body)
	}

	want(t, call(t, api, "POST", "/api/users", testKey, map[string]string{"username": ""}), http.StatusBadRequest, "empty username")
	want(t, call(t, api, "POST", "/api/users", testKey, map[string]string{"username": "   "}), http.StatusBadRequest, "blank username")
	want(t, call(t, api, "POST", "/api/users", testKey, map[string]string{"username": "a\x00b"}), http.StatusBadRequest, "control character")
	want(t, call(t, api, "POST", "/api/users", testKey, map[string]string{"username": strings.Repeat("x", 33)}), http.StatusBadRequest, "long username")
	want(t, call(t, api, "POST", "/api/users", testKey, "{not json"), http.StatusBadRequest, "broken json")
	want(t, call(t, api, "GET", "/api/users/nobody", testKey, nil), http.StatusNotFound, "unknown user")
}

func TestRunLifecycle(t *testing.T) {
	api := newAPI(t, nil)
	userID := createUser(t, api, "rook")

	want(t, call(t, api, "POST", "/api/runs/start", testKey, map[string]string{"user_id": "nobody"}), http.StatusNotFound, "run for an unknown user")
	want(t, call(t, api, "POST", "/api/runs/start", testKey, map[string]string{"user_id": ""}), http.StatusBadRequest, "run with no user")

	runID := startRun(t, api, userID)
	base := "/api/runs/" + runID

	want(t, call(t, api, "POST", base+"/rooms/enter", testKey, map[string]any{"room_index": 0, "room_type": "combat", "elapsed_time": 1}), http.StatusCreated, "room entered")
	want(t, call(t, api, "POST", base+"/rooms/clear", testKey, map[string]any{"room_index": 0, "room_type": "combat", "enemies_killed": 9, "elapsed_time": 30}), http.StatusCreated, "room cleared")
	want(t, call(t, api, "POST", base+"/upgrade", testKey, map[string]any{"room_index": 0, "upgrade_id": "damage_up", "elapsed_time": 31}), http.StatusCreated, "upgrade chosen")
	want(t, call(t, api, "POST", base+"/rooms/enter", testKey, map[string]any{"room_index": -1, "room_type": "combat"}), http.StatusBadRequest, "negative room index")
	want(t, call(t, api, "POST", base+"/rooms/enter", testKey, map[string]any{"room_index": 0, "room_type": ""}), http.StatusBadRequest, "missing room type")
	want(t, call(t, api, "POST", "/api/runs/nope/rooms/enter", testKey, map[string]any{"room_index": 0, "room_type": "combat"}), http.StatusNotFound, "event for an unknown run")

	events := call(t, api, "GET", base+"/events", testKey, nil)
	want(t, events, http.StatusOK, "event log")
	var log []struct {
		EventType string `json:"event_type"`
	}
	events.decode(t, &log)
	if len(log) != 3 || log[0].EventType != "entered" || log[2].EventType != "upgrade" {
		t.Errorf("expected three events in order, got %+v", log)
	}

	end := map[string]any{"score": 1200, "level": 6, "enemies_killed": 40, "duration": 300, "best_combo": 12, "weapon_used": "pulse_rifle", "boss_defeated": true}
	bad := map[string]any{"score": -5}
	want(t, call(t, api, "POST", base+"/end", testKey, bad), http.StatusBadRequest, "negative score")
	want(t, call(t, api, "POST", base+"/end", testKey, map[string]any{"score": 2000000000}), http.StatusBadRequest, "absurd score")

	done := call(t, api, "POST", base+"/end", testKey, end)
	want(t, done, http.StatusOK, "end run")
	var run struct {
		Status       string `json:"status"`
		Score        int    `json:"score"`
		BossDefeated bool   `json:"boss_defeated"`
	}
	done.decode(t, &run)
	if run.Status != "complete" || run.Score != 1200 || !run.BossDefeated {
		t.Errorf("unexpected finished run: %+v", run)
	}

	want(t, call(t, api, "POST", base+"/end", testKey, end), http.StatusConflict, "ending a run twice")
	want(t, call(t, api, "POST", base+"/rooms/enter", testKey, map[string]any{"room_index": 1, "room_type": "combat"}), http.StatusConflict, "event after the run ended")
	want(t, call(t, api, "POST", "/api/runs/nope/end", testKey, end), http.StatusNotFound, "ending an unknown run")
	want(t, call(t, api, "GET", "/api/runs/nope", testKey, nil), http.StatusNotFound, "unknown run")
	want(t, call(t, api, "GET", "/api/runs/nope/events", testKey, nil), http.StatusNotFound, "events of an unknown run")

	empty := call(t, api, "GET", "/api/runs/"+startRun(t, api, userID)+"/events", testKey, nil)
	if strings.TrimSpace(empty.body) != "[]" {
		t.Errorf("an empty event log should be an empty list, got %q", empty.body)
	}
}

func TestStatsAddUp(t *testing.T) {
	api := newAPI(t, nil)
	userID := createUser(t, api, "rook")
	for i, score := range []int{100, 900, 400} {
		runID := startRun(t, api, userID)
		want(t, call(t, api, "POST", "/api/runs/"+runID+"/end", testKey,
			map[string]any{"score": score, "level": i + 1, "enemies_killed": 10, "duration": 60}), http.StatusOK, "end run")
	}
	r := call(t, api, "GET", "/api/stats/"+userID, testKey, nil)
	want(t, r, http.StatusOK, "stats")
	var stat struct {
		TotalRuns  int `json:"total_runs"`
		BestScore  int `json:"best_score"`
		BestLevel  int `json:"best_level"`
		TotalTime  int `json:"total_time"`
		TotalKills int `json:"total_kills"`
	}
	r.decode(t, &stat)
	if stat.TotalRuns != 3 || stat.BestScore != 900 || stat.BestLevel != 3 || stat.TotalTime != 180 || stat.TotalKills != 30 {
		t.Errorf("unexpected stats: %+v", stat)
	}
}

// two requests ending the same run at once: exactly one may win.
func TestEndingARunIsAtomic(t *testing.T) {
	api := newAPI(t, nil)
	runID := startRun(t, api, createUser(t, api, "rook"))

	const attempts = 16
	codes := make([]int, attempts)
	var wg sync.WaitGroup
	for i := range attempts {
		wg.Add(1)
		go func() {
			defer wg.Done()
			body := fmt.Sprintf(`{"score": %d}`, i+1)
			codes[i] = call(t, api, "POST", "/api/runs/"+runID+"/end", testKey, body).code
		}()
	}
	wg.Wait()

	won := 0
	for _, code := range codes {
		switch code {
		case http.StatusOK:
			won++
		case http.StatusConflict:
		default:
			t.Errorf("unexpected status %d", code)
		}
	}
	if won != 1 {
		t.Errorf("expected exactly one request to end the run, %d did", won)
	}
}

func TestEventLimitPerRun(t *testing.T) {
	api := newAPI(t, nil)
	runID := startRun(t, api, createUser(t, api, "rook"))
	body := map[string]any{"room_index": 0, "room_type": "combat"}
	for i := 0; i < services.MaxEventsPerRun; i++ {
		if r := call(t, api, "POST", "/api/runs/"+runID+"/rooms/enter", testKey, body); r.code != http.StatusCreated {
			t.Fatalf("event %d: expected 201, got %d", i, r.code)
		}
	}
	want(t, call(t, api, "POST", "/api/runs/"+runID+"/rooms/enter", testKey, body), http.StatusTooManyRequests, "one event too many")

	r := call(t, api, "GET", "/api/runs/"+runID+"/events", testKey, nil)
	var log []json.RawMessage
	r.decode(t, &log)
	if len(log) != repositories.MaxEventsReturned {
		t.Errorf("expected the log to be capped at %d, got %d", repositories.MaxEventsReturned, len(log))
	}
}

func TestOversizedBodyIsRejected(t *testing.T) {
	api := newAPI(t, func(c *config.Config) { c.MaxBodyBytes = 64 })
	big := `{"username": "` + strings.Repeat("a", 500) + `"}`
	want(t, call(t, api, "POST", "/api/users", testKey, big), http.StatusRequestEntityTooLarge, "oversized body")
}

// wrong guesses at the key have to count against the rate limit, or the
// limit does nothing to slow someone guessing it.
func TestRateLimitCoversFailedAuth(t *testing.T) {
	api := newAPI(t, func(c *config.Config) { c.RateLimitPerMin = 5 })
	for i := 0; i < 5; i++ {
		want(t, call(t, api, "GET", "/api/users/x", "guess", nil), http.StatusUnauthorized, "wrong key inside the limit")
	}
	want(t, call(t, api, "GET", "/api/users/x", "guess", nil), http.StatusTooManyRequests, "wrong key past the limit")
	want(t, call(t, api, "GET", "/api/users/x", testKey, nil), http.StatusTooManyRequests, "right key past the limit")
}

func TestWebsocketPingPong(t *testing.T) {
	api := newAPI(t, nil)
	srv := httptest.NewServer(api)
	defer srv.Close()
	url := "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws"

	if _, resp, err := websocket.DefaultDialer.Dial(url, nil); err == nil {
		t.Fatal("expected the socket to need the api key")
	} else if resp == nil || resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 without a key, got %v (%v)", resp, err)
	}

	header := http.Header{"X-API-Key": []string{testKey}}
	evil := http.Header{"X-API-Key": []string{testKey}, "Origin": []string{"https://evil.example"}}
	if _, _, err := websocket.DefaultDialer.Dial(url, evil); err == nil {
		t.Fatal("expected a browser origin that is not on the list to be refused")
	}

	conn, _, err := websocket.DefaultDialer.Dial(url, header)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
	// junk first: it must be ignored, not end the connection
	if err := conn.WriteMessage(websocket.TextMessage, []byte("not json")); err != nil {
		t.Fatalf("write: %v", err)
	}
	if err := conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"something_else"}`)); err != nil {
		t.Fatalf("write: %v", err)
	}
	if err := conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"ping"}`)); err != nil {
		t.Fatalf("write: %v", err)
	}
	conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, raw, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var msg struct {
		Type string `json:"type"`
	}
	if err := json.Unmarshal(raw, &msg); err != nil || msg.Type != "pong" {
		t.Fatalf("expected a pong, got %q", raw)
	}
}
