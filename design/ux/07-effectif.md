# Fiche UX 07 — Effectif

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

**Mini-fiche au survol (validée, 19/11/2026)** : survoler le nom d'un joueur ou le « i » voisin montre la mini-fiche
(en-tête, forme, contrat, 36 attributs colorés) sans changer d'écran ; clic sur le nom = fiche complète ; au clavier,
focus sur le nom + I. La fiche fixe de droite est retirée : le tableau prend toute la largeur. Détail :
`mini-fiche-joueur.md`.

> **Template**: UX Spec
> **Statut** : proposé (ux-designer CCGS, 19/11/2026, mode autonome, rigueur `minimal`)
> **Écran** : `Effectif` (route « Effectif », chapitre Effectif/Vestiaire) · carrière Monde · PC souris + clavier
> **Phases du parcours** : première heure (premier tour du groupe), semaine type, fin de saison (contrats)
> **Palier d'accessibilité** : Standard (`design/accessibility-requirements.md`)
> **Liés** : `design/player-journey.md` §2 (07), `design/ux/interaction-patterns.md` (N1, N5, E2, E3, F3, F8), fiche 08 (fiche joueur), fiche 10 (composition)
> **Périmètre** : ce que voit et fait le joueur ; ni couleurs ni polices (direction artistique), ni code (ui-programmer)

## 1. But

