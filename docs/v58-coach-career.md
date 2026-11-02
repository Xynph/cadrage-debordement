# V58 — Mobilite des entraineurs (hors match)

Le module **independant** `dist/coach-career.js` s'appuie sur `CDCoachMarket` existant sans dupliquer ni modifier `dist/coach-market.js`. Il fournit : profil de coach, liste des postes vacants, offres classees, negociation contractuelle, licenciement, embauche, mutation entre clubs, historique et attribution IA deterministe des postes disponibles. Aucun comportement n'est branche dans l'interface ou les sauvegardes officielles. Aucune modification du moteur de match ou des effectifs.

**Contrat de raccordement pour l'integrateur :** mapper identifiants club/coach, salaire dans une unite financiere commune avec le budget, et evenement `hire`, `dismiss`, `move` vers les mouvements de personnel effectifs. Le debit de salaire est illustratif et doit etre adapte a un contrat annuel et au registre financier reel ; ne pas effectuer de double debit. Les profils, reputations et budgets des fixtures sont fictifs. Prevoir le poste du joueur, sa fin de contrat et les sauvegardes anciennes avant activation.

**Limites :** ce module ne licencie personne dans une vraie partie, ne genere pas encore de candidature UI, ne migre aucune sauvegarde ; la disponibilite IA est determinee sans aleatoire. Les negociations sont des controles de budget et duree, pas un systeme de discussions narratives.

Tests : `tests/v58-coach-career.cjs` et test V48 existant ; rapport JSON via CI. L'autre compte garde l'exclusivite de l'integration, du jeu et des fusions.
