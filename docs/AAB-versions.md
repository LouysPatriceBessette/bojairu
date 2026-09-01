# Android App Bundle versions

Play `versionCode` history for Bojairũ AABs built with
[`mobile/tool/build_AAB`](../mobile/tool/build_AAB).

Each successful run appends one row. `--test` records intended Play **internal
testing** use; `--prod` records intended **Production** track use. Both flags
build the same prod-release AAB (flavor `prod`, production relay and license
URLs). The Usage cell is written exactly as `Test interne` or `Production`.

User-visible `versionName` still comes from the latest git tag
(`mobile/tool/compute_version.sh`). `versionCode` is this table: first build
is **101**, then last listed number + 1. Gaps are allowed. Do not reuse a
number already uploaded to Play.

The Notes column is for the operator. The script leaves it empty.

Older Play uploads (for example internal `versionCode` 40) are not listed
here.

| Version | Built at | Usage | Notes |
| --- | --- | --- | --- |
| 101 | 2026-08-25 17:43 EDT | Production |  |
| 102 | 2026-09-01 14:09 EDT | Production |  |
