package license

import (
	"context"
	"time"
)

// Purchase is a client-uploaded store token.
type Purchase struct {
	Platform      string
	ProductID     string
	PurchaseToken string
}

// Verifier validates store purchases against the store API.
type Verifier interface {
	VerifyPurchase(ctx context.Context, in Purchase) (Result, error)
}

// Stub does not call a store. Phase A clients reported license status
// separately. Phase B replaces this with Play when credentials are configured.
type Stub struct{}

func (Stub) VerifyPurchase(context.Context, Purchase) (Result, error) {
	return Result{
		ValidationState: ValidationPending,
		Reason:          "play_verifier_unconfigured",
	}, nil
}

// Clock is overridable in tests.
type Clock func() time.Time
