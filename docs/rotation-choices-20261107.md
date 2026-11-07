# Rotation actionnable — 7 novembre 2026

Nouvelle aide à la décision dans la rubrique existante Effectif > Couverture des postes : 15 postes observés, alerte lorsque le titulaire ne remplit pas les seuils de condition/charge ou quand moins de deux joueurs sont prêts, proposition d'examiner un remplaçant réellement frais **hors feuille à 23**, accès à sa fiche et à la composition native.

Le moteur de match, la composition et les sauvegardes ne sont jamais modifiés automatiquement. Une navigation ou une consultation ne crée pas de mutation, et les choix de joueurs demeurent manuels. Aucun nouveau champ de sauvegarde.

Réception exigée : test natif `node tests/rotation-choices.cjs` et test Chromium `python tests/rotation-choices-browser.py` sur carrière fictive réelle. L'ancienne carrière reste couverte par la validation native des exports ; ce lot ne réalise aucune migration. Ne pas annoncer Windows natif testé. Exclusions : MATCH3D, DATA/LNR, effectifs, calendrier et autres PR.
