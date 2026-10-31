# Resistance native des carrieres multi-clubs

## Perimetre et coordination

Base de conception : main `3655df2302d2f2ccbe37674ef473bb96cb91c6f5`, mobilite jouable #78. Ce lot ajoute uniquement des tests, un workflow en lecture seule et ce dossier. Aucun changement de `dist/`, de `tests/harness.cjs`, de sauvegarde utilisateur ou de fichiers UI-01 (#79). `DEVELOPPEMENT.md` reste reserve au producteur pendant sa refonte : cette documentation et l'issue #73 constituent le journal du lot.

Le banc execute les scripts natifs par le harness existant : vrais matchs, `finishRound`, `advanceSeason`, candidatures, acceptations, annulations, installations, exports, validation et import confirme. Il ne substitue pas le simulateur V51 au championnat.

## Trois campagnes de quinze saisons

- `reference` : club 0, conditions financieres initiales natives, candidatures natives tous les trois ans lorsqu'une offre est possible.
- `deficit` : meme club et graine de depart ; tresorerie initiale de -250 000 euros et dette de 2 000 000 euros injectees explicitement dans la fixture. Aucun assainissement force ensuite.
- `rotation` : aller-retour controle entre les clubs 0, 7 et 12, avec quatorze prises de poste et quatre retours dans le club d'origine. Les conditions financieres et de reputation necessaires sont tracees individuellement. Ce n'est PAS un echantillon du marche naturel.

La campagne configuree represente 45 saisons et 8 415 matchs comptabilises dans les carrieres principales. Les transitions temoins et replays de checkpoints executent aussi des actions natives, mais ne sont pas ajoutes artificiellement au nombre de saisons. Les resultats ne sont acquis qu'apres la reussite des trois campagnes completes et de leur agregation.

## Invariants et preuves

Chaque journee rapproche exactement le changement de tresorerie avec les nouvelles lignes du registre financier du club gere. Les installations ont un seul debit et un refus repete sans mutation. Chaque passation compare les quatorze clubs avec une transition native temoin issue du meme etat et de la meme graine : argent, joueurs professionnels, contrats, espoirs, installations, dette, reputation et archives sportives. Les compteurs V48 et les historiques du bureau sont controles sans introduire de second poste de manager.

Exports/imports reels a mi-saison, avant et apres les prises de poste, ainsi qu'entre segments de cinq saisons. Les checkpoints de test sont ecrits atomiquement apres chaque saison achevee, avec empreinte des sources et checksum. Ils ne contiennent que des carrieres generees et ne sont pas publies dans les artefacts : seuls les rapports sans donnees personnelles sont conserves.

Les 15 groupes du test court comprennent : panne du stockage avec dernier fichier conserve et reprise d'ecriture, echec d'import sans remplacement de la carriere, erreur pendant la transition avec rollback, double acceptation refusee, etats corrompus, compatibilite opt-in et refus des rapports incomplets. Le compteur des rapports incremente chaque groupe reellement execute, jamais une formule de compte theorique.

## Determinisme : limite explicite

Le harness natif utilise deja une graine fixe. Le banc y associe un etat aleatoire de test conserve hors de `S`, dans l'enveloppe de checkpoint. Il permet de comparer des replays dans les memes conditions. **Le jeu en production ne gagne aucun RNG persistant ni nouveau format de sauvegarde grace a ce test.** Aucun patch de source, mock des resultats sportifs ou mouvement de joueurs artificiel n'est utilise. La rotation ajuste seulement les conditions declarees de sa fixture.

## Execution

```sh
node tests/career-resilience.cjs
node ci/career-resilience-run.cjs reference 5 /tmp/career-resilience
node ci/career-resilience-run.cjs reference 10 /tmp/career-resilience
node ci/career-resilience-run.cjs reference 15 /tmp/career-resilience
# Refaire les trois commandes pour deficit et rotation dans le meme repertoire.
node ci/career-resilience-report.cjs /tmp/career-resilience
```

Ne pas reutiliser un checkpoint si les sources du jeu ou le pilote de campagne ont change : le controle d'empreinte le refuse. Une execution arretee n'est pas declaree reussie ; son checkpoint permet seulement une reprise explicite. La CI borne chaque segment et exige tous les scenarios au meme SHA. Le workflow n'a que `contents: read`, aucun push, aucune fusion ni modification de protection GitHub.

## Interpretation des rapports

Les rapports JSON contiennent les soldes des quatorze clubs, leurs effectifs et masse salariale, installations, changements de coach, titres, offres/refus, investissements et interventions de fixture. La synthese distingue tresoreries negatives et pertes comptables : elle ne deduit pas un benefice annuel d'un simple ecart de soldes. Les compteurs de coach comprennent les prises de poste du joueur et ne sont pas annonces comme uniquement IA.

Deux trajectoires naturelles/conditionnelles et une rotation forcee ne suffisent pas a calibrer statistiquement l'economie ou les championnats. Les chiffres sont descriptifs ; aucune correction de regle economique n'est activee. Aucun test Windows natif, rendu graphique, theme ou appareil mobile n'est revendique.

## Livraison

La PR ne doit etre fusionnee qu'apres succes de `Tests JavaScript`, `Validation CI` et `Validation carrieres longues` sur son dernier SHA, puis verification des workflows `push` sur le commit fusionne. La PR graphique #79 est distincte : la refonte doit ensuite rejouer ces invariants pour prouver qu'elle ne change pas les carrieres.
