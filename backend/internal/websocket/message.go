package websocket

import "encoding/json"

type MessageType string

const (
	TypePing       MessageType = "ping"
	TypePong       MessageType = "pong"
	TypeGameState  MessageType = "game_state"
	TypePlayerMove MessageType = "player_move"
	TypeRunStart   MessageType = "run_start"
	TypeRunEnd     MessageType = "run_end"
)

type Message struct {
	Type    MessageType     `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}
