# UX Spec : 19 — Formation (centre retiré, suivi des jeunes fusionné)

Décisions de Léo du 19/11/2026 intégrées : Page « Centre » retirée ; Suivi des jeunes fusionné dans Formation (page unique) ; densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

> **Statut** : en conception (proposé, non validé par Léo)
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.2 (cycle de formation), 1.4 fin de saison (promotions, contrats)
> **Identifiants** : une seule page « Formation » (`academy_canvas.gd`, 5 onglets) ; la page Centre est retirée et le Suivi des jeunes est fusionné dans l'onglet Progression (décision de Léo, 19/11/2026)
> **Plateforme** : PC souris + clavier ; palier Standard
> **Sources** : captures `formation-1920.png`, `centre-1920.png`, `suivi-des-jeunes-1920.png` (semaine 5, 60 espoirs).
> **Non vérifié** : onglets Effectif U18, Progression, Passerelles, Encadrement ; l'écran « suivi individuel » (bouton « Indisponible ») ; fin de saison.

---

## 1. But

**Besoin** : avoir la relève sous la main et décider qui monte, reste ou part.
**But du joueur** : repérer en 5 secondes les jeunes à décider (potentiel élevé, contrat qui s'achève, prêts pour l'équipe première) et agir.
**Besoin du jeu** : transformer la formation en pipeline visible (jeunes issus du club, « histoire du club »), nourrir la rétention de fin de saison.

### 5 secondes
1. Combien d'espoirs, combien de pépites (potentiel ≥ 85), combien à décider.
2. La liste des jeunes triée par ce qui compte (potentiel, âge, fin de contrat).
3. Le jeune sélectionné avec son action (promouvoir, garder, libérer).

