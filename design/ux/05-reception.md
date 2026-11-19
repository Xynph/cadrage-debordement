# UX Spec : Réception (courrier)

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p ; lignes de tableau 24-26 px ; échelle d'interface 90/100/115/130 %) ; règle unique d'Échap (ferme la fenêtre, sinon retour de fiche/sous-écran, sinon menu pause) et bouton « Menu » visible dans la coque.

> **Statut** : En conception (brouillon autonome, rigueur `minimal`)
> **Auteur** : ux-designer (CCGS)
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.2 Semaine type
> **Identifiant** : `ReceptionCanvas` (`ui/immersive08/reception_canvas.gd`)
> **Plateforme** : PC Windows, souris + clavier, 1280×720 à 2560×1440
> **Palier d'accessibilité** : Standard
> **Entrées liées** : `player-journey.md` (écran 05), `interaction-patterns.md` (E2, E4, E5, F8, N5), `accessibility-requirements.md` (T1, C1, D1, K1, K2, M6, G3)
> **Écrans liés** : `04-bureau.md`, `06-presse.md` (bascule conférences), écrans cibles des courriers
> **Sans style visuel** : couleurs et polices relèvent du directeur artistique.

## 1. But

- **Joueur** : repérer ce qui demande une réponse, l'ouvrir, y répondre ou le classer, sans rien rater.
- **Jeu** : recevoir les décisions engageantes (réponses aux courriers du club) et marquer le lu.
- **Émotion visée** : maîtrise de la boîte, pas corvée ; « 0 à faire » donne du soulagement.

## 2. Ce qu'il doit voir en 5 secondes

1. **Principal** : le courrier **à traiter en priorité** ouvert dans le volet de lecture, avec ce qu'on attend (échéance, action).
2. **Secondaires (3)** : la liste groupée par jour ; les filtres (Tous / Non lus / À faire) ; les actions du courrier (Favori, Lu, Archiver).
3. **Le reste** : filtre Sujet, dossier du courrier (expéditeur, service, reçu), bascule vers conférences.

## 3. Navigation

```
Rail > RÉCEPTION (1)  <-- cet écran  (ouvert aussi par Espace « prochain non lu »)
  ├── Courrier > action « Ouvrir les sélections / la composition / ... »  --> écran cible
  ├── Courrier du club > carte de réponse  --> commande (réponse envoyée)
  └── Courrier de presse > « Ouvrir la conférence » --> Presse
```

