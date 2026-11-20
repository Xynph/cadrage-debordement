# Écrans de transferts — décisions de Léo (19/11/2026)

Point de départ du chantier « écrans de transferts » (à mener dans une conversation dédiée).

## Ce qui est rejeté

- Le « Centre des transferts » en tableau de bord à onglets (fiche `design/ux/20-transferts.md`, maquettes https://claude.ai/artifact/GLS9G2QXAqCJuvzEvZFoxm) : « j'aime pas tout ça… Je veux plutôt la même façon de faire que FM ou Tennis Manager ou autre avec des vrais écrans pour chaque offre etc. »

## Ce qui est validé

**Flux « une offre = un écran »** (recherche : `recherche-flux-offres.md`). Chaque affaire a son écran plein, ouvert depuis la fiche du joueur, le Recrutement ou un courrier ; on confirme sur l'écran, jamais dans une petite fenêtre.

- **Achat** : ① Faire une offre au club vendeur (indemnité, valeur, budget de transferts avec rallonge du conseil, période des mutations, autres clubs intéressés) → ② Réponse du club (accepte / demande au moins X / refuse) → ③ Négocier le contrat avec l'agent du joueur → ④ Accord conclu (arrivée immédiate ou au 1er mai).
- **Vente** : courrier → écran « Offre reçue pour ton joueur » (accepter, demander plus, refuser ; conséquences ; accord au 1er mai hors période) → réponse de l'acheteur → vente conclue ; « Proposer ton joueur aux clubs ».
- **Autres écrans** : signer un joueur libre, proposer un pré-contrat, approche d'un de tes joueurs (14 jours pour prolonger), prolonger un joueur (directement ou par l'agent).
- **Suivre plusieurs affaires** : la Réception filtrée sur « Transferts » + l'état affiché sur la fiche du joueur. Pas de tableau de bord.

**Moteur** :

- Le club vendeur répond **après 1 à 3 jours de jeu**, par courrier (achat seulement), comme FM.
- **Négociation par tours avec l'agent** (achat et prolongation) : 3 propositions au plus, réaction écrite en trois niveaux (satisfait / réservé / agacé, en mots), rupture possible sur une offre insultante ; **durée du contrat négociable à l'achat**.
- **Plus tard** : clauses, indemnité échelonnée, prêts, échanges de joueurs, statut promis.

## Règles transversales qui s'appliquent

`direction-artistique/interface/revue-20261119/RETOURS-LEO.md` (hors dépôt, PC de Léo) et `design/art/art-bible.md` : jamais de petite fenêtre ; tout est cliquable ; clic sur un nom = fiche joueur, survol = mini-fiche (36 attributs colorés) ; cadre commun validé ; un peu plus de couleurs doublées d'un mot ; densité FM.

## Systèmes déjà dans le jeu à servir

`docs/gdd/budget-transferts.md` (enveloppe, rallonge, report), `docs/gdd/vente-joueurs.md` (offres reçues et spontanées, demander plus, accords au 1er mai), `docs/gdd/calendrier-mutations.md` (période des mutations, joueurs libres, supplémentaires, jokers, pré-contrats). Les fenêtres actuelles (négociation d'un joueur libre, marché entre clubs, offres reçues, pré-contrat, rallonge, confirmations) sont à remplacer par ces écrans.
