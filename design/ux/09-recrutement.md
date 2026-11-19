# Fiche UX 09 — Recrutement et contrats

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque ; Budget de transferts distinct de la trésorerie.

> **Template**: UX Spec
> **Statut** : proposé (ux-designer CCGS, 19/11/2026, mode autonome, rigueur `minimal`)
> **Écran** : `Recrutement` (routes Recrutement + négociation de contrat en fenêtre) · carrière Monde · souris + clavier
> **Phases du parcours** : semaine type (un poste à combler), fin de saison (file de contrats, fenêtre de transferts)
> **Palier d'accessibilité** : Standard
> **Liés** : fiche 07 (vue « Contrats »), fiche 08 (onglet Contrat), `design/ux/interaction-patterns.md` (E2, E3, F8, W1, W3)

## 1. But

- **Joueur** : combler le poste qui manque dans le groupe, avec l'argent dont il dispose : repérer des pistes, les observer, comparer deux profils, ouvrir une négociation.
- **Jeu** : transformer un besoin du club (relève insuffisante, fins de contrat) en décision de recrutement et en dépense maîtrisée.
- **Dans les 5 secondes** : (1) **quel poste manque** (priorité 1), (2) **combien je peux dépenser**, (3) **la prochaine action** : observer ou approcher.

## 2. Contexte d'arrivée

| Question | Réponse |
|---|---|
| Venu de | Alerte Bureau (« contrats », « poste à pourvoir »), fiche joueur (Proposer une prolongation → négociation), rail, Gabi |
| État d'esprit | Ambitieux mais prudent (argent, risque) |
| Charge cognitive | Moyenne à haute : liste longue, informations manquantes (niveau inconnu) |
| Veut | Trouver un renfort crédible, savoir s'il peut se le payer |
| Craint | Payer trop cher un joueur mal connu ; rater la fenêtre |

**Cible émotionnelle** : « Je prends une décision avertie, pas un pari. »

## 3. Navigation

```
Carrière Monde
  └── Recrutement                         ← cet écran
        ├── Onglets : Besoins du club (défaut) · Recherche · Joueurs suivis · Rapports · Offres reçues (n)
        ├── Comparaison (2 pistes)        ← plein écran
        ├── Mission du recruteur          ← fenêtre
        └── Négociation                   ← fenêtre, depuis « Approcher » ou une prolongation
```

- **Modalité** : écran plein ; comparaison et missions en fenêtre (W3, une seule fenêtre à la fois).
- **Entrées** : rail ; alerte Bureau (arrive filtré sur le poste en besoin) ; fiche joueur (négociation seule, pas cet écran) ; accès rapide.
- **Sorties** : fiche joueur de la piste (Entrée) ; Effectif vue « Contrats » (bandeau « n fins de contrat cette saison ») ; Finances (lien sur le montant disponible).
- **Échap** : ferme la fenêtre ouverte, sinon revient d'une piste ou d'un sous-écran, sinon ouvre le menu pause (règle unique de Léo, 19/11/2026) ; jamais de pause tant qu'une piste ou une fenêtre est ouverte.

## 4. Hiérarchie

1. **Principal** : le besoin sélectionné et ses pistes (liste de joueurs pour ce poste).
2. **Secondaires** : (a) le montant disponible ; (b) la piste choisie (panneau de droite) avec **une seule action principale** ; (c) les trois besoins du club (priorités 1-3).
3. **Reste** : missions, rapports, comparaison, relève, marché entre clubs (filtres de source).

## 5. Wireframe 1280×720

