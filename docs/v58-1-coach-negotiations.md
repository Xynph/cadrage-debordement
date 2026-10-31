# V58.1 — Negotiations independantes des entraineurs
Module `dist/coach-negotiations.js` distinct des effectifs V59. Il ajoute candidatures, offres concurrentes, contre-propositions, budget salarial, engagements a duree bornee, refus, demissions, licenciements, evolution de reputation, historique et selection deterministe par les clubs.

**Contrat de raccordement :** les donnees de simulation ne sont pas des sauvegardes officielles; adapter managerId, clubId, montants et contrats aux donnees reelles du jeu lors de la revue par le compte integrateur. Aucun code de recrutement joueur n'est modifie. Aucun changement automatique de club du joueur, ni interface, ni transaction dans la sauvegarde native.

Tests V58.1: 10 scenarios independants y compris 15 saisons et reprise JSON. CI execute aussi V58. Budget : controle de plafond seulement; aucune depense reelle ni indemnites de rupture gerees. L'acceptation d'une contre-proposition est volontairement conditionnee au plafond communique par l'integrateur.

L'autre compte est seul responsable de l'integration dans le vrai jeu et de la fusion.
