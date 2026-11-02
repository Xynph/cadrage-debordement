# CALENDRIER-03 — Import en ligne LNR avec horaires simulés

**Décision utilisateur :** les deux univers utilisent les **422 affiches exactes** du TOP 14 (182) et de PRO D2 (240) 2026–2027 ; au démarrage d'une nouvelle carrière (1er juillet 2026), on respecte les dates officielles et on comble uniquement les jours et heures non annoncés par une programmation de simulation, clairement identifiée comme telle. Aucun résultat réel n'est imposé.

## Nouveau script reproductible
`tools/calendrier03-lnr.py` parcourt `https://top14.lnr.fr/calendrier-et-resultats/2026-2027/j1` à `j26` et `https://prod2.lnr.fr/calendrier-et-resultats/2026-2027/j1` à `j30`. Extraction conservatrice des liens de clubs, exigence de 14/16 clubs distincts par journée, contrôle des doublons, de 182+240 affiches et des doubles rencontres aller-retour. Les heures annoncées sont conservées, les horaires manquants sont simulés (TOP 14 : samedi après-midi/soir et dimanche ; PRO D2 : jeudi/vendredi), en variant la grille selon la journée.

Les champs `officialKickoff` et `simulatedKickoff` sont **distincts**. Le jeu choisira le premier si confirmé, sinon le second. Les événements officiels restent liés à leur URL LNR. Les scores restent toujours `null`.

## Commande à exécuter sur une machine ayant accès à l'internet public
`python3 tools/calendrier03-lnr.py --output world-data/calendrier03/full-2026-2027.json`

Pour travailler hors ligne, télécharger les 56 pages HTML sous `top14-j1.html`, ... et `prod2-j30.html`, puis `--input-dir <répertoire>`. **Sans `--allow-partial`**, le script refuse d'écrire un calendrier incomplet. Pour auditer une extraction partielle uniquement : `--allow-partial`.

Tests unitaires locaux : `python3 -m unittest discover -s tests -p 'calendrier03-lnr.py'` (ou `python3 tests/calendrier03-lnr.py`).

## Limites constatées
L'environnement conteneur du compte producteur n'a pas pu résoudre `top14.lnr.fr` (DNS), donc **l'extraction des 422 matchs n'a pas été exécutée**. Des pages réelles ont été ouvertes via l'outil de recherche : les URLs par journée fonctionnent et exposent des noms et, selon la programmation, des heures. Le script est une première implémentation qui nécessite un test contre de véritables réponses HTML, notamment pour la segmentation des journées et la date des matchs. Les dates exactes peuvent varier au sein d'une journée et devront être extraites du groupe correspondant avant de considérer la programmation finale comme exacte. **Le fichier complet n'est pas livré et aucun résultat 422/422 n'est revendiqué.**

Les noms de clubs alternatifs de `world-data/univers01` ne sont pas encore liés aux identifiants des clubs réels par un dictionnaire officiellement vérifié ; il faudra établir cette correspondance explicitement avant mise en service. Aucune modification des fichiers du jeu ou des sauvegardes.

Sources publiques : https://top14.lnr.fr/calendrier-et-resultats/2026-2027/j1 ; https://prod2.lnr.fr/calendrier-et-resultats/2026-2027/j9 .
