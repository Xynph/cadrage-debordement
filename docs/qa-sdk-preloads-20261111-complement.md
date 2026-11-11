# Complément après gel des neuf fixtures SDK — 11 novembre 2026

Ce complément conserve le [rapport figé](qa-sdk-preloads-20261111.md) intact.
Il ne modifie pas la sélection ni les deux exécutions CI de la branche commune.
La base de production locale reste `96f537040bf9f2e37bf10b0a9b09518b732244a2`,
avec les correctifs de fixtures `120bb1e` et contrats UI `bfc4a99`.

Les neuf wrappers ont désormais tous exécuté le vrai SDK après installation
du helper. Atteindre les assertions ne signifie pas que les neuf suites sont
vertes : les résultats ci-dessous restent distincts.

| Réception après gel | Qualification | Temps Node complet hors verrou | Preuve durable |
| --- | --- | --- | --- |
| lineup-layout, DISPLAY=:102 | PASS : 867 contrôles, aucun échec ; GD inchangé | 113,969 s ; attente 0 s | [reçu](qa-sdk-preloads-20261111-complement/lineup-receipt.json), [rapport](qa-sdk-preloads-20261111-complement/lineup-report.json), [extrait](qa-sdk-preloads-20261111-complement/lineup-excerpt.log) |
| interface-layout, DISPLAY=:102 | NON QUALIFIÉ : trois assertions rouges, puis erreur terminale `PressTabs` null | 128,249 s ; attente 0 s | [reçu](qa-sdk-preloads-20261111-complement/interface-receipt.json), [extrait](qa-sdk-preloads-20261111-complement/interface-excerpt.log) |
| readability06, DISPLAY=:102 | NON QUALIFIÉ : assertions rouges et arrêt au budget, sans compteur global terminé | 180,252 s ; attente 0 s | [reçu](qa-sdk-preloads-20261111-complement/readability-receipt.json), [extrait](qa-sdk-preloads-20261111-complement/readability-excerpt.log) |
| guide dock/native silencieux, DISPLAY=:102 | PASS : 160 contrôles, aucun échec ; même GD silencieux que layout/native | 117,572 s ; attente 0 s | [reçu](qa-sdk-preloads-20261111-complement/guide-dock-native-receipt.json), [extrait](qa-sdk-preloads-20261111-complement/guide-dock-native-excerpt.log) |

Chaque reçu porte le SHA du **harness effectivement exécuté**, celui du wrapper
et celui du helper original. Aucun hash de source modifiée après le replay
n'est substitué au hash testé. Le SDK est Godot officiel Linux 4.7.2, Node
22.23.4, audio Dummy, profils privés et une invocation par verrou.
Le serveur 102 a été relancé par root ; son processus Xvfb est vérifié.
Aucune preuve Windows n'est revendiquée.

## Diagnostic restant

L'interface attend encore qu'une seule activation sélectionne un numéro et
ouvre ses candidats. Le code courant de `tactics_canvas.gd::_choose_slot`
sélectionne d'abord le numéro ; une seconde activation ouvre les candidats.
L'accès direct à Presse sans courrier est volontairement refusé dans
`main.gd::_navigate`, d'où `PressTabs` null dans l'ancien harness.
La visibilité des lignes de l'Effectif reste à diagnostiquer avec ses mesures
physiques ; aucun faux vert n'est donné à ce contrôle.

Readability attend notamment une pagination absente de l'effectif immersif
actuel, à défilement continu. Les comparaisons de salaire/échéance et de
contexte du dossier sont encore rouges et ne sont pas toutes attribuées à
cette seule évolution UI. Le processus a été arrêté au budget de 180 s :
aucun résultat global terminé n'est inventé.

Le nouveau cas guide conserve la géométrie, les vrais clics et le focus. Sa fin
vérifie zéro `requested`, muted et aucun lecteur audio. Aucun ERROR n'est
filtré et aucun TTS n'est réactivé. Les cas layout/stretch et dock/stretch
restent à recevoir. Les deux cas natifs passés ne qualifient pas implicitement
le wrapper sans filtres, qui cumule quatre scénarios.

Les adaptations d'interface en cours et les prochains reçus restent une
famille séparée du gel CI ; ce document n'autorise aucun push supplémentaire
sur la branche commune.
