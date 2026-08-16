package operatornotice

import "testing"

func TestParseArgsRequiresTargetOrSite(t *testing.T) {
	_, err := ParseArgs(nil)
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestParseArgsDryRunDefault(t *testing.T) {
	opts, err := ParseArgs([]string{"--consult-site"})
	if err != nil {
		t.Fatal(err)
	}
	if opts.Confirm || !opts.ConsultSite || opts.TargetBuild != 0 {
		t.Fatalf("got %+v", opts)
	}
}

func TestParseArgsConfirmAndTarget(t *testing.T) {
	opts, err := ParseArgs([]string{"--target-build=39", "--confirm"})
	if err != nil {
		t.Fatal(err)
	}
	if !opts.Confirm || opts.TargetBuild != 39 || opts.ConsultSite {
		t.Fatalf("got %+v", opts)
	}
	if opts.TargetBuildString() != "39" {
		t.Fatalf("target string %q", opts.TargetBuildString())
	}
}

func TestParseArgsRejectsBothModes(t *testing.T) {
	_, err := ParseArgs([]string{"--consult-site", "--dry-run", "--confirm"})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestParseArgsRejectsNegativeBuild(t *testing.T) {
	_, err := ParseArgs([]string{"--target-build=-1"})
	if err == nil {
		t.Fatal("expected error")
	}
}
