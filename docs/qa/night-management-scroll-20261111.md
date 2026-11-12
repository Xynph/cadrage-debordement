# Retour du vestiaire et des reçus — diagnostic et réception

Le scénario graphique réel est reçu sur
`d40311c053aba931756df212c2690adb04a76994` : **61 contrôles, zéro échec**,
wrapper terminé avec le code 0, parole **0 demande / 0 démarrage**.
Il conserve aussi la fenêtre de reçus, son instance, son focus et son scroll,
les brouillons, les reçus et citations, ainsi que les octets du profil,
l’état sportif exporté, le RNG et l’horloge.

## Deux causes distinguées

Le premier échec, sur `d896d631`, concernait la préparation du scénario.
À 2560×1440, la route Vestiaire ouvre « Cette semaine ». La page
`CarnetRelations` n’existe que dans « Entretiens et duos ». Le test active
maintenant le vrai bouton `LockerTab_people` par Entrée, puis vérifie que
l’export conserve route et onglet. Ni le mode de carrière ni les données
sportives ne sont remplacés pour contourner l’échec.

Le second échec était un défaut produit. Sur
`c657eee47816bdca3a79e83d389bbd80bf5a64d0`, le défilement droit était à 90
avant et après la prise de focus sur l’engagement gauche, puis revenait à 0
après consultation d’une fiche. L’adresse conservée nommait
`@ScrollContainer@3622` ; après reconstruction, la même position structurelle
contenait `@ScrollContainer@3921`. Le résolveur strict refusait cette identité
instable. `CareerWorkspace`, explicitement nommé, était bien résolu.

## Correction minimale et preuve

Les deux surfaces de `relationships_view.gd` portent désormais les noms
`RelationshipFollowScroll` et `RelationshipPeopleScroll`. Le résolveur commun
reste strict : aucune acceptation aveugle d’un autre contrôle de même type
au même indice. Aucun écran, style, moteur ou format de sauvegarde n’est réécrit.

La [trace rouge complète](evidence/night-management-scroll-20261111/red-c657eee4.log)
reste distincte de la
[réception verte complète](evidence/night-management-scroll-20261111/green-d40311c0.log).
Cette dernière montre `RelationshipPeopleScroll`, `resolved: true`,
`stored_y: 90`, `actual_y: 90`, et le focus revenu au lien d’origine.
L’assertion sur le scroll est conservée ; un contrôle supplémentaire exige
les identités stables des deux colonnes.

Le [rapport natif](evidence/night-management-scroll-20261111/green-d40311c0-report.json)
et le [manifeste SHA-256](evidence/night-management-scroll-20261111/receipt.json)
conservent le périmètre et les empreintes. Les deux PNG originaux réellement
obtenus font 2560×1440 ; ils ont été inspectés par l’intégrateur. Le manifeste
référence leurs fichiers d’origine et leurs empreintes, sans dupliquer les
images dans cette preuve légère.

## Limites

Réception ciblée Linux/X11, Godot 4.7.2, rendu Compatibility Mesa llvmpipe.
Elle n’est ni une nouvelle campagne globale SDK/CI, ni une recette Windows.
Les avertissements d’environnement restent visibles dans le journal complet.

Sur cette base, les deux hôtes Analyse/Club utilisent déjà `ClubMemoryScroll`
et le conteneur extérieur `CareerWorkspace` est nommé. Les autres surfaces
anonymes rencontrées n’ont pas été modifiées sans cas reproductible ni test.
