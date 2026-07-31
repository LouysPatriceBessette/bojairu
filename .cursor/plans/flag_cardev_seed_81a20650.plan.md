---
name: Flag cardev seed
overview: Ajouter `--cardev` à `run:dev` pour, à chaque démarrage debug, vider toute la DB locale puis peupler les contacts connectés du catalogue Simulation et un véhicule « QA Civic », sans activer le mode Simulation / FakeRelay.
todos:
  - id: run-dev-flag
    content: Parser --cardev dans run_dev.sh (+ dart-define) et doc melos ; pas d’exclusion plateforme
    status: completed
  - id: config-seed
    content: AppConfig.carDevSeed + car_dev_seed.dart (flush DB complète, contacts catalog, qaSeedE2eVehicle, onboarding)
    status: completed
  - id: bootstrap-wire
    content: Brancher maybeApplyCarDevSeed dans bootstrap.dart (debug, quand CARDEV)
    status: completed
  - id: analyze
    content: flutter analyze --fatal-infos sur les fichiers touchés
    status: completed
isProject: false
---

# Flag `--cardev` — seed contacts + véhicule

## Décisions figées

- **Contacts :** injection locale `kind == connected` avec les noms de [`SandboxBotCatalog`](mobile/lib/sandbox/sandbox_bot_catalog.dart) (Louys, Monica, Ròberr, Liuva, Leo) — **pas** d’entrée Simulation, pas de FakeRelay, pas de ribbon.
- **Véhicule :** réutiliser [`qaSeedE2eVehicle`](mobile/lib/debug/qa_vehicle_seed_helpers.dart) (« QA Civic », Honda Civic 2020, 50 000 km).
- **Reset :** chaque lancement avec `--cardev` **vide toute la DB opérationnelle**, puis reseede contacts + véhicule. Pas de tests parallèles entre modules sur la même base.
- **Plateforme :** le flag n’est **pas** limité à Android (Maestro / autres cibles possibles plus tard).

## Flux

```mermaid
flowchart LR
  cli["run_dev.sh --cardev"] --> define["dart-define CARDEV=true"]
  define --> boot["bootstrap debug"]
  boot --> flush["flush toute la DB"]
  flush --> seedC["upsert 5 contacts catalog"]
  flush --> seedV["qaSeedE2eVehicle"]
  seedC --> app["app usable"]
  seedV --> app
```

## Changements

### 1. Script — [`mobile/tool/run_dev.sh`](mobile/tool/run_dev.sh)

- Parser `--cardev`.
- Si actif : ajouter `--dart-define=CARDEV=true` aux `run_args` (build normal).
- **Ne pas** refuser hors Android.
- Commentaire d’usage + ligne dans la description melos [`pubspec.yaml`](pubspec.yaml) `run:dev`.

### 2. Config — [`mobile/lib/config/app_config.dart`](mobile/lib/config/app_config.dart)

- Champ `carDevSeed` via `bool.fromEnvironment('CARDEV', defaultValue: false)`.

### 3. Seed — nouveau [`mobile/lib/debug/car_dev_seed.dart`](mobile/lib/debug/car_dev_seed.dart)

- `maybeApplyCarDevSeed(AppDatabase db, {required bool enabled})` :
  - no-op si `!enabled` / `!kDebugMode` ;
  - **flush DB complète** (réutiliser / étendre le clear existant type `clearDevOperationalTables` pour y inclure **toutes** les tables véhicule aussi — aujourd’hui ce helper ne les couvre pas) ;
  - upsert les 5 contacts (`contact:cardev:<Name>`, `connected`, avatars catalogue) ;
  - `qaSeedE2eVehicle(db)` ;
  - onboarding + profil minimal si besoin pour entrer dans l’app après wipe ;
  - `debugPrint('cardev seed: applied')`.

### 4. Bootstrap — [`mobile/lib/bootstrap.dart`](mobile/lib/bootstrap.dart)

- Quand `config.carDevSeed` : `await maybeApplyCarDevSeed(...)` au démarrage debug.
- Rien d’autre (pas de logique de coexistence avec d’autres seeds).

### 5. Vérif

- `cd mobile && ./tool/flutterw analyze --fatal-infos` sur les fichiers touchés.

## Usage attendu

```bash
./tool/melosw run run:dev -- --cardev
```

Relancer avec `--cardev` = DB vide + contacts Simulation + QA Civic. Sans le flag = comportement actuel.
