# Three Contextual Rooms Implementation Plan

**Goal:** Raccorder presse, infirmerie et direction à trois scènes natives utiles.
**Architecture:** Trois vues et trois décors indépendants ; directeur commun pour priorité, fermeture et points d’entrée. Les domaines existants restent autorités.
**Tech Stack:** Godot4.6, GDScript, vrai worker Node, ressources locales CC0.
**Spec:** docs/superpowers/specs/2026-11-10-three-contextual-rooms.md

## Global constraints
- Six déclarations des causeries et leur ton intrinsèque restent inchangés.
- Identité réelle du club et portraits existants ; panneaux publicitaires Oval Legacy27 inchangés.
- Pas de données, diagnostics, événements ni effets inventés ; affichage indisponible si aucune source.
- Aucun accès concurrent avec match/causerie/entretien prioritaire ; visite pure.

## Interfaces
Vues extendsControl, var director:Node, update_frame(model:Dictionary,data:Dictionary={}) ->void. Décors extendsNode3D, var club:Dictionary selon les patterns rooms. Chaque composant ne modifie que ses fichiers dédiés. Parent seul édite director.gd et room_factory.gd ; il confirme les données/conditions après les reconnaissances.

## Tasks
- [ ] Presse : press_room_view.gd, rooms/press_room.gd, tests/godot-press-room.gd. Tester contexte/questions autorisées, attente, refus, résultat, visite pure et limites720p.
- [ ] Infirmerie : medical_room_view.gd, rooms/medical_room.gd, tests/godot-medical-room.gd. Tester joueur réel, données absentes, charges autorisées et aucun gain médical par visite.
- [ ] Direction : board_room_view.gd, rooms/board_room.gd, tests/godot-board-room.gd. Tester mesures/objectifs réels et décisions disponibles, aucune fausse requête.
- [ ] Parent : confirmer contrats exacts issus du code, intégrer factory/directeur/points d’entrée, actualiser commandes seulement si nécessaire et validé.
- [ ] QA : wrapper Godot opt-in et parcours réels/visite pure/erreurs/identité/fermeture à1280×720 et1600×900 ; capturer les trois lieux.
- [ ] Revue indépendante, PR dédiée coordonnée avec525 ; attendre fusion525 puis supprimer la dépendance au stack proprement, sans recopier les changements de525.

## Review focus
Contexte périmé entre ouverture et réponse : refus serveur visible ; joueur/staff parti : pas d’identité fabriquée ; sauvegarde pendant visite : pas d’état fantôme ; match lancé pendant visite : priorité immersion match ; texte long/sans logo : repli neutre et décisions toujours accessibles.

## Contrat obligatoire ajouté après précision utilisateur
- Domaine club-meetings.cjs / tests/native-club-meetings.cjs : état optionnel strict, scènes persistantes, file/reçus bornés, programmation par faits réels, guards/observe purs hors mutations acceptées.
- Projection model.clubLife.clubMeetings.scene : id,kind,context,playerId?,reason,completed,ackAllowed. Vue reçoit les mêmes champs plus meetingId=id.
- club_meeting_ack {meetingId} : confirmation des priorités actuelles ou lecture médicale seulement si ackAllowed ; presse requiert sa vraie commande complète. club_meeting_continue {meetingId} uniquement après completed.
- Presse : accueil/semaines effectivement avancées si conférence disponible. Médical : épisodes nouveaux de blessure/reprise, pas chaque clic/semaine de blessure inchangée. Direction : priorités initiales, bilans périodiques et objectifs/faits nouveaux, aucune dépense forcée.
- Parent seul raccorde native-systems/worker/main/director. Tester redémarrage avant/après décision, imports anciens, commandes détournées, refus/replay/rollback disque, observation/visite sans effets.