- **Joueur** : savoir en un regard où en est son groupe (qui est apte, qui s'arrête, qui est en fin de contrat), retrouver un joueur et ouvrir sa fiche.
- **Jeu** : faire de l'effectif le point de départ des décisions de semaine (composition, contrats, soins) sans le transformer en tableur.
- **Dans les 5 secondes** : (1) combien de joueurs sont indisponibles, (2) qui est le joueur sélectionné et dans quel état, (3) où sont les fins de contrat de la saison.

## 2. Contexte d'arrivée

| Question | Réponse |
|---|---|
| Venu de | Barre latérale (touche 2 ou 3 selon le rang), alerte du Bureau (« blessé », « fin de contrat »), accès rapide, retour de fiche joueur |
| État d'esprit | Calme, appropriation ; parfois inquiet (blessés avant un match) |
| Charge cognitive | Moyenne : 40 lignes, un seul objectif à la fois |
| Veut | Trouver un joueur précis, ou vérifier la santé du groupe avant de composer |
| Craint | Rater un contrat qui expire, aligner un blessé ou un fatigué |

**Cible émotionnelle** : « Je connais mon groupe, rien ne m'échappe. »

## 3. Navigation

```
Carrière Monde
  └── Effectif                      ← cet écran (chapitre « Effectif / Vestiaire »)
        ├── Fiche joueur (08)       ← Entrée ou double-clic
        ├── Comparaison (2 joueurs) ← mode « Comparer »
        └── Vestiaire               ← onglet frère du chapitre
```

- **Modalité** : écran plein, non modal ; sélection et filtres sont de l'état d'interface (aucune commande moteur).
- **Entrées** : rail (Effectif), alerte Bureau (arrive avec le filtre correspondant), accès rapide (joueur : arrive en fiche, pas ici), retour de la fiche (garde ligne choisie, tri, filtre, position de défilement).
- **Sorties** : fiche joueur (Entrée) · Composition (via bandeau d'alerte « n joueurs indisponibles dans ton XV », voir §6) · Prolongation (bouton du panneau, ouvre la négociation) · autre menu du rail.
- **Échap** : ordre de priorité, une seule action par appui : (1) ferme une fenêtre ouverte ; (2) si la recherche a le focus, la vide, puis un 2e appui sort du champ ; (3) si un filtre est actif, le retire ; (4) sinon ouvre le menu pause (règle unique décidée par Léo le 19/11/2026, N5 ; le bouton « Menu » de la coque l'ouvre aussi). Un filtre ou une recherche actifs n'ouvrent donc jamais la pause : il faut d'abord les retirer (déviation, voir §11).

## 4. Hiérarchie

1. **Principal** : le tableau des joueurs (zone dominante, > 55 % de la largeur utile).
2. **Secondaires** : (a) les 4 compteurs cliquables qui servent de filtres rapides ; (b) le panneau du joueur choisi ; (c) la barre de filtres (recherche, pastilles, poste).
3. **Reste** : vues « Condition / Contrats / Développement », Comparer, Vestiaire, équilibre du groupe (en infobulle des compteurs).

## 5. Wireframe 1280×720 (canevas réel 2560×1440, texte 130 % par défaut)

```
┌────┬─────────────────────────────────────────────────────────────────────────────────────┐
│    │ Effectif · Les hommes du projet.        [Aptes 40/40][Blessés 0][Fins de contrat 6][Niv. 60]│
│ Nav│ [Vue d'ensemble][Condition][Contrats][Développement]        [Comparer 0/2] [Vestiaire]│
│124 │ ┌─Recherche──────┐ (Tous 40)(Avants)(Arrières)(Indisponibles)(Fin contrat)(À surveiller)│
│ px │ └────────────────┘ [Poste: Tous ▾] [Filtres & tri ⚙]                                   │
│    │ ┌ N° Joueur         Poste        Niv Pot  Condition   Fin ctr  Statut ┐ ┌─Joueur choisi┐│
│    │ │ AVANTS · 21 joueurs                                                  │ │ [photo]      ││
│    │ │●1 Kyle FAIRCLOUGH Pilier g.    66 68-72 ▬▬▬ 100%   2028    Titulaire│ │ NOM Prénom   ││
│    │ │●2 Blake OLLERENS. Talonneur    65 65-69 ▬▬▬ 100%   2027 ⏳ Titulaire │ │ Poste · âge  ││
│    │ │ 3 Sebastian ATH.. Pilier d.    62 66-70 ▬▬▬ 100%   2029    Titulaire│ │ Niv 59 Pot..││
│    │ │ …                                                                    │ │ Statut       ││
│    │ │ ARRIÈRES · 19 joueurs                                                │ │ Condition 100%││
│    │ │ …                                         (défile, en-tête figé)     │ │ Contrat 500 €││
│    │ └──────────────────────────────────────────────────────────────────────┘ │ [Ouvrir la   ││
│    │ 40/40 joueurs · tri : Poste · 1 sélectionné                              │ │  fiche →]    ││
│    │                                                                          │ │ [Prolonger]  ││
├────┴──┬──────────────────────────────────────────────────────────────────────┴─┴──────────────┤
│ pied  │ Sauvegarde auto · 19/09        Espace Suite · 1-9 Menus · Échap Retour · Ctrl K Chercher │
└───────┴─────────────────────────────────────────────────────────────────────────────────────┘
```

| Zone | Contenu | Taille (largeur utile × haut) | Défile ? | Débordement |
|---|---|---|---|---|
| Titre + compteurs | Nom d'écran, 4 compteurs-filtres | 100 % × 11 % | Non | Compteurs passent sur 2 lignes à 130 % |
| Vues + actions | Onglets de vue, Comparer, Vestiaire | 100 % × 6 % | Non | « Vestiaire » reste, « Comparer » passe en icône + mot court |
| Filtres | Recherche, pastilles, poste, « Filtres & tri » | 100 % × 11 % | Non | Pastilles rares (« À surveiller ») dans « Filtres & tri » |
| Tableau | En-tête figé + lignes virtuelles | 66 % × 58 % | Verticalement | Colonnes retirées par priorité (§6) |
| Panneau du joueur | Résumé + 2 actions | 30 % × 58 % | Non | Passe sous le tableau en bandeau d'une ligne sous 1100 px utiles |
| Pied | Statut sauvegarde + raccourcis | 100 % × 5 % | Non | Raccourcis regroupés sous « ? » (≥ 12 px réels) |

**Focus à l'ouverture** : la ligne choisie du tableau (ou la première ligne si rien n'est choisi) ; arrivée depuis une alerte : la première ligne du filtre appliqué.

## 6. Blocs et données

### 6.1 Compteurs-filtres (4)

| Compteur | Donnée | Clic = |
|---|---|---|
| Aptes | disponibles / total (ex. « 40 / 40 ») | filtre « Tous » |
| Blessés ou indisponibles | blessés + suspendus + en sélection (nombre), gravité maximale en infobulle | filtre « Indisponibles » |
| Fins de contrat | joueurs dont le contrat s'achève cette saison | filtre « Fin de contrat » |
| Niveau moyen | moyenne du XV de départ (pas du groupe entier) ; écart avec la saison passée en infobulle | aucun (information) |

Le compteur « 40 joueurs » de l'écran actuel est retiré (redondant avec « Tous, 40 » et le pied).

### 6.2 Tableau (vue « Vue d'ensemble », par défaut)

Colonnes dans l'ordre, priorité d'affichage (1 = retirée en dernier) :

| # | Colonne | Contenu exact | Priorité | Tri au clic (1er sens) | Aide (infobulle) |
|---|---|---|---|---|---|
| 1 | N° | numéro de feuille ; pastille pleine = titulaire, cerclée = remplaçant, vide = hors groupe | 1 | croissant | « Numéro sur la prochaine feuille » |
| 2 | Joueur | photo 24 px + Prénom NOM (jamais tronqué : T5) | 1 | alphabétique | — |
| 3 | Poste | poste principal en toutes lettres | 1 | ordre rugby 1→15 | « Autres postes : … » (remplace l'ancienne colonne « Autres » aux codes « 3E L-8 », jugés cryptiques) |
| 4 | Niv. | niveau /100, chiffre | 1 | décroissant | niveau actuel |
| 5 | Pot. | fourchette (ex. 62-66) ; « ? » si inconnue | 3 | décroissant (borne haute) | potentiel estimé |
| 6 | Condition | pourcentage + barre, repère visible à 80 % (seuil de feuille) | 1 | croissant (les moins aptes d'abord) | seuil et conséquence |
| 7 | Âge | années | 3 | croissant | — |
| 8 | Fin ctr | année ; icône + mot « fin de saison » si le contrat s'achève cette saison | 2 | croissant | date exacte, prolongation possible ou non |
| 9 | Statut | mot : Titulaire · Remplaçant · Hors groupe · Blessé (gravité) · Suspendu (n matchs) · En sélection (retour jj/mm) | 1 | par gravité (indispo en tête) | — |

À 1280 (130 %), restent par priorité : N°, Joueur, Poste, Niv., Condition, Statut, puis Fin ctr.

**Tri par défaut** : groupes **Avants (n° 1–8)** puis **Arrières (n° 9–15)** ; dans un groupe, **ordre rugby des postes** (pilier gauche 1, talonneur 2, pilier droit 3, deuxième ligne 4-5, troisième ligne aile 6-7, numéro 8, demi de mêlée 9, ouvreur 10, ailiers 11/14, centres 12/13, arrière 15), puis niveau décroissant, puis nom. (L'écran actuel trie par ordre alphabétique du libellé : « Pilier droit » avant « Pilier gauche » et « Talonneur », contre l'ordre de la feuille.) Un autre tri enlève les groupes (liste plate) et le dit dans le pied (« tri : Niveau ↓ »). Valeur inconnue : toujours en bas (E3).

**Retirés de la vue par défaut** (déplacés vers les vues) : Fatigue, Salaire/sem., Moy., Forme, Min. Colonnes « Moy. » et « Forme » vides (tirets) tant qu'aucun match n'est joué : masquées.

### 6.3 Vues

| Vue | Colonnes ajoutées / remplaçantes (ordre) | Tri par défaut |
|---|---|---|
| Condition | Joueur, Poste, Condition, Fatigue (valeur + « plus bas = mieux »), Charge prévue, Absence (type, gravité, retour), Minutes, Matchs | Condition croissant |
| Contrats | Joueur, Poste, Salaire/sem., Fin de contrat, Prolongation (Disponible / Refusée / Impossible), Marge, **Marché** (« — » · « En vente » · « Offre reçue » · « Départ prévu », mot ; infobulle = phrase d'état ; GDD `vente-joueurs.md`) | Fin de contrat croissant |
| Développement | Joueur, Âge, Niv., Pot. estimé, Marge, Minutes, Moy., Forme | Marge décroissant |

### 6.4 Panneau du joueur choisi

Contenu (dans l'ordre) : photo, Prénom NOM, poste, âge ; niveau + potentiel ; statut (mot) ; condition (% + barre) et fatigue (n/100) ; **3 points forts** (attribut + valeur, mêmes clés que la carte « Points forts » de la fiche 08 ; « — » si indisponible) ; contrat (salaire/sem., fin) ; **Ouvrir la fiche** (principal) ; **Prolonger** (visible seulement si la prolongation est possible) ; **Vente** dans le bloc contrat, en un seul bouton d'état : « **Proposer** » (« Proposer aux autres clubs » en infobulle) · « **Retirer** » (joueur proposé) · « **Voir l'offre** » (ouvre « Offres reçues ») · « **Départ prévu** » (accord conclu, grisé) ; grisé aussi pendant un match, avec la raison du blocage en infobulle (espoir de moins de 20 ans, recrue de moins de 3 journées, prêt) ; une ligne d'état sous le contrat dit « Proposé aux autres clubs · valeur estimée … », « Offre reçue : à traiter dans Offres reçues. » ou la vente en attente (« effectif au 1er mai ») ; Comparer. La vue « Contrats » porte en plus le bouton « Offres reçues · n » dans son encart « Marché des transferts » (résumé : joueurs proposés, offres, ventes en attente).
Retirés : bloc « Équilibre du groupe » (Avants 21 / Arrières 19 / U21 11 : en infobulle du compteur « Aptes ») et le doublon « Disponibilité » + « Contrat & statut » en trois cartes (fusionnés en un seul bloc).

### 6.5 Sources de données

| Donnée | Source | Rafraîchie | Valeur absente |
|---|---|---|---|
| Joueurs, postes, contrats, niveau, potentiel | état de carrière (moteur) | à chaque jour avancé, à chaque commande de contrat | « — » + infobulle « Non communiqué » |
| Condition, fatigue, absences | moteur (soins/charge) | à chaque jour | idem |
| Numéro et statut de feuille | feuille de match courante | à chaque validation de composition | « Hors groupe » |
| Tri, filtre, sélection, vue | état d'interface | à l'action | valeurs par défaut |

L'interface ne modifie aucune donnée : « Prolonger » et « Ouvrir la fiche » émettent seulement `ContractNegotiationRequested(playerId)` et `OpenPlayerSheet(playerId)`.

## 7. Actions et raccourcis

| Action | Souris | Clavier | Réponse |
|---|---|---|---|
| Choisir un joueur | clic ligne | ↑ ↓, Pg↑/↓, Début/Fin | panneau mis à jour ; ligne reste visible |
| Ouvrir la fiche | double-clic, bouton | Entrée | écran 08 ; retour garde la place |
| Trier | clic en-tête (2e clic = inverser) | **Tab** vers l'en-tête, ← → entre colonnes, Entrée/Espace trie, Entrée à nouveau inverse ; ou « Filtres & tri » (liste + sens) | flèche + « tri : … » dans le pied |
| Filtrer | pastilles, compteurs, poste | Tab, Entrée ; **/** = recherche locale (écran au focus, hors champ). Ctrl K / Ctrl F restent l'accès rapide global (N4) : pas de détournement | compteur « n / 40 » |
| Effacer filtres | bouton dans le vide de résultat, pastille active re-cliquée | Échap quand le focus est dans la recherche (efface), 2e Échap sort | retour à « Tous » |
| Comparer | bouton, bouton de ligne | Maj+Espace sur une ligne (ajoute/retire, max 2) ; Entrée sur « Comparer (2/2) » | écran de comparaison |
| Changer de vue | onglets | Ctrl+Tab / Ctrl+Maj+Tab (cycle), flèches ← → sur la rangée d'onglets | colonnes remplacées, tri de la vue appliqué |
| Prolonger | bouton | Tab, Entrée | négociation (fenêtre) |
| Mettre en vente / retirer | bouton « Proposer » / « Retirer » du panneau | Tab, Entrée | commande `sale_list` ; colonne « Marché » (« En vente ») et message du moteur dans la fenêtre « Offres reçues » ou en retour de commande ; si une offre existe, le bouton devient « Voir l'offre » et ouvre « Offres reçues » (fiche 09 §6.5) |
| Clic droit sur une ligne | menu : Ouvrir la fiche · Comparer · Prolonger · Proposer aux autres clubs | touche Menu / Maj+F10 | motif « menu rapide » (manquant n°4) |

Aucun raccourci à une lettre pendant la saisie (K5). Le focus d'un tableau et celui d'une ligne sont distingués (K2) : voir §9.

## 8. États

| État | Déclencheur | Rendu | Comportement |
|---|---|---|---|
| Normal | ouverture | voir §5 | — |
| Première fois (première semaine) | carrière neuve, aucun filtre utilisé | liseré discret sur « Fins de contrat » et mot de Gabi dans le pied (« Regarde qui finit son contrat cette saison ») ; pas de fenêtre | disparaît après un clic |
| Chargement | retour d'une commande longue / passage de jour | lignes en gris (squelette), compteurs « … » ; 0,35 s avant d'apparaître | tableau en lecture seule |
| Vide (filtre) | aucun joueur ne correspond | « Aucun joueur ne correspond à ce filtre. » + bouton **Effacer les filtres** ; compteur « 0 / 40 » | focus sur le bouton |
| Vide (« À surveiller ») | personne à surveiller | « Personne à surveiller cette semaine. » + lien « Voir tout l'effectif » | — |
| Joueur indisponible | blessure, suspension, sélection | statut en mots + icône ; ligne reste active | bandeau d'alerte si le joueur est dans le XV (« Tu as 1 titulaire indisponible : ouvrir la composition ») |
| Aucun joueur choisi | première ouverture sans sélection | panneau : « Choisis un joueur pour le voir ici » | focus sur la 1re ligne |
| Donnée manquante | potentiel inconnu, photo absente | « — » ou silhouette neutre ; jamais de ligne vide | infobulle « Non communiqué » |
| Erreur de lecture | état de carrière illisible | bandeau d'erreur en tête (« Les données du groupe n'ont pas pu être lues. Reviens au Bureau puis rouvre l'effectif. ») + Réessayer | tableau vide, pas de crash |
| Moteur occupé (`app.waiting`) | Continuer | actions de contrat et de vente désactivées avec la raison en infobulle | lecture et tri restent libres |
| Vente bloquée | espoir < 20 ans, recrue < 3 journées, prêt, match en cours | bouton de vente grisé ; raison écrite en clair en infobulle et sur la ligne d'état | lecture libre |
| Vente en attente | accord conclu hors période des mutations | bouton « Départ prévu » grisé ; colonne Marché « Départ prévu » ; le joueur reste dans l'effectif et joue jusqu'au 1er mai | exécutée à l'ouverture (courrier « vente exécutée ») ou annulée avec la raison |

## 9. Accessibilité (T1, C1, C3, D1, D3, D6, K1, K2, K6, K8, E1)

- **Texte** : lignes de tableau 12-13 px à 1920 (T1), en-têtes de colonne en capitales 11-12 px, jamais sous 11 px ; pied et raccourcis lisibles (C1, ratio ≥ 4,5:1).
- **Hauteur de ligne** 24-26 px à 1920, comme Football Manager (décision de Léo, 19/11/2026 ; K6 : cible ≥ 24 px) ; aujourd'hui ≈ 28 px : ≈ 22-24 lignes visibles au lieu de 21, groupes repliables conservés (Entrée sur le titre de groupe).
- **Couleur non seule** : statut en mot ; blessure = icône + gravité en texte (D3) ; fin de contrat = icône + mot ; condition = chiffre + barre + repère à 80 % (D6) ; chips « Titulaire / Hors groupe » aujourd'hui verts identiques : différencier par forme (pleine / cerclée / sans chip) et mot.
- **Focus** : liseré ≥ 2 px, distinct du survol et de la sélection. La ligne choisie et le tableau focalisé ont chacun un signe visible (le filet doré actuel sous l'en-tête ne suffit pas, K2).
- **Ordre de focus** : rail → onglets de vue → compteurs → recherche → pastilles → poste → Filtres & tri → tableau (en-tête puis lignes) → panneau (Ouvrir, Prolonger, Comparer) → pied.
- **Alternative au clic** : tri complet au clavier (en-tête), comparaison au clavier, aucun glisser-déposer sur cet écran.
- **Infobulles** : toutes accessibles au clavier (focus déclenche le nom accessible), pas d'info critique uniquement en survol.
- **Mouvement** : défilement et barres sans animation ; « Mouvement réduit » sans effet visible ici.
- **À 130 %** : aucune troncature de nom, poste ni montant (T5).
- **Contraste** : texte ≥ 4,5:1 sur son fond réel (ligne choisie et survol compris), contours de barre, focus et icônes porteuses de sens ≥ 3:1 (C1, C3) ; jetons de couleur à valider avec la direction artistique.

## 10. Ce qu'on retire, déplace, garde

| Écran actuel | Décision |
|---|---|
| Compteur « 40 joueurs » | Retiré (redondant) |
| Compteur « 0 blessé » | Remplacé par « Blessés ou indisponibles », cliquable |
| 3 listes déroulantes Poste / Groupe / Contrat + pastilles Avants/Arrières/Fin de contrat | Groupe et Contrat retirés des listes (déjà pastilles) ; Poste conservé ; autres critères sous « Filtres & tri » |
| Colonnes Autres, Fat., Salaire, Moy., Forme, Min. | Déplacées vers vues (Condition / Contrats / Développement) ; « Autres » vers infobulle du poste |
| Chips de statut tous verts | Mot + forme, « Hors groupe » en texte simple |
| Bloc « Équilibre du groupe » du panneau | Déplacé en infobulle du compteur « Aptes » |
| Boutons Vestiaire + Comparer dans le même rang que les vues | « Vestiaire » unique, en onglet du chapitre, identique à 1280 et 1920 (aujourd'hui bouton à 1920, onglet à 1280) |
| Mise en page 1280 (liste verte étroite, panneau d'aperçu en 4 onglets) | Remplacée par le même écran à colonnes réduites : une seule disposition à toutes les tailles |
| Tableau + « Filtres & tri » | **Gardés** (socle de tableau, tri, recherche insensible aux accents) |

## 11. Déviations des motifs

- **E3** : ajoute le tri au clavier et l'ordre de poste rugby, déviation voulue (motif manquant n°9).
- **N5** : Échap n'ouvre pas la pause quand un filtre ou la recherche est actif (incohérence 1 du relevé) ; sinon règle unique de Léo (19/11/2026) : menu pause.
- **E2** : pastille de filtre au format « Tous 40 » (sans virgule) comme en Réception ; actif = repère de forme (cadre épais) en plus de la teinte.

## 11 bis. Transitions, localisation, entrées

**Transitions** : ouverture et sortie de l'écran sans fondu obligatoire (instantané ; 100 ms au plus en « Transitions : Normales », 0 en « Aucune ») ; changement de vue, tri, filtre et panneau du joueur : mise à jour instantanée, sans animation (M1, M2) ; squelette de chargement : voir §8 (0,35 s avant affichage).

**Localisation** (français ; prévoir +40 % pour d'autres langues, colonnes élastiques, jamais de troncature d'un nom, d'un poste ou d'un montant) : titre d'écran ≤ 30 caractères ; libellé de compteur ≤ 22 ; pastille de filtre ≤ 18 + nombre ; en-tête de colonne ≤ 12 ; Prénom NOM ≤ 28 sur une ligne ; statut ≤ 34 (« Blessé (grave) · retour 12/10 ») ; message de vide ≤ 70.

**Entrées (souris + clavier ; manette hors périmètre)** : [x] choisir, ouvrir, trier, filtrer, comparer, prolonger à la souris ; [x] les mêmes au clavier (§7) ; [x] ordre de focus défini (§9) ; [x] aucune action par glisser-déposer ; [x] aucune précision de souris requise.

## 12. Critères d'acceptation (binaires)

- [ ] Ouvert, le focus est sur une ligne du tableau, visible, en < 200 ms (hors chargement).
- [ ] Hauteur de ligne 24-26 px à 1920 (≈ 22-24 lignes visibles) et texte de ligne 12-13 px.
- [ ] Le panneau du joueur affiche 3 points forts ; « / » ouvre la recherche locale sans toucher l'accès rapide (Ctrl K).
- [ ] Le tableau se trie, s'inverse et se filtre sans souris ; la comparaison de 2 joueurs aussi.
- [ ] Tri par défaut : groupes Avants puis Arrières, postes dans l'ordre rugby 1→15 (test sur « pilier gauche avant talonneur avant pilier droit »).
- [ ] À 1280×720 et 130 % : aucune troncature de nom, poste, montant ; colonnes retirées dans l'ordre de priorité.
- [ ] Capture en niveaux de gris : Titulaire, Remplaçant, Hors groupe, Blessé, Suspendu restent distinguables par le mot.
- [ ] Filtre sans résultat : message + bouton « Effacer les filtres » focalisé.
- [ ] Retour depuis une fiche : même ligne, même tri, même défilement.
- [ ] Aucune écriture directe dans l'état de carrière depuis cet écran.
- [ ] Vente : le bouton du panneau suit l'état (« Proposer », « Retirer », « Voir l'offre », « Départ prévu ») ; la colonne « Marché » de la vue « Contrats » affiche « En vente », « Offre reçue » ou « Départ prévu » ; un joueur bloqué a le bouton grisé et sa raison écrite.

## 13. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Échap sur écran racine : pause ou rien ? | Léo / game-designer | **Résolue le 19/11/2026** : menu pause ; bouton « Menu » dans la coque en plus |
| Un joueur « Blessé » sort-il automatiquement des groupes Avants/Arrières ? | game-designer | À valider |
| Hauteur de ligne des tableaux | direction artistique + Léo | **Résolue le 19/11/2026** : 24-26 px comme Football Manager (≈ 22-24 lignes visibles) |
| Où vit la liste des fins de contrat (file de tâches de fin de saison, journey §3.4) ? | game-designer + ui-programmer | Ici, vue « Contrats » et compteur, sinon à créer |
| Écran de comparaison (2 joueurs), appelé d'ici, de la fiche 08 et du recrutement : aucune fiche ne le spécifie | ux-designer | À spécifier (fiche à créer) |
| Compteur « Aptes » : son clic ouvre « Tous » ; un filtre « Aptes » serait plus honnête | ux-designer | Conseil, non bloquant |
