# Économie V2 — E3.1 prototype PC consultatif (R&D isolée)

**Statut : DRAFT, aucune activation.** Prototype généré en HTML indépendant avec `node ci/economy-v2-e31-run.cjs reference 827381`. Ouvrir `economy-v2-e31-reports/e31-reference-827381.html` dans un navigateur. Ni `dist/index.html` ni aucune sauvegarde ne référence le prototype.

## Sources et portée probatoire

- **Panneau haut : données effectivement observées par le moteur natif**, via E2.9/E3.0 : saisons, tours, pression indicative de trésorerie, transitions observées de sortie du seuil. Le seuil salarial de planification est purement illustratif, **ni dette ni faillite**, et ne prouve aucune causalité des décisions. Comptages issus de la vraie campagne de 15 saisons propre au profil et à la graine.
- **Panneau bas : décisions sur quatre fixtures E3.0 explicitement SYNTHÉTIQUES** (montants en unités abstraites, pas des euros du jeu) : maintien, échelonnement, suspension des seuls achats facultatifs. Aucun calendrier réel d'échéances et de projets identifiés dans E2.9 ne permet actuellement de simuler ces trois décisions en production. Le prototype ne prétend donc pas montrer une projection native personnalisée.
- **Comparaison avant/après** : maintenir les achats (avant), choix sélectionné (après), soldes finaux, écart, semaines en négatif, semaines de couverture obligatoire à risque, achats facultatifs différés, série temporelle. L'affichage sportif reste qualitatif : rythme des projets conservé, ralenti ou suspendu ; **pas de baisse de niveau inventée**, pas d'effets joueurs/matchs calculés.
- **Crise impossible** : lorsque les charges réellement dues épuisent les fonds, l'alerte indique qu'aucune suspension d'achats ne résout la situation. Crises récupérables grâce à un arbitrage facultatif ou des revenus déjà renseignés dans la fixture, jamais une dotation, dette ou un crédit imaginaires.

## Robustesse

- Aucune modification E1–E3.0, moteur, sauvegarde, PRODUCTEUR, MATCH 3D, DATA/LNR, gate, `main`.
- Page sans requête réseau, sans écriture ni action gameplay, injection JSON échappée, provenance native et parité vérifiées. La parité est constatée par E3.0, pas recalculée dans le navigateur.
- Workflow E3.1 : 3 profils × 2 graines × 15 saisons natives = **90 saisons demandées** ; tests Node E1–E3.1, artefacts JSON+HTML ; job Chromium séparé produit les **vraies captures 1920×1080 et 1440×900** avec vérification absence de débordement horizontal, erreurs JavaScript et fonctionnement des trois boutons. Ces résultats ne sont considérés comme prouvés **qu'après SUCCESS du HEAD exact**.
- `e31-viewports.json` relie captures, résolution et résultats de test.

## Réserves avant intégration

1. Identifier le calendrier **observé** des recettes certaines, échéances payables contractuelles et investissements réellement facultatifs par club, sans créer de passif legacy fictif.
2. Obtenir des coûts sportifs réellement mesurés : effets sur recrutement, infrastructures, formations, ambitions et satisfaction, testés sans pénalité arbitraire.
3. Prouver la jouabilité auprès de joueurs : lisibilité, compréhension de l'arbitrage et possibilité de redressement dans le moteur lui-même, pas seulement les fixtures.
4. Conserver l'intégrité des sauvegardes et résoudre séparément la limite de l'autorité anti-rollback offline de E2.9.

Aucun READY, gate ou fusion. La mise à disposition d'un fichier HTML en artefact ne livre pas une fonctionnalité dans le jeu.
