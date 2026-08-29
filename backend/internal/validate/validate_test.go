package validate

import "testing"

func TestNonEmpty(t *testing.T) {
	if err := NonEmpty("username", "", MaxUsernameLen); err == nil {
		t.Error("expected error for empty value, got nil")
	}
	if err := NonEmpty("username", "player1", MaxUsernameLen); err != nil {
		t.Errorf("expected no error for valid value, got %v", err)
	}
	tooLong := make([]byte, MaxUsernameLen+1)
	if err := NonEmpty("username", string(tooLong), MaxUsernameLen); err == nil {
		t.Error("expected error for value exceeding max length, got nil")
	}
	exact := make([]byte, MaxUsernameLen)
	if err := NonEmpty("username", string(exact), MaxUsernameLen); err != nil {
		t.Errorf("expected no error at exact max length, got %v", err)
	}
}

func TestMaxLen(t *testing.T) {
	if err := MaxLen("weapon_used", "", MaxShortStrLen); err != nil {
		t.Errorf("expected empty string to be allowed by MaxLen, got %v", err)
	}
	tooLong := make([]byte, MaxTagsLen+1)
	if err := MaxLen("run_tags", string(tooLong), MaxTagsLen); err == nil {
		t.Error("expected error for value exceeding max length, got nil")
	}
	exact := make([]byte, MaxTagsLen)
	if err := MaxLen("run_tags", string(exact), MaxTagsLen); err != nil {
		t.Errorf("expected no error at exact max length, got %v", err)
	}
}

func TestRange(t *testing.T) {
	cases := []struct {
		name    string
		val     int
		min     int
		max     int
		wantErr bool
	}{
		{"below min", -1, 0, MaxScore, true},
		{"above max", MaxScore + 1, 0, MaxScore, true},
		{"at min", 0, 0, MaxScore, false},
		{"at max", MaxScore, 0, MaxScore, false},
		{"mid range", MaxLevel / 2, 0, MaxLevel, false},
		{"negative duration", -1, 0, MaxDuration, true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := Range("field", c.val, c.min, c.max)
			if c.wantErr && err == nil {
				t.Errorf("Range(%d, %d, %d): expected error, got nil", c.val, c.min, c.max)
			}
			if !c.wantErr && err != nil {
				t.Errorf("Range(%d, %d, %d): expected no error, got %v", c.val, c.min, c.max, err)
			}
		})
	}
}
