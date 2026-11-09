# Relecture des actions du match — 9 novembre 2026

## Conception
Le contact 0.7 est une garde de proximité, pas un plaquage attesté : les scènes
ne donnent ni plaqueur ni chute. Ce lot approfondit la compréhension des faits
réellement enregistrés sans modifier ces poses ou inventer une collision.
Depuis le Journal, une relecture ouvre un instantané local du journal filtré,
avec navigation chronologique, filtre « moments clés » structuré et schéma
origine–destination du ballon. Minute, équipe, score et consigne viennent du fait.
Les données manquantes sont explicites, les points hors terrain ne sont pas affichés.
Le match reste à son état courant : aucune commande worker, aucune sauvegarde,
aucun replay 3D ou résolution de match n'est produit par cette consultation.

## Plan
- Tester l'entrée réelle du Journal et l'ouverture clavier.
- Ajouter le lecteur local et le schéma de position à partir de scene.from/to.
- Tester navigation, filtre, données absentes, instantané figé et immuabilité.
- Recevoir Godot Linux aux dimensions 720p–1440p et le journal existant.

## Réception
- Test nouveau d'abord rouge sur l'absence du lecteur ; test de changement de
  contexte ensuite rouge sur la conservation du lecteur de l'ancienne carrière,
  puis correctif de fermeture dans `_bind_current_context`.
- Godot4.7.2 Linux + Node22.23.4 : **43 contrôles réussis**, clavier réel,
  navigation, filtres, données absentes/inconnues, coordonnées hors terrain,
  snapshot figé, fermeture après changement de contexte/navigation. Le modèle
  projeté (horloge comprise) et les octets du profil restent identiques.
  Preuves locales : `/tmp/cd-action-review-xFDWIb/`.
- Régression Journal existante : **297 contrôles réussis**, dont géométrie
  720p–1080p et navigation/import ; `/tmp/cd-match-journal-tyeXlV/`.
- Contact0.7 : test géométrique réussi, aucune modification des poses ;
  `/tmp/cd-match-contact07-rLIVLQ/`.
- Quatre captures graphiques Xvfb/llvmpipe à720p/900p/1080p/1440p,
  `/tmp/cd-action-review-tu04z1/review-*.png`. Captures720p et1080p inspectées :
  contenu, navigation et fermeture lisibles. Elles précèdent uniquement la
  suppression des décimales inutiles et la fermeture sur changement de contexte.
  Les41 contrôles de cette version passent aussi graphiquement, **mais le runner
  graphique échoue** sur les erreurs d'environnement audio : aucune carteALSA,
  `libspeechd.so.2` absente et synthèse vocale non initialisée. Ces erreurs ne
  sont pas masquées ; aucune recette audio/Windows ni plaquage animé revendiqué.

Reproduction depuis un projet préparé (`scripts/build-godot-prototype.py
--stage-only --node <Node22>`, import SDK), avec les répertoiresXDG accessibles :

```bash
CD_GODOT_EXE=<Godot4.7.2> node tests/godot-match-action-review.cjs
CD_GODOT_EXE=<Godot4.7.2> node tests/godot-match-journal.cjs
CD_GODOT_EXE=<Godot4.7.2> node --test tests/godot-match-contact07.cjs
```

Le runner de relecture signale unSKIP explicite si le SDK est absent ; sa
réception ci-dessus a réellement utilisé le SDK. `CD_ACTION_REVIEW_GRAPHICS=1`
active les captures avec un affichageX11 disponible.

## Raccordement et limites
Aucun raccord du worker, du manifeste des domaines ou de la sauvegarde.
Le bouton `RELIRE` est ajouté auJournal déjà accessible en match. Le lecteur
copie les faits correspondant aux filtres courants ; son filtre de momentsclés
n'infère rien du texte. Une ancienne action non structurée reste lisible mais
ne gagne pas une position, une équipe ou un type inventé. Le lecteur n'identifie
pas un plaqueur et ne reconstitue pas les déplacements des30joueurs.
Aucun champ persistant, budget, RNG ou horloge n'est ajouté/modifié.
