---
name: Expiry and reminders
overview: "Deux types distincts. Décision (cas 1) : recette A partout, bientôt = décideur, à T = celui qui attend la réponse. Paiement (cas 2) : horloge 14 h locale inchangée. Livraison des paquets : échéance en clair ou 7 jours."
todos:
  - id: relay-expires-at
    content: "Relais : expires_at en clair, 7 j par défaut, ne pas livrer un paquet expiré"
    status: completed
  - id: client-envelope-helper
    content: "App : une fonction d’envoi ; proposition logement + offre / réactivation véhicule passent l’échéance"
    status: completed
  - id: unify-reminders
    content: Une fonction recette A ; logement passe de B à A (rôles bientôt/à T) ; véhicule offre + réactivation ; invitations déjà A
    status: completed
  - id: docs-openspec
    content: Docs + OpenSpec alignés (1.2b, rappels logement) ; paiement inchangé
    status: completed
isProject: false
---

# Expiration des paquets et deux types de rappels

## Distinction (tranchée)

- **Cas 1 — Rappel de décision :** une action (accepter / refuser / voter) n’a pas été faite avant une heure T. Recette A (3 h→T−30 min, 8 h→T−1 h, 24 h→T−2 h, 48 h→T−4 h, plus ping à T).
- **Cas 2 — Rappel de paiement :** une ligne de plan logement à payer selon le calendrier. Horloge 14 h locale **inchangée**. Pas la recette A.

Les pings **à la réception** d’un paquet (« une offre t’attend ») ne sont ni le cas 1 ni le cas 2 : ils restent tels quels.

## Qui est prévenu (cas 1)

- **Bientôt (avant T) :** celui qui doit décider.
- **À T si rien n’a été fait :** celui qui attendait la réponse.

Aujourd’hui ce découpage n’existe **que** pour les invitations (les deux pings vont à l’inviteur, car l’invité n’a pas encore l’app). Les propositions logement envoient un seul « bientôt » (recette B) à l’auteur **et** aux participants, **sans** ping à T. Le véhicule n’a aucun rappel planifié.

## Qui est prévenu (cas 2) — déjà en place, on n’y touche pas

Dans [`housing_payment_reminder_service.dart`](mobile/lib/housing/reminders/housing_payment_reminder_service.dart) : avant l’échéance, le responsable s’il y en a un, sinon tout le monde ; en retard, tout le monde.

## Ce qui changerait (cas 1 seulement)

- Propositions logement : recette B → A ; séparer destinataires bientôt vs à T.
- Offre / réactivation véhicule : **ajouter** recette A (réception existe déjà).
- Invitations : horloge déjà A ; inchangé.
- Votes dépense / figer-virement véhicule : notification à réception seulement ; **pas de T** aujourd’hui → pas de recette A tant qu’il n’y a pas d’échéance.

## Livraison des paquets (pas un rappel)

Échéance lisible par le relais ; sinon conservation 7 jours ; ne plus remettre un paquet expiré. Filet app inchangé.
