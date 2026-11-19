# UX Spec : 15 — Après-match (« Pourquoi »)

> **Statut** : en conception (proposé, non validé par Léo)
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.3 jour de match (fin) → 1.2 semaine suivante
> **Identifiant** : même composant que l'entracte (`MatchBetween`, état `finished`) ; bloc « Pourquoi » = `_remplir_pourquoi` ; moteur `native/engine/match-pourquoi.cjs` (`direct.pourquoi`)
> **Plateforme** : PC souris + clavier
> **Palier d'accessibilité** : Standard
> **Sources** : `match_between.gd` (lignes 2470-2550 lues), `ui/decision_feedback.gd` (reçus de décision, ne concerne pas ce bloc). Aucune capture 1920 de l'après-match : visuels non vérifiés.
> **Liens** : `14-match-entracte.md`, `design/player-journey.md` friction n° 5

---

## 1. But

**Besoin du joueur** : savoir pourquoi le match s'est terminé ainsi, et ce qu'il peut changer. C'est le test de la boucle (kill condition du game brief : un joueur extérieur doit comprendre l'issue sans aide).
**But du joueur** : lire en moins de 10 secondes score, note et les 3 raisons principales, puis cliquer sur le levier qui l'intéresse ou continuer.
**Besoin du jeu** : transformer un résultat en décisions pour la semaine (composition, condition, tactique, discipline, préparation).

### 5 secondes
1. Score final et issue (victoire, défaite, nul) en gros.
2. Le titre « Pourquoi on a gagné / perdu / ce nul » et ses trois raisons.
3. Un bouton unique pour continuer.

### Hiérarchie
| Rang | Bloc |
|---|---|
| Principale | Les 3 raisons classées, chacune avec son levier |
| Secondaire 1 | Score final + note du match + classement après le match (place gagnée ou perdue) |
| Secondaire 2 | Avis de Gabi (une phrase, ton adapté à l'issue) |
| Secondaire 3 | Bouton principal de suite |
| Derrière « Voir plus » | Statistiques complètes, journal, notes de joueurs, autres raisons au-delà de 3 |

---

## 2. Contexte à l'arrivée

| Question | Réponse |
|---|---|
| Ce qu'il faisait | Regarder le sifflet final |
| Émotion | Victoire : fierté, envie d'en savoir plus. Défaite : frustration, besoin de comprendre, peur de la sanction du conseil |
| Charge cognitive | Faible à moyenne, attention disponible |
| Ce qu'il sait | Le score et son impression du match |
| Ce qu'il veut | Une explication honnête, un levier pour la semaine |
| Ce qu'il craint | « C'était injuste » ou « c'est ma faute et je ne sais pas laquelle » |

**Cible émotionnelle** : victoire = « je vois ce qui a marché, je le garde » ; défaite = « je sais quoi changer, ce n'est pas la fin ».

---

## 3. Navigation

```
Direct 3D (13) → coup de sifflet → Après-match (15)
   ├── Levier → écran concerné (Composition, Entraînement, Tactique, Discipline, Préparation)
   ├── Voir plus → Statistiques / Journal (PLUS)
   └── Continuer → Conférence de presse (si annoncée) → Bureau
```
**Mode** : overlay du match fini ; non modal, pas de piège. Le résultat « reste à valider » tant que le joueur n'a pas cliqué Continuer (le texte d'infobulle des leviers le dit déjà).

| Entrée | Déclencheur |
|---|---|
| Sifflet final | état `finished` du direct |
| Match confié à l'adjoint | fin de la simulation |
| Reprise de sauvegarde sur un match fini | rechargement |

| Sortie | Destination | Donnée |
|---|---|---|
| Continuer (libellé du moteur « VALIDER LE RÉSULTAT », puis « OUVRIR LA CONFÉRENCE DE PRESSE → » ou « SEMAINE SUIVANTE ») | Presse, sinon Bureau | résultat validé |
| Clic sur un levier | écran du levier, avec retour à l'après-match | route |
| Échap | **ne ferme pas** ; focus sur le bouton principal | décision 16/11 |

