# Presse et recrutement — qualité native0.6

Ce lot enrichit les domaines existants. Il ne crée ni banque de questions, ni système de relations, ni algorithme de recrutement supplémentaires. Les500questions, leurs2500réponses et les cinq tons restent disponibles avec leurs effets habituels.

## Une déclaration que le journaliste peut rappeler

Une question peut rappeler littéralement une réponse déjà enregistrée dans la carrière. La source doit appartenir au même journaliste, au même club, à la même saison et au même thème ; sa semaine doit précéder la conférence. La date est affichée avec le contexte. Le rappel se poursuit par la question native et conserve les cinq réponses proposées. Une source déjà rappelée n'est pas réutilisée en boucle.

Les textes incomplets ne sont pas reconstruits à partir du ton ou de la banque. Les relations personnelles continuent de suivre le coach après un changement de club ; elles n'autorisent pas à attribuer au club actuel une ancienne déclaration faite ailleurs. Les trois derniers échanges affichent aussi le club concerné, lorsqu'il est identifiable dans le monde actuel.

Le texte effectivement présenté est conservé dans le champ existant `questionText` de l'archive. Aucun nouveau champ de carrière n'est ajouté. Le plafond existant de600caractères reste appliqué : une source qui ne permet pas un rappel complet sous ce plafond est ignorée, sans troncature déguisée en citation. Les dialogues demeurent explicitement simulés, y compris pour les identités journalistiques référencées.

## Des rapports de recrutement argumentés

Dans **Recrutement → Besoins & missions**, chaque rapport devient une carte présentant :

- sa source datée, avec la semaine de suivi réellement enregistrée, distincte d'une date de calendrier inventée ;
- sa correspondance de famille de poste avec les besoins actuels, les solutions aptes et les contrats durables ;
- les faits conservés à cette date : âge, niveau relevé, prime et salaire ;
- le potentiel estimé et l'appréciation comparative du recruteur, sans promettre de progression ;
- les informations non conservées et les points à actualiser ;
- la présence actuelle dans le vivier, qui ne garantit ni éligibilité ni accord de signature.

La seconde passe de densité suit la demande de Léo : sous-onglets **Besoins / Missions / Rapports**, un seul rapport sélectionné à la fois, puis **Faits relevés / Avis / À vérifier** dans sa carte. Les corps restent à12/13px et les titres locaux à18px. Les questions et les cinq réponses de presse sont intégrales, avec des choix plus compacts ; aucune citation n'est coupée pour réduire la hauteur. La réception visuelle sur l'EXE doit encore vérifier le confort réel de cette densité.

Les qualités techniques détaillées ne figurent pas dans les archives scouts existantes. Le récit le dit explicitement : il ne lit pas les attributs cachés du candidat pour inventer une force ou une faiblesse. L'avis A/B/C est celui enregistré à la date du rapport ; le contexte exact de comparaison d'alors n'est pas archivé. Le rapprochement avec les besoins actuels est présenté séparément, sans prétendre reconstituer cet ancien contexte.

Le marqueur « rapport ancien » reprend le seuil de13semaines de suivi déjà utilisé par le moteur de recrutement. Une date absente rend l'ancienneté non vérifiable. Une donnée manquante reste inconnue ; la projection tolérante ne change pas la validation stricte d'import. Un joueur absent du vivier après mobilité ou changement de pack conserve son rapport historique, sans disponibilité supposée.

Le coût de5000€, les deux journées de travail, les critères des missions, les capacités d'effectif et les règles de négociation restent inchangés. La consultation n'ajoute pas de mutation, de tirage aléatoire ou de sauvegarde.

## Vérifications ciblées

Les tests `native-press-followups06.cjs`, `native-recruitment06.cjs` et `native-press-followups06-worker.cjs` couvrent les citations Unicode exactes, leur date, les séparations journaliste/club/saison/thème, l'absence de répétition, les cinq réponses, les rapports partiels ou anciens, le candidat absent, la consultation pure et le reset de nouvelle carrière. Le vrai worker vérifie aussi une mission après deux journées, le prix payé, l'export/import, la reprise et le refus disque atomique. Les archives utilisées pour provoquer une relance dans ce dernier test sont des fixtures explicites, pas des citations réelles.

Le test `godot-recruitment06.cjs` reçoit les nouvelles cartes et les sources de relance en mode headless. Les tests presse existants restent applicables. La réception visuelle de l'EXE et les captures sont effectuées par l'intégrateur ; une géométrie headless n'est pas une preuve de rendu graphique ni de DPI réel.
