# Parcours management — retour aux lectures réelles

Le reçu graphique qualifié porte sur `d40311c053aba931756df212c2690adb04a76994` :
**61 contrôles, zéro échec**, Godot 4.7.2/X11, 2560×1440. Le SHA exact est celui
du gel communiqué par root ; `provenance.json` donne les empreintes des scripts
et des sources produit calculées depuis les objets git de ce SHA. Le wrapper
ne publie pas de durée TAP ; aucune durée n’est reconstruite.

La préparation utilise une vraie carrière `fiction`, club 13, le worker réel,
un entretien « rassurer », une décision de vestiaire « responsabiliser » et
huit changements publics de plan individuel pour remplir dix reçus. Les
préparatifs et l’export de baseline précèdent la consultation mesurée.

Le parcours active réellement Entretiens et duos, ouvre la fiche de Pierre
Mercier depuis son engagement puis revient. La liste de droite conserve son
défilement non nul à 90 px. Les deux colonnes portent désormais les noms stables
`RelationshipFollowScroll` et `RelationshipPeopleScroll`. Le dossier ouvert
depuis un ancien reçu revient à la même instance de fenêtre de décisions, avec
le même défilement et le focus rendu au lien d’origine. Les reçus, citations,
coûts, conséquences et brouillon de préparation restent inchangés.

Les assertions vérifient zéro commande worker lors des liens et retours, profil
identique octet pour octet, état sportif exporté égal, seed et horloge persistées
identiques. Les signaux Gabi sont réellement comptés ici : zéro demande et zéro
démarrage de parole. Ces assertions passent dans les 61 contrôles ; les valeurs
brutes de profil/seed/horloge ne sont pas sérialisées dans report.json.

## Deux images qualifiées

- [Retour au vrai vestiaire](images/vestiaire-retour-fiche-2560.png).
- [Retour à la même fenêtre de décisions](images/decisions-retour-fiche-2560.png).

Ces deux PNG natifs originaux ont été inspectés et copiés sans retouche : noms,
engagements et reçus lisibles. Ils proviennent uniquement du reçu final 61/0.
Aucun profil complet n’est publié.

## Trois historiques rouges distincts

| Dossier original | SHA | Contrôles / échecs | Limite observée |
| --- | --- | --- | --- |
| phase9/management | `d896d631bd2ea141283c0e09609695a547a6b200` | 25 / 1 | Onglet de détail non activé pendant la préparation |
| phase9/management-people | `d0aceccb28b51ebea3fb15d7c5dbfb3adb7ea988` | 60 / 1 | Défilement de l’autre liste non conservé |
| phase10/management-scroll | `c657eee47816bdca3a79e83d389bbd80bf5a64d0` | 60 / 1 | Diagnostic des noms des surfaces de défilement |

Rapports et journaux rouges sont conservés dans `history/`. Leurs PNG ne sont
pas publiés ici et ne sont pas présentés comme des preuves vertes. Le premier
wrapper avait déjà le flag coach à zéro ; son échec ne qualifie pas un problème
de parole. La cause et le correctif des noms stables sont documentés par le
propriétaire du contrôleur.

## Intégrité et portée

`manifest.json` donne origines, tailles, SHA-256, dimensions et SHA par cas.
`sha256sum --check SHA256SUMS` vérifie les copies, le manifeste, la provenance et
ce document. Les originaux restent dans les dossiers de travail indiqués.
Ce dossier est une recette locale ciblée ; aucun SDK/import n’a été exécuté
pour le constituer, et il ne constitue pas une campagne globale ou Windows.
