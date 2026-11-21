package identity

import (
	"errors"
	"strings"
	"testing"
)

func TestValidateRegistration(t *testing.T) {
	cases := []struct {
		name, email, pass, full string
		ok                      bool
	}{
		{"ok", "a@b.uz", "Parol1234", "Jasur Aliyev", true},
		{"bad email", "not-an-email", "Parol1234", "Jasur Aliyev", false},
		{"short pass", "a@b.uz", "short", "Jasur Aliyev", false},
		{"long pass", "a@b.uz", strings.Repeat("x", 73), "Jasur Aliyev", false},
		{"short name", "a@b.uz", "Parol1234", "J", false},
	}
	for _, c := range cases {
		err := ValidateRegistration(c.email, c.pass, c.full)
		if c.ok && err != nil {
			t.Errorf("%s: kutilmagan xato %v", c.name, err)
		}
		if !c.ok && !errors.Is(err, ErrInvalidInput) {
			t.Errorf("%s: ErrInvalidInput kutilgan, got %v", c.name, err)
		}
	}
}
