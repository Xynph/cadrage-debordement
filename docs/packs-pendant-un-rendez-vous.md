# Packs d'identités pendant un rendez-vous du club

Décision de Léo (11 novembre 2026) : le blocage de la gestion des packs par un rendez-vous obligatoire n'était pas voulu.

## Constat

- Une conférence de presse est en attente dès la création d'une carrière. Tant qu'un rendez-vous est en attente, `guard()` de `native/engine/club-meetings.cjs` refuse toute commande d'écriture, sauf les lectures (`snapshot`, `export`, `save`, `import`, `shutdown`…), la décision attendue et `new_career`.
- Dans la pratique, seule `pack_select` avec `scope: "career"` était concernée. `pack_inspect`, `pack_install` et `pack_select` avec `scope: "creation"` sont traitées par le worker avant la garde et passaient déjà. Il n'existe aucune commande de suppression de pack.
- Scénario gênant : reprise d'une carrière dont le pack d'identités est absent. L'avertissement invite à gérer les packs, mais le retour au pack de base était refusé jusqu'à la fin de la conférence.

## Correction

- `pack_inspect`, `pack_install` et `pack_select` sont désormais explicitement passives pour les rendez-vous du club : la garde les laisse passer et l'observateur ne les compte pas comme une avancée de la carrière (aucun rendez-vous créé, expiré ou déplacé).
- Le refus d'une commande sportive indique la marche à suivre : « Rendez-vous du club : terminez le rendez-vous en attente, dans votre courrier, en Réception, avant de poursuivre. » La conférence s'ouvre depuis son courrier en Réception, comme l'indique déjà le refus de la presse (`press.cjs`). Le texte est affiché tel quel par Godot (« ACTION NON EFFECTUÉE · … ») ; la mise en page n'est pas touchée et aucun test existant ne fige la phrase exacte (deux testent seulement la présence de « rendez-vous »), les suites existantes n'ont donc pas été modifiées.

## Accès et application : deux questions séparées

**Accès à la gestion des packs** (ouvrir l'écran, analyser, installer, choisir le pack des nouvelles carrières) : toujours autorisé pendant un rendez-vous. Aucun effet sur la carrière.

**Application à la carrière en cours** (`pack_select`, carrière) : autorisée, car elle ne change que la présentation. Vérifié (`tests/native-club-meetings-packs.cjs`) :

- le pack n'est jamais copié dans la carrière : la sauvegarde contient seulement la référence du pack choisi. Les noms sont substitués à l'affichage, à chaque lecture de l'état ;
- l'état enregistré est identique avant et après (effectif, finances, temps, tirage aléatoire, rendez-vous, textes de conférence déjà enregistrés), hors la référence du pack ;
- le rendez-vous en attente, ses questions, ses réponses et son identifiant sont inchangés, aussi après redémarrage ;
- une conférence terminée mais pas encore refermée garde son enregistrement ; le changement de pack peut seulement modifier les noms qui s'affichent dans ses textes ;
- le retour au pack de base rend exactement les noms d'origine.

Ce que le changement de pack modifie à l'écran pendant un rendez-vous : les noms de joueurs, de clubs et d'encadrement cités dans les textes déjà affichés ou archivés (par exemple les questions de la conférence) suivent immédiatement le pack choisi, comme ils le font en dehors d'un rendez-vous. Si l'on veut figer ces textes pendant la conférence, il faudrait refuser seulement `pack_select` de carrière tant qu'une conférence est ouverte, y compris le retour au pack de base, ce qui rétablirait le blocage du scénario ci-dessus. Le choix retenu est de ne pas le faire : l'enregistrement est intact et l'affichage reste cohérent.

## Autres commandes du même type (à décider)

Déjà possibles pendant un rendez-vous : `snapshot`, `export`, `save`, `import` (et la reprise d'une copie de sécurité), `shutdown`, `recover_profile`, `remove_checkpoint`, `competition_editor_preview`, `epcr_preview`, ainsi que les commandes de packs ci-dessus.

Candidates, non modifiées ici :

- `interclub_negotiate` et `academy_groups_preview` : consultations dont le worker vérifie déjà qu'elles ne modifient pas la carrière. Elles sont refusées pendant un rendez-vous.
- `coach_note_save` et `coach_note_remove` : carnet personnel du manager, sans effet sportif ni financier ; elles sont aujourd'hui refusées.

Les réglages d'affichage, de son et d'options sont enregistrés par Godot en local, hors du moteur, et ne passent pas par cette garde. Il n'existe pas de commande moteur de renommage de sauvegarde.

À laisser refusées : tout ce qui avance le temps, change l'effectif, les finances, un contrat, un objectif ou une décision du club, et les activations de fonctions de carrière (`*_enable`, `*_activate`).
