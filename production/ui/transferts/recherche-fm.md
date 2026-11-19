# Recherche : les écrans de transfert de Football Manager

> `/team-ui` phase 1a (ux-designer CCGS), 19/11/2026. Demande de Léo : « des vrais écrans comme dans FM ».
> On relève **fonctions et organisation**, pas l'apparence : aucune couleur, mise en page exacte, logo ni texte de FM n'est repris.
> Sources lues : voir `docs/ressources-utiles.md`, section « Écrans de transfert — recherche FM (19/11/2026) ». Les versions vont de FM19 à FM27 ; les détails varient d'une édition à l'autre.

## Ce que fait FM (synthèse)

1. **Un hub unique.** FM26 a regroupé dans une seule section « Recruitment » ce qui était éclaté : scouting, activité de transferts, historique, planificateur d'effectif, budget. Les éditions précédentes avaient un « Transfer Centre » où toutes les affaires entrantes et sortantes se traitent au même endroit, y compris plusieurs offres d'un coup. FM27 annonce des cartes en plein écran « pour fermer moins de fenêtres », un panneau de commande en tête (budget, focus de recrutement, délégation) et une tuile « Transfer Window ».
2. **Scouting en amont, séparé de la transaction.** Scouting Centre : recommandations (classées A à E), recherche, focus de recrutement (poste, type de transfert, niveau mini, potentiel, âge), missions, couverture, rapports avec part de connaissance ; shortlist enregistrable, comparée à l'effectif par poste.
3. **Écran d'offre dédié** : transfert ou prêt ; indemnité, date du transfert (immédiat ou fin de saison), frais additionnels et clauses (échéances, bonus de matchs/sélections, pourcentage à la revente, rachat), cadenas pour rendre un terme non négociable, échange de joueurs ; « Faire l'offre » (réponse en 24-48 h de jeu) ou « Proposer des termes » (négociation en direct).
4. **Puis le contrat du joueur avec l'agent** : promesses et statut dans l'effectif d'abord, puis salaire, durée, primes, clauses, commission d'agent ; tours de négociation, patience de l'agent limitée ; « Suggérer des termes » selon le budget.
5. **Offres reçues** : accepter, négocier ou refuser ; plusieurs offres pour un même joueur regroupées dans un seul message (FM27) ; décisions prises directement dans le message.
6. **Statut de transfert** du joueur : intérêt actif / rumeur, retour de l'agent, liste « indésirables » ou « à développer » déléguée au directeur sportif ; « Proposer aux clubs », intermédiaires (commission ≤ 10 %), annonces TransferRoom (Requirements entrants, Pitch Opportunities sortants) et onglet de suivi des joueurs proposés.
7. **Budget** : transferts et salaires, ajustables par curseur ; budget négatif = alerte avec montant à récupérer, puis reprise en main par le conseil s'il n'est pas récupéré.
8. **Deadline day** : thème dédié, entrée de menu, rapports du directeur sportif sur les agents qui poussent un départ, onglet d'actualités (transferts conclus, rumeurs, réactions).
9. **Historique** : transferts filtrables entrants/sortants ; engagements futurs comptés à part dans les finances.

## Tableau : fonction FM → transposition RL27 → priorité

Priorité : **P1** = dans la fiche 20 et branchable sur le moteur actuel ; **P2** = dans la fiche, attend une projection moteur ou le chantier calendrier ; **P3** = réservé ou écarté.

