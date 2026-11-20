# Finances — auto-relecture cliquable / petites fenêtres / maquette (20/11/2026)

Maquette choisie par Léo : variante 1 « Verdict en tête, quatre blocs » + bloc Alloué / Engagé / Restant (variante 3) + colonne de verdict fixe (variante 2).
Captures relues : `E:\Cadrage-Debordement\temp\da-finances\captures-finales-3\` puis `captures-finales-4\` (1920×1080 et 1280×720, six onglets).

## A. Cliquabilité

| Élément | Effet du clic | Verdict |
| --- | --- | --- |
| Onglets Synthèse … Classement, Ctrl+Tab | change d'onglet | OK |
| Bloc Verdict (Synthèse et colonne) | onglet Budget (sauf sur Budget, où il n'a pas d'allure cliquable) | OK |
| Carte Trésorerie | onglet Trésorerie (sur Trésorerie : Budget) | OK |
| Carte Budget de transferts (Alloué / Engagé / Restant) | écran Recrutement | OK |
| Carte Marge courante | onglet Budget (sur Budget : Trésorerie) | OK |
| Vigilances (contrats, infrastructures, plafond) + liens « Contrats → » etc. | Salaires / Stratégie (Infrastructures) / Salaires | OK |
| Lignes des Prochaines échéances | Salaires / Budget ou Formation / Trésorerie | OK |
| Lignes « Où va l'argent » | Salaires / Budget ou Formation / Stratégie | OK |
| « Ajuster le budget » | Stratégie (décisions financières) | OK |
| Barres et points de la courbe | le mouvement, surligné dans le journal (Trésorerie) | OK |
| Totaux Entrées / Sorties / Solde (Trésorerie) | onglet Budget — **corrigé** (avant : rien, alors qu'ils ont l'allure des chiffres cliquables) | OK |
| Lignes du journal des flux | écran de la catégorie (Salaires, Infrastructures, Budget) | OK |
| Préc. / Suiv. | page du journal, sur place | OK (pagination) |
| Salaires : en-têtes de colonnes | tri sur place | OK (tri) |
| Salaires : nom du joueur | fiche complète ; survol = mini-fiche | OK |
| Salaires : « Voir le contrat → » | fiche joueur, section contrat | OK |
| Transferts : « Ouvrir le recrutement », « Consulter les salaires… » | Recrutement / Salaires | OK |
| Budget : tuiles Formation / Installations / Recettes | Formation / Stratégie / Trésorerie | OK |
| Budget : « Ouvrir les décisions financières » | Stratégie | OK |
| Classement : nom du club | fiche du club | OK |
| Classement : étiquette de santé | n'a plus l'allure d'une puce (liseré + mot) — **corrigé** | OK |
| Classement : mini-courbe | infobulle seulement (graphe, pas d'allure de bouton) | AVIS |

Couvert par `tests/godot-finances-ecran.gd` (toute zone listée change d'écran ou d'onglet, aucune fenêtre).

## B. Petites fenêtres

Aucune : aucun clic de Finances n'ouvre de Window / AcceptDialog / ConfirmationDialog / PopupPanel (vérifié par le test sur les six onglets). Finances ne dépense rien elle-même : les dépenses (travaux, formation payée, recrutement) se confirment sur leur écran ; pas de confirmation d'argent à convertir ici. Seule exception utilisée : mini-fiche au survol d'un nom.

## C. Fidélité à la maquette

BLOQUANT (corrigés)
- 1280×720 : la phrase du verdict chevauchait les descriptions des paliers (Synthèse et colonne fixe). Les descriptions passent en infobulle en fenêtre étroite ; test de non-chevauchement ajouté.

À CORRIGER (corrigés)
- Axe de la courbe : graduations non rondes, la ligne d'équilibre marquée « −880 € ». Graduations 1/2/5, zéro écrit « 0 € » ; test ajouté.
- Budget : deux boutons ivoire pleins ; « Ajuster le budget » y devient un lien.
- Classement : pastille arrondie bordée (rayon ≠ 0) et cadre complet autour de ton club → liseré + mot, fond relevé + liseré ivoire.
- Classement : même phrase « Pas encore de saison close… » sur 14 lignes, tronquée à 1280 → l'en-tête de colonne dit « Trois dernières saisons · à venir ».
- 1280 : textes tronqués (marge, vigilances, légende de la courbe, pagination « Préc. 1 / 4 », Transferts, Budget) → reflux ou libellés plus courts.

AVIS (écarts acceptés)
- Courbe : la maquette montre 12 semaines datées ; le journal n'a pas de dates, donc « 12 derniers mouvements » (aucune semaine inventée).
- Échéances : trois lignes hebdomadaires réelles au lieu d'une liste datée (pas de calendrier de paiements dans les données).
- La rallonge du conseil reste dans Recrutement (la carte y mène).
- Synthèse 1920 : bande libre sous la courbe (≈ 100 px) ; on garde la hauteur de la maquette.
