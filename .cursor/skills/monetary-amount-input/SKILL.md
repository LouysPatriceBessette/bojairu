---
name: monetary-amount-input
description: >-
  Requires every user-editable monetary amount field (cost, price, penalty,
  expense amount, violation amount, fuel cost, etc.) to pad to two fractional
  digits on blur via AppDecimalTextField or VehicleNarrowUnitField with
  fractionDigits: 2. Use when adding or editing Flutter money inputs, vehicle
  forms, housing expense/settlement/penalty fields, or any currency major-unit
  TextEditingController.
---

# Monetary amount input (blur → two decimals)

## Hard default

Every **user-editable monetary amount** in major currency units (dollars, euros,
…) **must** format on **blur** (focus loss) by padding missing fractional digits
to **exactly two** (e.g. `40` → `40.00`, `35.5` → `35.50`).

This is the **default** for the whole app. Do **not** leave a money field as a
plain `AppTextField` / `VehicleNarrowUnitField` without blur formatting.

Only skip this when the user **explicitly** asks for a different money input
behavior for that field.

## Canonical widgets

| Situation | Use |
| --- | --- |
| Standard form amount | `AppDecimalTextField(controller: …, fractionDigits: 2, …)` |
| Narrow field + unit suffix (e.g. fuel cost + `$`) | `VehicleNarrowUnitField(…, decimal: true, fractionDigits: 2, unitSuffix: currencySymbol)` |
| Custom layout that cannot use those widgets | Call `applyFixedDecimalInputOnBlur(controller, fractionDigits: 2)` on focus loss (same as housing expense split rows) |

Helpers live in `mobile/lib/util/fixed_decimal_input.dart` and
`mobile/lib/widgets/app_decimal_text_field.dart`.

## Display (not input)

Showing stored money to the user uses `formatMinorAsMoney` (or related display
helpers) — see `display-number-rounding` / `format_money.dart`. That is separate
from **input** blur formatting; both must be correct.

## Not monetary (do not force `.00`)

- Odometer / horometer / distance
- Volume (liters / gallons)
- Percentages (`fractionDigits: 1` when that product rule applies)
- Integer counts (days, quantities that are whole units by design)
- Integer **minor-unit** editors if a field is intentionally cents-as-integer
  (e.g. vehicle-sharing rate stored as integer cents/km) — only when the
  existing product UI is clearly not a major-unit money field

## Agent checklist (every money field touch)

1. Identify whether the control edits a **currency major-unit amount**.
2. If yes → `AppDecimalTextField` / `VehicleNarrowUnitField` + `fractionDigits: 2`
   (or `applyFixedDecimalInputOnBlur` with `2`).
3. Grep sibling forms for the same pattern; do not leave one money field as a
   plain decimal `TextField` while others already pad on blur.
4. Analyze the touched Dart paths before delivery.

## Failure mode to avoid

Shipping a new or edited money field that accepts `40` and leaves `40` after
blur while maintenance/housing amounts already become `40.00`.
