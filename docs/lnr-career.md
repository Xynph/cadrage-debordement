# LNR-01 — Carrière optionnelle « Effectifs LNR 31 octobre 2026 »

## Périmètre et authenticité
Le jeu propose à la création d'une **nouvelle** carrière deux univers **indépendants** :
- univers fictif d'origine (choix par défaut, anciennes sauvegardes inchangées) ;
- mode LNR fondé sur les fichiers officiels déjà intégrés dans \`modding/data03\` et \`modding/data04\`, instantané du **31/10/2026** : 30 clubs, 1 592 identifiants de joueurs uniques, noms, groupe de poste, nationalités lorsqu'elles existent, et source officielle de l'effectif.

Le moteur natif reste à 14 clubs. Les **14 clubs répertoriés TOP 14** constituent sa ligue jouable. Les **16 clubs répertoriés PRO D2** sont consultables dans l'onglet Effectif, mais ne sont pas simulés comme une deuxième division. Cela n'est **pas** un championnat officiel TOP 14 2026/27 reproduit historiquement.

Les groupes « 1ère ligne », « 2ème ligne », « 3ème ligne », demi, aile, centre et arrière sont issus de DATA-04, **mais aucune spécialisation pilier droit/gauche/talonneur ou polyvalence précise n'a été certifiée**. Pour les postes nécessaires au moteur, \`lnrAssignment\` distribue des familles de rôles de manière **déterministe et fictive**, sans prétention de conformité réglementaire individuelle. Les affectations spécifiques devront être remplacées par des preuves détaillées avant d'être présentées comme réelles.

**Pure simulation, jamais factuels** : notes et compétences sportives, certains âges, salaires, contrats, budget/trésorerie et couleurs de jeux, calendrier 26 journées et résultats. Aucune appartenance contractuelle ou historique garantie au **01/07/2026**. Les pages LNR sont des instantanés contemporains ; aucune date d'effet des transferts, de staff ou de contrat n'a été inventée.

## Techniques, sauvegardes et compatibilité
- \`dist/lnr-rosters-data.js\` contient un export statique compact de tous les identifiants noms/groupes/nationalités collectés et passés en correspondance par \`id\` entre DATA-03 et DATA-04 ; aucune requête réseau au démarrage du jeu.
- \`dist/lnr-career.js\` configure et documente les modes ; \`dist/game.js\` ne change le roster initial que lorsque le joueur sélectionne le mode LNR. Les commandes natives \`buildSheet\`, simulations, entraînements, recrutement et sauvegardes restent utilisées.
- \`S.lnrMode={version:1,snapshot:'2026-10-31',scope:'top14',simulated:true}\` est ajouté **uniquement** aux nouvelles carrières LNR. Le validateur \`dist/saves.js\` accepte ce mode avec vérification stricte de l'identité des clubs et refuse un faux instantané ; en son absence, le validateur conserve **exactement** les règles fictives et des anciennes identités.
- Nouvelle carrière LNR non convertible automatiquement depuis une carrière existante : pas d'écrasement de données sans action explicite « nouvelle carrière ». Aucune donnée du dossier \`modding/**\` n'a été modifiée.
- Jeu univers original/ancien export identique, et mode LNR persistant au rechargement. La sauvegarde de carrière contient les identités de joueur et les paramètres fictifs de simulation, sans revendication de vérité.

## Tests
- \`node tests/lnr-career.cjs\` : 30 clubs/1592 IDs uniques, mode fictif par défaut, mode LNR, export, ligue native, lecture seule du catalogue, falsification rejetée.
- \`node tests/lnr-career-long.cjs\` : 4 saisons et exports validés après chaque saison.
- \`python tests/lnr-career-browser.py\` : Chromium Linux 1280/768/390/320, choix initial explicite, 14 clubs jouables, 30 clubs consultables, sauvegarde/reprise, univers fictif inchangé.
- Gates \`Tests JavaScript\` et \`Validation CI\` obligatoires sur HEAD PR avant fusion, post-fusion sur son SHA exact.
- Pas de certification du lanceur Windows ni des vraies lois de mutations/transferts, finances ou effectifs historiques.
