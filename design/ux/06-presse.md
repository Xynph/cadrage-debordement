# UX Spec : Presse

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

> **Statut** : En conception (brouillon autonome, rigueur `minimal`)
> **Auteur** : ux-designer (CCGS)
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.2 Semaine type (après un match), 1.4 Fin de saison
> **Identifiant** : `PressCanvas` (`ui/immersive08/press_canvas.gd`, nœud `CarnetPresse`)
> **Plateforme** : PC Windows, souris + clavier, 1280×720 à 2560×1440
> **Palier d'accessibilité** : Standard
> **Entrées liées** : `player-journey.md` (écran 06), `interaction-patterns.md` (N2, E1, E2, F3, F8), `accessibility-requirements.md` (T1, C1, D6, K1, M6, S2)
> **Écrans liés** : `05-reception.md`, Classements, Calendrier, Rivalités, Après-match
> **Sans style visuel** : couleurs et polices relèvent du directeur artistique.

## 1. But

- **Joueur** : savoir s'il a une conférence à donner et la préparer ; lire ce que la presse écrit de son club.
- **Jeu** : capter les réponses de la conférence (ton, brouillon) et conserver les déclarations publiées.
- **Émotion visée** : se sentir regardé et pouvoir s'exprimer ; aucune alarme gratuite.

## 2. Ce qu'il doit voir en 5 secondes

1. **Principal** : l'état de la conférence : « Conférence ouverte : n question(s) à préparer » avec le bouton « Préparer la conférence », ou « Aucune conférence prévue » avec la date de la prochaine.
2. **Secondaires (3)** : le journal du jour (titres) ; les indicateurs de relation à la presse (Médias, Supporters, Pression) ; la mémoire des échanges (déclarations conservées).
3. **Le reste** : historique, portraits et relations, réglage « Conférences ordinaires ».

## 3. Navigation

```
Rail > Presse (entrée à confirmer à l'écran ; accès aussi depuis Bureau, Réception, après-match)
  └── PRESSE  <-- cet écran
        ├── Onglet Journal (défaut)
        ├── Onglet Conférence (questions + réponses, brouillon)
        ├── Onglet Historique (déclarations archivées)
        └── Onglet Portraits (journalistes et relations)
```

Onglets : les quatre sont dans l'écran (motif N2 : un seul jeu d'onglets). Sorties : Échap ferme d'abord la fenêtre ou la fiche ouverte ; sinon menu pause, comme sur tout écran racine (règle unique décidée par Léo le 19/11/2026, alignée sur 04 et 05 ; bouton « Menu » de la coque en plus) ; Alt ← revient à l'écran précédent.

Entrées : courrier de presse de Réception (« Ouvrir la conférence », avec « Revenir au courrier » dans l'onglet Conférence), Bureau, Après-match, rail (entrée « Presse » de la coque ; emplacement exact à confirmer à l'écran).

## 4. Wireframe 1280×720 (onglet Journal)

```
+------+-------------------------------------------------------------------------------------+
|rail  | <- ->  [Rechercher...]                                    [19 SEPT. 2026] [Continuer]|
|      +-------------------------------------------------------------------------------------+
|      | LA VOIX DU CLUB · Troisième Mi-Temps.   Alder Fen XV · Saison 2026-2027 · Semaine 5 |
|      | Médias 35/100 ▮▮▯  Supporters 41/100 ▮▮▯  Pression 6/100 ▮▯▯                       |
|      | [● Journal] [Conférence] [Historique] [Portraits]                                   |
|      +--------------------------------------------------+---------------------------------+
|      | LE JOURNAL SPORTIF         [Division v]          | LA SALLE DE PRESSE              |
|      | {faits du terrain}  titre du jour                | Conférence ouverte              |
|      |  Les résultats conservés                         |  3 question(s) à préparer       |
|      |  résumé du dernier tour (2 lignes)               |  2 réponse(s) en brouillon      |
|      |  Aucun résultat : « Le premier coup d'envoi      | [● Préparer la conférence ->]   |
|      |  ouvrira le journal. »                           | MÉMOIRE DES ÉCHANGES            |
|      |                                                  |  15 déclarations · 4 journalistes|
|      |  Classement : [voir Classements ->]              | [Historique] [Portraits]        |
+------+--------------------------------------------------+---------------------------------+
| Sauvegarde auto · dernière 19/09           Espace Suite · 1-9 · Échap Menu · Ctrl F · F1   |
+-----------------------------------------------------------------------------------------------+
```

