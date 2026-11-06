# V101–V104 — Pilotage des générations Espoirs (PRODUCTEUR)

Lot groupé : **V101 diagnostic des relations intermodules**, **V102 choix de parcours individuels** (équilibre, minutes, progression, professionnel), **V103 conseiller transparent basé sur minutes, condition et potentiel**, **V104 archive des générations** sur 15 saisons.

Le module `dist/espoirs-coaching-v101-v104.js` s'appuie sur V73 et V82–V100 déjà intégrés. `ensure` accepte les anciennes sauvegardes sans état `v101to104`; une valeur présente mais invalide est refusée sans effacement silencieux. Les changements de parcours et bilans annuels disposent d'un rollback si le stockage échoue. L'archive annuelle est idempotente et bornée à 15 saisons. Conseils explicables et **non automatiques** : ils ne transfèrent, ne promeuvent ni ne recrutent personne.

**V101 n'est pas une preuve de clics Chromium** : l'audit inspecte les relations objectifs/mentors/charges et le potentiel. Une vraie campagne interactive PC reste indispensable après raccord. Le panneau peut s'installer après les modules V82–V100 via `CDEspoirsCoachingV101V104.install(window)`. **Aucun raccord dans `dist/index.html` n'est apporté dans ce lot** : lancement du panneau et actions non disponibles dans le jeu installé tant que l'intégration ultérieure n'a pas été validée.

Tests dédiés : `node tests/v101-v104-espoirs-coaching.cjs` (17 saisons, actions, ancien JSON, audit, migration passive, rollback). Aucune modification MATCH 3D, R&D, DATA/LNR, calendrier, moteur ou sauvegarde centrale. PR DRAFT seulement ; vérifier la CI sur HEAD exact et la réception Chromium à l'intégration.