### Hiérarchie
| Rang | Bloc |
|---|---|
| Principale | Liste des jeunes (tableau) |
| Secondaire 1 | Panneau du jeune sélectionné (portrait, niveau, potentiel, 3 actions) |
| Secondaire 2 | « À décider » (contrats qui s'achèvent, places pros disponibles) |
| Secondaire 3 | Parcours Académie → Passerelles → Équipe première (état des étapes) |
| Derrière un onglet | Progression, Encadrement, compétition junior, suivi détaillé |

---

## 2. Contexte à l'arrivée

| Question | Réponse |
|---|---|
| Venait de | Alerte « espoir » du Bureau, courrier, fin de saison |
| Émotion | Attachement, impatience de voir un jeune éclore |
| Charge cognitive | Moyenne : 60 jeunes, trois groupes d'âge |
| Sait déjà | Un ou deux noms signalés par Gabi ou le courrier |
| Veut | Savoir qui promouvoir cette saison |
| Craint | Laisser partir une pépite, bloquer une place pro |

**Cible émotionnelle** : « Je suis fier de ceux que j'ai formés et je sais qui monte. »

---

## 3. Navigation

```
Formation (rail)
  └── Formation  [Effectif U21 · Effectif U18 · Progression (inclut le suivi des jeunes : Crabos 16-17, Espoirs 18-21, progression, temps de jeu) · Passerelles · Encadrement]
      (page Centre retirée : plus d'entrée au rail ; plus de page Suivi des jeunes)
```
**Mode** : écran plein.

| Entrée | Déclencheur |
|---|---|
| Rail | clic, chiffre |
| Alerte « espoir » du Bureau | lien |
| Club > Académie | lien |
| Fin de saison | file de décisions |

| Sortie | Destination |
|---|---|
| Préparer une intégration | écran d'intégration à l'équipe première |
| Clic sur un jeune | fiche du joueur |
| Ouvrir le suivi individuel | suivi (actuellement « Indisponible ») |
| Gérer la formation / Consulter les Espoirs | onglets de la même page |
| Échap | règle unique (décision de Léo, 19/11/2026) : ferme la fenêtre, sinon retour (historique), sinon menu pause |

---

## 4. Disposition

### 4.1 Wireframe 1280×720 (Formation, proposé)

```
┌────┬───────────────────────────────────────────────────────────────────────┐
│Rail│ ‹ Alder Fen XV › Formation                         [Préparer →]       │
│    ├───────────────────────────────────────────────────────────────────────┤
│    │ [Effectif][Progression][Passerelles][Encadrement]   U21 | U18 (bascule)│
│    │ 60 espoirs · 2 pépites (pot. ≥ 85) · 4 à décider                      │
│    ├──────────────────────────────────────────┬────────────────────────────┤
│    │ Filtres: Poste▾ Potentiel▾ Statut▾ [rech] │ LÉO DUPUIS · Arrière · 19 │
│    │ # Joueur   Âge Poste  Niv Pot  Prog Temps St │  Niveau 62 · Potentiel    │
│    │ ▌12 Léo Dupuis 19 Arrière 62 75-79 +2 320 ⚠ │  75-79                    │
│    │  4 N. Lefèvre 19 3e ligne 66 64-68 +1 280 ✓ │ [Promouvoir][Garder][Libérer]│
│    │  …                                          │  Condition 100 % ·        │
│    │  (tableau socle, tri au clavier)            │  Blessé : 1 sem.          │
│    ├──────────────────────────────────────────┴────────────────────────────┤
│    │ À DÉCIDER : 4 contrats d'espoir s'achèvent · 2 places pros libres [Voir→]│
│    │ Pied : Espace Suite · 1 à 9 Menus · Échap Retour · Ctrl K · F1         │
└────┴───────────────────────────────────────────────────────────────────────┘
```
Le parcours Académie → Passerelles → Équipe première (aujourd'hui en bas) devient l'onglet Passerelles.

### 4.2 Zones
| Zone | Contenu | Taille | Défilable | Débordement |
|---|---|---|---|---|
| Hero (« Le futur porte nos couleurs. », 4 compteurs, photo) | **un titre d'une ligne + 3 compteurs** | 10 % | Non | — |
| Onglets | 4 | 5 % | Non | — |
| Tableau | joueurs, 10 lignes visibles, colonnes # Joueur Âge Poste Niv Pot Prog Temps Statut | 60 % × 55 % | Oui | colonnes secondaires masquées en 1280 |
| Panneau du jeune | portrait, 2 chiffres, 3 actions, mini-courbe | 38 % × 55 % | Non | — |
| À décider | 1 ligne d'action | 8 % | Non | — |

### 4.3 Composants
| Composant | Rôle | Existant ? |
|---|---|---|
| Tableau des jeunes | lire et trier | Existant, hors socle : migrer vers `tableau.gd` (tri, focus clavier) |
| Panneau du jeune | agir | Existant (portrait, niveau, potentiel, vigilance) ; **actions Promouvoir / Garder / Libérer absentes de la capture** |
| Pastille de statut (« En formation », « Indisponible ») | état | Existant ; ajouter la raison (« Blessé · 1 sem. ») et l'icône |
| Fourchette de potentiel (« 75-79 ») | incertitude du staff | Existant ; infobulle « estimation du staff » |
| Ligne « À décider » | file de tâches | **Nouveau** (journey friction n° 4) |
| Parcours en 3 étapes | pipeline | Existant, déplacer vers Passerelles |

**Focus à l'ouverture** : première ligne du tableau (la plus prioritaire du tri par défaut).
**Tri par défaut** : « À décider d'abord » (contrat qui s'achève, potentiel élevé), puis niveau.

---

## 5. États

| État | Déclencheur | Visuel | Comportement |
|---|---|---|---|
| Liste pleine | cas normal | tableau | — |
| Aucun espoir | pas d'académie ou 0 jeune | « Ton académie est vide. Lance une campagne de détection. » + bouton | — |
| Filtre sans résultat | filtres trop stricts | « Aucun jeune ne correspond. » + « Effacer les filtres » | F8 : message + sortie |
| Jeune indisponible (blessé) | blessure | pastille « Blessé · 1 sem. » + icône | **Aujourd'hui : « Indisponible » sans motif** |
| Jeune à décider | contrat qui s'achève, prêt à monter | pastille « À décider » + point | tri en tête |
| Place pro disponible | `places = 2` | bandeau « 2 places pro libres » | actions actives |
| Aucune place pro | `places = 0` | action Promouvoir grisée + raison en infobulle (« Aucune place libre ») | G3 |
| Progression nulle | 0 sur la saison | « — » (et non « 0 » en vert) | **Aujourd'hui : 0 vert sur toute la colonne** |
| Début de saison | semaine 5, pas de rapport | « Premier rapport semaine X » | — |
| Suivi individuel indisponible | fonction absente | bouton retiré (pas grisé) | **Aujourd'hui : bouton « Ouvrir le suivi individuel · Indisponible »** |
| Chargement / erreur | moteur | « … » / bandeau | — |
| Première fois | 1re ouverture | note Gabi sur le potentiel (fourchette) | une fois |
| Fin de saison | clôture | « 4 espoirs en fin de contrat : décide avant le 30 juin » + file | — |

---

## 6. Interactions

### 6.1 Souris
| Cible | Action |
|---|---|
| Ligne du tableau | clic = sélection ; double-clic = fiche |
| En-tête | tri |
| Promouvoir / Garder / Libérer | action (confirmation, voir 6.3) |
| Filtres | listes déroulantes titrées |
| Onglets, U21/U18 | clic |
| « À décider → Voir » | ouvre la file |

### 6.2 Clavier
| Touche | Effet | Statut |
|---|---|---|
| ↑ ↓ Pg↑ Pg↓ Début Fin | ligne | socle |
| Entrée | fiche | socle |
| P | Promouvoir le jeune sélectionné | proposé (hors champ de saisie, K5) |
| Ctrl+Tab | onglet | proposé |
| Tri au clavier | flèche sur l'en-tête | proposé |
| Échap | règle unique : fenêtre, retour, sinon menu pause | modifié (décision de Léo, 19/11/2026) |

### 6.3 Actions engageantes
| Action | Règle |
|---|---|
| Promouvoir | confirmation : « Promouvoir Léo Dupuis en équipe première ? Contrat pro : X €/an. » focus sur Annuler |
| Libérer | bouton destructif, nom + coût, focus sur Annuler, irréversible dit |
| Garder | immédiat avec annulation possible 5 s (toast) |

---

## 7. Données

| Donnée | Source | Mise à jour | Format | Si manquant |
|---|---|---|---|---|
| Jeunes (niveau, potentiel estimé, âge, poste, temps de jeu, statut) | académie | semaine, match | entiers, fourchette | « — » |
| Progression de la saison | académie | semaine | entier signé | « — » |
| Contrat | académie | semaine | date | « — » |
| Places professionnelles | club | semaine | entier | masqué |
| Plafond de matchs (3/30) et « JIFF 0/3 saisons » | règles de la compétition | match | entiers | masqué |
| Encadrement (formateurs, installations, cohésion) | club | semaine | noms, niveaux | « — » |

L'écran lit seulement. Événements : promouvoir, garder, libérer, préparer une intégration (à confirmer côté moteur : commandes non lues).

---

## 8. Ce qu'on retire ou déplace

| Élément | Décision | Raison |
|---|---|---|
| Page **Centre** (Détection, Mentorat, Compétition junior, tous « au calendrier des Espoirs ») | **Retirée** (décision de Léo, 19/11/2026) ; aucune ligne de remplacement tant que ces fonctions n'existent pas | Page de promesse, aucune action ; la consolidation prime |
| Page **Suivi des jeunes** | **Fusionnée** dans l'onglet Progression de Formation (décision de Léo, 19/11/2026) | Le suivi duplique le tableau ; il dit lui-même « sans rien décider ici » |
| Bandeau hero + photo | Réduire | 10 % d'écran |
| Bouton « Ouvrir le suivi individuel · Indisponible » | Retirer | Bouton mort |
| Bouton « Préparer une intégration » (CTA vert en bannière) | Remplacer par les actions Promouvoir / Garder / Libérer dans le panneau du jeune | L'action est à côté du jeune |
| Colonne PROGRESSION : « 0 » en vert partout | « — » en gris si nul | Faux signal |
| « Plafond de matchs · 3/30 », « JIFF · 0/3 saisons · 3/30 matchs » (répété par ligne) | Une infobulle au survol du nom, pas une ligne par jeune | Jargon ; densité |
| « 0 depuis le dernier rapport · 205 min · 3 match(s) en équipe première » | « 205 min de jeu, 3 matchs en équipe première » | Vocabulaire |
| « Compétition junior » (vide : « – ») | Retirer jusqu'à existence | Vide |
| « Crabos », « Espoirs », « JIFF » non expliqués | Lexique par infobulle (G2) | Vocabulaire du rugby |
| Fiche d'un jeune « Indisponible » sans motif | Afficher motif et durée | D3 |

**Gap à signaler (conflit avec le journey)** : « Voir les jeunes à décider (promouvoir, garder, libérer) » est le besoin n° 19, mais les captures n'en montrent aucune action. Soit l'action existe ailleurs (non vue), soit le besoin n'est pas servi : à vérifier avant tout redessin.

---

## 9. Animations
| Transition | Durée | Réduit |
|---|---|---|
| Changement d'onglet | fondu 150 ms | instantané |
| Courbe de progression | tracé 300 ms | affichage direct |
| Promotion confirmée | message dans le toast, **pas d'animation festive plein écran** | — |

---

## 10. Accessibilité (Standard : D1, D3, D6, T1, T5, K1, K2, K6)

| Texte | Fond | Seuil |
|---|---|---|
| Colonnes du tableau (9-11 px à 1920 sur la capture) | tableau sombre | **12-13 px réels minimum** (tableaux denses, T1 dense ; en-têtes 11-12 px) |
| Potentiel (ambre) | panneau | 4,5:1 |
| Étiquettes « JIFF · 0/3 SAISONS · 3/30 MATCHS » | fond | ≥ 11 px, 4,5:1 |

| Élément | Risque | Mitigation |
|---|---|---|
| Statut | couleur seule (vert / ambre) | mot + icône (coche, croix, point d'exclamation) |
| Blessure | rouge | icône + « léger » / « grave » + durée (D3) |
| Progression | vert | signe + / − écrit |
| Potentiel élevé | ambre | étoile + chiffre |

**Focus** : onglets → filtres → tableau → panneau du jeune (Promouvoir, Garder, Libérer) → À décider. **Annonces** : « Léo Dupuis, arrière, 19 ans, niveau 62, potentiel 75 à 79, blessé une semaine ».
**Charge cognitive** : 4 blocs, 3 actions ; colonnes ≤ 8.

---

## 11. Critères de réception

- [ ] Promouvoir, Garder, Libérer sont accessibles depuis le jeune sélectionné.
- [ ] Un jeune blessé affiche motif et durée, avec icône.
- [ ] Aucun bouton « Indisponible » : le bouton est absent ou actif.
- [ ] Le tableau se trie et se parcourt au clavier ; texte ≥ 12 px réels.
- [ ] « Promouvoir » et « Libérer » demandent confirmation avec le focus sur Annuler.
- [ ] En fin de saison, les décisions de contrat des jeunes sont regroupées dans « À décider ».
- [ ] Pas de page vide dans le rail : Centre retiré, Suivi des jeunes absent du rail (décision de Léo, 19/11/2026).
- [ ] L'onglet Progression montre le suivi des jeunes (Crabos, Espoirs, progression, temps de jeu) sans seconde page.
- [ ] 1280×720 sans coupe ni chevauchement.

## 12. Questions ouvertes

| Question | Propriétaire | Résolution |
|---|---|---|
| Où se prennent aujourd'hui les décisions promouvoir / garder / libérer ? | ui-programmer / game-designer | Résolue (revue UX 19/11, voir §13) : Promouvoir = `academy_promote` ; Garder / Libérer = `academy_intake_confirm` à l'arrivée de la promotion |
| Centre : retirer du rail ou garder comme annonce ? | Léo | **Résolue le 19/11/2026** : retiré |
| Fusionner Suivi des jeunes dans Progression ? | Léo | **Résolue le 19/11/2026** : fusionné dans Formation |
| Onglets U18, Progression, Passerelles, Encadrement non capturés | ui-programmer | À capturer |

## 13. Ajouts de la revue UX (19/11/2026)

**Résolu à la revue (lecture du code)** : les décisions existent, mais pas telles que la spec les rêvait.
- **Promouvoir** : commande `academy_promote` (`academy_pathways_view.gd`, boutons « PREMIER CONTRAT PRO n AN(S) », avec confirmation chiffrée) ; atteinte aujourd'hui via « Préparer une intégration » (`academy_canvas.gd`, `_integration_dialog`). Le panneau du jeune ouvre cette même fenêtre ; il n'ajoute pas de seconde logique.
- **Garder / Libérer** : commande `academy_intake_confirm` (listes `keep` et `release`, `academy_intake_view.gd`), à l'arrivée de la nouvelle promotion seulement. **Aucune commande de libération hors de ce moment n'a été trouvée.** Le panneau montre donc Garder / Libérer uniquement quand la revue d'effectif est ouverte ; sinon les boutons sont absents (jamais grisés). Libérer à tout moment serait une nouvelle commande moteur : question pour Léo / game-designer, non requise par cette fiche.
- Le critère « Promouvoir, Garder, Libérer sont accessibles depuis le jeune sélectionné » de §11 se lit : Promouvoir toujours (si place pro), Garder / Libérer pendant la revue d'effectif.

**Localisation (longueurs max, +40 % prévus)** : nom du joueur 26 caractères ; poste 14 ; statut 22 (« Blessé · 1 sem. ») ; bouton 28 ; ligne « À décider » 70 sur 2 lignes.

**Méthodes d'entrée (PC)**
- Souris : §6.1.
- Clavier seul : Tab dans l'ordre de §10, ↑ ↓ dans le tableau, Entrée, P pour promouvoir (hors saisie) ; aucun glisser-déposer.
- Manette : hors périmètre.

**Critères supplémentaires**
- [ ] L'écran Formation s'affiche en moins de 500 ms avec 60 jeunes.
- [ ] Rendu correct à 1280×720, 1920×1080 et 2560×1440.

---

## 14. Choix de Léo, intégration DA (20/11/2026)

**Variante 1 · Tableau et fiche du jeune**, maquette validée « parfait » (`19-formation-retouche`), avec la règle fiche joueur : clic sur un nom = fiche complète, survol (ou « i ») = mini-fiche ; plus aucune fiche fixe à droite. Emprunt de la variante 3 : les **raisons écrites** de la file « À décider » (une carte par jeune, phrase tirée de ses vraies données : contrat qui s'achève, pépite, blessure, progression nulle).

**Écran** : titre + 4 compteurs cliquables (Espoirs, Pépites, À décider, Places pro libres) ; onglets Effectif · Progression · Passerelles · Encadrement ; puces Tous / À décider / Pépites / Blessés, recherche, menus Groupe (U21, U18, tous, jeunes professionnels), Poste, Tri (« À décider d'abord » par défaut) ; tableau (lignes de 24 px à 1920) aux niveaux et potentiels au barème coloré, fourchettes selon la connaissance, drapeau, statut écrit (puce + mot) ; bande « Décision pour … » (Promouvoir en ivoire plein, conditions du premier contrat, offres de 1 à 3 saisons si les parcours sont actifs) ; file « À décider avant la fin de saison ».

**Décisions** : Promouvoir ouvre une confirmation EN PLACE (jamais une fenêtre). Garder / Libérer n'existent qu'à la revue d'effectif de la nouvelle génération (sous-page « Nouvelle génération du centre », lien dans la bande de décision quand elle est à examiner ; « Libérer et valider » = confirmation en place, irréversible dit). Aucune date de contrat inventée : « fin de saison » ; « — » si la donnée manque.

**Sous-pages** (coque gardée, « ← Retour à la formation », Échap, Précédent / Suivant) : Suivi des jeunes (objectifs et gains observés), Nouvelle génération du centre, Prêt d'un jeune professionnel. Leurs confirmations sont en place. Plus de fenêtre « Progression » ni de fenêtre d'intégration ; « Pourquoi la mise à jour attend » s'affiche dans la page.

**Critères ajoutés** : chaque ligne, carte, compteur et nom ouvre une fiche, un filtre ou un écran ; aucune Window ouverte par un clic de l'écran ; aucun or hors Continuer.
