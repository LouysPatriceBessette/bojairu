---
name: Vehicle share revoke
overview: Implémenter révocation unilatérale (avec fermeture de session forcée si besoin), réactivation via kinds dédiés (offre-like accept), fige auto confirmé, plafond virement = soldes reportés, et UI Partages / Emprunteur — plus enrichir la règle « parler clair » avec l’exemple pending vs solde reporté.
todos:
  - id: rule-parler-clair
    content: Enrichir parler-clair-pas-de-jargon.mdc (exemple pending ≠ solde reporté)
    status: completed
  - id: envelope-kinds
    content: Ajouter kinds revoke / reactivate propose+accept / sessionEndByOwner + codec
    status: completed
  - id: repo-access
    content: "Repo: revoke+freeze auto, reactivate, accessible revoked, pending gates"
    status: completed
  - id: orch-notif-log
    content: Orchestrator send/import + notifs + activity log
    status: completed
  - id: ui-shares
    content: "UI Partages: check, Révoquer/Réactiver, dialogues, force session"
    status: completed
  - id: ui-borrower
    content: Hub + Autres actions + plafond virement si revoked
    status: completed
  - id: tests-analyze
    content: Tests ciblés + flutterw analyze --fatal-infos
    status: completed
isProject: false
---

# Révocation / réactivation de partage véhicule

## Décisions figées (ce fil)

- **Révocation** : unilatérale (Propriétaire) ; nouveau kind relay ; notif + journal des deux côtés ; fige **confirmé** auto (montant = solde courant au moment de la révocation) ajouté aux soldes reportés.
- **Réactivation** : kinds **dédiés** (proposition + acceptation), pas réutilisation offre/accept ; historique du même lien conservé ; notif Emprunteur.
- **Session ouverte** : dialogue « forcer » → lecture odomètre+photo côté Propriétaire → nouveau kind « session fermée par le propriétaire » → puis processus de révocation normal.
- **Fige / virement en attente de décision** (ex. virement 5 $ pas encore confirmé) : bouton **Révoquer** **désactivé**.
- **Virement si lien révoqué** : plafonné au **total des soldes reportés** (figes + virements confirmés) pour ramener à zéro ; bouton désactivé si ce total est 0.
- **Orthographe UI** (défaut du plan) : français corrigé (`a révoqué` / `a réactivé`, `voulez`, `réellement`) en gardant le sens de tes textes.

## Discipline (demande explicite)

Enrichir [`.cursor/rules/parler-clair-pas-de-jargon.mdc`](.cursor/rules/parler-clair-pas-de-jargon.mdc) : dans les **questions de clarification** au développeur, interdiction du jargon télégraphique seul (`pending`, etc.) ; obligation d’une phrase claire + **exemple concret** (comme fige/virement en attente de décision ≠ solde reporté).

## Transport (client only — pas de change Go relay)

Nouveaux `EnvelopeKind` dans [`mobile/lib/relay/envelopes.dart`](mobile/lib/relay/envelopes.dart) (suite après 28), chiffrement AEAD sur le modèle offre / session existant :

| Kind | Sens |
|------|------|
| `vehicleSharingRevoke` | Révocation unilatérale + payload fige confirmé (même `freezeId` / breakdown des deux côtés) |
| `vehicleSharingReactivatePropose` | Propriétaire propose réactivation du **même** `linkId` |
| `vehicleSharingReactivateAccept` | Emprunteur accepte |
| `vehicleUseSessionEndByOwner` | Fermeture de session forcée (lecture + photo déjà prises) |

Handlers + envoi dans [`handshake_orchestrator.dart`](mobile/lib/relay/handshake_orchestrator.dart) ; kinds d’activité dans [`relay_activity_log_service.dart`](mobile/lib/activity/relay_activity_log_service.dart) ; notifs locales FR dans [`push_notification_service.dart`](mobile/lib/notifications/push_notification_service.dart) + ARB.

**Pas de modification du binaire relay** : les kinds sont opaques au forwarder (même pattern que 16–28).

## Données / repo

Réutiliser `VehicleSharingLinkStatus.revoked` + `revokeSharingLink` dans [`vehicles_repository.dart`](mobile/lib/db/repositories/vehicles_repository.dart).

Ajouter :

- `reactivateSharingLink` (ou équivalent) : `revoked` → `active`, conserver ids / historique, `revokedAt` cleared or kept as audit (minimal : status `active`).
- Étendre `listBorrowerAccessibleEntries` (et filtres hub Emprunteur) pour **inclure** les liens `revoked` (sinon plus d’« Autres actions »).
- Helpers : session ouverte pour un lien ; fige/virement `pending` pour un lien ; création fige **confirmé** sans dialogue (réutiliser breakdown courant via `VehicleUsageBalanceService`).

## UI Propriétaire — [`vehicle_sharing_shares_screen.dart`](mobile/lib/screens/vehicle_sharing/vehicle_sharing_shares_screen.dart)

Écran « Partages » (screenshot gauche) :

- Lignes **actives** : crochet vert `Icons.check_circle` (comme hub [`vehicle_sharing_hub_screen.dart`](mobile/lib/screens/vehicle_sharing/vehicle_sharing_hub_screen.dart) L197–201) + bouton droite **Révoquer**.
- **Révoquer** disabled si fige ou virement en attente de décision sur ce lien.
- Sinon : si session ouverte → dialogue forcer (textes validés) Annuler / Oui → parcours lecture odo+photo (réutiliser flux fin de session existant autant que possible) → envoi `sessionEndByOwner` → puis dialogue révocation standard.
- Sinon : dialogue « Retirer l’accès de cet emprunteur » Annuler / Confirmer → revoke + fige auto + envelope.
- Lignes **révoquées** (afficher aussi les `revoked`) : pas de crochet ; bouton **Réactiver** → propose réactivation (kinds dédiés). Emprunteur accepte côté hub (carte / flux analogue offre pending).

« Aucun autre impact Propriétaire » hors : cet écran, journaux/notifs liés, et règles virement sur solde d’utilisation **de ce lien** quand révoqué.

## UI Emprunteur

- Hub / carte accessible : **Débuter une session** disabled si `revoked` ; **Autres actions** reste actif ([`vehicle_sharing_hub_screen.dart`](mobile/lib/screens/vehicle_sharing/vehicle_sharing_hub_screen.dart)).
- [`vehicle_sharing_other_actions_screen.dart`](mobile/lib/screens/vehicle_sharing/vehicle_sharing_other_actions_screen.dart) : si lien révoqué, désactiver Carburant / Entretien / Dommage ; laisser **Solde d’utilisation** et **Journaux**.

## Solde d’utilisation (lien révoqué)

[`vehicle_usage_balance_reconciliation_ui.dart`](mobile/lib/screens/vehicle/vehicle_usage_balance_reconciliation_ui.dart) :

- Pas de nouveau fige manuel (déjà figé à la révocation).
- Virement : montant max = `|usageBalanceCarriedForwardMinor(...)|` (total reporté) ; si 0 → bouton virement disabled.
- Les deux rôles (écran propriétaire pour ce lien + écran emprunteur).

## Tests ciblés

- Transport / parse revoke + reactivate + session-end-by-owner (sur le modèle `vehicle_sharing_offer_transport_test` / envelopes).
- UI ou logique pure : plafond virement / disable Révoquer si pending décision.
- `analyze --fatal-infos` + tests ciblés (pas la suite complète).

## Hors scope (ce lot)

- Change relay Go / image.
- Maestro E2E multi-device (sauf si tu le demandes ensuite).
- Refonte hors écrans / règles listés.
