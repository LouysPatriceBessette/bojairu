---
name: flutter-in-app-back-navigation
description: >-
  Prevents Flutter screens that trap users without an in-app back affordance.
  Use when adding or reviewing screens, AppBars, Navigator.push /
  pushReplacement, navigateToRoute vs navigateToChildRoute, GoRouter go vs
  push, or when the user reports being stuck / no Retour / no leading back.
---

# Flutter in-app back navigation (no traps)

## Incident (binding — 2026-07-26)

**Symptom:** Housing plan summary → *Voir les dépenses en détail*
(`HousingProposalExpensesDetailScreen`) showed expenses correctly but **no
in-app Retour**. User was trapped except for the Android system back control.

**Root cause (not “forgot IconButton”):** call sites used
`navigateToRoute` → **`Navigator.pushReplacement`**. The parent summary was
**removed** from the stack. Default `AppBar` only implies a leading back when
`ModalRoute.canPop` is true — after replacement, **canPop is false**, so **no
leading**.

**Correct API:** `navigateToChildRoute` → `Navigator.push` (already used on
`housing_active_plan_read_only_screen.dart` for the same detail screen).

**Forbidden “easy workaround”:** painting a `BackButton` / `leading:` that
calls `Navigator.pop` when the route was opened with `pushReplacement` and
there is nothing meaningful to pop back to — or relying on the **system** back
gesture alone as the product exit.

---

## Hard rules

1. **Every pushed screen the user can open must have a clear in-app way out**
   (AppBar leading back, explicit close, or documented module exit that is
   visible in the chrome). System back / gesture is **not** sufficient product
   UX for Bojairũ.

2. **Choose the navigator API by intent:**

| Intent | API | Stack effect | AppBar auto-back |
| --- | --- | --- | --- |
| Drill-down / detail / “view …” | `navigateToChildRoute` / `navigateToChild` / `Navigator.push` / GoRouter `push` | Parent stays | Yes (when canPop) |
| Replace current (no return to previous) | `navigateToRoute` / `navigateTo` (`go`) / `pushReplacement` | Parent gone | **No** |

3. **`navigateToRoute` is a dangerous name.** It means **replace**, not
   “open a route”. Before any `navigateToRoute(` call, answer: *Should the user
   return to the screen I’m leaving?* If **yes** → **`navigateToChildRoute`**.

4. **Do not “fix” a missing leading by only setting `leading: BackButton()`**
   without verifying `canPop` / that the route was **pushed**. If canPop is
   false, fix the **entry** navigation first.

5. **Before shipping a new screen**, mentally (or with Maestro) walk:
   open → see content → leave via **in-app** control → land on the previous
   product screen. If that walk fails, the change is not done.

---

## Checklist (new or touched screen)

```
[ ] Entry uses push/child API when return is required
[ ] AppBar shows leading back OR an explicit visible exit (not system-only)
[ ] After pop/back, user is on the expected parent (not home / empty stack)
[ ] Nested navigators / rootNavigator: true — same canPop rules on that stack
[ ] Grep sibling call sites for the same destination (don’t leave one
    pushReplacement path while another was fixed)
```

---

## Code pointers (this repo)

| Symbol | File | Meaning |
| --- | --- | --- |
| `navigateToRoute` | `mobile/lib/navigation/app_navigation.dart` | `pushReplacement` — no auto back |
| `navigateToChildRoute` | same | `push` — drill-down |
| `navigateTo` / `navigateToChild` | same | GoRouter `go` vs `push` |
| Expenses detail (incident) | `housing_proposal_expenses_detail_screen.dart` | Must be opened with child route |

---

## Home module cards → Licenses (binding — 2026-08-09)

**Symptom:** Accueil → **Licences** had no in-app AppBar back; only Android
system back. Recurrent class of trap when a new home tile is wired with
`navigateTo`.

**Root cause:** `home_screen.dart` used `navigateTo(context, '/licenses')`
(`GoRouter.go`) — same stack replacement as Settings’ anti-pattern. Settings
already uses `navigateToChild`; Licenses did not.

**Fix:** `navigateToChild(context, '/licenses')` so `canPop` is true and the
AppBar leading appears.

**Rule of thumb for home tiles:** any card that should return to Accueil
(settings-like, licenses, “view …” detail) → **`navigateToChild`**. Reserve
`navigateTo` for top-level module shells where replacing Accueil is intentional
and the module has its own exit.

---

## Post-submit wizard → confirmation (binding — 2026-07-26)

**Symptom:** After submitting a plan-line amendment (form → aperçu → « Changement
demandé »), AppBar / « Atrás » returned to **Editar gasto** instead of the
housing hub.

**Root cause:** Submit used `navigateToRoute` (`pushReplacement`) from aperçu
only. Stack stayed: hub → Modifier le plan → form → **detail**. Popping detail
resurfaced the form.

**Fix:** `openHousingAmendmentDetailAfterSubmit` in
`housing_amendment_navigation.dart` — `popUntil(isFirst)` then `push` detail so
Back lands on the hub.

**Rule:** After a multi-step wizard **commits**, do not only replace the last
step. Clear intermediate wizard routes (or pop to the intended parent) **then**
open the confirmation/detail screen.

---

## When reviewing agent or human diffs

If the diff adds `navigateToRoute(` or `pushReplacement(` to open a detail /
preview / “view” screen, **flag it**. Ask whether return is required. Default
assumption for any *Voir …* / detail / form opened from a list or summary:
**child push**. After a **submit** that should leave the wizard, prefer
`popUntil` (or equivalent) to the parent **then** push confirmation — not a
single `pushReplacement` of the last wizard page alone.