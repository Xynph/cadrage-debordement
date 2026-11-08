# Portage de l’inventaire GitHub dans Oval Legacy 27

Demande de Léo du 8 novembre 2026 : reprendre toutes les bonnes idées de `docs/idees-github-20261108.md` et les développer pleinement. Cette spécification étend le lot staffs/Gabi de la PR396, sans remplacer ses preuves par une promesse. Référence : main3fe6d160, base de travail2e0fff10.

## Résultat attendu

Une carrière Windows native cohérente à30clubs : chaque système récupéré possède un écran utile, une décision reliée à l’unique état de carrière, des conséquences expliquées et une reprise fidèle. Le carnet anthracite/ivoire reste la direction artistique. Les nouvelles vues emploient les IDs et identités du pack actif. Les chiffres économiques et comportements sociaux sont des simulations, sans prétendre décrire les personnes réelles du pack privé.

## Couverture obligatoire

| Familles / candidats | Livrable |
|---|---|
| F01/C01–C02 | Conserver la BDD commune qualifiée, postes/contrats sourcés et vieillissement existants. Audits supplémentaires séparés des données de production ; aucun remplacement aveugle par une ancienne PR. |
| F02/C03–C04, F03/C05–C06 | Compléter préparation, opposition, choix tactiques et retour des décisions depuis les projections reçues PR396. |
| F04/C07–C08,C29 | Besoins, suivi persistant, contrats sur plusieurs saisons, stratégies d’agents avec devis34semaines en France30. |
| F05/C09–C10,C28 | Formation native, détection, mentorat, parcours et mémoire des générations ; adaptation explicite30clubs des API Espoirs, sans supprimer le verrou du validateur pour accepter un état non qualifié. |
| F06/C11–C12,C31 | Staff/photos PR396 ; réunions, plans de travail et protocoles médicaux reliés aux contrôleurs, délégations explicites. |
| F07/C13,C27 | Priorité sportive, objectifs datés, réunions et bilan annuel ; un seul calcul de confiance. |
| F08/C14 | Finances, engagements connus, devis d’investissement et installations ; pas de faux bilan comptable issu d’un journal tronqué. |
| F09/C15,C26 | Vestiaire hebdomadaire, conversations, promesses, leadership et duos ; choix persistants et effets expliqués. |
| F10/C16,F18/C25 | Rivalités, faits interclubs, confrontations et palmarès depuis les seuls résultats réellement conservés ; pas de passé inventé. |
| F11/C17 | Candidatures et mutation intersaison entre les deux divisions, sans seconde carrière ni contrat personnel fictif. |
| F12/C18 | Politique supporters et activité commerciale sur le vrai calendrier ; prévision distincte d’une recette encaissée. |
| F13/C19 | Amélioration progressive des corps/contact dans Godot ; geste qualifié puis séquence continue et benchmark30acteurs. Le prototype R&D n’est pas une livraison. |
| F14/C20 | Gabi : voix retenue, conseils contextuels courts, mêmes textes voix/bulles, commandes de jeu toujours accessibles. |
| F15/C21 | Fiches, comparaisons et hiérarchie visuelle originales dans Godot ; réception à1280×720,1600×900,1920×1080. |
| F16/C22–C23 | Journal factuel par division et conférence2–4questions,4réponses, conséquences moral/confiance et historique ; une conférence maximum par contexte. |
| F17/C24 | Trois sponsors fictifs, signature unique et revue du conseil avec vrais montants du moteur. |

## Contraintes globales

- L’unique autorité est `S`. Aucun stockage parallèle pour finances, joueurs ou calendrier. Aucune réinitialisation du profil personnel.
- Modules fonctionnels disponibles avant validation de démarrage ; aucune dépendance à un faux navigateur. `CDNativeHeadless` désactive les installateurs de rendu.
- Les champs nouveaux sont optionnels pour les anciennes carrières ; un champ présent invalide ou de version inconnue est rejeté explicitement à l’import et au redémarrage.
- Projections pures : aucun ensure/setup, tirage RNG, date réelle, écriture ou clôture sur `snapshot`. Identités calculées après les IDs, sans remplacement textuel approximatif.
- Commandes dans la transaction du worker : validation du payload, contrôle de phase, décision, validation complète puis un seul écrit disque ; rollback état/store/RNG/horloge en cas d’échec.
- Aucun changement de règle de rugby sans `docs/rugby-rules-reference.md`, saison2026–2027 et source exacte. Aucune règle de compétition déduite du seul code historique.
- Données réelles et budgets selon `docs/donnees-du-jeu.md`. Photos privées non publiées, secrets exclus des branches, aucune facturation activée pour la voix.
- Un module chargé, un test synthétique ou une maquette ne constitue pas une fonctionnalité Windows reçue.

