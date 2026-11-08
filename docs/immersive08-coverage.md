# Couverture de la refonte immersive08

Base vérifiée : f335fb76, 8 novembre 2026. Références 1440p approuvées dans le chat. Échéance 9 novembre 07h30 Europe/Paris.

| Famille | Routes et sous-vues à recevoir | Graphisme | Interactions / preuve |
|---|---|---|---|
| Entrée | Accueil, Création, Packs, reprise/import/récupération | À faire | À tester |
| Bureau | Synthèse, priorités, groupe, classement, journal, échéances | Sept tuiles aux coordonnées 1440p approuvées, images originales, fontes et pictos exacts | Capturé en 1440p ; navigation et invariance intégrale export/disque ; replis à recevoir |
| Réception | Courrier, non lus, favoris, archives, recommandations | Trois colonnes et bandeau du concept B, quatre photographies originales de la Réception et illustration médicale | Capturé en 1440p ; clic réel depuis le rail, sélection, lecture intégrale, marquage, favoris, archivage et retour Effectif. Repères limités à la session ; le moteur fournit l’ordre de réception sans horodatage ni expéditeur |
| Effectif | Vue générale, condition, contrats, développement, dossier, comparaison | Tableau 13 colonnes, 24 lignes par page, portraits d'origine, fiche complète et six onglets | Capturé en 1440p ; recherche, identifiants, pagination, retour, présence des attributs et du carnet ; contrats/notes/replis à approfondir |
| Tactique | Composition XV/banc, candidats, préparation, plan de jeu | Gabarit trois colonnes, briefing original, 15 maillots, banc, consignes et vigilance | Capturé en 1440p ; vrais choix attaque/défense, qualifications, affectation, charge, sauvegarde et reprise exacte ; autres sous-vues à refaire |
| Développement | Recrutement, suivi, Formation, Centre | À faire | À tester |
| Club | Club/Histoire, Staff, Travail du club, Stratégie, Finances | À faire | À tester |
| Compétitions | Calendrier, Classements, Presse, Rivalités | À faire | À tester |
| Carrière | Manager, mobilité et historique | À faire | À tester |
| Match | Pré-match, direct 3D, journal, résultat, statistiques | À faire | À tester |
| Transversal | Recherche/navigation, préférences, confirmations, erreurs, coach | À faire | À tester |

PR399 reçue à la tête `611065ae`, fusion locale de dépendance `26e6443`. Libération #73/6727978166, raccordement #73/6728276495 ; moteur, sauvegardes, guide et CI/gate restent exclus de l'écriture. Les nouveaux gabarits passent par l'application réelle, avec un profil jetable. Le contrôle Windows graphique du premier lot a donné 195 contrôles, 0 échec, ainsi que 38 images vérifiées ; les captures de travail sont dans `CD/output/oval-legacy-27/preuves-jeu-1440p`. Cela ne couvre ni les autres menus encore en cours, ni le paquet Windows final.

Aucun écran n'est déclaré reçu sur la seule présence d'un fichier ou d'un test statique. Pour chaque prochaine famille, comparer la capture du jeu à son concept à résolution égale, contrôler les interactions et documenter les états vides et les replis.

Le lot Réception et ajustement du shell a été exécuté sur Windows et RTX 4080 SUPER. 239 contrôles passent. Le Bureau et l’action principale restent visibles après un redimensionnement réel successif à 1920×1080, 1600×900, 1280×720, 1440×900 et 2560×1440. Les contrôles et l’historique de navigation restent en place. Les captures à 1280×720 et 1440×900 couvrent ce scénario de redimensionnement du Bureau. La lecture des autres pages et du match après resize reste à vérifier.
