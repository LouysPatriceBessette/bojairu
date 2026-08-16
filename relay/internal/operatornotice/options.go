package operatornotice

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"strings"
)

// Options is the VPS CLI for an Android-only operator FCM notice.
type Options struct {
	TargetBuild int
	ConsultSite bool
	Confirm     bool
}

// ParseArgs reads `relay operator-notice` flags. Default is dry-run
// (Confirm=false). At least one of --target-build or --consult-site is required.
func ParseArgs(args []string) (Options, error) {
	var opts Options
	var dryRun bool
	fs := flag.NewFlagSet("operator-notice", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	fs.IntVar(&opts.TargetBuild, "target-build", 0, "Play versionCode the in-app page compares against (omit to skip the update affordance)")
	fs.BoolVar(&opts.ConsultSite, "consult-site", false, "in-app page offers a link to https://bojairu.app")
	fs.BoolVar(&dryRun, "dry-run", false, "count distinct FCM tokens and exit without sending (default when --confirm is absent)")
	fs.BoolVar(&opts.Confirm, "confirm", false, "actually send FCM operator_notice to distinct Android tokens")
	if err := fs.Parse(args); err != nil {
		return Options{}, err
	}
	if fs.NArg() != 0 {
		return Options{}, fmt.Errorf("unexpected argument %q", fs.Arg(0))
	}
	if dryRun && opts.Confirm {
		return Options{}, errors.New("use either --dry-run or --confirm, not both")
	}
	if opts.TargetBuild < 0 {
		return Options{}, errors.New("--target-build must be a positive integer")
	}
	if opts.TargetBuild == 0 && !opts.ConsultSite {
		return Options{}, errors.New("at least one of --target-build or --consult-site is required")
	}
	return opts, nil
}

func (o Options) TargetBuildString() string {
	if o.TargetBuild <= 0 {
		return ""
	}
	return fmt.Sprintf("%d", o.TargetBuild)
}

func (o Options) Summary() string {
	var parts []string
	if o.TargetBuild > 0 {
		parts = append(parts, fmt.Sprintf("target_build=%d", o.TargetBuild))
	} else {
		parts = append(parts, "target_build=-")
	}
	if o.ConsultSite {
		parts = append(parts, "consult_site=1")
	} else {
		parts = append(parts, "consult_site=0")
	}
	if o.Confirm {
		parts = append(parts, "mode=confirm")
	} else {
		parts = append(parts, "mode=dry-run")
	}
	return strings.Join(parts, " ")
}
