# Connaissance des joueurs et nouvelles carrières

Version Cloud sur la suite polyvalence et tactique de la PR529, cible 2560×1440.

| Joueur | Niveau actuel | Potentiel |
|---|---|---|
| Notre club | Exact | 5 valeurs possibles |
| Autre club, sans observation | Inconnu | Inconnu |
| Première observation | 9 valeurs, par exemple 72–80 | 11 valeurs, par exemple 76–86 |
| Observation approfondie | 5 valeurs, par exemple 73–77 | 5 valeurs, par exemple 82–86 |

Les bornes proviennent du moteur, sont conservées entre observations et ne permettent pas de retrouver systématiquement la vraie note en faisant leur moyenne. Les tris et filtres utilisent les informations visibles. Les notes au poste restent accessibles pour notre propre feuille de match. Les qualités des joueurs extérieurs sont masquées avant observation approfondie.

Les observations ciblées fonctionnent aussi pour les joueurs sous contrat : confirmation de 5 000 €, file commune limitée à quatre missions, rapport après une ou deux semaines de travail selon le recruteur en poste. Deux observations distinctes approfondissent la connaissance. Un joueur ayant effectivement participé à une rencontre suivie est observé ; une rencontre mondiale simulée hors de notre suivi ne révèle rien.

À chaque nouvelle carrière, le potentiel varie toujours, jusqu’à ±5. Seule la variation du niveau actuel, jusqu’à ±3, possède une case : elle est cochée par défaut. Les petits écarts sont les plus fréquents. Le tirage modifie les qualités réelles, conserve les identités et les postes et ne se rejoue jamais au chargement. Les anciennes carrières ne sont pas tirées à nouveau.

Les exports restent restaurables et contiennent l’état interne complet ; aucun aperçu JSON brut n’est présenté dans les menus du jeu. La création personnalisée bénéficie désormais de la même copie de reprise que la création standard, après prévalidation sans effet.

## Captures du jeu

Les PNG de ce dossier proviennent du vrai moteur et de l’application Godot sur Linux, en 2560×1440. Les rapports de réception indiquent les contrôles exécutés. Les captures de création montrent la case active par défaut, la case décochée et sa présence dans l’atelier fictif.

## Intégration

Cette branche est empilée sur la PR529. Aucune fusion dans main n’est effectuée ici. Le main parallèle 283ecd0 ajoute des scènes contextuelles ; sa réception cumulative appartient à l’intégration finale. Les anciennes suites multi-résolutions ne constituent pas une réception du 720p : la cible demandée reste 1440p.

## Réception cumulative

Les contrôles utilisent des profils temporaires hors de l’application.

| Contrôle | Résultat reçu |
|---|---:|
| Politique de connaissance et variation, tests purs | 28 tests passés |
| Matrice variation sur les éditions natives et carrière personnalisée | 6 tests passés |
| Observation réelle, reprise, refus atomiques et capacité de 32 000 dossiers | 2 tests passés |
| Attributs complets, qualités compactes et progression | 3 tests passés |
| Barèmes seniors et conservation des profils sources | 3 tests passés |
| Protection de la carrière avant remplacement depuis l’atelier | 1 test passé |
| Création dans le jeu, clavier, défaut et atelier en 1440p | 27 contrôles passés |
| Connaissance dans le jeu, vrais rapports initial et approfondi en 1440p | 213 contrôles passés |
| Helpers de visibilité et statuts d’observation | 34 contrôles passés |
| Refus d’export : fermeture propre du banc, sans accès à une réponse absente | 1 test passé |
| Contrats, tris du recrutement, autres postes et tactique | 154 + 153 + 179 + 433 contrôles passés |
| Comparaison du recrutement en 1440p | 33 contrôles passés |

Le moteur de référence et le worker ont également passé leur comparaison stricte d’état, export, RNG, scènes, délégation, reprise, verrou et panne disque. L’import Godot ne contient pas d’erreur de script.

Les rapports `.tap` joints conservent les sorties terminales. Le message `QA_EXPORT_REFUSED` de la réception UI est le refus volontaire attendu par son test dédié, dont le résultat final est vert. Le statut d’observation affiché et son tri suivent désormais la connaissance courante : À observer, Observé ou Approfondie ; une observation déjà approfondie propose Actualiser.

Deux échecs de réception ont été examinés : le test d’attributs attendait encore des qualités publiques sur le marché non observé (assertions remplacées par un contrôle explicite du masquage) ; un lancement du comparateur avait utilisé son ancien défaut 720p (relance explicite 2560×1440, sans revendiquer les petites résolutions). Un dépassement isolé de l’attente d’export graphique n’a pas été reproduit en natif, en headless ni lors de la réception graphique suivante ; aucun délai de production n’a été augmenté.
