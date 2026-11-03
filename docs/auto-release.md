# Intégration automatique des PR ordinaires — prototype désactivé

Le gate historique et ses protections restent inchangés. Le nouveau workflow n'agit que si la variable de dépôt CD_AUTO_RELEASE_ENABLED vaut true ; cette variable n'est pas activée par la PR.

Conditions : événement workflow_run JavaScript terminé avec succès, une seule PR propriétaire ouverte et non DRAFT, SHA exact, base main actualisée et mergeable_state clean, diff intégral (maximum 12 fichiers) limité à documentation, tests Node, feuilles CSS et modules UI uiXX-/vXX- testés. Tout changement de moteur, sécurité, CI, sauvegarde, DATA/LNR ou workflows est rejeté.

Les sept jobs JavaScript doivent être verts ; tous les derniers workflows PR visibles sur le même HEAD doivent être terminés et verts. Le code de main est exécuté sur un checkout épinglé sans identifiants persistants. Le moteur existant ci/chat-release.cjs pilote le gate ci/release-gate.cjs, vérifie main, bloque les SHA périmés, fusionne par squash sous protection serveur et réceptionne les sept jobs post-fusion. Même groupe de concurrence que le gate Chat.

Avant activation : CI complète de cette PR, revue des permissions GitHub Actions, essais à blanc/contrôles de refus et preuve réelle d'une fusion témoin. Une CI d'une PR sensible peut finir avant les autres workflows : l'auto-release refuse alors la fusion, sans relance automatique ; l'intégrateur utilise le gate historique. Aucun bypass.

Le contrôleur compare les fichiers de la PR avec ceux de toutes les autres PR ouvertes et refuse un chevauchement (réservations des deux producteurs). Si la liste est trop longue/incomplète, il échoue fermé.
