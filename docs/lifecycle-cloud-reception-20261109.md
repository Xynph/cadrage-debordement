# Réception Cloud du lot renouvellement et portraits

Le lot assemble le renouvellement des joueurs et du staff, les reconversions, la détection des regens, le suivi des jeunes, le retrait des six doublons du catalogue et les outils d'inventaire des médias. Les sources des campagnes historiques restent gelées dans leurs rapports ; leurs résultats ne sont pas présentés comme une nouvelle campagne décennale sur cette tête.

## Réception de l'assemblage

Les commandes sont exécutées sous Node22.23.4 et Godot4.7.2 Linux. Les validations finales de client et de textures portent sur le code assemblé `349972f`, avec les douze planches complètes et le catalogue reçu. Aucune nouvelle recette Windows n'est revendiquée.

- La compilation commune et le staging officiel passent. Les 1 592 profils et 30 clubs sont strictement identiques avant/après neutralisation des seules empreintes `dist/game.js` et `dist/development.js`. Les registres Monde et staff passent aussi leurs contrôles de compilation. Le nouvel import des ressources Godot réussit.
- Le vrai worker intégré parcourt deux saisons complètes et six checkpoints aux semaines 10, 20 et 34 : import/export identiques, fermeture et reprise exactes à chaque checkpoint, passage en saison3. Durée locale 114,689s avec plafond180s conservé ; maximum5 631 605octets et352227nœuds. Aucun staff, politique de population, prédicat de validation ou checkpoint n'est désactivé.
- Dix tests Node de descripteurs et d'assets passent sans saut : fichiers présents, empreintes exactes, 160 bases joueurs et40staff, couverture du catalogue, variantes et traits observés. La revue indépendante a vu les200sources et ne constate aucun doublon visuel certain ; l'unicité perceptuelle des compositions n'est pas garantie.
- Le client graphique X11 reçoit6004contrôles de textures et de découpes : les200cellules correspondent aux pixels des douze sources. Les planches joueurs1254×1254 utilisent des bornes fractionnelles4×4 ; le nouveau staff1536×1024 utilise6×4. Les caches restent bornés à48textures et128matériaux.
- Le parcours de cohérence des portraits passe33contrôles sur ce profil, avec une nouvelle base au-delà des32historiques : promotion, petites et grandes fiches, pleine page, entraînement, composition, bureau, recrutement, adversaires réels et réouverture. Le nombre de contrôles dépend notamment du nombre de menaces adverses projetées ; le reçu de l'auteur en comptait35. Le parcours détection/progression passe249contrôles graphiques dans l'assemblage. Le protocole JSON-lines et le pont Godot passent également. Les quatre tâches client se terminent sans erreur ni contrôle sauté.
- Les tests courts couvrent activation des centres, anciennes sauvegardes, marqueur de banque absent/1/2 et refus atomiques des valeurs invalides ; les deux schémas fermés des joueurs juniors acceptent uniquement ce champ optionnel. Les projections de détection et de formation conservent le marqueur seulement lorsqu'il existe. Les fixtures de comparaison historique retirent explicitement le nouveau marqueur de naissance, sans modifier qualités ou RNG ; les naissances2 restent vérifiées par les vrais workers.
- Les anciens exports et packs à5884IDs restent lisibles malgré le catalogue actif à5878joueurs. La photo d'un alias peut servir de repli au canonique sans modifier le pack ou la carrière. Les outils Python restent en lecture seule, avec sorties agrégées ; fichiers vides et flux ZIP corrompus ne sont pas comptés comme vérifiés.

## Portraits et limites de couverture

La banque contient200bases réellement embarquées, dont les48historiques. La version2 s'applique à la naissance des nouveaux personnages ; les références historiques gardent leur apparence et les reconversions héritent du joueur. La sélection respecte la bande d'âge initiale du staff : le catalogue complet est disponible et rendu, sans promettre que chaque carrière attribue naturellement toutes ses bases.

Les traits déclarés observés restent séparés des consignes de génération. Trois cellules71/74/76 de players-04 présentent des marques d'aspect cicatriciel confirmées par trois lecteurs, sans prétendre décrire une blessure réelle. Les réserves visuelles portent sur quelques cheveux proches du bord et les ambiances différentes des anciennes planches. Aucun PNG n'a été retouché pour satisfaire un compteur.

L'inventaire public Atlas reste30villes+30stades présents et vérifiés. Le reçu privé86+86 et la couverture complète des portraits/logos des116clubs attendent un contrôle des reçus ou fichiers locaux. Le pack historique de58clubs ne prouve pas cette couverture. Aucun média privé ou profil personnel n'a été transféré.

## Intégration

La dernière CI complète devra être verte sur le SHA publié exact, suivie du gate officiel et du contrôle post-fusion. Les runs antérieurs ne valent pas validation de cette tête. Le timeout antérieur du test intégré académie a été comparé aux logs et reproduit localement : variance de durée, sans divergence logique démontrée ; aucun plafond n'est relevé pour le masquer.

### Corrections après la CI de 66d6225

L'auditeur des contrats cherchait encore les six alias dans les effectifs actifs. Il vérifie maintenant la source de compatibilité séparée et distingue 5 878 fiches actives, six alias historiques et 5 884 IDs lisibles ; toutes les gardes de rattachement restent actives. Dix tests ciblés et l'audit CLI de production passent, avec les mêmes 114 échéances et 71 modifications relevées.

Les trois campagnes France de référence précèdent les métadonnées de portraits. Leurs contextes de test reproduisent explicitement ces anciennes naissances, sans filtrer l'état final ou changer les SHA attendus. Les dix saisons et leurs 4 330 résultats retrouvent les documents, empreintes et curseurs de hasard d'origine. Les naissances actuelles de banque2 restent couvertes séparément par sept tests de vrais workers et de persistance.

Le [cache des prédicats natifs](native-save-predicate-cache-20261109.md) réduit ensuite le coût de validation sans retirer de contrôle. Les mêmes fonctions `Number.isFinite`, `Number.isInteger` et `Array.isArray` sont mémorisées au chargement. Sur le même parcours complet, le témoin frais66d prend118,247s et la version retenue98,364s, soit16,81% de gain mural ; exports, six checkpoints et deux fichiers de profil restent identiques à l'octet. Le plafond reste180s. Le contrat des types, coercitions, proxies et limites ainsi que les régressions de sauvegarde sont reçus ; le staging et le pont Godot sont vérifiés à nouveau après intégration. La CI du nouveau SHA demeure nécessaire.
