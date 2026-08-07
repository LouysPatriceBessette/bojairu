## Product scope (2026-08-07)

**Out of product for the shipping “thin” sharing cut.** Category-based expense allocation with housing-style **ratios** (Fuel / Maintenance / Payments / Violations propose-and-accept) is **not** part of Bojairũ vehicle sharing.

The **only** cost reconciliation between Propriétaire and Emprunteur is the **usage balance** in `vehicle-sharing-usage-metrics`: rate × attributed distance, fuel anchors already in that model, maintenance **compensation** already provided there, freeze + bilateral transfers. There is **no** second reconciliation mechanism.

| Topic | Product rule |
| --- | --- |
| Maintenance spend | **100% Propriétaire** (not split by ratio). Emprunteur may report maintenance performed; cost sharing is via usage-balance compensation, not category ratios. |
| Fuel | Covered by full-tank anchors + usage-balance formula — **not** by configurable fuel-sharing ratios. |
| Violations / traffic tickets | **Informational** journal / reports only. The app does **not** allocate ticket cost or run responsibility propose/accept. |
| Payments (lease, etc.) | **Not** allocated via sharing ratios in this product. |

Former ADDED requirements below are **superseded** by this scope note. Do not implement them for the current release.

## SUPERSEDED Requirements (do not implement)

### Requirement: Vehicle expenses use fixed categories
~~The system SHALL classify each shared vehicle expense into exactly one of Fuel, Maintenance, Violations, Payments.~~ **Superseded — out of product.**

### Requirement: Fuel category shows observed usage as informational input
~~Fuel sharing ratios with propose/accept.~~ **Superseded — out of product.**

### Requirement: Maintenance category uses a single agreed ratio
~~Configured maintenance-sharing ratio.~~ **Superseded — out of product.** Maintenance cost stays with the Propriétaire.

### Requirement: Payments category uses a configured ratio
~~Payments-sharing ratio.~~ **Superseded — out of product.**

### Requirement: Violations require one responsible participant or unknown
~~Violation responsibility with evidence gates for unknown.~~ **Superseded — out of product.** Violations remain informational records only.

### Requirement: Ratio and responsibility changes require acceptance
~~Propose-and-accept for ratios and violation responsibility.~~ **Superseded — out of product.**

### Requirement: Allocations are explainable
~~Category allocation breakdown UI.~~ **Superseded — out of product.** Use the usage-balance breakdown in `vehicle-sharing-usage-metrics` instead.
