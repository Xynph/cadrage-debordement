# Écran de match dédié — décisions validées le 7 novembre 2026

Léo a validé les maquettes et les quinze interactions, puis demandé leur mise en place. PC 1920×1080 et 1440×900, aucun défilement global. Écran propre au match : score compact, terrain entier en caméra éloignée, statistiques permanentes à droite, huit portraits stables du banc, commentaire discret en bas.

Tactique ouvre composition/consignes/remplacements groupés ; Remplacements ouvre les changements rapides ; portrait du banc présélectionne l'entrant. Les fenêtres de gestion et de statistiques laissent le match avancer seconde par seconde, sans saut ni accélération ; fermeture restaure les préférences, sans annuler une pause manuelle ou imposée. Changements validés ensemble, remplacements en attente annulables, rééligibilité vérifiée à l'arrêt de jeu. Conseil natif de l'adjoint applicable au clic.

Match intégral, résumé long, temps forts ; deux vitesses indépendantes. Résultat immédiat séparé, confirmation obligatoire ; annuler ne délègue rien ; confirmer confie le reste à l'adjoint et va au résultat sans pause mi-temps. Match regardé : pause impérative à mi-temps, rouge, blessure nécessitant intervention. Paramètres permanents : 2D/3D, caméras éloignées, préférences mémorisées hors carrière.

Approches : conserver les quatre pages #376 réduirait la place du terrain ; superposer seulement une nouvelle apparence laisserait les problèmes de suivi ; retenu : shell dédié et contrôleur de présentation appelant les API natives. Aucun coefficient de jeu, règle rugby, MATCH3D, index réservé LNR ou schéma de sauvegarde modifié.

Le moteur avance par minutes/séquences : les secondes sont la cadence de présentation, pas une nouvelle simulation physique. Ne pas inventer de statistiques : compteurs natifs, événements structurés et attribution acteur seulement quand enregistrée. Historique de mesures depuis ouverture de l'écran, sans reconstruire un passé absent. Blessures du moteur actuel principalement calculées en fin de rencontre : ne pas inventer des blessures en direct. Interface entière testée avec le vrai moteur ; simulation directe comparée avec mêmes graines aux mêmes appels natifs.
