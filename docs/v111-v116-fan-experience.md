# V111–V116 — Expérience supporters et activité commerciale (simulation fictive)

Six versions groupées, distinctes des Espoirs V101–V104 et de la direction sportive V105–V110.

- **V111** : prévision de demande selon politique tarifaire, sentiment, campagnes et qualité d'accueil ; enregistrement commercial facultatif de créneaux fictifs 1–26, bornés à la jauge (pas des matchs réels).
- **V112** : choix des tarifs fictifs 12 / 20 / 30 € ; prévision de recette évolutive.
- **V113** : choix d'une campagne abonnements, coût unique par saison, progression du nombre suivi.
- **V114** : jusqu'à deux actions locales distinctes par saison, coût et gain de satisfaction bornés.
- **V115** : niveau de service une seule fois par saison ; coût fictif et effet sur les prévisions.
- **V116** : bilan de satisfaction, audience et recettes enregistrées, archive de 12 saisons, clôture idempotente.

## Invariants et intégration différée

Les entrées sont enregistrées dans l'état optionnel `v111to116`. Les anciennes sauvegardes restent prises en charge par initialisation différée, mais les états explicitement corrompus sont refusés. Les actions et la clôture ont un rollback si `save` échoue. La rotation annuelle est explicite et ne rejoue pas les dépenses. Les sorties du module ne modifient **aucune rencontre, aucun résultat, aucun calendrier ni les règles de la compétition**. Les recettes et coûts sont fictifs, uniquement dans `clubs[club].cash`. Les « créneaux » d'affluence sont des simulations commerciales, **pas des journées officielles ni des présences observées** ; aucune donnée extérieure n'est inventée.

Le module `dist/fan-experience-v111-v116.js` fournit `install(window)`, des commandes d'interface et un panneau pour le bureau, mais **n'est pas chargé par `dist/index.html`** dans cette PR. Le contrôle Chromium de ses véritables boutons et l'intégration éventuelle avec V101–V110 restent à réceptionner séparément. Fichiers propres à la PR seulement, sans changement du moteur, des saves centrales, de MATCH 3D, R&D, DATA/LNR ou calendrier.

Test dédié : `node tests/v111-v116-fan-experience.cjs` : choix, limites, budgets, duplicate rounds, rollback, export/import JSON, saison longue 17 ans et adaptateurs.

**Livraison** : PRODUCTEUR, PR DRAFT, aucun gate ni merge. État prêt à évaluer seulement après vérification CI du HEAD exact et réception future de l'interface intégrée.
