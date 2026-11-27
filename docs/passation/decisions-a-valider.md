# Décisions à valider par le créateur à son retour

Une question claire chacune. En son absence : préparer les options (captures APRÈS seulement), ne rien intégrer, ne pas trancher. Certaines ont peut-être été tranchées depuis : vérifier dans les PR récentes.

## Tests et CI
1. Reprise de partie : « Continuer » relancé juste après un arrêt en début de semaine, quand les deux programmes d'entraînement donnent le même tirage : garder le programme de la semaine précédente (comportement actuel, #1326) ? Oui / non.
2. `match-pilotage` « aile faible » : élargir les séries à au moins 1 500 matchs, même seuil de 1 point ? Oui / non (seulement si ce test est rouge).
3. Tests modifiés avec accord direction (27/11) pour lesquels une trace existe : confirmer qu'on garde la pratique (mêmes contrôles, mêmes seuils, PR courte par famille).
4. Réparation de la feuille après blessure à l'entraînement du jour de match (#1356, #1363) : elle déplace aussi 3 arrières au lieu de remplacer seulement le blessé. Voulu ? Oui / non.
5. Anciens tests en mode France exclus de la CI : migrer ou supprimer ? (liste à produire, voir a-faire.md P1-5).
6. Politique CI : les push de `main` vont maintenant jusqu'au bout (#1348), ce qui consomme plus de minutes gratuites. OK ?

## Interface
7. Bureau avec un blessé : la ligne « ! Blessés » garde sa place, le joueur surveillé se range à droite des pastilles ⚠/⚑ (#1347). OK ?
8. Match plein écran très chargé : le banc devient défilable (ses 8 lignes gardées, #1345). OK ?
9. « Déléguer le match » : un clic dans le quart de seconde qui suit l'ouverture de l'avant-match est ignoré. Négligeable ?
10. Compte rendu de presse : le refaire comme l'écran des questions (grand titre, cartes de couleur, jauges) ? Oui / non.
11. Calendrier, bouton « ? » : l'ouvrir dans une petite fenêtre ? Oui / non.
12. Incertitude : quelle grammaire commune avant d'agir (A pastille du staff, B fourchette ou palier, C flèche ▲▼) pour entraînement, staff, rapport de force, offres, blessures, courrier, vestiaire, énergie, phases arrêtées, conseil ? Suggestion : C. Et la note au poste exacte (Composition, rapport, changements) passe-t-elle en lettre ?
13. Pression du conseil (« 58 / 100 ») et moral/confiance d'un joueur en conférence : mot de palier seul ou chiffre gardé ?
14. Un clic sur un rôle dans la fiche du joueur doit-il devenir le rôle du club ?

## Jeu et moteur
15. Joueur 3D v4 (gabarits aux mesures du Top 14) : validé, intégré en v5 (#1291) ; restes (pectoraux du pilier, revers de chaussettes carrés, bras arrière au sprint) : on peaufine ou on laisse ?
16. Épaule qui entre de 15 à 19 cm dans le buste de l'adversaire en mêlée et au plaquage : accepter, ou faire tourner la clavicule (visible) ?
17. Près des poteaux, la touche fait gagner un peu plus (51,7 %) que prendre les points (49,2 %) à cause du renvoi après points : rendre ce renvoi un peu plus disputé ? Oui / non.
18. Geste du botteur au drop : demande un pack d'animations privé, hors dépôt : on l'intègre ? (accord explicite requis)
19. Remplaçants (K3, #1350) : un changement à la 50e modifie la suite du match dans 25 à 40 % des cas ; assez ou trop ?
20. Niveau au poste (K2, #1351) : un joueur à −15 à son poste pèse de 0 à −4,6 points selon le poste ; ailiers, centres, arrière encore faibles. Renforcer ?

## Économie
21. D2 japonaise / Pro D2 : le propriétaire comble jusqu'à 30 % au-delà de sa promesse. A : on garde, exception D2 japonaise ; B : il s'arrête à sa promesse, le club garde une petite perte ; C : il promet plus dès le départ, sans jamais dépasser.
22. Sauvegardes Monde (≈ 19 Mio, limite ordinaire 24 Mio) : alléger à la source (relevé hebdomadaire des qualités) avant que ça grossisse ? Oui / non.
23. Bug de sauvegarde saison 2 (club 80, D2 japonaise) : la carrière exacte existe-t-elle encore pour la rejouer ?

## Divers
24. Anciens travaux jamais poussés ou conversations à clore (archivage des conversations terminées : « Lois manquantes », « Défense et gestes 3D », « contacts 3D bras ») : le créateur archive depuis sa liste.
