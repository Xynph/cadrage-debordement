# Phase 9 — contrats et fatigue

Réceptions graphiques ciblées sur `096f3d8f6a879bc2e240e99b2184ab7f3d688182`,
SHA de common figé communiqué par root. Les wrappers ne génèrent pas de
`provenance.json` : le manifeste distingue cette attribution de la preuve
directe des journaux et fournit les empreintes des scripts sur ce SHA.

| Cas | Contrôles / échecs | Durée TAP |
| --- | --- | --- |
| Contrats | 270 / 0 | 47,834 s |
| Fatigue | 685 / 0 | 106,471 s |

Les journaux identifient Godot 4.7.2 et X11/llvmpipe. Aucune nouvelle exécution
SDK n’a été lancée pour constituer ce dossier. Les compteurs Gabi/parole ne
sont pas mesurés par ces wrappers ; aucune assertion 0/0 n’en est tirée.

## Captures originales sélectionnées

Les cinq PNG sont copiés octet pour octet, sans retouche, en 2560×1440.

- [Contrats, effectif réel](images/contrats-effectif.png) : 52 joueurs, échéances
  et couverture par poste lisibles, salaire par semaine explicite.
- [Contrats, unité mensuelle](images/contrats-monthly.png) : libellés et montants
  mensuels visibles. L’image annuelle non sélectionnée a aussi été inspectée.
- [Nom long — illustration synthétique](images/contrats-nom-long.png) : le test
  remplace temporairement `app.model.squad[0].name`, filtre ce nom, capture la
  troncature, puis restaure le joueur. Ce nom ne provient pas du moteur.
- [Fatigue, carrière réelle](images/fatigue-carriere-reelle-1440.png) : plan
  individuel confirmé dans une vraie carrière, sans lancement de séance.
- [Fatigue — projection UI synthétique](images/fatigue-projection-de-recette-1440.png) :
  condition/charge/blessure/suspension/sélection modifiées dans le seul modèle
  affiché pour illustrer les compteurs. Le profil moteur n’est pas modifié.

La confirmation individuelle, non sélectionnée, a été inspectée : elle précise
que l’action ne lance pas la séance. Les tests séparent consultation sans
commande/écriture, confirmation du plan et projection illustrative. Les 685
contrôles fatigue incluent aussi des fixtures isolées de seuils/filtres ; ils
ne sont pas tous des interactions sur une carrière réelle.

Les captures ne prouvent ni la persistance moteur des états synthétiques, ni
une campagne SDK globale, ni une recette Windows. Aucun profil complet ou
fixture complète n’est livré.

## Intégrité

Le manifeste associe chaque pièce à son origine, sa taille, son SHA-256 et son
SHA de code. `sha256sum --check SHA256SUMS` vérifie toutes les pièces, manifeste
et présent document compris ; le fichier de sommes ne s’inclut pas lui-même.
