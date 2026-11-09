# Préparer l’Europe dans l’effectif natif

Le bouton **Préparer l’Europe** ouvre un brouillon de liste pour les clubs participants à la Champions Cup ou au Challenge européen. Il utilise la référence EPCR **2026/27** fournie par le moteur, sans extrapoler aux saisons suivantes.

Le manager peut sélectionner les joueurs de son effectif, vérifier la liste et la présence des joueurs de sa feuille actuelle, puis lire les points à corriger et les informations à confirmer. Le contrôle natif utilise le même validateur que les tests ; l’interface ne réécrit pas les règles. Une qualification de première ligne inconnue reste inconnue : un poste de jeu ou une estimation ne certifie pas l’habilitation.

La liste proposée conserve tout l’effectif, même au-delà de 42, afin de montrer le dépassement plutôt que de retirer silencieusement des joueurs. **Tout sélectionner**, **Vider la liste** et les cases restent accessibles au clavier. Modifier un choix invalide le rapport précédent jusqu’à la prochaine vérification.

Ce brouillon est consultatif : aucune inscription officielle, aucun changement de carrière ni blocage du coup d’envoi. La fermeture efface les choix et le dialogue l’annonce dès son ouverture. La liste définitive, les fenêtres de renforts, les contrats et les apparitions dans une autre équipe ne sont pas encore gérés comme un registre d’inscription persistant.

## Contrat de raccordement

- L’entrée n’est affichée que si `model.epcrPreparation` est un objet.
- Le dialogue conserve ses cases pendant le rendu normal du modèle. **Vérifier ce brouillon** envoie `epcr_preview` avec `registeredIds` et `competitionId`.
- La réponse affiche `registration` et `teamSheet`, leurs `status` et leurs messages natifs. Une réponse ne portant pas sur les IDs demandés ne remplace pas le rapport du brouillon.
- Le dialogue refuse de démarrer une consultation pendant une autre commande. Les cases sont verrouillées pendant la requête ; un échec reste visible.
- Au redimensionnement, le dialogue suit les bornes de la fenêtre et conserve le brouillon. Le contenu est défilable, le bouton Fermer reste hors du défilement.

## Qualification

Après staging officiel (`python3 scripts/build-godot-prototype.py --stage-only --node /chemin/node`) et import Godot des assets, `CD_GODOT_EXECUTABLE=/chemin/Godot_4.7.2 node --test tests/godot-epcr-preparation.cjs` utilise un profil jetable et le vrai worker local. Le scénario ouvre depuis les deux versions de l’effectif (720p et grand écran) au clavier, contrôle le dépassement réel de 42 joueurs, retire un joueur, vérifie la liste vide, redimensionne jusqu’à 720p/1440p, ferme au clavier et vérifie que la réouverture efface le brouillon et l’ancien verdict. Une liste limitée à la feuille réelle reste « à confirmer » lorsque les qualifications sont inconnues. L’export complet et les octets du profil avant/après doivent rester identiques, y compris l’horloge et le RNG. Aucun profil privé, identité réelle ni pack local requis.

Réception Linux sans fenêtre et pilote audio Dummy. Le test ne revendique ni un export Windows ni un examen physique des pilotes ou du son.

Réception du 9 novembre 2026 sur Linux : **70 contrôles réussis, zéro échec**, Node 22.23.4 et Godot 4.7.2. Les contrôles de visibilité vérifient les rectangles des commandes dans chaque zone de défilement après le déplacement réel du focus. Les premiers essais ont révélé l’absence du bouton dans la variante d’effectif sous 1600 px ; les deux variantes possèdent désormais leur entrée.
