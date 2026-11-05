# Proposition — alternance exclusive de deux comptes ChatGPT

**Statut : PROPOSITION NON ACTIVÉE.** Ce texte ne remplace pas AGENTS.md tant qu'une PR de gouvernance n'a pas été approuvée, intégrée et annoncée dans #73. Aucune autorisation de fusion implicite.

## Principe

Les comptes Business et Plus ont les mêmes capacités de travail possibles : **producteur** (analyse, développement, tests, publication de PR) ou **intégrateur** (revue indépendante, gate, fusion autorisée et contrôle post-fusion). Il existe toutefois **une seule session active à la fois** et **un seul détenteur du rôle d'intégrateur à un instant donné**. Les deux comptes ne travaillent jamais simultanément, même sur des branches différentes.

## Prise de relais obligatoire

1. Avant toute opération, consulter le dernier `main`, `AGENTS.md`, `DEVELOPPEMENT.md`, les PR/CI et les derniers commentaires de #73, dont les réservations. Ne jamais déduire l'état du dépôt d'une conversation passée.
2. Publier dans #73 la **PRISE DE RELAIS** : compte actif, rôle, dernier SHA main, PR concernées, périmètre et fichiers réservés, état CI, autorisations reçues, prochaine action. L'autre compte reste inactif jusqu'à la passation. Une réservation dans #73 est une convention de coordination, pas un verrou serveur.
3. Pour finir, publier une **PASSATION** : HEAD exact, liens PR/runs/tests, actions réalisées, changements de main, réservations libérées, blocages, prochaine priorité et disponibilité du compte suivant.
4. En cas de relais incomplet, conflit de réservation ou état incertain, **STOP pour toute mutation et fusion** ; le nouveau compte commence uniquement par un audit de lecture.

## Règles de fusion indépendantes du compte

- Les deux comptes **peuvent être candidats au rôle d'intégrateur à tour de rôle**, jamais simultanément. Cela ne permet pas à une session de fusionner sans décision de Léo.
- Pour **chaque PR individuelle**, Léo autorise explicitement la fusion sur la PR concernée. Une autorisation générale, ancienne, pour une autre PR ou simplement « continue » n'est pas suffisante.
- Conserver strictement le gate officiel `ci/release-gate.cjs`, `docs/chat-release-gate.md`, les préconditions de CI verte (classification, cinq suites, Validation CI), le contrôle `mergeable_state=clean`, le HEAD SHA exact et sa garde contre le remplacement, et l'absence de bypass. Le protocole `/cd-check NUMERO SHA40` ne fusionne jamais ; `/cd-merge NUMERO SHA40` n'est envoyé **qu'après autorisation explicite et préconditions complètes**.
- Après fusion, exiger la CI post-fusion sur le **SHA réel de main**, sept jobs SUCCESS avant de transmettre le rôle, sans supposer qu'un ancien run vert suffit.
- Une PR sur laquelle le compte a lui-même travaillé demande une revue explicite de son diff et de ses risques avant demande de fusion ; favoriser la revue de l'autre compte si disponible sans remettre en cause l'alternance exclusive.

## Interaction avec la PR #75

La PR #75 propose une gouvernance parallèle à deux intégrateurs et des protections serveur. **Ne pas la confondre** avec cette alternance exclusive. Il faudra trancher en revue avant toute modification d'AGENTS.md : conserver les exigences de protection pertinentes sans instituer deux sessions actives. Si des protections serveur sont requises par la gouvernance retenue, leur configuration réelle et vérifiable reste préalable ; une documentation ne prouve pas leur activation.

## Protections à reprendre de la PR #75 sans parallélisme

Les contrôles de sécurité proposés dans #75 sont complémentaires, mais leur mécanisme de « deux intégrateurs parallèles » doit être écarté au profit de **l'alternance exclusive** :

1. Faire appliquer au serveur GitHub des règles sur `main` : pull request obligatoire, absence de push direct ou force-push, contrôles requis à jour, aucune exception administrateur/bypass. Ces règles doivent être **vérifiées effectivement**, pas seulement décrites.
2. Conserver la vérification de la dernière tête de PR et de `mergeable_state=clean`, ainsi que le contrôle du `main` courant et la CI post-fusion du SHA réel ; après tout changement de `main`, renouveler le contrôle de la PR suivante.
3. Si une merge queue est envisagée, vérifier la compatibilité `merge_group` des workflows avant activation ; ne jamais prétendre que la queue existe sans preuve.
4. Les commentaires #73 coordonnent l'alternance, **sans constituer un verrou atomique** ; aucune fusion ne se fait hors du release gate officiel. Les outils expérimentaux de #75 ne remplacent ni `ci/release-gate.cjs` ni `docs/chat-release-gate.md`.
5. Conserver les tests de sauvegardes pour les PR qui changent les carrières, et les vérifications réglementaires avant changement des règles sportives. Ces exigences ne sont pas assouplies par l'alternance.
6. La PR #75 est actuellement conflictuelle avec main : **ne pas la fusionner telle quelle**. La présente proposition documentaire ne change pas les réglages GitHub et ne confère aucun droit de fusion.

## Bilans destinés à Léo

Un seul feu :
- 🟢 **VERT** : travail autonome possible, bouton cliquable nommé selon la prochaine étape recommandée.
- 🟠 **ORANGE** : l'autre compte doit agir ; préciser le message à lui transmettre, et garder le bouton Continuer pour les tâches autonomes restantes.
- 🔴 **ROUGE** : une décision ou autorisation indispensable de Léo manque ; aucune opération sensible avant son intervention.

Toujours afficher un **bouton cliquable dont le libellé décrit précisément la prochaine étape recommandée** (jamais seulement « Continuer »). Le bouton ne vaut jamais autorisation de fusion.

## Activation

1. Revue de cette proposition contre #75 et le présent AGENTS.md.
2. Choix explicite de la gouvernance par Léo, puis PR dédiée modifiant AGENTS.md sans écraser les changements retenus de #75.
3. Tests documentaires/CI, intégration autorisée avec gate inchangé, vérification post-fusion, annonce d'activation dans #73.

**Jusqu'à ces étapes, l'ancienne règle d'intégrateur unique reste applicable.**