---

## 4. Disposition

### 4.1 Wireframe 1280×720

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [FIN]  Meadowbridge R. [é] 24 – 17 [é] Alder Fen XV              [PLUS ▾]    │
│        Défaite · Note du match 5,5 / 10 · 4e → 6e au classement ▼2          │
├──────────────────────────────────────────────────────────────────────────────┤
│  POURQUOI ON A PERDU                                                         │
│                                                                              │
│  ▼ CONDITION    Tes talonneurs ont fini à 38 % d'énergie : touches perdues  │
│                 en seconde période.                       [Voir la condition]│
│  ▼ TACTIQUE     Ton jeu au pied a donné 7 ballons à l'adversaire.            │
│                                                           [Voir les consignes]│
│  ▲ DISCIPLINE   Seulement 4 pénalités concédées : c'est ce qui t'a gardé     │
│                 dans le match.                            (pas d'action)     │
│                                                                              │
│  [ Voir plus : statistiques, notes, journal ]                                │
├──────────────────────────────────────────────────────────────────────────────┤
│ [Gabi] « Pas de panique : le talonneur de remplacement n'a pas été utilisé. »│
├──────────────────────────────────────────────────────────────────────────────┤
│                              [ OUVRIR LA CONFÉRENCE DE PRESSE → ]  ●focus    │
└──────────────────────────────────────────────────────────────────────────────┘
```
Les valeurs ci-dessus sont des exemples de mise en page, pas des données du jeu.

### 4.2 Zones
| Zone | Contenu | Taille | Défilable | Débordement |
|---|---|---|---|---|
| Bandeau de résultat | `FIN`, score, issue, note, évolution de classement | pleine largeur × 12 % | Non | — |
| Bloc Pourquoi | titre + 3 lignes de raisons | 60 % hauteur | Non | **le texte d'une raison n'est plus tronqué** (aujourd'hui 2 lignes + « … ») : 3 lignes autorisées |
| Voir plus | bouton, ouvre PLUS > Statistiques | une ligne | Non | — |
| Carte de Gabi | portrait + phrase | 10 % | Non | infobulle |
| Pied | bouton principal | 10 % | Non | — |

### 4.3 Composants
| Composant | Rôle | Existant ? |
|---|---|---|
| Bandeau de résultat | score, issue, note, classement | partiellement (score dans la barre) ; **issue en mots et classement : à ajouter** |
| Ligne de raison : pictogramme de sens (▲ positif, ▼ négatif) + libellé du levier + texte | une cause | Existant (couleur ivoire/verte seule pour le sens → **ajouter ▲ ▼ et le mot**) |
| Bouton de levier (un par écran concerné, dédoublonné par route) | agir | Existant |
| Carte de Gabi | conseil | Existant |
| Voir plus | progressive disclosure | **À ajouter** (aujourd'hui : stats par PLUS) |
| Bouton principal | suite | Existant (`primary_text`) |

**Focus à l'ouverture** : le bouton principal (Continuer). Raison : l'utilisateur pressé n'est jamais bloqué ; Tab remonte vers les leviers. **Alternative à valider** : focus sur la première raison si le joueur veut lire.

---

## 5. États

| État | Déclencheur | Visuel | Comportement |
|---|---|---|---|
| Victoire | `issue = victoire` | Titre « Pourquoi on a gagné » ; raisons surtout ▲ ; Gabi félicite et nomme **ce qu'il faut garder** | Continuer = vers la presse |
| Défaite | `issue = defaite` | « Pourquoi on a perdu » ; raison n° 1 forcément la plus actionnable ; Gabi rassure et nomme **un levier** | idem ; leviers en évidence |
| Nul | `issue = nul` | « Pourquoi ce nul » ; deux raisons au moins (une ▲ une ▼) | idem |
| Autre issue | `issue` inconnue | « Pourquoi ce résultat » | idem |
| Aucune raison | `pourquoi.raisons` vide | **Aucun bloc aujourd'hui (silence)** : afficher « Match trop équilibré pour désigner une cause. Statistiques complètes ci-dessous. » + Voir plus | Ne jamais laisser le vide muet |
| Moins de 3 raisons | 1 ou 2 | N lignes, pas de ligne vide | — |
| Chargement | moteur calcule | « Gabi relit le match… » | boutons désactivés avec la raison |
| Erreur | moteur arrêté ou calcul échoué | bandeau « Le bilan n'a pas pu être calculé : le résultat est conservé » + bouton Relancer | Continuer reste disponible |
| Première fois | premier match de la carrière | infobulle Gabi : « Ça, c'est le Pourquoi : clique sur un levier pour agir » | une seule fois, passable |
| Mouvement réduit | préférence | pas de fondu | — |
| Sélection nationale ou match délégué | (non vérifié) | même structure | à vérifier |

**Ton selon l'issue (copy, pas de mise en page différente)** : en victoire on n'efface pas les causes négatives (« Tu as gagné malgré … ») ; en défaite on ne culpabilise pas, on nomme le levier.

---

## 6. Interactions

### 6.1 Souris
| Cible | Action | Réponse |
|---|---|---|
| Bouton de levier | clic | ouvre l'écran concerné, retour possible |
| Ligne de raison | survol | infobulle du texte complet (existant) |
| Voir plus | clic | statistiques complètes |
| Bouton principal | clic | continue |

### 6.2 Clavier
| Touche | Effet | Statut |
|---|---|---|
| Espace | active le bouton principal | existant (via le bouton) |
| Entrée | active l'élément au focus | existant |
| Tab / Maj+Tab | parcourt leviers, Voir plus, bouton principal | à vérifier |
| Échap | ne quitte pas ; rend le focus au bouton principal | décision 16/11 |
| Ctrl+J, 1 à 9 | non actifs avant validation | existant |

### 6.3 Restrictions
| État | Désactivé | Raison |
|---|---|---|
| Moteur occupé | leviers, Continuer | `app.waiting` ; message « … » sur le bouton |

---

## 7. Données

| Donnée | Source | Mise à jour | Format | Si manquant |
|---|---|---|---|---|
| Score, issue | `live`, `direct.pourquoi.issue` | au sifflet | entiers, enum | issue neutre |
| Raisons (≤ 3) | `direct.pourquoi.raisons` : `rang`, `levier`, `levierLabel`, `texte`, `sens`, `route` | au sifflet | liste | texte « trop équilibré » |
| Note du match | (non vérifié dans le code lu) ; facultative, voir §13 | au sifflet | 0-10 | masquée |
| Place au classement avant/après | classement en direct (`rang`, `delta`, existant dans l'entracte) | au sifflet | entiers | masquée |
| Avis de Gabi | `conseil` adjoint | au sifflet | texte | phrase générale |

**Événements** : « Continuer » (valide le résultat), « Ouvrir l'écran levier » (navigation), `delegation_demandee` non pertinent après le match.

---

## 8. Ce qu'on retire ou déplace

| Élément | Décision | Raison |
|---|---|---|
| Couleur seule (ivoire / vert) pour positif / négatif | Ajouter ▲ ▼ + le mot « point fort / à corriger » | D2, C1 |
| Texte de raison tronqué à 2 lignes | 3 lignes, jamais tronquer un chiffre | T5 |
| Étiquette de levier à 18 px (code, calque 2560) | 14 px réels minimum à 1920 | T1 |
| Barre PAUSE, vitesse, caméras | Masquer après le sifflet | Plus d'action possible |
| Bouton ÉQUIPE après le match | Masquer ou renommer « Consulter l'équipe » | Pas de changement possible |
| Quatrième raison et au-delà | Derrière « Voir plus » | Progressive disclosure (journey n° 5) |
| Panneau d'attente / double clic | Pas de double validation | — |

---

## 9. Animations
| Transition | Durée | Réduit |
|---|---|---|
| Arrivée du bloc Pourquoi | 250 ms fondu, raison par raison à 120 ms d'écart | instantané |
| Score final qui se fige | aucune animation | — |
Aucun effet de confettis ou de flash (M4).

---

## 10. Accessibilité (Standard)

| Texte | Fond | Seuil |
|---|---|---|
| Libellé de levier (couleur par levier) | panneau sombre | 4,5:1 : **les 5 teintes de levier à valider** (`LEVIER_TEINTES`) |
| Texte de raison | panneau | 4,5:1 |
| Note et score | panneau | 3:1 (grand) |

| Élément | Risque | Mitigation |
|---|---|---|
| Teinte du levier (composition bleu, condition vert, tactique ambre, discipline orangé, préparation violet) | confondables en deutéranopie | le mot du levier est déjà écrit en capitales : garder, ne jamais l'enlever |
| Sens positif / négatif | couleur | ▲ ▼ + mot |
| Variation de classement | flèche seule | « +2 places » écrit |

**Focus** : Continuer → (Tab) Voir plus → leviers → Gabi. Entrée active.
**Annonces** : « Défaite 17 à 24. Pourquoi on a perdu : trois raisons. »
**Charge cognitive** : 4 flux (score, 3 raisons, Gabi, suite) ≤ 7.

---

## 11. Critères de réception

- [ ] Au plus trois raisons visibles avant « Voir plus ».
- [ ] Le titre dit l'issue (gagné / perdu / nul) en mots.
- [ ] Sens de chaque raison lisible en niveaux de gris.
- [ ] Aucune raison tronquée par « … » sans infobulle.
- [ ] Zéro raison : message affiché, jamais un écran muet.
- [ ] Échap ne ferme ni ne quitte l'écran.
- [ ] Chaque levier ouvre le bon écran et permet de revenir.
- [ ] À 1280×720 : texte ≥ 14 px effectifs, aucun chevauchement.
- [ ] Test non guidé : 3 personnes sur 5 énoncent la cause principale sans aide.

## 12. Questions ouvertes

| Question | Propriétaire | Résolution |
|---|---|---|
| Existe-t-il une « note du match » dans les données ? (non vu dans le code lu) | game-designer | Ouverte |
| Après victoire, Gabi doit-il toujours nommer une cause négative ? | Léo | Ouverte |
| Capture 1920 de l'après-match (victoire et défaite) | ui-programmer | À faire |
| Écran ou bandeau dédié « Match fini » plutôt qu'un état de l'entracte ? | Léo | Ouverte (je recommande de garder le même écran) |

## 13. Ajouts de la revue UX (19/11/2026)

**Données facultatives** : la note du match et la place au classement sont affichées seulement si le moteur les fournit ; sinon le bandeau montre score + issue en mots, rien d'autre (aucune case vide). Le score et l'issue sont obligatoires.

**Localisation (longueurs max, +40 % prévus)** : titre « Pourquoi … » 28 caractères ; texte de raison 140 caractères sur 3 lignes ; libellé de levier 16 ; bouton de levier 26 ; phrase de Gabi 100 sur 2 lignes ; bouton principal 34.

**Méthodes d'entrée (PC)**
- Souris : leviers, Voir plus, bouton principal ; cibles ≥ 32 px de haut.
- Clavier seul : Tab / Maj+Tab dans l'ordre de §10, Entrée ou Espace sur le bouton au focus ; Échap ne quitte pas. Aucun glisser-déposer.
- Manette : hors périmètre.

**Critères supplémentaires**
- [ ] Le bloc Pourquoi s'affiche en moins de 300 ms après le sifflet final.
- [ ] Rendu correct à 1280×720, 1920×1080 et 2560×1440.
- [ ] Le libellé du bouton principal est celui que le moteur annonce (« VALIDER LE RÉSULTAT » ou équivalent) ; à aligner avec « VALIDER LA JOURNÉE → » du code actuel (`live_view.gd`).