## 5. Blocs de contenu et données exactes

| Bloc | Contenu | Source |
|---|---|---|
| Titre | « LA VOIX DU CLUB », « Troisième Mi-Temps. », club · saison · semaine | carrière |
| Indicateurs | **Médias**, **Supporters**, **Pression** : `n / 100` avec barre, mot de seuil (« faible », « sous tension ») | `mediaTrust`, supporters, `boardPressure` |
| Onglets | Journal, Conférence, Historique, Portraits | existants |
| Journal | sélecteur de division ; un titre du jour (« Les faits du terrain ») ; « Les résultats conservés » ; titres de presse | `press_view` |
| Salle de presse | « Conférence ouverte » / « Conférence indisponible » ; « n question(s) à préparer » ou la raison (`conference.reason`) ; « n réponse(s) en brouillon » ; bouton « Préparer la conférence » ou « Consulter le compte rendu » | `conference` |
| Mémoire des échanges | « n déclaration(s) conservée(s) », « n journaliste(s) », textes d'aide | `history`, `people` |
| Politique | « Conférences ordinaires » : « Y aller » / « Envoyer l'adjoint » + infobulle explicative | `press_policy` |

## 6. Actions et raccourcis

| Entrée | Effet |
|---|---|
| Clic « Préparer la conférence » | ouvre l'onglet Conférence. **Code actuel** : les questions ne s'affichent que si le joueur arrive depuis l'invitation du courrier ; sinon l'onglet dit « Ouvre l'invitation dans Réception. » (impasse sans bouton). **Cible** : le bouton mène aux questions quand la conférence est ouverte, ou l'onglet propose « Ouvrir l'invitation » (lien vers Réception) ; changement à valider (§11) |
| Onglets : Tab + flèches ← →, Entrée | changent d'onglet (**ajouter** : Ctrl+Tab ou chiffres 1-4 quand le focus est dans la zone) |
| Réponses de conférence | choisir une réponse par question (cinq tons, une seule par question) ; « n en brouillon » ; validation unique « Publier mes réponses » (inactive tant qu'une question reste sans réponse) ; **proposé** : récapitulatif des conséquences avant publication (deux temps, §11) |
| « Laisser Gabi répondre » | visible seulement si la délégation est permise ; raison de l'indisponibilité écrite à côté du bouton |
| « Y aller » / « Envoyer l'adjoint » | change le réglage ; état actif marqué (coche + libellé), pas la couleur seule |
| Espace, 1-9, Ctrl K/F, F1 | globaux (N5) |
| Échap | revient en arrière ; ne ferme pas une conférence en cours sans confirmation du brouillon perdu |

### Contenu des onglets (relevé dans `press_view.gd`)

- **Conférence** : si un résultat existe, « Retour de la dernière conférence » (variations Moral, confiance, médias, supporters, pression ; relation avec chaque journaliste avant → après). Puis, quand la conférence est ouverte depuis son invitation : un bloc par question (« QUESTION 01 »…) avec journaliste, titre de presse, style d'entretien, relation (« n échange(s) avec toi »), relance éventuelle, texte de la question, puis les réponses (ton en capitales, texte, conséquence chiffrée), « Publier mes réponses », et « Laisser Gabi répondre » si permis. Mémo : « Les relances reprennent tes échanges précédents… ».
- **Historique** : une entrée par conférence publiée, la plus récente d'abord (saison, semaine, club, journaliste, question, réponse) ; vide : « Tu n'as encore publié aucune conférence. » ; anciennes entrées sans texte : « …non conservé ».
- **Portraits** (nom interne « Relations », `press_people_view.gd`) : phrase d'intro (« Tes relations avec les journalistes te suivent… ») ; liste de journalistes (badge, nom, titre de presse), détail du journaliste choisi : style d'entretien, spécialités, relation `± n / 100` avec libellé et nombre d'échanges, explication de l'échelle (−100 à +100), « Les trois derniers échanges » (saison, semaine, club, ton, variation) ; vide : « Aucun journaliste disponible. » ; sans échange : « Aucun échange individuel conservé… ». La relation doit s'écrire en mot **et** en nombre (pas de couleur seule, D6).

## 7. États

| État | Déclencheur | Comportement |
|---|---|---|
| Conférence ouverte | match joué, questions prêtes | bouton principal ; « n question(s) à préparer » ; avertissement « La conférence se clôt le JJ/MM » |
| Conférence indisponible | aucune prévue | « Aucune conférence de presse prévue. » + prochaine date si connue |
| Brouillon | réponses partielles | « n réponse(s) en brouillon » ; bouton « Reprendre la conférence » |
| Conférence tenue | validée | titre « Conférence tenue » + conséquences (« Moral collectif 75 → 87 ») dans le volet ; bouton « Consulter le compte rendu » |
| Journal vide (début de saison) | aucun match | « Aucun résultat enregistré. Le premier coup d'envoi ouvrira le journal. » (conserver) |
| Journal indisponible | pas de carrière | « Journal indisponible : crée une carrière pour l'ouvrir. » (formulation du code à revoir) |
| Indicateur bas / haut | seuils | repère de seuil + mot (D6) |
| Attente moteur | `app.waiting` | bouton « … » avec raison |
| Erreur | commande refusée | avis qui dit quoi faire |

## 8. Accessibilité

- **Texte** : corps ~13 px, titres de journal ≥ 13 px, classement/tableau 12-13 px (T1) ; pas de troncature d'un titre de presse (T5).
- **Contraste** : texte sur la grande photo du bandeau : aplat derrière le titre et les indicateurs (C5).
- **Couleur** : indicateurs avec chiffre `n / 100` + mot de seuil + barre ; état « conférence ouverte/indisponible » par mot (D1, D6) ; réglage « Y aller / Envoyer l'adjoint » par coche.
- **Clavier** : ordre : rail, onglets, panneau principal, salle de presse, mémoire, réglage (K1) ; focus d'arrivée sur « Préparer la conférence » si ouverte, sinon sur le premier titre (K8).
- **Mouvement** : aucun défilement automatique du journal (M6).
- **Gabi** : conseil de presse en texte, pas seulement audio (S2).
- **Cognitif** : 3 indicateurs au lieu de 5 ; 4 onglets ; 1 bouton principal.
- **Cibles** : onglets ≥ 28 px de haut (K6).

## 9. Ce qu'on retire ou déplace par rapport à l'écran actuel

| Élément actuel | Décision | Raison |
|---|---|---|
| Indicateurs **Moral** et **Direction** (confiance du conseil) dans l'en-tête | **Déplacer** vers le Bureau (déjà présents) | ce ne sont pas des signaux de presse |
| Grande photo d'un homme en veste (bandeau) | **Réduire** ; garder en fond derrière un aplat | décorative ; prend 25 % de la hauteur ; contraste du titre |
| « Classement actuel » à 13 lignes dans le Journal | **Retirer**, remplacer par un lien « Voir le classement » | doublon de Classements, noie les titres |
| Liens « Classements », « Calendrier », « Rivalités » dans l'en-tête | **Retirer** | navigation du rail (Compétitions) |
| Panneau « Mémoire des échanges » à côté de « La salle de presse » | **Fusionner** dans la salle de presse sur deux lignes | deux cartes pour un même sujet |
| Réglage « Conférences ordinaires » sur la page d'arrivée | **Déplacer** en tête de l'onglet Conférence, **visible en permanence** (aussi sans invitation) | configuration rare ; sans invitation, l'onglet n'affiche que son explication et le réglage deviendrait introuvable |
| Deux photos dans « La salle de presse » (journaliste + salle) | **Retirer** une | décor |
| Visage de Gabi tronqué dans la barre haute (« lers BICKERSTAFF (66) et Blake OLLERE ») | **Retirer sur cet écran** | texte coupé, noms réels apparents à vérifier |
| Intitulé « Conférence indisponible » + « Aucune conférence de presse prévue. » | **Reformuler** : « Aucune conférence prévue. Prochaine : … » | dit quoi attendre |

Déviation aux motifs : N2 (un seul jeu d'onglets avec raccourci), F3 (valeur numérique + seuil), F8 (vide avec explication de la suite).

## 10. Critères d'acceptation

- [ ] Ouvert après un match : le bouton « Préparer la conférence » est visible et focalisé à 1280×720 sans défilement.
- [ ] Hors conférence : l'état « Aucune conférence prévue » et la prochaine date sont visibles.
- [ ] 3 indicateurs seulement ; chacun avec `n / 100` et un mot de seuil.
- [ ] Aucun classement complet dans le Journal ; lien « Voir le classement ».
- [ ] Navigation entre onglets au clavier ; l'onglet actif porte un état sélectionné.
- [ ] Aucun texte < 12 px ; contraste du titre sur photo ≥ 4,5:1.
- [ ] Aucune conférence perdue sans confirmation ; brouillon conservé après Échap.
- [ ] Journal vide au début de saison affiche son message sans carte vide.

## 11. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| Contenu des onglets Conférence et Historique et Portraits relevé dans le code (§6) ; rendu à capturer | ux-designer | relevé, capture à faire |
| La conférence ne s'ouvre que depuis l'invitation du courrier : garder ce circuit, ou permettre l'accès direct depuis Presse ? | Léo / game-designer | à trancher |
| Échap sur écran racine (Presse comprise) : menu pause ou rien ? | Léo | **Résolue le 19/11/2026** : menu pause, plus bouton « Menu » dans la coque |
| Publication en deux temps avec récapitulatif des conséquences (aujourd'hui un seul clic) | Léo | à valider |
| Les captures nomment des journalistes et joueurs apparemment réels : pack actif ? | Léo / data | à vérifier |
| Quelle échéance d'une conférence : fin de semaine ? avant le prochain match ? | game-designer | à trancher |
| Le réglage « Envoyer l'adjoint » a-t-il un coût de relation ? Dire laquelle dans l'infobulle | game-designer | non vérifié |

## 12. Compléments de revue (ux-review, 19/11/2026)

### Événements émis
| Action du joueur | Événement / commande |
|---|---|
| Changer d'onglet, Division, Voir le classement, Revenir au courrier | état d'interface ou navigation : aucun événement moteur |
| Choisir une réponse | état d'interface (brouillon conservé : `press_draft_choices`) ; aucun événement moteur |
| Publier mes réponses | `press_conference` {contexte, réponses, invitation} |
| Laisser Gabi répondre | `press_delegate` {contexte, invitation} |
| Y aller / Envoyer l'adjoint | `press_policy` {ordinary} ; ignoré si une commande est en cours ou si la valeur est déjà active |

### Transitions et animations
- Changement d'onglet : contenu remplacé sans animation (instantané) ; fondu de 0,12 s au plus, instantané sous « Mouvement réduit » (M1) ou « Transitions : Aucune » (M2).
- Résultat de conférence : valeurs affichées d'un coup, sans compteur animé.
- Aucun défilement automatique (M6).

### Contrôle d'entrée (souris + clavier ; manette hors périmètre)
- [x] Onglets, réponses, boutons atteignables au clavier (Tab, flèches, Entrée, Espace) ; ordre de focus défini (§8).
- [x] Tout faisable à la souris ; onglets et boutons ≥ 28 px.
- [x] Un brouillon de conférence survit à Échap et à la navigation.
- [x] Aucun glisser ; aucune limite de temps (la clôture « JJ/MM » est une échéance de jeu annoncée, pas un chrono).

### Localisation (français seul ; limites pour +40 %)
| Élément | Max. actuel | Prévoir |
|---|---|---|
| Onglet | 12 caractères (« Conférence ») | 17 |
| Libellé d'indicateur | 10 caractères (« Supporters ») | 14 |
| Titre de presse | 2 lignes de 60 caractères | 3 lignes |
| Texte de question | 3 lignes de 70 caractères | 5 lignes, défilement dans le bloc |
| Libellé de réponse + conséquence | 3 lignes | 5 lignes |
| Bouton principal | 24 caractères (« Préparer la conférence ») | 34 |
| « Envoyer l'adjoint » | 17 caractères | 24 |

### Critères supplémentaires
- [ ] L'écran Presse est affiché ≤ 500 ms après navigation.
- [ ] Rendu vérifié à 1280×720, 1920×1080, 2560×1440 et 21:9, y compris à 130 % de taille de texte.
- [ ] Depuis Presse, le joueur n'arrive jamais sur un onglet Conférence sans action possible (questions, ou lien « Ouvrir l'invitation »).
