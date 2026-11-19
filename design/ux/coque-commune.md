# UX Spec : Coque commune (rail, barre haute, zone de contenu)
> **Status**: In Review · **Author**: Léo (décisions du 19/11/2026) + ux-designer (autonome) · **Last Updated**: 2026-11-19
> **Journey Phase(s)**: carrière Monde, 16 écrans de gestion (titre, chargement, match en sortent)
> **Screen / Flow Name**: `CoqueCommune` (code actuel : `native/godot/ui/immersive08/shell.gd`)
> **Platform Target**: PC, souris + clavier, pas de manette ; référence 1920×1080, coque placée en pixels 2560×1440 (×4/3)
> **Related GDDs**: aucun GDD propre ; `design/player-journey.md` · **Related ADRs**: aucun
> **Related UX Specs**: `interaction-patterns.md` (N1 à N6, F5, G1, G2), `04-bureau`, `05-reception`, `07-effectif`, `16-calendrier-classement`, `18-club`
> **Accessibility Tier**: Standard (exception de densité de Léo, `design/accessibility-requirements.md`) · **Template**: UX Spec
> **Maquette validée**: `direction-artistique/interface/revue-20261119/frag/coque-retouchee-v2.html` (+ `apercus/coque-retouchee-v2.png`)
- **R1** (Léo) : tout ce qui ressemble à un lien, une ligne, un nom, un chiffre ou un bouton ouvre quelque chose ; jamais de zone qui semble cliquable et ne fait rien.
- **R2** (Léo) : jamais de petite fenêtre, un clic change d'écran. Exceptions : mini-fiche au survol d'un nom de joueur (ou « i »), menus déroulants (filtres, tri), menu ouvert par Échap, infobulle « Équilibre par poste », sélecteur de compétition, confirmation « Libérer ».
---
## 1. Purpose & Player Need
- **Besoin** : savoir à tout instant où l'on est dans la saison de son club, aller n'importe où en un geste, faire avancer le temps sans chercher le bouton.
- **Le joueur veut** : changer de section, revenir en arrière, chercher un nom, sauvegarder, continuer, sans jamais ouvrir de petite fenêtre.
- **Le jeu veut** : un cadre unique et stable qui dit le club, la date, l'état de sauvegarde et ce qui bloque l'avancée.
## 2. Player Context on Arrival
- Avant : carrière ouverte, ou match / page terminé. Émotion : calme à tendu (veille de match). Charge : moyenne (date, courrier, composition).
- Connu : club, division, rang, date, non lus. Veut : lire le courrier, ouvrir une section, Continuer. Craint : perdre sa partie, avancer sans valider, ne pas retrouver une page.
- **Cible émotionnelle** : un poste de commandement où tout est là, rien ne crie, un seul bouton or.
## 3. Navigation Position
```
Carrière (Monde) └── Coque commune (toujours présente)
   ├── Rail : 9 sections | Presse, Sélections | Carrière, Réglages, Sauvegarder
   ├── Barre haute : Menu, Précédent/Suivant, fil, Recherche, Date, Gabi, Continuer
   └── Contenu : un écran à la fois (Bureau, Effectif, ... Recherche, Réglages, Fiche du club, Aide de Gabi)
```
- **Modal** : non modale ; seul le menu pause (Échap / Menu) est un overlay sur voile 70 %.
## 4. Entry & Exit Points
| Déclencheur | Destination | Transition | Données | Notes |
|---|---|---|---|---|
| Entrée du rail, touches 1-9 | Section | Contenu change, coque fixe | route | Entrée active suit |
| En-tête (écusson + nom), 1er morceau du fil | Fiche du club | idem | club courant | |
| Morceau du fil | Page du morceau | idem | route | Dernier morceau : recharge la page à l'arrivée |
| Précédent / Suivant (Alt+← / →) | Page de l'historique | idem | entrée d'historique | |
| Recherche + Entrée | Écran Recherche | idem | texte | Pas de liste déroulante |
| Clic date | Calendrier au jour courant | idem | date | |
| Médaillon, F1 | Écran Aide de Gabi | idem | écran d'origine | Écart, voir Q1 |
| Continuer, Espace | Calcul puis écran d'événement ; bloqué : écran qui bloque | — | — | |
| Sauvegarder, Ctrl S | Aucun | — | — | Met à jour « Sauvegardé » |
| Menu, Échap | Menu pause | Voile 100 ms | écran courant | Reprendre / Échap rend le focus à l'origine ; Réglages ferme le menu et ouvre l'écran ; Accueil / Quitter : confirmation hors coque après sauvegarde |
## 5. Layout Specification
**5.1 Wireframe (1920×1080)**
```
┌──────────────┬─────────────────────────────────────────────────────────────────┐
│[ecu] CLUB    │[☰ Menu Échap][←][→] Club / Section / Page [Rechercher Ctrl K] mar.17 nov.·J9 (G)F1 [CONTINUER Espace] │48
│ div · rang   ├─────────────────────────────────────────────────────────────────┤
│ ▬▬▬▬▬▬▬▬     │                                                                 │
│ Bureau       │                                                                 │
│ Réception [4]│                                                                 │
│▌Effectif     │              { CONTENU 1640×984, marges 24 }                    │
│ Tactique ... Formation (62 px/ligne)                                           │
│ ──────────   │                                                                 │
│ Presse, Sélections (54 px)                                                     │
│ ↺ Carrière · ⚙ Réglages · ↓ Sauvegarder [Ctrl S]                               │
│ ✓ Sauvegardé mar. 17/11                                                        │
└──────────────┴─────────────────────────────────────────────────────────────────┘
   232 px
```
**5.2 Zones**
| Zone | Contenu | Taille 1920 (réf. 2560) | Défile | Débordement |
|---|---|---|---|---|
| Rail | `panneau`, pleine hauteur | 232×1080 (309×1440) | Non | Lignes 62 → 44 px min si hauteur insuffisante, puis le groupe central défile ; pied fixe |
| En-tête | écusson, nom, « division · rang », liseré `club-trait` 3 px incliné | 232×88 (309×117) | Non | Nom sur 2 lignes, puis 17 px, puis infobulle |
| Barre haute | `panneau`, filet bas | 1688×48 (2251×64) | Non | Le fil perd ses premiers morceaux ; Recherche rétrécit (min 220) |
| Contenu | `fond`, marges 24 | 1688×1032 (2251×1376) ; utile 1640×984 | Selon écran | Propre à l'écran |
**5.3 Composants**
| Composant | Type | Rôle | Réutilise |
|---|---|---|---|
| En-tête de club | Bouton large | Identité, clic = fiche du club | Nouveau (remplace logo = menu pause) |
| Entrées ×9 (sans numéro), Presse, Sélections | Lignes-boutons 62 / 54 px | Aller | N1 révisé |
| Badge non lus | Parallélogramme ; 0 = retiré, 100+ = « 99+ » | Nombre de messages (Réception) | Nouveau |
| Carrière, Réglages, Sauvegarder « Ctrl S » | Lignes-boutons 54 px + pictogramme | Aller / sauver sans fenêtre | N1, F5 remplacé |
| Ligne « ✓ Sauvegardé <date> » | Texte d'état | Retour de sauvegarde | F4, F5 |
| Menu « Échap » | Bouton, contour 1 px | Menu pause | Nouveau |
| Précédent, Suivant | Boutons carrés | Historique | N3 révisé |
| Fil d'Ariane | Liens | Se repérer, remonter | N3 révisé |
| Recherche « Ctrl K » | Champ (rayon 2 px) | Saisie, Entrée = résultats | N4 remplacé |
| Date + journée | Lien | Calendrier | N3 |
| Médaillon de Gabi « F1 » | Bouton | Aide | G1 révisé |
| Continuer « Espace » | Bouton `or` | Avancer ; bloqué : ouvre la cause | N6 révisé |
| Menu pause (480 px) | Overlay | Reprendre, Sauvegarder, Charger, Réglages, Accueil, Quitter | Charte §7.1 |
- **Focus à l'ouverture** : premier élément du contenu (K8) ; à l'ouverture de la carrière : Continuer ; après le menu : l'élément d'origine.
**5.4 Hiérarchie** : 1. **Continuer** (seul aplat or, dit ce qui bloque). 2. **Où suis-je** : entrée active, fil, club + division · rang. 3. **Ce qui attend** : badge, date, journée. 4. **Sur demande** : recherche, Gabi, Menu, sauvegarde (discrète en `ivoire-2`).
## 6. States & Variants
| État | Déclencheur | Visuel | Comportement |
|---|---|---|---|
| Repos / survol | Souris | `panneau` / `panneau-2`, liens soulignés | Infobulle 400 ms |
| Actif (rail) | Page de la section (ou de sa parente) | `panneau-3` + filet `ivoire` 3 px incliné 10° | `aria-current` ; une seule entrée |
| Focus clavier | Tab, flèches | Contour `ivoire` 2 px décalé 2 px | Distinct du survol |
| Précédent ou Suivant sans historique | Bord de l'historique | `ivoire-3`, flèche barrée, infobulle « Pas de page précédente » | Désactivé explicite |
| Sauvegarde en cours | Ctrl S, Sauvegarder | « Sauvegarde… » `ivoire-2` (après 350 ms) | Sauvegarder inactif ≤ 1 s |
| Sauvegardé | Fin d'écriture | « ✓ Sauvegardé mar. 17/11 » `v` | Infobulle manuelle / automatique |
| Échec | Erreur d'écriture | « ! Échec de la sauvegarde · Réessayer » `d` | Clic = nouvel essai ; reste jusqu'au succès |
| Continuer prêt / en cours / moteur arrêté | — / calcul / panne | « CONTINUER · Espace » / ovale tracé qui se remplit / « RELANCER » | Échap arrête le calcul |
| Continuer bloqué | Composition à valider, etc. | Raison ≤ 22 car. à la place d'« Espace », « ! » `nuit` | Clic ou Espace ouvre l'écran qui bloque (R1) |
| Recherche vide / sans résultat | Entrée | Invite « Un joueur, un club, un écran… » / « Aucun résultat pour « x » » + lien Bureau | |
| Chargement / données de club absentes | Ouverture de carrière ; Pack non chargé | Coque posée à vide ≤ 200 ms (textes vides, `panneau`) puis valeurs ; si absentes : « Club », plaque `club` + initiales, « — · — » | Coque utilisable ; rien de figé |
| Compact | 115-130 % sur 1080 | Lignes 62 → 44 px, police inchangée | Puis défilement du groupe central |
## 7. Interaction Map
**7.1 Navigation**
| Entrée | Action | Réponse | Notes |
|---|---|---|---|
| Clic entrée du rail | Ouvre la section | Filet glisse 100 ms, contenu entre | Son : tic |
| Touches 1 à 9 | Bureau, Réception, Effectif, Tactique, Recrutement, Club, Finances, Compétitions, Formation | idem | **Écart** : Réception était 1, Bureau 2 ; plus de numéro affiché, la touche est dite dans l'infobulle (« Effectif · touche 3 ») et dans Réglages |
| Tab / Maj+Tab | Barre haute → rail → contenu | Focus | Un seul arrêt pour le rail, ↑ ↓ dedans |
| Alt+← / Alt+→ | Page précédente / suivante | idem | Inactif si champ focalisé |
| Ctrl K, Ctrl F | Focus dans Recherche, texte sélectionné | Contour de focus | Aucune fenêtre |
| Échap | (1) ferme fenêtre ou menu déroulant ; (2) revient d'une fiche ou sous-page ; (3) ouvre le menu pause | — | Un appui = une action ; en match : pause |
**7.2 Actions**
| Entrée | Contexte | Action | Notes |
|---|---|---|---|
| Clic Menu | tout écran | Menu pause | Puce « Échap » omise sur sous-page (le pied d'écran dit « Échap Retour ») |
| Clic en-tête | tout écran | Fiche du club (`panneau-3` tant qu'affichée) | Infobulle « Fiche du club » |
| Clic morceau du fil | tout écran | Page du morceau | **Écart N3** : tous cliquables |
| Entrée dans Recherche | champ | Écran Recherche, 1er résultat focalisé | Échap : vide le texte, puis rend le focus au contenu |
| Clic ligne de résultat | Recherche | Ouvre la fiche ou l'écran | Lignes ≥ 32 px |
| Clic date / médaillon, F1 | barre | Calendrier / Aide de Gabi | |
| Clic Continuer, Espace | barre | Avance ou ouvre la cause du blocage | Ctrl J = +1 jour (infobulle) |
| Clic Sauvegarder, Ctrl S | rail | Sauve directement | Aucune boîte |
| Clic Réglages | rail | Écran dans la coque | **Écart** : n'est plus une fenêtre |
| Clic droit, molette | partout, rail compact | Clic droit sans effet (volontaire) ; molette défile le groupe central | |
**7.3 Restrictions** : champ focalisé : raccourcis à une touche, Espace et Alt+flèches inactifs. Menu pause ouvert : coque inerte. Continuer en cours : seul Échap actif. Intro et match immersif : coque absente.
## 8. Data Requirements
| Donnée | Source | Mise à jour | Propriétaire | Absent |
|---|---|---|---|---|
| Nom, écusson, couleurs du club | Données du club (jeu de base ou Pack Rugby Réel) | Chargement de carrière | Système club | « Club », plaque + initiales |
| Division, rang | Classement | Après chaque match | Système compétitions | « — · — » |
| Date, journée | Calendrier | À chaque jour | Système calendrier | « — » |
| Non lus | Courrier | À chaque message reçu ou lu | Système courrier | Badge retiré |
| État et date de sauvegarde | Sauvegarde | Début et fin d'écriture | Système de sauvegarde | « Pas encore sauvegardé » |
| Historique | Navigation | À chaque changement de page | Contrôleur de navigation | Boutons désactivés |
| Raison de blocage, libellé de Continuer | Progression (`primary_text`) | À chaque changement d'état | Système de progression | « Continuer » |
| Portrait de Gabi | Banque d'images | Chargement | Système d'images | Initiale « G » |
| Résultats de recherche | Index joueurs, clubs, écrans, staff | À la validation | Systèmes concernés | Message vide |
- La coque ne possède aucune donnée ; rien de réel dans le dépôt.
## 9. Events Fired
| Action | Événement | Payload | Récepteur |
|---|---|---|---|
| Rail, 1-9, fil, en-tête | `nav_requested` / `club_sheet_requested` | {route, source} / {club_id} | Navigation |
| Précédent / Suivant | `history_step` | {sens} | Navigation |
| Entrée dans Recherche | `search_submitted` | {texte} | Navigation, index |
| Date, Gabi | `calendar_requested`, `help_requested` | {date} / {route} | Navigation |
| Continuer | `advance_requested` ou `blocker_open_requested` | {} / {cause} | Progression |
| Sauvegarder, Ctrl S, menu | `save_requested` | {source} | Sauvegarde (réponse `save_finished` / `save_failed`) |
| Menu, Échap | `pause_menu_requested` | {} | Principal |
## 10. Transitions & Animations
| Transition | Type | ms | Easing | Interruptible | Mouvement réduit |
|---|---|---|---|---|---|
| Entrée de page (contenu seul) | Glissement 12 px axe incliné + fondu, cascade 30 ms (6 blocs max) | 160 | ease-out | Oui | Fondu 100 ms |
| Marqueur actif | Filet glisse | 100 | ease-out | Oui | Instantané |
| Menu pause | Voile + fondu | 100 | linéaire | Oui | Instantané |
| Continuer en cours | Ovale tracé qui se remplit | durée du calcul | linéaire | Oui (Échap) | Ovale fixe + pourcentage |
- La coque ne glisse jamais ; « Transitions : Aucune » = tout instantané.
## 11. Input Method Completeness Checklist
- **Clavier** : [x] tout atteignable (Tab, flèches du rail) ; [x] ordre barre → rail → contenu ; [x] chaque action souris a son équivalent (1-9, Alt+flèches, Ctrl K, F1, Espace, Ctrl S, Échap) ; [x] focus toujours visible ; [x] focus piégé dans le menu pause, Échap sort ; [x] Échap ne quitte jamais le jeu.
- **Manette, tactile** : non applicables.
- **Souris** : [x] survol défini (6, 7) ; [x] cibles ≥ 32 px de haut ; [x] clic droit sans effet, volontaire ; [x] molette sur le rail compact seulement.
## 12. Accessibility
| Texte | Fond | Requis | Ratio | OK |
|---|---|---|---|---|
| Entrées `ivoire` | `panneau` / `panneau-3` (actif) | 4,5 | 15,78 / 12,85 | [x] |
| « division · rang », date, touches `ivoire-2` | `panneau` / `panneau-2` / `panneau-3` | 4,5 | 8,86 / 8,16 / 7,22 | [x] |
| Badge `nuit` | `ivoire` | 4,5 | 18,18 | [x] |
| Continuer `nuit` | `or` | 4,5 | 12,18 | [x] |
| « ✓ Sauvegardé » `v` / « ! Échec » `d` | `panneau` | 4,5 | 8,59 / 6,14 | [x] |
| Initiales `ivoire` | `club` défaut | 4,5 | 8,27 | [x] |
| Contours Menu, Recherche `ivoire-3` | `panneau` | 3 (non textuel) | 4,92 | [x] |
- **Daltonisme** : ✓ toujours avec le mot « Sauvegardé » ; échec avec « ! » et le mot ; badge sans couleur ; le club jamais porteur seul. Mode daltonien : `v` → #5AA9E6.
- **Ordre de focus** : 1 Menu, 2 Précédent, 3 Suivant, 4 morceaux du fil, 5 Recherche, 6 Date, 7 Gabi, 8 Continuer, 9 En-tête, 10 entrées du rail (↑ ↓), 11 Presse, Sélections, Carrière, Réglages, Sauvegarder, 12 contenu. Maj+Tab depuis le contenu revient au rail.
- **Annonces** : page change (« Effectif, page ouverte », après l'entrée) ; fin d'écriture (« Partie sauvegardée » / « Échec de la sauvegarde ») ; au focus (« Continuer indisponible : composition à valider », « Réception, 4 messages non lus »).
- Lecteur d'écran hors palier engagé : ces textes sont les étiquettes accessibles si le moteur les prend. **Charge cognitive** : 6 flux (section, fil, date, non lus, sauvegarde, Continuer) < 7±2.
## 13. Localization Considerations
- Chaînes de localisation, expansion 40 %, RTL non ciblé, aucun texte dans une image.
| Texte | Base | Max car. | Débordement | Risque |
|---|---|---|---|---|
| Entrée du rail | 12 (« Compétitions ») | 18 | Jamais « … » ; sous 12 px réels interdit | Moyen |
| Nom du club | 12 | 28 sur 2 lignes | 17 px puis infobulle | Élevé (noms réels longs) |
| « division · rang » | 20 | 26 | 12 px puis infobulle | Moyen |
| Fil d'Ariane | 40 | 56 | Perd les premiers morceaux | Moyen |
| Raison de blocage | 20 | 22 | Raccourcie à la source | Élevé |
| « Sauvegardé mar. 17/11 » | 22 | 26 | 12 px | Moyen |
## 14. Acceptance Criteria
- [ ] **Perf** : coque visible ≤ 200 ms après l'entrée en carrière ; première image d'une page ≤ 200 ms.
- [ ] **Layout** : à 1920×1080, rail 232, barre 48, contenu 1688×1032 ; à 2560×1440, 309 / 64 / 2251×1376 ; sans recouvrement.
- [ ] À 1280×720 et à 130 % : aucun texte sous 12 px réels, nom du club et raison de blocage non tronqués ; nom de 28 caractères sur 2 lignes.
- [ ] Aucun numéro devant une entrée ; ordre exact : Bureau, Réception, Effectif, Tactique, Recrutement, Club, Finances, Compétitions, Formation | Presse, Sélections | Carrière, Réglages, Sauvegarder.
- [ ] Chaque morceau du fil, dernier compris, est cliquable ; aucun élément de la coque n'est inerte au clic.
- [ ] Ctrl K, Réglages, Sauvegarder n'ouvrent aucune fenêtre ; Entrée dans Recherche ouvre l'écran Recherche ; un seul aplat `or` : Continuer.
- [ ] Tout atteignable au clavier ; touches 1-9 selon l'ordre ci-dessus ; Échap : un appui = une action.
- [ ] Nom, écusson, division, rang lus des données du club (changer de club change la coque) ; Sauvegarder met à jour « ✓ Sauvegardé <date> » en < 1 s, l'échec affiche « ! » et « Réessayer ».
- [ ] Paires de la section 12 ≥ leur ratio ; en niveaux de gris, tous les états restent distinguables ; mouvement réduit : plus de glissement.
## 15. Open Questions
| Question | Owner | Délai | Résolution |
|---|---|---|---|
| Q1 : l'aide de Gabi (F1) était une bulle, hors exceptions de R2 : devient l'écran « Aide de Gabi ». Valider ? | Léo | Avant implémentation | Décidé en autonomie : écran (R2 sans exception pour la bulle) ; révisable sans refonte |
| Q2 : rail en sélection nationale (3 entrées) ; place d'Entraînement (absent de la liste de Léo, présent dans le code) | Léo / game-designer | Avant implémentation | Déféré (hors de cette coque : dépend du contenu des sections) ; Entraînement provisoirement sous Tactique |
| Q3 : bouton « +1 j » (N6) absent de la maquette | Léo | Avant implémentation | Décidé en autonomie : Ctrl J, infobulle de Continuer, Calendrier (maquette validée sans bouton) |
| Q4 : confirmations W1/W2 hors exceptions de R2 (sauf « Libérer ») | Léo | Avant implémentation | Déféré : ces boîtes appartiennent aux écrans qui les appellent, pas à la coque |
- **Écarts** à répercuter dans charte et motifs : N1 (sans numéro, Réception 2e, Entraînement retiré), N3 (fil cliquable), N4 (palette → écran), N5 (touches 1-9), N6 (bloqué = ouvre la cause), F5 (disquette → ligne du rail), G1 (plus de remarque dans la barre), charte §3C (contour 1 px `ivoire-3` sur Menu, Recherche, Précédent/Suivant, repris de la maquette), charte §7.1 (rail à entrées 18/24 au lieu de 13/18).
