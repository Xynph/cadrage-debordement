# Liens de consultation — inventaire et réception de nuit

Les identifiants sont lus dans la projection courante. Un lien inconnu, ambigu ou indisponible dans le contexte est refusé sans commande métier, recherche par nom ni accès aux données internes.

| Entité / information | Surfaces | Destination réutilisée ou ajoutée | État / limite |
| --- | --- | --- | --- |
| Joueur du club : nom, portrait | Effectif, dossier compact, fiche complète, Fatigue, travail individuel | Fiche complète existante par player.id | Reçu des vrais clics et retour ; champs, filtre et défilement conservés |
| Salaire et échéance d’un joueur | Effectif, revue des échéances, salaires financiers | Fiche complète, onglet contrat | Revue reçue 270/0 sur 096f3d8f, vrais noms/portraits/salaires/échéances ; devis/signature restent explicites |
| Joueur hors club non observé | Marché général | Dossier de recrutement projeté | Niveau et potentiel restent inconnus ; aucune donnée interne recherchée |
| Drapeau d’origine ou de sélection | Dossiers joueurs | Consultation nation_id | France depuis mandat anglais reçue ; les pays sans équipe projetée restent des drapeaux sans destination inventée |
| Nation | Annuaire et rencontres internationales | Consultation de la nation exacte | 13/0 sur d896d631 pour classement et convocations connues ; aucune mutation du mandat |
| Staff : nom et portrait | Annuaire, parcours | Profil de consultation projeté | Ni négociation ni engagement ; état de lecture de l’annuaire conservé |
| Club : nom, blason, adversaire | Classements, rencontres, calendrier et palette | Détail CompetitionCanvas existant | Pas d’annuaire staff de substitution ; ID absent refusé |
| Rencontre terminée : score | Calendrier et résultats conservés | Détail CompetitionCanvas existant | Vrai calendar-0 joué reçu ; statistiques affichées seulement si projetées |
| Date de rencontre | Rencontres et calendrier | Calendrier focalisé sur date valide | Date absente ou invalide reste texte ; aucun prochain match substitué |
| Compétition | En-tête, badges et fiches de rencontre | Classement de compétition exact | ID projeté ; aucun moteur ou format de compétition changé |
| Courrier de reprogrammation | Réception | Fixture exacte, sinon date réelle | Pas de bascule générique vers la prochaine rencontre |
| Invitation presse | Réception | Salle de presse de son message et invitation exacts | Garde réelle reçue ; aucune route Presse générique |
| Trésorerie, masse salariale, budget | Tuiles financières | Onglet financier existant | Pas de modification des montants ni des fonctions réservées à Claude |
| Barre ou point financier | Douze opérations du graphique | Écriture exacte, page et focus du journal | 40 contrôles réels sans échec ; repère de lecture invalidé dès changement du journal, aucun ID/date métier inventé |
| Barre de charge | Histogramme Fatigue | Liste exacte de la tranche | Retour avec filtre et défilement non nul reçu ; pas de commande, sauvegarde ou RNG modifiés |
| Rapport d’observation archivé | Recrutement | Détail report.id existant | Rapport réel 47/0 sur d896d631, deux PNG 2560×1440 ; archive inchangée et limites conservées, sans recherche de joueur caché |
| Prospect du vivier ou interclubs | Catalogues et négociation | Dossier enfant source+ID limité à la projection | Lecture 133/0 et prospects 70/0 sur 37ede657 ; devis public 66/0 sur dbe6a7e2 ; parent et brouillon conservés |
| Engagements, entretiens et reçus | Vestiaire et Dernières décisions | Personne connue par ID exact | Module reçu 43/0 sur fbc642e1 ; parcours graphique 61/0 sur d40311c0, mêmes lecteurs/focus/scroll restaurés ; joueur parti reste archive, aucune homonymie |
| Axes, vigilance, encadrement | Entraînement | Fiches joueur/staff existantes | 55/0 sur dbe6a7e2, test corrigé sans changement de produit ; zones de réglage restent distinctes |
| Joueur du terrain ou du banc | Composition | Sélection et ouverture existantes | Écran réservé #574 préservé ; pas de réécriture concurrente |
| Rapport médical pendant rendez-vous obligatoire | Scène médicale | Lecture dans la scène imposée | Sortie par navigation refusée ; aucun bouton toujours refusé ajouté |

Les vues Analyse et Club ont reçu 56 contrôles headless sur 65a2119b : liens joueur, staff et finance, sélecteur conservé, lecture sans mutation ; les gardes de concordance score/fixture sont reçues sur projection isolée. Leur recette graphique commune avec le Bureau a ensuite reçu 72/0 sur `bd6a5fe6`, avec score collectif réellement joué, visites par ID et trois PNG 2560×1440 : [preuves ciblées](evidence/night-analysis-club-office-20261112/README.md). Ce reçu ne qualifie pas toutes les surfaces restantes. Le courrier historique réduit à des chaînes sans ID et les séances sans adaptateur de consultation restent des limites explicites.

Les reçus sont conservés par SHA et par cas. Les reprises ciblées ne constituent pas une nouvelle campagne globale verte. Les premières tentatives rejetées par erreur de fixture ou de parsing restent documentées. Aucune recette Windows n’est revendiquée et aucune fusion Cloud n’a lieu avant le 12 novembre 2026 à 09 h Europe/Paris.
