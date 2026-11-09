# Diagnostic EPCR — liste proposée et feuille 2026/27

`native/engine/epcr-eligibility.cjs` fournit des diagnostics purs, sans lecture disque, horloge, sélection automatique ou hasard. Il ne constitue pas une inscription auprès d'EPCR et ne crée aucune inscription persistante dans la carrière. La date limite, les renforts et leurs contrats ne sont pas contrôlés par ce module.

## Sources et portée

Sources officielles lues le 9 novembre 2026, explicitement pour 2026/27 :

- [Investec Champions Cup, sections 3.1–3.3](https://www.epcrugby.com/champions-cup/champions-cup-rules).
- [EPCR Challenge Cup, sections 3.1–3.3](https://www.epcrugby.com/challenge-cup/ecc-rules).

Ce sont des résumés officiels, sans date de publication affichée, et non le handbook consolidé complet. Section 3.1 : liste jusqu'à 42 joueurs dont au moins 10 capables de première ligne ; aucune ventilation « six piliers et quatre talonneurs » n'est inventée. Sections 3.2–3.3 : feuille de 19 à 23, au moins six premières lignes permettant un premier remplacement dans chacun des trois postes.

Le module exige exactement `season: '2026/27'` et `competitionId: 'champions'` ou `'challenge'`. Toute autre saison ou compétition renvoie un diagnostic invalide. Les années futures ne sont pas supposées reprendre ce règlement.

## Contrat

```js
const E = require('../native/engine/epcr-eligibility.cjs');
const options = {season: '2026/27', competitionId: 'champions'};
const player = {id: 'opaque-player-id', frontRow: ['LH']};
E.profile(options);
E.registration(registeredPlayers, options);
E.teamSheet(starters, reserves, registeredPlayers, options);
```

Chaque joueur est `{id: string non vide, frontRow: array | null}`. `frontRow` contient exclusivement `LH` (pilier gauche), `HK` (talonneur), `TH` (pilier droit), sans doublons. `[]` signifie que le joueur est attesté non qualifié en première ligne ; `null` ou l'absence de champ signifie que l'information n'est pas connue. Une famille de poste, le poste principal, le nom, la nationalité ou une statistique du jeu ne constituent pas seuls une preuve de qualification réglementaire. Les qualifications polyvalentes doivent être étayées.

La liste passée à `teamSheet` est la **liste proposée complète**, dont l'unicité, la taille et les dix premières lignes sont également diagnostiquées. Elle fait autorité sur les qualifications. Un rôle supplémentaire déclaré seulement sur la feuille produit `sheet-qualification-mismatch`. La feuille ne peut transformer une qualification inconnue sur la liste en qualification certaine.

`starters` est le XV ordonné de 1 à 15. Les trois premiers joueurs doivent couvrir respectivement LH, HK, TH. Au moins trois **remplaçants distincts** doivent pouvoir couvrir LH, HK, TH au premier remplacement. Le solveur de couverture examine les permutations de joueurs polyvalents : un joueur qualifié aux trois postes ne compte pas comme trois remplaçants. Le total doit être 19–23 et inclure au moins six joueurs qualifiés en première ligne.

`profile` renvoie `covered`, `violations`, les bornes numériques, `source`, `sections` et `sourceScope: 'official-summary'`. Les deux diagnostics renvoient :

```js
{
  valid: false,
  status: 'unknown', // 'valid', 'invalid' ou 'unknown'
  violations: [],   // refus certains : {code, playerIds: []}
  unknowns: [{code: 'registration-front-row', playerIds: ['opaque-id']}],
  counts: {players: 42, frontRow: 9, unknownFrontRow: 1}
}
```

Une violation certaine impose `status: 'invalid'`. À défaut de violation, une preuve manquante nécessaire impose `status: 'unknown'` et `valid: false`. Le module ne rend pas toute la liste incertaine si dix spécialistes sont déjà attestés et que l'information manquante concerne un joueur inutile à cette preuve. `teamSheet.counts` ajoute `starters` et `reserves` et compte les qualifications de la liste pour les joueurs sélectionnés.

`factory()` expose les mêmes méthodes ; sa source peut être injectée dans la VM native sans `require`, dépendance globale, RNG ou I/O. Les entrées sont toujours conservées et les résultats ne partagent pas les tableaux d'entrée.

## Limites d'intégration

Aucun contrôle ici de la première inscription du 8 octobre 2026, des cinq remplacements d'inscrits pendant les poules, du contrat de trois mois, de l'apparition avec un autre club, du mercredi midi GMT, de la seconde inscription du 25 mars 2027 ou des annonces de feuille. Ces obligations figurent dans les sections 3.1, 3.4–3.5 et 7.1 des sources. Elles requièrent un registre daté, des preuves contractuelles et un historique persistant. Ne pas présenter ce diagnostic comme une conformité EPCR complète.

Les dix inscrits et les six de la feuille sont des nombres de **joueurs**, pas de qualifications cumulées. La procédure de mêlée non disputée et ses conséquences d'effectif relève du moteur de match et n'est pas appliquée par ce diagnostic.

Ne pas transformer l'effectif courant d'une ancienne sauvegarde en « liste officiellement inscrite ». L'absence de registre d'inscription appelle un état consultatif explicite. Aucun blocage du coup d'envoi ou changement de format de sauvegarde n'est apporté par ce lot.

## Vérification

`node --test tests/epcr-eligibility.cjs` couvre les deux tournois, saisons non couvertes, listes 41/42/43 et seuil 9/10, feuilles 18/19/23/24, vrais postes du XV, six premières lignes et trois remplaçants distincts, polyvalence, qualifications inconnues, doublons, faux rôle ajouté à la feuille, joueur non inscrit, entrées malformées, non-mutation d'entrées gelées et factory exécutée en VM indépendante. Reçu sous Node 22.23.4 : huit tests réussis. Aucun test Windows ou de sauvegarde n'est revendiqué pour ce module sans état.
