package websocket

import (
	"log/slog"
	"net/http"
	"sync/atomic"

	"github.com/gorilla/websocket"
)

// the most sockets the hub will hold open at once. each one costs two
// goroutines and a buffer, so without a ceiling a client could open them
// until the process ran out of memory.
const MaxClients = 512

type Hub struct {
	clients        map[*Client]bool
	broadcast      chan []byte
	register       chan *Client
	unregister     chan *Client
	allowedOrigins map[string]bool
	upgrader       websocket.Upgrader
	// connections accepted and not yet closed. counted here rather than by
	// len(clients), which only the Run goroutine may read.
	open atomic.Int32
}

// allowedOrigins mirrors the http CORS allow-list (empty means no browser
// origin is trusted). a request with no Origin header at all, which is any
// native client, is still allowed through: CheckOrigin only exists to stop
// a web page from opening a cross-origin socket.
func NewHub(allowedOrigins []string) *Hub {
	allowed := make(map[string]bool, len(allowedOrigins))
	for _, o := range allowedOrigins {
		allowed[o] = true
	}

	h := &Hub{
		clients:        make(map[*Client]bool),
		broadcast:      make(chan []byte),
		register:       make(chan *Client),
		unregister:     make(chan *Client),
		allowedOrigins: allowed,
	}
	h.upgrader = websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin: func(r *http.Request) bool {
			origin := r.Header.Get("Origin")
			return origin == "" || h.allowedOrigins[origin]
		},
	}
	return h
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = true
			slog.Info("websocket client connected", "total", len(h.clients))

		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				// the only place a send channel is closed. it runs after the
				// client's read loop has ended, so nothing can still be
				// sending on it.
				close(client.send)
				h.open.Add(-1)
				slog.Info("websocket client disconnected", "total", len(h.clients))
			}

		case message := <-h.broadcast:
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					// not keeping up. dropping the connection ends its read
					// loop, which unregisters it through the path above.
					client.conn.Close()
				}
			}
		}
	}
}

func (h *Hub) HandleConnection(w http.ResponseWriter, r *http.Request) {
	if h.open.Add(1) > MaxClients {
		h.open.Add(-1)
		http.Error(w, "too many connections", http.StatusServiceUnavailable)
		return
	}

	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		h.open.Add(-1)
		slog.Warn("websocket upgrade failed", "error", err)
		return
	}

	client := NewClient(h, conn)
	h.register <- client

	go client.WritePump()
	go client.ReadPump()
}