## Acceptation

Tests réels du worker :30clubs/deux divisions, contexte semaine27–34, doublons refusés, reprise/import/export, versions hostiles, ancienne carrière et erreur disque. Vérification des effets, pas seulement des réponses JSON. Carrières longues avec checkpoints et limites de taille/nœuds. Puis tests Godot des vrais contrôles, captures aux trois tailles et EXE exporté déplacé avec Node embarqué. GitHub conserve commits, PR, CI finale et gate ; aucun succès futur revendiqué.

## Précisions de Léo après réception des captures

Conserver le catalogue presse déjà créé :30journalistes (10référencés avec sources,20fictifs), médias réels et fictifs,500questions/25thèmes/1500formulations. Leurs personnalités de jeu et leur relation individuelle avec le coach doivent être visibles et persistantes, y compris après changement de club. Ne pas remplacer ce catalogue par de nouvelles rédactions anonymes.

Chaque question propose désormais **5réponses**, la cinquième étant **l’humour**, choix explicite de Léo. Total2500options. Les quatre identifiants de réponse historiques sont conservés ; leurs dialogues déjà archivés restent exacts. Les formulations peuvent être retravaillées pour un français naturel et des reparties originales adaptées au sujet. La personnalité simulée ne doit pas être présentée comme une biographie ou un propos réel d’un journaliste référencé.

Gabi est bourru, chaleureux et drôle : expressions du Sud-Ouest par touches, vocabulaire du rugby, humour de vestiaire original. Présence souhaitée : premières visites et décisions importantes, puis discrétion. La voix Algenib vieillie/éraillée validée reste la cible ; le quota gratuit bloque actuellement la production, pas de facturation ni changement de voix final dissimulé.

## Extension de la mission autonome de six heures

Mission explicitement lancée par Léo le8novembre à12:20:56UTC, seuil18:20:56UTC. Les douze pistes comparées sont dans `docs/ameliorations-autonomes-20261108.md`. L'intégrateur choisit les solutions réversibles, sans nouvelle validation écran par écran, conformément à cette mission.

Quatre lots indépendants complètent le portage : recherche/navigation au clavier, mémoire du club et comparaison de saisons, journal de match filtrable, préférences durables de confort. La navigation reste à six chapitres ; ajouter une aide contextuelle ou un onglet dans un écran est préféré à un nouveau menu principal. Les nouveaux modules présentent les données reçues sans augmenter l'état de carrière.

### Approches et décisions d'intégration

- Pour retrouver un joueur/écran : palette native avec recherche accent-insensible, résultats typés et clavier ; conserver les filtres locaux utiles. Un autre menu global ou une recherche par navigateur ajoute des détours et ne correspond pas au produit Windows.
- Pour raconter une carrière : projeter les archives existantes par ID et les événements enregistrés ; ne pas fabriquer points, budgets, affluences ou scores historiques absents. Une nouvelle base de faits persistants aurait un coût de compatibilité et de taille injustifié.
- Pour relire le match : onglet Journal filtrant les événements déjà produits, sans retour temporel ni modification du moteur. Les raccourcis de navigation et filtres n'appliquent aucune décision sportive.
- Pour le confort : fichier de préférences local versionné distinct de S, erreurs visibles, volume général et mouvement réduit, qualité/caméra persistantes. Un zoom arbitraire qui déborde à1280×720 est exclu de ce lot.

### Réception de ces extensions

Contrôles clavier et vraie souris, trois résolutions1280×720/1600×900/1920×1080, identités du pack par ID, données vides/anciennes et import d'une autre carrière. Une consultation, un filtre ou une préférence n'altère ni S, ni RNG, ni octets de sauvegarde. Les préférences sont bornées, écrites atomiquement, et l'original invalide est conservé. Le journal ne réinitialise pas son filtre/focus à chaque tick ; le contexte périmé d'un dossier n'ouvre pas le joueur homonyme d'une autre carrière.
