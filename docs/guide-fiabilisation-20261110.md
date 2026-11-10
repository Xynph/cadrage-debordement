# Guide et navigation clavier — réception du 10 novembre 2026

La suite générale signalée rouge par la PR #508 passe désormais : **501 contrôles, zéro échec**, avec le vrai moteur et un profil jetable hors de l'application. La branche part de `cd3fa73`, sur la chaîne PC #506/#507/#508. Aucune fusion ou nouvelle réception Windows n'est effectuée ici.

## Défauts du produit corrigés

- **Approcher le joueur** : le guide protège maintenant l'action par son identifiant `OfferRecruitment`. Son nouveau libellé n'était plus reconnu par l'évitement ; à 1920 px, le portrait ou la bulle recouvrait le bouton du dossier. La recette conserve l'ouverture d'offres à la souris pour deux vrais joueurs disponibles et aux trois tailles.
- **Réinitialisation du marché** : la reconstruction restitue le focus à `MarketReset`, notamment après Entrée. Ce correctif vient du chantier recrutement (`aa2939b`, repris ici en `97df960`).
- **Recherche au clavier** : fermer Ctrl+K par Échap restitue le focus au contrôle exact qui l'avait avant ouverture. La référence est faible, et le contrôle doit être encore présent, visible et utilisable ; une commande ou un dialogue prioritaire empêche cette restitution. La fermeture de la fenêtre utilise aussi ce retour. L'activation d'un résultat garde son parcours de navigation habituel.

## Contrats du banc actualisés sans contourner le moteur

Les 29 échecs initiaux mêlaient les deux défauts confirmés et des attentes anciennes :

- reprise depuis l'accueil par `EntryResume`, vers **Réception**, puis consultation du Bureau ;
- paramètres ouverts par le rail à la souris et avec Entrée, au lieu du menu bas historique ;
- sélection de deux pistes par leur identifiant, puis ouverture de l'action du dossier : le grand écran ne présente plus plusieurs boutons de contrat simultanés ;
- conférence reçue par le moteur et vrais changements de jour jusqu'à `calendarCadence.matchReady`, avant de commencer chaque match ;
- validation du résultat par `match_screen.finish`, à la souris puis au clavier, au lieu de chercher l'ancien texte « Valider la journée » ;
- réactivation par le vrai bouton **Aide du coach** des paramètres, au lieu d'émettre un ancien signal de dialogue.

Les contrôles d'empreinte du profil et d'export/RNG pendant la consultation sont conservés. La progression nécessaire aux matchs n'a lieu qu'après ces contrôles de lecture pure. Les gardes presse/date ne sont pas désactivées. Le banc couvre toujours offres, menus, routes, erreurs d'écriture, direct/pause/résultat, désactivation et réactivation.

## Vérifications observées

Linux, Node 22.23.4, SDK Godot 4.7.2, ressources préparées et importées dans un cache privé.

| Recette | Résultat |
| --- | --- |
| `godot-guide-integration.cjs` | 501 contrôles ; zéro échec ; 73,6 s |
| `godot-navigation.cjs` | 133 contrôles ; zéro échec ; 30,9 s |
| `godot-guide-voice.cjs` | 199 contrôles ; zéro échec |
| `godot-gabi-composition.cjs` | 32 contrôles ; zéro échec |
| `godot-gabi-real-model.cjs` | 33 contrôles ; zéro échec |

Les trois dernières suites ont été reçues ensemble sans échec ni test ignoré. La recette navigation a été reçue avant la dernière adaptation du sélecteur de résultat dans le banc général ; le contrôleur testé est inchangé depuis cette réception.

Définir `CD_GODOT_EXECUTABLE` et lancer les suites indiquées avec Node 22. Le lanceur crée son profil dans le dossier temporaire système. Pour les captures, la suite générale accepte `CD_GUIDE_INTEGRATION_GRAPHICS=1` sur un affichage disponible ; cette réception locale était sans fenêtre. Le banc doit être reçu graphiquement sur le cumul de l'intégrateur pour confirmer les dimensions finales avec les autres chantiers. Aucun chiffre de cadence, image native Windows ou réglage de voix activée n'est revendiqué.

La prochaine étape est la recette cumulative après intégration des six chantiers. Les retouches Blender des manches et du carnet restent sur PC.
