package services

import "errors"

// the failures a caller is allowed to hear about. anything else that comes
// out of a service is an internal error and must not be shown to a client.
var (
	ErrNotFound      = errors.New("not found")
	ErrUnknownUser   = errors.New("user not found")
	ErrUsernameTaken = errors.New("username already taken")
	ErrBadUsername   = errors.New("username may not contain control characters")
	ErrRunNotActive  = errors.New("run is not active")
	ErrTooManyEvents = errors.New("this run has reached its event limit")
)
