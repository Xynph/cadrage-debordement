# Âge, développement et déclin — proposition V11

## Ce que disent les sources consultées le 07/11/2026

- Peeters et al., 2023, *Anthropometric and physical characteristics in U16, U18 and U20 elite French youth rugby union players*, PLOS ONE. 1 423 joueurs des académies FFR, données 2010–2020 : les catégories plus âgées sont généralement plus fortes, rapides, puissantes et endurantes. Étude des jeunes ; ce n'est pas une courbe de déclin senior. [Article](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0295623), DOI 10.1371/journal.pone.0295623.
- Barr et al., 2014, *Long-Term Training-Induced Changes in Sprinting Speed and Sprint Momentum in Elite Rugby Union Players*. Résumé : 38 seniors et 31 juniors, puis petit suivi à deux ans ; vitesse pouvant plafonner tôt dans la vingtaine, quantité de mouvement encore entraînable. Taille réduite, pas de seuil universel à 30 ans. [DOI](https://doi.org/10.1519/JSC.0000000000000364).
- Pickering et al., 2021, *Why Are Masters Sprinters Slower Than Their Younger Counterparts?* Revue : performance de sprint culminant généralement dans la vingtaine puis recul avec l'âge, facteurs de force, puissance et coordination. Extrapolation prudente : sprinters masters, pas 11 postes de rugby. [PubMed](https://pubmed.ncbi.nlm.nih.gov/33450731/), DOI 10.1123/japa.2020-0302.
- Étude publiée en 2022, *A game for all shapes and sizes? Changes in anthropometric and performance measures of elite professional rugby union players 1999–2018*. 291 joueurs, plusieurs saisons par joueur : les tendances de professionnalisation et de sélection ne mesurent pas une courbe biologique individuelle. Cette étude constate des hausses de vitesse avec les saisons observées : ne pas la citer comme preuve d'un déclin automatique à 30 ans. [Article](https://bmjopensem.bmj.com/content/8/1/e001235), [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC8867314/).

Aucune de ces sources ne fournit une loi exacte de perte annuelle de points sur 36 attributs ni 11 âges de pic par poste. Les chiffres ci-dessous sont exclusivement des paramètres de game design à calibrer.

## Audit du jeu actuel

`dist/development.js` possède déjà entraînement, expérience en match, potentiel, retraite et évolution annuelle. `ageGrowth()` diminue les gains après 22/26/29/31 ans. `ageDevelopmentPlayer()` fait baisser le rating à partir de 32 ans derrière et 34 ans devant, puis retire aussi des points de vitesse/endurance et en ajoute au mental. `skill()` ajoute la variation de rating à toutes les compétences : le déclin général touche donc également toutes les capacités et s'additionne aux retraits physiques. Les 36 attributs du master ne sont pas raccordés à cette évolution. Il ne faut pas empiler une seconde progression sur celle-ci.

## Candidat isolé

`tools/rugby-real-v11/aging.cjs` propose une évolution annuelle sur copies, avec un état latéral âge/saison idempotent. Aucun champ de sauvegarde ni fichier de production modifié.

- Développement lié à l'entraînement et au temps de jeu, plafonné par le potentiel global ; l'âge seul ne donne aucun gain. Sans entraînement ni temps de jeu un jeune ne progresse pas automatiquement.
- Vitesse, accélération, explosivité, agilité et détente plafonnent plus tôt et baissent plus nettement. La force reste plus longtemps conservée ; l'endurance a sa propre courbe.
- Les techniques et lectures du jeu évoluent plus tardivement et régressent plus lentement. Les qualités d'expérience ne compensent pas artificiellement toutes les pertes physiques.
- Paramètres différenciés sur les 11 familles. Les pics d'aptitude rapide proposés vont de 23 à 25 ans, force de 26 à 29, technique de 27 à 30, mental de 30 à 33. Des plateaux précèdent les déclins. Il ne s'agit pas de pics de performance globale observés par poste.
- Professionnalisme existant module légèrement l'évolution. Blessure longue et surcharge réduisent les occasions de progression. Aucun nouveau tirage de blessure, aucune retraite forcée ni modification des six traits cachés ou du potentiel.
- Bornes 20–97 ; une spécialité peut dépasser le potentiel global, qui n'est pas un plafond identique pour tous les attributs. Les profils d'âges initiaux déjà estimés par le master ne sont pas réécrits : pas de deuxième bonus/malus d'âge au lancement.

Les trajectoires 18→40 ans utilisent des profils témoins identiques (65 partout, potentiel 85, même exposition) afin d'isoler l'effet des courbes. Elles ne reconstituent aucune carrière réelle. La retraite native reste à raccorder à ces courbes lors d'une future modification autorisée de development.js ; les joueurs dépassant leur retraite ne doivent pas rester artificiellement dans les effectifs.

## Intégration à transmettre

Remplacer la composante annuelle héritée et raccorder les nouveaux gains au système d'entraînement existant ; ne jamais appliquer les deux. Calculer l'âge depuis la date de carrière et la naissance existante (année seule = âge approximatif). Versionner uniquement les nouvelles carrières ou une migration explicitement testée ; les sauvegardes existantes gardent leur modèle. Ni le module ni ces seuils ne sont activés par cette PR.