Entrées : rail, touche 1, Bureau « Courrier », Espace sur un écran racine, lien d'un message.
Sorties : Échap ferme d'abord la fenêtre ou la fiche ouverte ; sans rien d'ouvert, il fait ce que fait Échap sur tout écran racine (menu pause, annoncé au pied « Échap Menu » : règle unique décidée par Léo le 19/11/2026, alignée sur 04 ; le bouton « Menu » de la coque l'ouvre aussi). Jamais de menu pause juste après la fermeture d'un courrier ou d'une fiche.

## 4. Wireframe 1280×720

```
+------+-------------------------------------------------------------------------------------+
|rail  | <- ->  [Rechercher...]                                    [19 SEPT. 2026] [Continuer]|
|      +-------------------------------------------------------------------------------------+
|      | Réception. · 40 non lus · 6 à faire · 1 urgence                                     |
|      | [Tous][Non lus 40][À faire 6][Sujet v]  |  Sélections · dim. 6 sept., 07:40         |
|      | À TRAITER EN PRIORITÉ                    |  [Favori ☆] [Lu ✉] [Archiver ✓]           |
|      | |● SÉLECTIONS Convocations ...  07:40 ●|  |  Convocations internationales : 1 joueur  |
|      | | SÉLECTIONS Les postes ...      07:44 ●|  |  Texte du courrier (4 à 6 lignes)         |
|      | AUJOURD'HUI                              |  [● Ouvrir les sélections ->]             |
|      | | PRESSE Rumeur ... [À FAIRE · 26/09]  |  |  --- réponses possibles (si courrier club) |
|      | HIER                                     |  [Réponse A : ▲ ▼]  [Réponse B : ...]    |
|      | | FORMATION ...                       |  |                                           |
|      | ...                                      |  Expéditeur · Service · Reçu  (1 ligne)   |
|      |                                          |  Espace : courrier suivant non lu         |
+------+-------------------------------------------------------------------------------------+
| Sauvegarde auto · dernière 19/09           Espace Suite · 1-9 · Échap Menu · Ctrl F · F1   |
+-----------------------------------------------------------------------------------------------+
```

Liste ≈ 35 % de la largeur, lecture ≈ 65 %.

## 5. Blocs de contenu et données exactes

| Bloc | Contenu | Source |
|---|---|---|
| Titre + compteurs | « Réception. » ; « n non lus · n à faire · n urgence » | boîte du moteur |
| Filtres | pastilles « Tous », « Non lus n », « À faire n » ; menu « Sujet » (catégories, favoris, archives) | état d'interface |
| Liste | groupes « À TRAITER EN PRIORITÉ », « AUJOURD'HUI », « HIER », « JEU. 17 SEPT. »… ; ligne : icône de catégorie, **catégorie · expéditeur**, titre, heure, étiquette « À FAIRE · avant le JJ/MM » ou « URGENT », pastille non lu, « ×n » pour un fil regroupé | 80 px de haut (104 avec étiquette) |
| Lecture | icône, expéditeur, service, date et heure ; titre ; corps ; action principale (bouton qui ouvre l'écran cible) | courrier sélectionné |
| Actions du courrier | Favori, Lu, Archiver | commandes |
| Réponses (courrier du club) | cartes : libellé + conséquences chiffrées (▲ ▼ =) tirées du moteur ; recommandée marquée ; indisponible avec raison écrite | `_reply_club_mail` |
| Dossier du courrier | expéditeur, service, reçu, état, « Ta boîte » : **réduit à une ligne** | voir §9 |
| Courrier suivant non lu | bouton + indication « Espace » | N5 |

## 6. Actions et raccourcis

| Entrée | Effet |
|---|---|
| Clic ligne | ouvre le courrier ; il passe à lu |
| ↑ ↓ / Début / Fin | change de courrier (marque lu après affichage ; **proposé : seulement après 1 s** pour ne pas vider la boîte en parcourant) |
| Entrée | ouvre l'action principale du courrier |
| Espace | prochain non lu, puis Continuer (N5) |
| Clic carte de réponse | **proposé** : choisit ; bouton « Envoyer la réponse » confirme ; « Annuler » avant envoi |
| F (proposé) ou clic étoile | favori ; L : lu/non lu ; A : archiver (actifs seulement hors champ de saisie) |
| Tab | rail, filtres, Sujet, liste, actions du courrier, réponses, courrier suivant |
| Échap | ferme la fenêtre ou la fiche ouverte ; sinon menu pause (règle unique du 19/11/2026, voir §3) ; Alt ← revient à l'écran précédent |

Un filtre actif qui masque le courrier ouvert **ne le remet pas à « Tous » en silence** : un message « Filtre retiré : le courrier ouvert n'y figure pas ».

## 7. États

| État | Déclencheur | Visuel / comportement |
|---|---|---|
| Boîte pleine, première semaine | 40 non lus | bandeau d'une ligne : « 40 non lus. Commence par les 6 à faire » ; bouton « Tout marquer comme lu » (confirmation avec libellé et nombre) |
| Non lu / lu | état du courrier | titre gras + pastille **et** étiquette « Non lu » programmatique ; lu : poids normal |
| Sélectionné | clic/clavier | fond renforcé + liseré 5 px (pas la couleur seule) |
| À faire / Urgent | échéance | texte « À FAIRE · avant le … » / « URGENT » (mots, couleur en renfort) |
| Vide (filtre) | aucun courrier | « Aucun message dans cette vue. » + bouton « Tout afficher » (F8) |
| Vide (boîte) | rien à traiter | « Boîte à jour : aucun message à traiter. » |
| Réponse indisponible | condition non remplie | libellé atténué **et** raison écrite sous la carte (pas seulement infobulle) |
| Réponse envoyée | commande OK | cartes inactives, « Réponse envoyée : [libellé] » dans le volet |
| Attente moteur | `app.waiting` | cartes inactives avec message « Réponse en cours… » |
| Erreur | commande refusée | avis qui dit quoi faire (G3) |
| Courrier supprimé/déplacé | fil replié | « ×n » avec ▸ ▾ et texte « Déplier » |

## 8. Accessibilité

- **Texte** : titres ≥ 13 px, métadonnées (catégorie, heure) ≥ 11 px ; actuellement 9-10 px à 1080p (T1). Pas de troncature d'un titre décisif ; titre complet en infobulle et dans le volet (T5).
- **Couleur** : non lu = pastille + gras + libellé ; « À FAIRE » / « URGENT » = mot ; conséquences des réponses ▲ ▼ = symbole + mot (« gagne », « perd »), pas seulement vert/rouge (D1).
- **Focus** : liseré 2 px (K2) distinct de la sélection (liseré 5 px à gauche) et du survol ; arrivée sur le premier courrier prioritaire (K8) ; focus conservé sur la liste après archivage (passe au suivant).
- **Clavier** : tout atteignable ; réponses engageantes en deux temps (K1, décision sans erreur).
- **Défilement** : la liste ne défile pas seule (M6) ; un courrier ne disparaît jamais sans possibilité de le retrouver (Archivés).
- **Cognitif** : aperçu de liste (4 champs par ligne) ; actions du courrier 3 ; réponses ≤ 3 visibles puis « Voir plus ».
- **Contraste** : texte pâle des courriers lus ≥ 4,5:1 (62 % d'opacité de l'existant à vérifier, C1).
- **Cibles** : lignes 80 px, boutons d'action ≥ 28 px de haut (K6).

## 9. Ce qu'on retire ou déplace par rapport à l'écran actuel

| Élément actuel | Décision | Raison |
|---|---|---|
| Carte « LE DOSSIER DU COURRIER » avec grande photo de vestiaire | **Retirer** la photo ; réduire les métadonnées à une ligne sous le texte | décoration sans info ; occupe la moitié de la lecture ; « Expéditeur » et « Service » répètent l'en-tête |
| Ligne « Ta boîte : 40 non lus · 6 à faire » dans le dossier | **Retirer** | déjà dans le titre |
| Libellé « Espace : message non lu suivant » à ≈ 8 px en bas de la lecture | **Agrandir** ; bouton « Courrier suivant non lu » principal secondaire | texte quasi illisible |
| Visage + remarque de Gabi dans la barre haute (coupée, « ce qui touche l… ») | **Retirer sur cet écran** ; la remarque est dans le volet si utile | texte tronqué, 4 places pour Gabi (catalogue G) |
| Filtre « Sujet » (menu) à côté des pastilles | **Garder**, aligné sur la pastille Effectif (même format de compte) | cohérence E2 |
| Remise silencieuse du filtre à « Tous » | **Remplacer** par message | incohérence E2 |
| Envoi de réponse en un clic | **Passer en deux temps** | conséquences chiffrées (coût, moral), motif E5 |

Déviation aux motifs : E4 (les flèches marquent lu après 1 s) ; E5 (deux temps) ; F8 (vide avec action).

## 10. Critères d'acceptation

- [ ] Ouverture : le premier courrier « À traiter en priorité » est sélectionné et son action principale est focalisée.
- [ ] Parcours ↑ ↓ de toute la liste sans marquer tout lu en une volée.
- [ ] Aucune réponse n'est envoyée sans confirmation ; « Annuler » disponible avant l'envoi.
- [ ] Une réponse indisponible affiche sa raison à l'écran (sans survol).
- [ ] « Aucun message dans cette vue » propose « Tout afficher ».
- [ ] Texte de la liste ≥ 11 px et titres ≥ 13 px à 1920×1080 ; pas de titre tronqué en 1280×720.
- [ ] Niveaux de gris : non lu, à faire, urgent distinguables.
- [ ] 40 courriers : défilement fluide sans perte de focus.

## 11. Questions ouvertes

| Question | Propriétaire | Statut |
|---|---|---|
| 40 courriers non lus au départ d'une carrière : pourquoi autant ? Regrouper ou archiver d'office les infos ? | game-designer | à trancher |
| « Tout marquer comme lu » : acceptable ou on rate des décisions ? | Léo | à trancher |
| Les raccourcis lettre (F, L, A) entrent-ils en conflit avec la recherche (K5) ? | ui-programmer | à vérifier |
| Bascule vers les conférences : relevée dans le code (`press_view.gd`) : l'invitation de presse ouvre l'onglet Conférence de Presse avec un bouton « REVENIR AU COURRIER » ; à reprendre dans l'action principale du courrier de presse | ux-designer | résolu (reprise dans §3 : « Ouvrir la conférence ») |
| Échap sur écran racine (Réception comprise) : menu pause ou rien ? | Léo | **Résolue le 19/11/2026** : menu pause, plus bouton « Menu » dans la coque |
| Réponses en deux temps, marquage lu après 1 s, filtre jamais remis à « Tous » en silence : changements de comportement proposés | Léo | à valider |

## 12. Compléments de revue (ux-review, 19/11/2026)

### Événements émis
| Action du joueur | Événement / commande |
|---|---|
| Clic ou flèche sur un courrier (après 1 s) | marquage lu (commande de lecture, nom à confirmer) |
| Favori, Lu / Non lu, Archiver | commandes de courrier (noms à confirmer) |
| Envoyer la réponse (courrier du club) | `club_mail_reply` {id, choice} ; les décisions de calendrier passent par `calendar_mail_decide` {id, choice} |
| Annuler (avant l'envoi) | aucun événement : l'état de choix est local à l'interface |
| Tout marquer comme lu | commande groupée, après confirmation (libellé et nombre) |
| Filtres, tri, Sujet, repli de fil | état d'interface : aucun événement moteur |
| Ouvrir l'écran cible, Ouvrir la conférence, Courrier suivant non lu | navigation : aucun événement moteur |

### Transitions et animations
- Changement de courrier : volet de lecture remplacé sans animation (instantané).
- Filtre : liste remplacée en fondu de 0,12 s ; instantané sous « Mouvement réduit » (M1) ou « Transitions : Aucune » (M2).
- Archivage : la ligne disparaît et le focus passe au courrier suivant ; pas de glissement obligatoire.
- Message « Filtre retiré » : visible 6 s puis relisible dans le pied de page (durée de l'auto-dismiss documentée, M6).

### Contrôle d'entrée (souris + clavier ; manette hors périmètre)
- [x] Liste, filtres, actions et réponses atteignables au clavier (§6), ordre de focus défini.
- [x] Tout faisable à la souris ; boutons ≥ 28 px ; lignes de 80 px.
- [x] Raccourcis lettre (F, L, A) inactifs dans un champ de saisie (K5).
- [x] Aucun glisser ; aucune limite de temps ; Échap sans piège.

### Localisation (français seul ; limites pour +40 %)
| Élément | Max. actuel | Prévoir |
|---|---|---|
| Titre de courrier en liste | 2 lignes de 38 caractères | 2 lignes de 54, titre complet en volet |
| Étiquette « À FAIRE · avant le JJ/MM » | 24 caractères | 34 |
| Libellé de réponse | 60 caractères | 84, 3 lignes |
| Conséquence chiffrée | 40 caractères | 56 |
| Pastille de filtre | 14 caractères | 20 |
| Bouton d'action principale | 30 caractères | 42 |

### Critères supplémentaires
- [ ] L'écran est affiché et la liste de 40 courriers utilisable ≤ 500 ms après navigation.
- [ ] Rendu vérifié à 1280×720, 1920×1080, 2560×1440 et 21:9, y compris à 130 % de taille de texte.
- [ ] Un courrier de presse propose « Ouvrir la conférence » ; depuis Presse, « Revenir au courrier » rend la même sélection.
