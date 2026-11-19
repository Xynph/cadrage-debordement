# UX Spec : 18 — Club (vue d'ensemble, direction, infrastructures, staff, histoire)

> **Statut** : en conception (proposé, non validé par Léo)
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 19/11/2026
> **Phase du parcours** : 1.2 (décision de moyen terme), 1.4 fin de saison
> **Identifiant** : écran Club, 5 onglets (Vue d'ensemble, Direction, Infrastructures, Staff, Histoire)
> **Plateforme** : PC souris + clavier ; palier Standard
> **Sources** : captures `club-1920.png` (Vue d'ensemble) et `staff-1920.png` (Staff), semaine 5.
> **Non vérifié** : onglets Direction, Infrastructures, Histoire ; sous-pages « Stratégie » et « Travail du club » (captures non lues).

---

## 1. But

**Besoin** : sentir que le club est un projet à long terme et voir ce qu'on peut améliorer pour quel prix.
**But du joueur** : en 5 secondes, lire l'état de la direction (confiance du conseil, objectif de la saison) et trouver la prochaine amélioration utile.
**Besoin du jeu** : porter les décisions de moyen terme (installations, staff, demandes à la direction, jalons du conseil).

### 5 secondes
1. Confiance du conseil (/100) et ce que le conseil attend (objectif de la saison).
2. Ce qui est à décider : jalon à planifier, devis d'installations.
3. Un onglet à choisir.

### Hiérarchie (Vue d'ensemble)
| Rang | Bloc |
|---|---|
| Principale | Confiance du conseil + objectif de la saison (une seule carte) |
| Secondaire 1 | Prochain jalon / « À décider » (jalon à fixer, devis infrastructures, demande à la direction) |
| Secondaire 2 | Vestiaire (moral, disponibles, leader) |
| Secondaire 3 | Résumé installations (3 lignes) |
| Derrière les onglets | Encadrement, vie du club, stade, budget |

---

## 2. Contexte à l'arrivée

| Question | Réponse |
|---|---|
| Venait de | Bureau (objectif du conseil), alerte de la direction, fin de saison |
| Émotion | Ambition calme, ou inquiétude si la confiance baisse |
| Charge cognitive | Moyenne : 9 blocs aujourd'hui |
| Sait déjà | Son objectif approximatif |
| Veut | Voir si le conseil est satisfait et quoi améliorer |
| Craint | Une confiance qui chute sans cause visible |

**Cible émotionnelle** : « Le club est à moi, je vois où il va. »

---

## 3. Navigation

```
Club (rail)
  ├── Vue d'ensemble
  ├── Direction     (conseil, objectifs, demandes)
  ├── Infrastructures (devis, projets)
  ├── Staff         (encadrement, contrats, recrutement du staff)
  └── Histoire      (palmarès, jalons)
        liens vers : Finances, Vestiaire, Annuaire, Travail du club, Recrutement
```
**Mode** : écran plein.

| Entrée | Déclencheur |
|---|---|
| Rail, touche chiffre | clic |
| Objectif du conseil au Bureau | lien |
| Vigilance « Infrastructures » de Finances | lien |
| Fin de saison | alerte |

| Sortie | Destination |
|---|---|
| Voir le stade | écran du stade |
| Suivre les objectifs | Direction |
| Entrer au vestiaire | Vestiaire (Effectif) |
| Projets et devis des infrastructures | Infrastructures |
| Présenter une demande à la direction | Direction |
| Ouvrir l'annuaire, Travail du club | pages liées |
| Échap | historique |

---

## 4. Disposition

### 4.1 Wireframe 1280×720 (Vue d'ensemble, proposé)

```
┌────┬───────────────────────────────────────────────────────────────────────┐
│Rail│ ‹ Alder Fen XV › Club                              [Préparer →]       │
│    ├───────────────────────────────────────────────────────────────────────┤
│    │ [Vue d'ensemble][Direction][Infrastructures][Staff][Histoire]        │
│    ├────────────────────────────────┬──────────────────────────────────────┤
│    │ CONFIANCE DU CONSEIL           │ À DÉCIDER                            │
│    │      94 / 100   ● Solide       │ ! Aucun jalon fixé  [Fixer un jalon →]│
│    │  Objectif : Construire un      │ ! Devis infrastructures [Voir →]     │
│    │  effectif compétitif           │ ! Demande à la direction [Présenter →]│
│    │  Avancement : 0 match joué     ├──────────────────────────────────────┤
│    │  [Suivre les objectifs →]      │ VESTIAIRE                            │
│    ├────────────────────────────────┤ Moral 81/100 · Disponibles 40/40     │
│    │ INFRASTRUCTURES                │ Leader : Donal GANNON [Vestiaire →]  │
│    │ Centre d'entraînement 2/10     │                                      │
│    │ Cellule médicale 0             │                                      │
│    │ Académie 60/75                 │                                      │
│    ├────────────────────────────────┴──────────────────────────────────────┤
│    │ Pied : Espace Suite · 1 à 9 Menus · Échap Retour · Ctrl K · F1         │
└────┴───────────────────────────────────────────────────────────────────────┘
```

### 4.2 Zones
| Zone | Contenu | Taille | Défilable | Débordement |
|---|---|---|---|---|
| Onglets | 5 | pleine × 5 % | Non | — |
| Confiance + objectif | jauge 0-100, verdict en mot, objectif, avancement, lien | 45 % × 55 % | Non | texte de l'objectif sur 2 lignes + infobulle |
| À décider | 3 lignes d'action max | 50 % × 30 % | Non | « Voir tout » |
| Vestiaire | 3 chiffres | 50 % × 20 % | Non | — |
| Infrastructures | 3 lignes | 45 % × 25 % | Non | — |
| Bandeau hero (« Un club, une ambition », grand nom) | **réduit** à nom du club + stade (1 ligne) | 8 % | Non | — |

### 4.3 Composants
| Composant | Rôle | Existant ? |
|---|---|---|
| Jauge de confiance (demi-cercle) | niveau | Existant ; ajouter seuils (D6) et le mot (« Solide / Fragile / Menacé ») |
| Carte objectif | but de saison | Existant |
| Ligne « À décider » (icône + phrase + bouton) | action | **Nouveau**, rassemble 3 boutons éparpillés (jalon, devis, demande) |
| Carte vestiaire | moral, disponibles, leader | Existant |
| Ligne d'installation (nom, niveau n/10, lien) | amélioration | Existant |
| Onglets | navigation | Existant, aligner sur le motif unique d'onglets |

**Focus à l'ouverture** : onglet « Vue d'ensemble », puis première ligne « À décider ».

---

## 5. États

| État | Déclencheur | Visuel | Comportement |
|---|---|---|---|
| Début de carrière | avant le premier bilan | « Premier bilan à venir » + jauge neutre | Texte déjà présent ; ajouter « le conseil juge à partir de la journée 4 » si la règle existe (à vérifier) |
| Confiance solide | ≥ seuil haut | mot « Solide » + coche | — |
| Confiance fragile / menacée | ≤ seuil bas | mot + icône + cause (« 3 défaites de suite ») | Gabi explique |
| Aucun jalon fixé | `jalon` vide | « Aucune échéance fixée : fixe-en une avec la direction » + bouton | **Aujourd'hui : deux endroits disent « aucune échéance »** (objectifs et jalon) : un seul |
| Aucune décision à prendre | rien | « Rien à trancher cette semaine. » | — |
| Staff au complet / poste vacant | selon effectif | « Poste vacant : Analyste » + Recruter | — |
| Installation au maximum | niveau 10/10 | « Au maximum » | bouton grisé avec la raison |
| Chargement / erreur | moteur | « … » / message | — |
| Première fois | 1er affichage | note Gabi : « Voilà le tableau de bord du président » | une fois |

---

## 6. Interactions

### 6.1 Souris
| Cible | Action |
|---|---|
| Onglet | clic |
| Boutons de carte (→) | ouvrent la sous-page |
| Ligne d'installation | clic = détail et devis |
| Membre du staff | clic = fiche ; **Prolonger**, **Libérer** sur la ligne |
| Annuaire, Travail du club | pages liées |

### 6.2 Clavier
| Touche | Effet | Statut |
|---|---|---|
| Tab / Maj+Tab | onglets, lignes, boutons | à vérifier |
| Ctrl+Tab | onglet suivant | proposé |
| ← → sur la rangée d'onglets | change d'onglet | proposé |
| Entrée | active | existant |
| Échap | historique | existant |

### 6.3 Restrictions et actions destructives
| Action | Règle |
|---|---|
| **Libérer** un membre du staff | Bouton de style destructif, libellé « Libérer Rhys Ormerod », confirmation avec focus sur Annuler et coût de rupture écrit (interaction-patterns W1 et manquant n° 6) |
| Prolonger | confirmation légère (durée, coût) |
| Améliorer une installation | coût et délai écrits avant « Confirmer » |

---

## 7. Données

| Donnée | Source | Mise à jour | Format | Si manquant |
|---|---|---|---|---|
| Confiance du conseil | direction (`/100`) | chaque match et chaque semaine | 0-100 | « Premier bilan à venir » |
| Objectif de la saison | direction | à la saison | texte + avancement | « Aucun objectif » |
| Jalon du conseil | direction | à la demande | date + texte | « Aucune échéance fixée » |
| Vestiaire (moral, disponibles, leader) | vestiaire | semaine | entiers | « — » |
| Installations (niveau, devis) | club | à l'amélioration | n/10 | « — » |
| Staff (rôle, âge, contrat) | staff | semaine, contrats | liste | « Poste vacant » |
| Supporters (sentiment, abonnés) | club | semaine | 0-100 ; entier | masqué |
| Trésorerie, budget | `finance.cash`, `finance.wage` | semaine | euros | « — » |

L'écran ne modifie rien. Événements : améliorer l'installation, prolonger, libérer, présenter une demande (voir `decision_feedback.gd` : `club_facility_upgrade`, `extend_contract`, etc.).

---

## 8. Ce qu'on retire ou déplace

| Élément | Décision | Raison |
|---|---|---|
| Neuf blocs sur la Vue d'ensemble | Garder 4 (confiance+objectif, à décider, vestiaire, installations) | Bureau trop chargé = v4 rejeté ; 5 s |
| « L'encadrement » (liste de 4 staff) | Déplacer vers l'onglet Staff | Doublon : la Vue d'ensemble et l'onglet Staff le montrent chacun |
| Cartes « Vie du club » (supporters, abonnés, partenaire, nouvelles en 9 px) | Déplacer vers Histoire ; nouvelles dans le courrier | Texte illisible, hors besoin |
| « Budget 3,54 M€ » | Retirer : lien vers Finances | Doublon avec Finances |
| Cartes « Prochain jalon du conseil » + « Aucun jalon enregistré » | Fusionner dans « À décider » | Doublon (deux endroits) |
| Hero « Un club, une ambition » (grande bannière) | Réduire | ~190 px perdus |
| Numéros de section « 09 », « 10 » (Staff) | Retirer | Étiquettes de débogage |
| Deux « Entraîneur principal » (Malo Schwenke et Kurt Wootton) | Vérifier : deux postes distincts ou une donnée dupliquée ? | Confusion, à confirmer côté données |
| Étiquette « Carrière » sur chaque membre du staff | Remplacer par une information utile (contrat, rôle) ou retirer | Sens inconnu |
| Listes déroulantes sans titre (« Alder Fen XV », « Équipe du club ») | Les titrer (« Club », « Groupe ») | K1, G3 |
| « Mentorat des jeunes · 0 lien(s) » | « Mentorat : aucun duo » | Jargon |
| « Les identités du staff ne modifient ni ses capacités ni les résultats » | Retirer | Message technique, inutile au manager |
| Boutons Prolonger / Libérer identiques | Style destructif pour Libérer | Cohérence |

---

## 9. Animations
| Transition | Durée | Réduit |
|---|---|---|
| Changement d'onglet | fondu 150 ms | instantané |
| Jauge qui se remplit | 400 ms | valeur directe |
Aucune animation bloquante.

---

## 10. Accessibilité (Standard : D6, T1, T5, C1, K1)

| Texte | Fond | Seuil |
|---|---|---|
| Étiquettes secondaires (« Affluence prévue… », 9-10 px) | photo ou panneau | ≥ 12 px réels, 4,5:1 (C5 : voile derrière sur photo) |
| Texte posé sur la photo du stade (« Fenbank Ground ») | photo | voile ; 4,5:1 au pire pixel |
| Valeurs vertes (81/100, 94) | panneau | 4,5:1 |

| Élément | Risque | Mitigation |
|---|---|---|
| Jauge de confiance (vert → gris) | couleur | chiffre + mot + seuil marqué |
| Niveaux d'installation (points verts) | couleur | « 2/10 » écrit (déjà) |
| Alertes de contrat staff | couleur | texte « Contrat jusqu'à… » |

**Focus** : onglets (←→) → « À décider » → carte confiance → vestiaire → installations → pied.
**Annonces** : « Confiance du conseil 94 sur 100, solide. Objectif : … ».
**Charge cognitive** : 4 blocs, ≤ 7 flux.

---

## 11. Critères de réception

- [ ] La Vue d'ensemble n'affiche pas plus de 4 blocs.
- [ ] La confiance est lue en chiffre et en mot, sans couleur seule.
- [ ] Les décisions à prendre sont dans un seul bloc.
- [ ] « Libérer » demande une confirmation avec le nom, le coût et le focus sur Annuler.
- [ ] Aucun texte sous 12 px réels ; pas de texte sur photo sans voile.
- [ ] Parcours clavier complet, y compris le changement d'onglet.
- [ ] À 1280×720, aucun défilement horizontal, aucun bouton coupé.

## 12. Questions ouvertes

| Question | Propriétaire | Résolution |
|---|---|---|
| Direction, Infrastructures, Histoire : non capturés | ui-programmer | À capturer |
| Y a-t-il deux entraîneurs principaux dans les données ? | game-designer | Ouverte |
| Seuils de la confiance du conseil (solide / fragile / menacé) | game-designer | Ouverte |
| Le vestiaire est-il sous Club ou sous Effectif ? (aujourd'hui lié aux deux) | Léo | Ouverte |

## 13. Ajouts de la revue UX (19/11/2026)

**Seuils de la confiance du conseil (proposés, réglages de données à confirmer par game-designer)** : Solide ≥ 70 ; Fragile 40 à 69 ; Menacé < 40. Le mot et l'icône suivent ces seuils ; le chiffre /100 reste toujours affiché.

**Localisation (longueurs max, +40 % prévus)** : objectif de la saison 80 caractères sur 2 lignes ; ligne « À décider » 56 ; nom de membre du staff 26 ; libellé de bouton 26 (« Libérer Rhys Ormerod » : le nom complet reste, le reste du libellé passe en infobulle si trop long).

**Méthodes d'entrée (PC)**
- Souris : §6.1 ; boutons ≥ 32 px de haut.
- Clavier seul : Tab dans l'ordre de §10, ← → sur les onglets, Entrée ; aucun glisser-déposer.
- Manette : hors périmètre.

**Critères supplémentaires**
- [ ] La Vue d'ensemble s'affiche en moins de 400 ms.
- [ ] Rendu correct à 1280×720, 1920×1080 et 2560×1440.
