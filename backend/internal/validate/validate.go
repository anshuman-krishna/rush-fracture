// package validate holds bounds checks for client-submitted gameplay data.
// none of this is anti-cheat (a modified client can still lie about its
// score) — it just stops garbage/absurd values from being persisted
// verbatim, and caps string fields so no single field can bloat a row.
package validate

import "fmt"

const (
	MaxUsernameLen = 32
	MaxIDLen       = 64  // user_id / run_id references (generateID is 32 hex chars today)
	MaxShortStrLen = 64  // weapon_used, room_type, upgrade_id
	MaxTagsLen     = 512 // mutations, run_tags (comma-separated lists)

	MaxScore     = 1_000_000_000
	MaxLevel     = 1000
	MaxKills     = 1_000_000
	MaxDuration  = 86400 // seconds, 24h
	MaxCombo     = 100_000
	MaxRoomIndex = 10_000
)

func NonEmpty(field, val string, maxLen int) error {
	if val == "" {
		return fmt.Errorf("%s is required", field)
	}
	if len(val) > maxLen {
		return fmt.Errorf("%s exceeds max length of %d", field, maxLen)
	}
	return nil
}

func MaxLen(field, val string, maxLen int) error {
	if len(val) > maxLen {
		return fmt.Errorf("%s exceeds max length of %d", field, maxLen)
	}
	return nil
}

func Range(field string, val, min, max int) error {
	if val < min || val > max {
		return fmt.Errorf("%s must be between %d and %d", field, min, max)
	}
	return nil
}
