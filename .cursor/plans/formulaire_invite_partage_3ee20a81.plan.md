---
name: Formulaire invite partage
overview: Remplacer le stub « Nouveau partage » par un formulaire Propriétaire (tarif/km, période optionnelle type Logement, règles libres), persister l’offre pending en Drift avec migration de schéma, puis revenir à la fiche partages.
todos:
  - id: schema-offer-fields
    content: Colonnes VehicleSharingLinks + migration 37 + createSharingOffer étendu
    status: completed
  - id: invite-form-ui
    content: Formulaire invite (tarif, dates Logement, texte) + prefs route + envoi
    status: completed
  - id: l10n-invite-form
    content: ARB FR/EN/ES + regen ; retirer stub
    status: completed
  - id: verify-invite-form
    content: flutter analyze --fatal-infos (+ tests si cassés)
    status: completed
isProject: false
---

# Formulaire d’invitation partage véhicule

## Décisions figées

- **Envoi** = `createSharingOffer` + enregistrement tarif / période / texte (migration schéma).
- **Période** : les deux dates vides = aucune période ; si l’une est remplie, les deux sont obligatoires et début &lt; fin (calendrier comme Logement).
- **Tarif** : optionnel, défaut **0** ; saisie décimale en unités majeures ; stockage en **centimes** (`* 100`) + devise des préférences (même pattern que l’achat carburant).
- Pas de sync relay dans cette livraison (comportement actuel des offres).

## Schéma — [`vehicle_tables.dart`](mobile/lib/db/vehicle_tables.dart) + migration

Sur `VehicleSharingLinks`, ajouter :

| Colonne | Type | Défaut |
|---|---|---|
| `ratePerKmMinor` | `int` | `0` |
| `rateCurrency` | `text` | `''` (écrit avec la devise prefs à la création) |
| `availabilityStart` | `DateTime?` | null |
| `availabilityEnd` | `DateTime?` | null |
| `ownerRulesText` | `text` | `''` |

Migration Drift : `schemaVersion` **36 → 37** dans [`app_database.dart`](mobile/lib/db/app_database.dart) (`alterTable` / `addColumn` pour chaque champ).

Étendre [`createSharingOffer`](mobile/lib/db/repositories/vehicles_repository.dart) pour accepter ces champs et les écrire à l’insert.

## UI — [`vehicle_sharing_invite_form_screen.dart`](mobile/lib/screens/vehicle_sharing/vehicle_sharing_invite_form_screen.dart)

Passer en `StatefulWidget` + `AppPreferences prefs` (route dans [`app.dart`](mobile/lib/app.dart)).

Formulaire simple (`ListView` + padding safe area) :

1. **Tarif par km** — champ numérique décimal, défaut `0` ; libellé du type « Tarif par km d’utilisation » + courte aide (compensation usure / service).
2. **Période de disponibilité** — deux rangées date début / fin via [`showAppDatePicker`](mobile/lib/util/week_start_calendar.dart) (même usage que `_stepDates` Logement dans [`housing_plan_screen.dart`](mobile/lib/screens/housing/housing_plan_screen.dart) ~L2253+) ; durée affichée si les deux dates sont valides ; erreur si une seule date ou fin ≤ début.
3. **Autres règles** — `TextField` multiligne libre.
4. Bouton primaire **Envoyer l’invitation** (toujours actif si période valide / vide) → parse tarif → `createSharingOffer` → `context.pop` (éventuellement jusqu’à la fiche partages).

Afficher le nom du contact choisi en en-tête (lecture `ContactsRepository`) pour clarifier à qui s’adresse l’offre.

## L10n

Remplacer `vehicleSharingInviteFormStubBody` ; ajouter clés FR/EN/ES dans `app_fr.arb` / `app_en.arb` / `app_es.arb` + regen (`flutter gen-l10n` via workflow existant du projet).

## Vérif

- `cd mobile && ./tool/flutterw analyze --fatal-infos .`
- Tests ciblés si des tests touchent `createSharingOffer` / table links ; sinon analyze suffit pour ce formulaire.
