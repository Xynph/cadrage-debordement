# Notes globales et période des salaires

Demande de Léo : ajouter Niveau et Potentiel à la revue des contrats, et pouvoir choisir dans Paramètres entre salaire hebdomadaire, mensuel et annuel.

Niveau et Potentiel suivent Poste, avant les informations contractuelles. Les notes viennent des champs projetés rating et potential ; les valeurs absentes restent inconnues. Elles ne sont pas des mesures officielles ni une nouvelle calibration.

La période choisie est une préférence locale persistée et validée, avec hebdomadaire par défaut pour les profils antérieurs. Affichage annuel = hebdomadaire × 52 ; mensuel = hebdomadaire × 52 / 12. Cette annualisation d’affichage n’est pas le coût d’une saison comptable du jeu. Les valeurs moteur restent hebdomadaires ; frais, primes et trésorerie restent des montants distincts. Les saisies sont reconverties avant commande moteur, sans modifier un salaire lorsque seule l’unité change.

Vérifier : notes identiques aux joueurs, valeurs inconnues, trois périodes, rechargement de préférence, fichier ancien/invalide, conversion et commande de négociation, montants non salariaux inchangés, captures réelles 2560×1440.

## Tri par les en-têtes

Chaque colonne de données d’un tableau de joueurs sert de tri : premier clic sélectionne le critère, second clic inverse le sens, flèche visible sur la colonne active. Comparaison numérique pour les nombres, textuelle pour les libellés, chronologique pour les échéances. Les valeurs inconnues restent après les connues dans les deux sens ; un identifiant stable départage les égalités. Le tri porte sur toute la liste filtrée. Il n’y a pas de pagination des joueurs : toutes les lignes sont dans une zone défilante interne, tandis que les en-têtes, filtres et panneaux de contexte restent fixes. La molette défile uniquement la liste survolée, sans propagation au menu global. Les boutons d’action restent des actions et ne modifient jamais la carrière au tri.

## Réception du cumul

Contrats : 161 contrôles graphiques 1440 (dont trois unités) puis 153 contrôles sans affichage après intégration de toutes les vues. Effectif : 104 contrôles ; Fatigue/Individuel : 569 ; Recrutement : 153 ; Académie/tableaux génériques/banc/salaires : 119 ; unités pures : 43 ; paramètres et commandes salariales réelles : 51 en X11 ; préférences existantes : 190. Les tests de lecture vérifient les identifiants, le hash du profil sportif et l’absence de commande. Le rapport du cumul référence le HEAD testé.

Les captures finales Effectif et Paramètres sont celles du cumul sans pagination, pas celles des branches individuelles antérieures. La capture Contrats mensuelle inclut Niveau/Potentiel, les en-têtes triables et le défilement interne.
