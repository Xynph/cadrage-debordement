# Réception UI-02C — plan indépendant, sans édition du chantier producteur

Références lues : `main e706d6a`, UI-02A #81 (`86ca5af4fcf591f512c3110388519b20d26ac11b`), UI-02B #83 (`9b3a290d29f17aa526cac26e430a07fbb1a93ef6`). Le producteur réalise UI-02C ; ce document prépare sa revue, **il ne certifie pas un écran qui n'a pas encore été réceptionné**.

## Points de contrat repérés à la lecture

- `chooseColumns` autorise l'absence de `name`, tandis que `renderTable` ne crée le bouton d'ouverture de fiche que dans cette colonne. Le contrôleur doit conserver une action accessible indépendamment des colonnes, ou rendre l'identification obligatoire. Tester la réouverture d'une fiche après masquage du nom.
- Les onglets inactifs de `renderPlayer` portent `tabindex=-1` ; `bindActions` ne gère que click/change/input. Le raccordement doit traiter flèches, Home/End, focus initial et retour à l'appelant. Ce n'est pas la preuve d'un défaut dans le futur contrôleur : vérifier sa version réelle.
- Une liste de colonnes vide est refusée par le modèle. Le rendu ignore la demande lorsque toutes les cases sont décochées : vérifier que cases et colonnes ne divergent pas après cet essai.
- Les tris de valeurs nulles sont inversés avec le sens descendant. Définir un comportement cohérent pour les valeurs absentes et vérifier qu'il est compris ; ne pas présenter une donnée manquante comme zéro.

Ces remarques ont été transmises dans #73 pendant que le producteur réserve ses chemins. Aucun changement de #81, #83 ou UI-02C n'est effectué dans ce lot.

## Matrice de réception priorisée

| Priorité | Parcours | Preuve à exiger |
|---|---|---|
| P0 | Chargement et navigation | Scripts/styles effectivement chargés ; fiche ouverte depuis l'onglet Joueurs, retour au bon filtre ; les trois autres onglets de l'effectif restent utilisables |
| P0 | Données sportives | Note et potentiel issus des fonctions natives sur copie ; 11 attributs, salaire et numéro de saison conformes ; pas de recalcul métier divergent |
| P0 | Confidentialité sportive | Projection propre à l'effectif du manager ; ne pas révéler le potentiel non observé des adversaires par un ID arbitraire |
| P0 | Absence d'effet de bord | État S, stockage bdt-v1 et flux RNG inchangés après navigation, tris, colonnes et comparaison ; ancien joueur sans données initialisées testé |
| P0 | Sauvegarde | Import/export native avant/après ; nouvelle carrière, ancien format, changement de club V58 ; aucune préférence visuelle stockée dans la carrière |
| P0 | Données obsolètes | Fiche d'un joueur vendu, retiré ou d'un ancien club : fermeture ou état clair, jamais modification du mauvais joueur |
| P0 | Sécurité | Noms, IDs et recherches malveillants échappés ; stockage des colonnes corrompu/indisponible sans panne ni effacement des sauvegardes |
| P1 | Clavier et focus | Onglets au clavier, recherche sans perte de curseur, confirmation visible, retour focus, nom masqué et zéro colonne |
| P1 | Comparaison | Exactement deux joueurs distincts, valeurs natives, message pour familles différentes, valeurs absentes non transformées en zéros |
| P1 | Responsive | Vrais clics et captures aux largeurs 320/390/768/1024/1440, Tribune/Analyste/Système, pas de débordement global ; défilement local des tableaux autorisé |
| P1 | Régressions UI-01/V40 | Commandes de session, alerte de sauvegarde sur mobile et ui01-integration.css préservées ; match, feuille à 23, tactiques et modales accessibles |
| P1 | Carrière longue | Réexécuter le banc multi-clubs après raccordement, vérifier le rafraîchissement des fiches et historiques aux changements de saison/club |

## Conditions de livraison

Réception de la PR consolidée du producteur sur le dernier main, revue des chemins et dépendances, tests ciblés puis CI complète du SHA exact. Aucun merge séparé de #81/#83 au milieu de son raccordement. L'intégrateur seul peut fusionner une PR non brouillon compatible ; vérification des runs push sur le SHA résultant et passation dans #73. La réussite des composants isolés n'est pas une livraison jouable.

**Statut de ce document : préparation terminée, réception fonctionnelle UI-02C à effectuer sur sa PR. Aucun test visuel nouveau n'est revendiqué ici.**