| Fonction FM | Transposition Rugby Legacy 27 | Priorité |
|---|---|---|
| Hub unique (Transfer Centre / Recruitment) | **Centre des transferts** plein écran, chapitre « Transferts » du Recrutement (N2) à côté de « Pistes » (fiche 09) | P1 |
| Moins de fenêtres, cartes plein écran (FM27) | Négociation, offres reçues et marché entre clubs sortent des fenêtres empilées ; seules les confirmations W1 restent | P1 |
| Panneau de commande / budget toujours visible | Bandeau commun : disponible / enveloppe, dépensé · reconstitué, période des mutations ; colonne Budget fixe dans la Négociation | P1 |
| Écran d'offre dédié (indemnité puis contrat) | **Écran Négociation** à 3 étapes : ① accord avec le club (indemnité), ② contrat du joueur (salaire, durée, prime), ③ conclusion ; journal des réponses | P1 |
| Négociation avec l'agent, tours, patience | Propositions n/3 déjà au moteur (joueur libre) ; journal « Réponses » ; concurrence d'autres clubs (enchère du marché entre clubs) affichée | P1 |
| Offres reçues traitées au même endroit | Onglet **Offres reçues** = fenêtre de la PR #1009 en tableau + panneau ; Demander +5/10/15 %, accords différés au 1er mai | P1 |
| Statut de transfert / liste des transferts | Onglet **Joueurs proposés** : statut en mots (proposé, offre reçue, accord conclu, non vendable + raison), filtre fins de contrat | P1 |
| Alerte budget dépassé + intervention du conseil | Refus écrit « Hors budget de transferts… » + **rallonge du conseil** (déjà au moteur) | P1 |
| « À traiter » / décisions dans le message | Vue d'ensemble : file **À traiter** triée par urgence ; le courrier ouvre l'onglet concerné | P1 |
| Fenêtre de transfert, deadline day | **Calendrier des mutations LNR** (31/12 libres, 31/01 deux supplémentaires, 1er mai – 30 juin, 1er juillet arrivées, jokers médicaux) ; « Dernière semaine des mutations » en tête, sans thème spécial ni minuteur | P2 (chantier calendrier) |
| Pré-contrats (Bosman, 6 derniers mois) | Onglet **Pré-contrats** : possibles dès le 1er janvier, signés (arrivée 1er juillet), mes joueurs convoités | P2 (chantier calendrier) |
| Liste des négociations en cours | Onglet **Négociations** (arrivées, prolongations, pré-contrats) | P2 (projection moteur à créer) |
| Historique filtrable | Onglet **Historique** + « Échos du marché » (actualités transferts du Monde) | P2 (projection moteur à créer) |
| Scouting Centre, focus de recrutement, shortlist, rapports | **Inchangés dans la fiche 09** (Pistes : besoins, recherche, suivis, rapports, missions, comparaison) ; rappel dans la Vue d'ensemble | P1 (existant) |
| Échéancier, bonus, % à la revente, rachat | Ligne « Échéancier » réservée à l'étape ① ; pas de clauses tant que le moteur ne les porte pas (question à Léo) | P3 |
| Prêts (entrants/sortants) | Hors périmètre de cette fiche ; le moteur a des prêts d'académie, pas un marché de prêts | P3 |
| Intermédiaires, TransferRoom, retour d'agent sur la valeur | Écarté (cap « consolider ») ; la « valeur estimée » affichée suffit | P3 |
| Cadenas « terme non négociable » | Écarté : une seule variable par étape dans notre moteur | P3 |
| Curseur transferts ↔ salaires | Écarté : la masse salariale est un plafond de ligue (52 %), pas une enveloppe que le conseil arbitre | P3 |
| Thème visuel « deadline day » | Écarté (identité RL27, pas de copie d'apparence) | P3 |

## Leçons retenues

- FM sépare nettement **trouver** (scouting) et **conclure** (transferts) : on garde Pistes (fiche 09) et on crée Transferts, sans doublon de recherche.
- Les critiques de FM26 (labyrinthe d'interface, tableaux denses disparus, texte trop petit) relevées pendant la veille DA du 19/11 confirment : tableaux denses mais lisibles, pas de fenêtres en cascade, budget visible sans clic.
- Ce que FM fait par message (« décider dans le courrier ») est déjà notre lien courrier → onglet ; on n'ajoute pas de réponse dans le courrier lui-même (une seule surface de décision).
