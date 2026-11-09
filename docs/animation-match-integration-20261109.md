# Crochet, passe et stade en match

Ce chantier reprend les trois démonstrations de la PR #431. La présentation des portages et des séquences de jeu au large s’appuie sur les actions existantes et le XV en jeu. Les données de présentation ne changent ni l’issue d’une action ni les règles du match.

- **Crochet** · rendre lisible le changement d’appui d’un porteur pendant une progression. Vérifier le déclenchement dans une séquence réellement produite par le moteur et le retour à la course.
- **Passe** · identifier deux joueurs et montrer le transfert du ballon pendant une séquence de jeu au large. Vérifier les deux sens du terrain, la reprise d’un ancien direct et l’absence de confusion avec les réceptions de coups de pied.
- **Stade** · conserver le jour par défaut et permettre de choisir la soirée dans les préférences. Vérifier le réglage dans le direct 3D.

## Raccord retenu

- Le crochet se déclenche sur une progression d’au moins huit mètres du porteur identifié, avec le plan équilibré. Le sens de l’inclinaison alterne selon la minute. Le rendu conserve la trajectoire et le ballon. L’ancrage durable d’un pied est mesuré sur la démonstration à vitesse modérée.
- Une progression au large fournit les joueurs présents au moment de l’action. Le rendu choisit deux coéquipiers, met le ballon en place progressivement, puis montre le lâcher, le vol et la prise derrière le point de lâcher. Le receveur reprend le portage vers le point d’arrivée enregistré. La transition entière dure 0,30 s pour tenir dans le rythme du direct, avec des déplacements schématiques. Ce détail de mise en scène est calculé à la lecture du journal. La [loi 11 de World Rugby](https://passport.world.rugby/laws-of-the-game/laws-by-number/11-knock-forward-or-throw-forward) impose le contrôle du sens de la passe.
- Les deux gestes se jouent une fois par action, en mode normal et sur le direct. La pause et le réglage de mouvements réduits les désactivent. La reprise d’un match sauvegardé conserve son état en pause.
- Dans **Paramètres → Affichage → Éclairage du stade**, choisir **Jour** ou **Soirée**. Le réglage s’applique au match 3D et se conserve localement avec le choix du moniteur. La revue d’action conserve son terrain 2D.

## Recette

Les recettes graphiques Windows sur ce PC se lancent avec `--screen 1` et un profil isolé. Les tests ci-dessous exécutent les séquences déterministes et les contrôles de rendu sans affichage avec `CD_GODOT_EXE` pointant vers le SDK Godot.

```powershell
node --test tests/animation-live-cut.cjs tests/match-pass-live.cjs tests/godot-preferences.cjs
```