```
┌────┬──────────────────────────────────────────────────────────────────────────────────────┐
│    │ Recrutement · Le prochain renfort.             Budget de transferts 1,8 M€ / 3,5 M€      │
│ Nav│ BESOINS DU CLUB :                                                                      │
│124 │ ┌P1 Talonneur ────────┐┌P2 Deuxième ligne ─┐┌P3 Troisième ligne ─┐   [Lancer une mission]│
│ px │ │relève insuffisante  ││10 fins de contrat ││10 fins de contrat  │   [Comparer 0/2]     │
│    │ │9 pistes · 0 suivie  ││cette saison       ││cette saison        │                      │
│    │ └─────────────────────┘└───────────────────┘└────────────────────┘                      │
│    │ [Besoins du club][Recherche][Joueurs suivis 0][Rapports 0]   Source: (Marché joueurs)(Entre clubs)(Relève)│
│    │ [Recherche….] [Poste: Talonneur ▾] [Âge ▾] [Offre ▾] [Prime ▾] [Réinitialiser]       │
│    │ ┌ ☆ Joueur              Poste    Âge Niv Pot  Prime     Salaire/s  Observation ┐ ┌Piste┐│
│    │ │ ☆ Rémi GARNIER        Pilier d. 18  ?  ?   1 000 €   300 €     Non observé   │ │photo││
│    │ │ ☆ Tom CHEVALLIER      Pilier d. 26  ?  ?   1 000 €   300 €     Non observé   │ │NOM  ││
│    │ │ ☆ Louis LEFÈVRE …                                    (défile)               │ │Niv ?││
│    │ └─────────────────────────────────────────────────────────────────────────────┘ │Pot ?││
│    │ 27 / 27 pistes · tri : Observation puis niveau ↓                                │ │Prime ││
│    │                                                                                 │ │Salaire│
│    │                                                                                 │ │[Observer]│
├────┴──┬──────────────────────────────────────────────────────────────────────────────┴─────┤
│ pied  │ Échap Retour · 1-9 Menus · Ctrl K Chercher · F1 Aide                                  │
└───────┴──────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contenu | Taille | Défile ? | Débordement |
|---|---|---|---|---|
| Titre + disponible | nom d'écran, montant, lien Finances | 100 % × 10 % | Non | Montant jamais tronqué |
| Besoins | 3 cartes cliquables (filtre) | 100 % × 13 % | Non | 2 cartes visibles + « + 1 » à 130 % |
| Onglets + filtres | onglets, source, recherche, listes | 100 % × 14 % | Non | Filtres rares sous « Réinitialiser · Plus » |
| Liste des pistes | tableau (socle) | 62 % × 55 % | Vertical | colonnes par priorité |
| Panneau piste | identité, contrat, action | 33 % × 55 % | Vertical (sections repliables) | rapport détaillé replié |
| Pied | raccourcis | 100 % × 5 % | Non | — |

Les trois cartes « Besoins » passent **du bas de l'écran vers le haut** : le joueur choisit d'abord son besoin, puis voit les pistes qui y répondent.

**Focus à l'ouverture** : première carte de besoin (priorité 1) ; arrivée depuis alerte : la première piste du poste alerté.

## 6. Blocs et données

### 6.1 Montant disponible

« Disponible pour les transferts » : montant restant de l'enveloppe de transferts fixée par le conseil (`finance.transferBudget.disponible`, à l'euro, jamais tronqué), avec « sur X € alloués par le conseil » (`enveloppe`) et « Dépensé X € · reconstitué Y € ». Infobulle : enveloppe de la saison, trésorerie du club, dépensé en indemnités et primes, reconstitué par les ventes, rappel que les salaires n'y entrent pas. Clic = Finances (Synthèse). Règle : [docs/gdd/budget-transferts.md](../../docs/gdd/budget-transferts.md).
Implémentation (19/11/2026) : bandeau sous les trois repères du haut, entre la photo et la priorité du poste ; la tuile « Trésorerie du club » reste (la trésorerie n'est pas le plafond de dépense, mais elle reste utile). Si `transferBudget` est absent ou `actif` faux (carrière sans budget de saison), pas de bandeau : la tuile « Trésorerie du club » reste la seule référence.
Report et rallonge (19/11/2026) : « sur X € alloués » compte l'enveloppe fixée + le report + les rallonges accordées. Infobulle : ligne « Report de la saison passée : X € » (si > 0) et « Rallonges accordées par le conseil : X € (n sur m possibles) » ; la ligne « Dépensé · reconstitué » ajoute « rallonge » et « report » seulement si elle tient dans le bandeau (50 caractères). Source : `ui/transfer_budget.gd`.

### 6.1 bis Bandeau « fins de contrat »

Ligne sous les cartes de besoin, visible seulement si n > 0 : « n fins de contrat cette saison · Voir dans l'effectif → » (ouvre Effectif, vue « Contrats »). Source : moteur (contrats), rafraîchie à chaque jour ; absent si n = 0. Elle porte, ici, la file de fin de saison du parcours (journey §3.4) sans dupliquer la liste.

### 6.2 Besoins du club (3 cartes)

| Champ | Contenu |
|---|---|
| Priorité | « Priorité 1 · urgent », « Priorité 2 », « Priorité 3 » (mot + chiffre ; remplace « Veille 1/2/3 » et les 3 couleurs rouge/ambre/vert) |
| Poste | Talonneur, Deuxième ligne, Troisième ligne… |
| Raison | texte court : « relève insuffisante », « 10 fins de contrat cette saison » (pluriel correct, jamais « fin(s) ») |
| Pistes | « 9 pistes · 0 suivie » |
| Clic | filtre la liste sur ce poste |

### 6.3 Liste des pistes (tableau socle, voir E3)

| Colonne | Contenu | Priorité | Tri au clic |
|---|---|---|---|
| ☆ | suivre / ne plus suivre (étoile pleine/vide + mot dans l'infobulle) | 1 | suivies d'abord |
| Joueur | photo, Prénom NOM, club d'origine en 2e ligne | 1 | alphabétique |
| Poste | poste principal | 1 | ordre rugby 1→15 |
| Âge | années | 2 | croissant |
| Niv. | niveau observé ; « ? » si non observé | 1 | décroissant (inconnu en bas) |
| Pot. | fourchette observée ; « ? » | 2 | décroissant |
| Prime | prime d'acquisition (€) | 1 | croissant |
| Salaire /sem. | salaire demandé (€) | 2 | croissant |
| Observation | mot : Non observé · Observation en cours (jusqu'au jj/mm) · Rapport du jj/mm | 1 | observés d'abord |

**Tri par défaut** : Observation (rapports d'abord), puis niveau décroissant, puis prime croissante. Aujourd'hui la liste est triée par poste ascendant, avec « Niveau » et « Potentiel » à « — » sur 27 lignes sur 27 : le tri n'aide pas.
Le bouton « À observer » répété sur chaque ligne est **retiré** (l'action est dans le panneau et sur sélection multiple).

### 6.4 Panneau de la piste choisie

Dans l'ordre : photo, Prénom NOM, poste, âge, club ; niveau et potentiel (« Non observé » si absent) ; Suivre ; **action principale** :
- non observé : « **Observer** » (principal) ; « Approcher » grisé avec la raison (« Observe d'abord ce joueur pour connaître son niveau ») ;
- observé : « **Approcher le joueur** » (principal), « Observer à nouveau » (secondaire) ;
- marché fermé : les deux grisées avec la date de réouverture.
Puis : synthèse du contrat (prime, salaire demandé, durée proposée : « 1 à 3 ans »), comparaison au même poste (niveau de la piste, moyenne de l'effectif, potentiel observé), et « Voir le rapport » (faits relevés, vigilance, observation) replié.

### 6.5 Onglets

| Onglet | Contenu | Vide |
|---|---|---|
| Besoins du club (défaut) | cartes + liste filtrée | « Aucun besoin urgent. Ton groupe est équilibré. » + « Lancer une recherche » |
| Recherche | tous les joueurs du marché avec critères libres | « Aucun joueur ne correspond. » + « Réinitialiser les critères » |
| Joueurs suivis (n) | pistes étoilées | « Tu ne suis personne. Étoile une piste pour la retrouver ici. » + « Voir les besoins » |
| Rapports (n) | rapports datés, filtre par poste | « Aucun rapport. Lance une mission pour en recevoir en n jours. » + « Lancer une mission » |

| Offres reçues (n) | GDD `docs/gdd/vente-joueurs.md`. Haut : « Sur le marché : n joueurs » (liste courte, « Retirer » par ligne). Puis une carte par offre : Prénom NOM, poste, âge · **{Club acheteur}** ({championnat}) · **{montant}** (valeur estimée {valeur}) · « Valable jusqu'à la fin de la semaine prochaine » / « Dernière semaine » · « Revient au budget de transferts : {50 %} » (si #1001). Actions : **Accepter la vente** (fenêtre de confirmation, focus sur Annuler), **Demander plus** (+5 / +10 / +15 %, une fois ; ensuite « Offre déjà relevée »), **Refuser**. Garde : « Accepter » grisé + raison (« Tu dois garder au moins 37 joueurs professionnels », « Il te faut deux joueurs à ce poste ») | « Aucune offre pour l'instant. Propose un joueur aux autres clubs depuis l'Effectif ou sa fiche ; les offres arrivent à la fin de chaque semaine. » + « Ouvrir l'Effectif » |

**Confirmation de vente** (fenêtre W1) : « Vendre {Prénom NOM} à {Club} pour {montant} ? » · lignes : « Caisse : +{montant} » · « Budget de transferts : +{retour} » (si #1001) · « Effectif après vente : {n} joueurs » · « Tu garderas {k} JIFF » (si le joueur est JIFF) · « S'il est dans ta feuille, il en sera retiré. » Boutons : **Vendre** / Annuler (focus). Réponses écrites après action : « {Nom} rejoint {Club} pour {montant}. » · « {Club} relève son offre à {montant}. La vente reste à confirmer. » · « {Club} retire son offre après ta demande de {montant}. » · « Offre refusée. »

Les deux compteurs « 0 profils suivis » / « 0 rapports conservés » du bandeau actuel passent dans les libellés d'onglet.

### 6.6 Négociation (fenêtre)

Champs : prime, salaire/sem., durée (1 à 3 ans), clauses disponibles ; sous le formulaire, **récapitulatif de l'engagement** : coût total sur la durée, part du budget restant, effet sur la masse salariale. Bouton principal nommé par l'action : « **Envoyer l'offre** » ; secondaire « Annuler » avec le **focus par défaut sur Annuler** (engagement d'argent : incohérence 4 du relevé). Réponse : accepté, contre-proposition, refus + raison + « Ce que tu peux changer ».
**Rallonge du conseil** (joueur libre, `contract_negotiation.gd`) : quand l'enveloppe bloque l'offre mais que la caisse la permettrait, le refus est suivi du bouton « **Demander X € au conseil** » (X = offre − reste, arrondi au millier supérieur). Pas de bouton si c'est la caisse qui limite. Clic = confirmation « Rallonge du budget de transferts » : libellé du bouton = action (« DEMANDER X € AU CONSEIL »), **focus par défaut sur Annuler** ; le texte annonce que le président répond tout de suite, l'effet sur la confiance (−3 points si accordée, −1 si refusée) et les rallonges déjà accordées (n sur m). La réponse du conseil s'affiche dans la négociation rouverte (accordée : l'offre devient possible). Même bouton dans le marché entre clubs (`interclub_market_view.gd`) quand l'indemnité saisie dépasse le disponible.

### 6.7 Sources et événements

| Donnée | Source | Rafraîchie | Absence |
|---|---|---|---|
| Pistes, prime, salaire demandé | marché (moteur) | à chaque jour | ligne masquée si identité manquante |
| Niveau, potentiel observés | rapports de recrutement | à la fin d'une mission | « ? » |
| Disponible pour les transferts | `finance.transferBudget` (disponible, enveloppe) | à chaque jour ou dépense | « — » + « Voir Finances » si absent ou inactif |
| Besoins du club | analyse de l'effectif | à chaque jour, après contrat | « Aucun besoin urgent » |

| Action | Événement | Payload |
|---|---|---|
| Observer / Mission | `ScoutMissionRequested` | `{playerId ou criteria}` |
| Suivre | `ProspectFollowToggled` | `{playerId}` |
| Envoyer l'offre | `OfferSubmitted` | `{playerId, premium, wage, years}` |
| Comparer | `CompareToggled` | `{playerId}` |
| Accepter / Demander plus / Refuser une offre | commande `sale_answer` | `{offerId, action: accept\|counter\|decline, percent?, confirmed?}` |

## 7. Actions et raccourcis

| Action | Souris | Clavier | Réponse |
|---|---|---|---|
| Choisir un besoin | clic carte | Tab, Entrée | filtre, compteur « n / N pistes » |
| Choisir une piste | clic ligne | ↑ ↓, Pg↑/↓, Début/Fin | panneau mis à jour |
| Ouvrir la fiche | double-clic | Entrée | fiche 08 (origine = Recrutement) |
| Suivre | clic étoile | Espace sur la ligne | étoile pleine + « Suivi » en texte |
| Observer / Approcher | bouton | Tab, Entrée | mission / négociation |
| Trier | clic en-tête | en-tête focalisé, ← →, Entrée | comme E3 + tri au clavier |
| Comparer | case/bouton | Maj+Espace (max 2), puis Entrée sur « Comparer 2/2 » | écran de comparaison |
| Changer d'onglet | clic | Ctrl+Tab, ← → | motif d'onglets unique |
| Changer de source | pastilles | Tab, Entrée | remplace la liste |

## 8. États

| État | Déclencheur | Rendu | Comportement |
|---|---|---|---|
| Première fois | aucune mission, rien suivi | carte priorité 1 mise en avant, phrase de Gabi : « Commence par observer 3 talonneurs. » | disparaît après la 1re mission |
| Chargement | actualisation du marché, mission en cours | squelette de lignes ; « Observation en cours · reste n jours » dans la colonne | tri reste utilisable |
| Vide | filtre sans résultat | message + « Réinitialiser » | focus sur le bouton |
| Marché fermé | hors fenêtre | bandeau : « Le marché est fermé jusqu'au jj/mm. Tu peux observer et suivre. » ; Approcher grisé | Observer reste actif |
| Budget insuffisant | prime à la signature (joueur libre) ou indemnité (accord entre clubs) > `transferBudget.disponible` ; le salaire n'entre pas dans le budget (jugé par la masse salariale) | le moteur rend le devis indisponible (`available:false`) avec la raison (« Hors budget de transferts : il reste X € sur l'enveloppe de Y € fixée par le conseil. ») ; raison écrite visible dans la fiche (Vigilance), la négociation et la carte du marché entre clubs, pas seulement en infobulle | bouton d'envoi grisé ; le moteur revérifie à la signature. Marché entre clubs : indemnité saisie au-delà du disponible → « Soumettre les conditions » grisé avec la raison sous les champs. Si la caisse le permet : bouton « Demander X € au conseil » sous la raison (confirmation, focus sur Annuler, effet sur la confiance) ; sinon la raison dit que la caisse limite et aucun bouton n'apparaît |
| Piste déjà prise / retirée | autre club signe | ligne « Plus disponible » barrée + icône ; sélection suivante | message au pied, conservé jusqu'à l'action suivante (aucune disparition automatique, M6) |
| Offre refusée | réponse | fenêtre : raison + options (revoir salaire, durée) | aucun silence : G3 |
| Erreur de marché | données illisibles | bandeau + Réessayer | liste vide, pas de crash |
| Moteur occupé | Continuer | boutons d'action grisés + raison | lecture libre |

## 9. Accessibilité (T1, T5, C1, C3, D6, K1, K2, K6)

- Tableau 12-13 px ; lignes 24-26 px comme Football Manager (aujourd'hui ≈ 28 px, 14 lignes visibles à 1920 ; cible ≈ 22-24).
- Priorité des besoins, statut d'observation, « Marché fermé » : toujours en mots (la couleur rouge/ambre/vert des cartes actuelles est retirée comme seul porteur).
- Montants entiers, séparateur de milliers, devise toujours présente ; jamais de troncature d'un montant (T5).
- Étoile : état en texte (« Suivi ») pour lecteur et infobulle.
- Négociation : focus piégé dans la fenêtre, Échap annule, focus par défaut sur « Annuler » (engagement d'argent).
- Focus visible ≥ 2 px ; ordre : rail → montant → besoins → onglets → source → filtres → liste → panneau → pied.
- Tri et comparaison au clavier ; aucun glisser-déposer.
- Aucun délai : pas de limite de temps sur l'offre (K7), sauf date de fenêtre affichée.
- **Contraste** : texte ≥ 4,5:1 sur son fond réel, étoile, contours et focus ≥ 3:1 (C1, C3) ; jetons à valider avec la direction artistique.

## 10. Ce qu'on retire, déplace, garde

| Écran actuel | Décision |
|---|---|
| Illustration (photo de coach) + liens « Repérer la relève » / « Marché entre clubs » | Retirés ; remplacés par les pastilles de source |
| Tuiles « profils suivis », « rapports conservés » | Déplacées en compteurs d'onglets |
| Tuile « Poste à surveiller : Talonneur » | Fusionnée dans la carte Priorité 1 |
| Tuile « Trésorerie » | Remplacée par « Budget de transferts » (restant / alloué) |
| Cartes « Besoins de recrutement » en bas, « Veille 1/2/3 » | Montées en haut, « Priorité 1/2/3 » en mots |
| Bouton « À observer » sur chaque ligne | Retiré ; action dans le panneau |
| Panneau détail à 6 blocs | Réduit à 4 blocs + « Voir le rapport » replié |
| Bouton « Missions du recruteur » du panneau | Déplacé en bouton unique « Lancer une mission » en tête |
| Liste, tri, filtres, comparaison, négociation, recherche | **Gardés** |

## 11. Déviations des motifs

- **E3** : première extension du tableau socle à Recrutement (incohérence 3 du relevé), avec tri au clavier.
- **W1** : bouton nommé par l'action et focus sur Annuler pour tout engagement d'argent (déviation voulue, incohérence 4).
- **F8** : états vides avec action (motif manquant n°8).
- **E2** : pastilles de source au même format que les autres filtres.
- **N5** : Échap n'ouvre pas la pause tant qu'une fenêtre ou une piste est ouverte ; sinon menu pause (règle unique de Léo, 19/11/2026).

## 11 bis. Transitions, localisation, entrées

**Transitions** : ouverture/sortie instantanées (100 ms au plus en « Normales », 0 en « Aucune ») ; changement d'onglet, de source, de besoin : remplacement instantané ; fenêtre de négociation : apparition instantanée avec voile, focus piégé ; squelette de chargement 0,35 s (§8) ; « Mouvement réduit » : sans effet visible (M1, M2).

**Localisation** (+40 % prévu ; nom, poste, montant jamais tronqués) : titre ≤ 30 ; carte de besoin : poste ≤ 24, raison ≤ 40 ; onglet ≤ 20 + nombre ; en-tête de colonne ≤ 14 ; Prénom NOM ≤ 28, club ≤ 30 ; montant : 11 caractères avec devise (« 3 542 000 € ») ; bouton ≤ 24 (« Approcher le joueur ») ; message de vide ≤ 80.

**Entrées (souris + clavier ; manette hors périmètre)** : [x] besoin, piste, étoile, observer, approcher, comparer à la souris ; [x] les mêmes au clavier (§7) ; [x] ordre de focus (§9) ; [x] aucun glisser-déposer ; [x] aucune précision de souris requise.

## 12. Critères d'acceptation

- [ ] L'écran s'ouvre et le focus est placé en < 200 ms (hors chargement) ; le filtre par besoin répond en < 100 ms.
- [ ] Le bandeau « n fins de contrat » apparaît si n > 0 et ouvre Effectif › Contrats.
- [ ] À l'ouverture, on voit le poste prioritaire, le montant disponible et une action principale unique sans défiler (1280×720 / 130 %).
- [ ] Liste triée Observation > Niveau > Prime par défaut ; tri complet au clavier.
- [ ] Une piste non observée ne peut pas être « approchée » ; la raison est visible, pas seulement en infobulle.
- [ ] La négociation affiche le coût total et la part du budget avant envoi ; focus par défaut sur Annuler.
- [ ] Marché fermé : Approcher grisé avec la date de réouverture ; Observer et Suivre restent actifs.
- [ ] États vides : message + action, focus sur l'action.
- [ ] Aucun « fin(s) » ni jargon ; pluriel correct.
- [ ] Capture en niveaux de gris : priorités 1-2-3 distinguables.

## 13. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Existe-t-il un « budget de recrutement » distinct de la trésorerie ? | game-designer | **Résolu (19/11/2026)** : oui, enveloppe de transferts fixée par le conseil chaque saison, voir [docs/gdd/budget-transferts.md](../../docs/gdd/budget-transferts.md) ; source `finance.transferBudget` |
| La file de fins de contrat (journey §3.4) doit-elle vivre ici ou dans Effectif > Contrats ? | Léo / game-designer | Proposé : Effectif (vue Contrats) + bandeau ici |
| Missions : durée et coût visibles avant lancement ? | game-designer | À confirmer |
| Le comparateur à 2 exige-t-il que les deux pistes soient observées ? | game-designer | À confirmer |
| Échap sur Recrutement sans fenêtre ni piste ouverte : retour ou pause ? | Léo | **Résolue le 19/11/2026** : menu pause |
| Écran de comparaison (2 pistes) : aucune fiche ne le spécifie | ux-designer | À spécifier (fiche à créer) |

## 14. Dépendances

