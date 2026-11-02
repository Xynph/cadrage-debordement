# V17 — raccordement natif PC

Le bureau existant (nav `dashboard`) accueille V17 via `v17-native-adapter.js`, sans second lien de navigation et sans modifier `manager.js` ni `game.js`. Ordre : `game.js`, moteur consultatif, bureau unifie, adaptateur.

`CDV17Native.snapshot()` fournit une copie superficielle des etats utiles de S et club(); fatigue par `physicalLoadValue`. Les matches n'ont pas de statistiques historiques importees et les tours de saison sans dates explicites ne recoivent **aucune date inventee** ; le panneau calendrier devra afficher les rencontres par numero de journee une fois le moteur V17 adapte. Les compositions sont consultatives ; la validation effective demeure `sheetErrors`, `slotEligible` et le jeu. Aucun effet de morale, entraînement, tactique, blessure ou sauvegarde ajouté.

Test d'integration à realiser : navigateur PC sur tableau de bord et bascule des panneaux, Node sur l'adaptateur, sauvegarde historique chargee et CI sur HEAD final. En cas de manque de données, les panneaux doivent le declarer. Pas de fusion producteur.