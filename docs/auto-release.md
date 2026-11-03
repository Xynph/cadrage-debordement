# Intégration automatique des PR ordinaires — prototype désactivé

Le gate historique et ses protections restent inchangés. Le nouveau workflow n'agit que si la variable de dépôt CD_AUTO_RELEASE_ENABLED vaut true ; cette variable n'est pas activée par la PR.

Conditions : événement workflow_run JavaScript terminé avec succès, une seule PR propriétaire ouverte et non DRAFT, SHA exact, base main actualisée et mergeable_state clean, diff intégral (maximum 12 fichiers) limité à documentation, tests Node, feuilles CSS et modules UI uiXX-/vXX- testés. Tout changement de moteur, sécurité, CI, sauvegarde, DATA/LNR ou workflows est rejeté.

Les sept jobs JavaScript doivent être verts ; tous les derniers workflows PR visibles sur le même HEAD doivent être terminés et verts. Le code de main est exécuté sur un checkout épinglé sans identifiants persistants. Le moteur existant ci/chat-release.cjs pilote le gate ci/release-gate.cjs, vérifie main, bloque les SHA périmés, fusionne par squash sous protection serveur et réceptionne les sept jobs post-fusion. Même groupe de concurrence que le gate Chat.

Avant activation : CI complète de cette PR, revue des permissions GitHub Actions, essais à blanc/contrôles de refus et preuve réelle d'une fusion témoin. Une CI d'une PR sensible peut finir avant les autres workflows : l'auto-release refuse alors la fusion, sans relance automatique ; l'intégrateur utilise le gate historique. Aucun bypass.

Le contrôleur compare les fichiers de la PR avec ceux de toutes les autres PR ouvertes et refuse un chevauchement (réservations des deux producteurs). Si la liste est trop longue/incomplète, il échoue fermé.

La politique exige les workflows JS, V60 et V61 sur chaque HEAD ; tout changement sous dist/ exige aussi UI Chromium. Si un contrôle attendu n'apparaît pas (même pas démarré), son absence bloque automatiquement. Un run rouge, annulé, en cours ou des résultats paginés/ambigus bloquent également.

Les fichiers de tests et documentation de sécurité (`tests/auto-release.cjs`, `tests/chat-release.cjs`, `docs/auto-release.md`, `docs/chat-release-gate.md`, etc.) sont explicitement exclus de l'auto-intégration ; revue manuelle obligatoire pour ces chemins.

## Sécurisation supplémentaire du témoin (03/11/2026)

Le contrôleur reste **inactif** sans `CD_AUTO_RELEASE_ENABLED=true`. Même avec ce flag, toute fusion est maintenant refusée à moins que `CD_AUTO_RELEASE_MODE=trial`, `CD_AUTO_RELEASE_TEST_PR` (numéro exact) et `CD_AUTO_RELEASE_TEST_SHA` (HEAD complet exact) ne correspondent à un unique événement CI. Les valeurs manquantes, périmées ou un autre mode sont rejetés sans appel au gate. Un témoin ne peut contenir qu'un seul fichier ajouté : `docs/ci-auto-release-trial.md`. **Il n'existe volontairement aucun mode de fusion générale dans ce correctif.**

Avant un vrai essai, l'intégrateur doit contrôler les réservations de #73 et les PR concurrentes, les droits effectifs du token, l'état initial des variables et la possibilité de restauration immédiate. Les variables de témoin doivent être posées en premier, contrôlées, puis le flag activé seulement dans une fenêtre maîtrisée. Déclencher une CI fraîche sur le HEAD témoin, inspecter l'événement et le passage par le gate officiel, la fusion protégée, puis les 7/7 jobs du nouveau main. Désactiver ensuite le flag et effacer les variables du témoin. En cas de doute : STOP, ne jamais affirmer une fusion automatique réussie. Une activation générale nécessitera un changement distinct et un contrôle fiable des réservations de l'issue #73, non couvertes par le simple recoupement des PR ouvertes.
