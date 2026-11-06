# Finances V2 — première intégration jouable (#365)

## Ce qui change
Depuis l'onglet **Finances** de la vraie carrière PC, une synthèse V2 affiche la trésorerie native du club, les salaires de l'effectif et les recettes/charges du **journal conservé**. Le journal est plafonné à 100 écritures par le moteur existant : ces sommes ne constituent donc pas un bilan annuel ni une comptabilité à partie double. Les anciennes prévisions demeurent distinctes plus bas dans l'onglet.

Deux décisions déjà existantes sont réunies au même endroit : choisir le budget de formation 0/4 000/12 000 € par semaine financée et acheter le prochain niveau d'installations si le moteur l'autorise. Les boutons appellent directement `careerSetAcademyInvestment` et `worldUpgradeFacility` ; aucune seconde logique de débit n'est ajoutée. L'achat des installations est immédiat ; choisir un budget de formation ne débite pas immédiatement. L'onglet Formation et l'ancien panneau Investissements restent utilisables.

Pour les anciennes sauvegardes, les modules facultatifs non encore activés offrent les boutons natifs `careerEnable` et `worldEnable`. La lecture du tableau de bord ne modifie pas `S`, le générateur aléatoire ni la sauvegarde.

## Ce qui n'est PAS implémenté
Pas de migration du noyau comptable E1, pas d'ajout de dette, de recettes garanties, de financement fictif, de changements du moteur de match, de nouveaux choix de redressement ou de promesse de classement. Les flux enregistrés restent la vérité disponible. Les projections V41 existantes demeurent hypothétiques.

## Réception à réaliser sur HEAD exact
- `node --test tests/finance-v2-playable.cjs` : vue, cohérence des valeurs, anciens états, garde-fous, non-mutation et montage dans l'index.
- Tests natifs de carrière, investissements, sauvegardes/import et suite JavaScript générale du dépôt sur CI.
- Vérification visuelle Chromium 1920×1080 et 1440×900, confirmation dans l'onglet Finances (pas un fichier HTML autonome).
- Sur une copie de carrière : acheter des installations, constater le débit et l'écriture, exporter/importer, comparer le niveau et le cash ; choisir 4k, entraîner, vérifier le débit unique puis recharger.
Aucune qualification n'est acquise tant que les tests/CI correspondants ne sont pas réellement réussis.

## Sécurité
Diff borné à `dist/finance-v2.js`, `dist/index.html`, la fonction `finance()` de `dist/game.js`, ce test et cette note. Aucun changement PRODUCTEUR, DATA/LNR, studio-ui, MATCH 3D, gate ni PR R&D.
