# Menu V3 — conception et réalisation

Objectif : un accueil jouable vert sombre/orange, avec stade original au coucher du soleil, navigation latérale et cinq cartes de carrières fondées sur les snapshots V2.

Approche retenue par l'intégrateur : conserver CDMenuSlots et les callbacks de création/import/pause existants, ajouter un module de présentation main-menu-v3.js et une feuille main-menu-v3.css. Un stade fictif original généré avec imagegen est livré en WebP local (214 868 octets), sans marque, sponsor ni requête réseau en jeu. Le SVG original de secours est proposé sous CC0-1.0. Aucun framework ni dépendance de production.

1. Écrire les tests de présentation (5 cartes, données réelles, erreur isolée, stockage inchangé, difficulté persistée, préférences séparées). Observer leur échec.
2. Réaliser le module, les styles et le stade. Raccorder au renderer existant ; inclure la difficulté native entre univers et club. Pas de profil entraîneur non pris en charge.
3. Tester navigation au clavier, focus et dialogues, réduction d'animation, contraste et taille du texte ; les erreurs de stockage restent visibles.
4. Tests Node ciblés, suite complète, Chromium à 1440/768/390 px, création/reprise/import/pause/réglages et captures réelles.
5. Documenter, publier une PR depuis main validé après #157, vérifier le SHA et l'arbre, CI complète, fusion avec SHA attendu, contrôle push.

Risques à couvrir : index ou snapshot corrompu ; ancienne carrière hors bibliothèque ; 5 slots pleins ; nom hostile ; stockage refusé ; focus perdu après rendu ; menu pause qui reprendrait le chronomètre sans action explicite. Aucun changement Business, format de sauvegarde ou source DATA.

## Réalisation

- `main-menu-v3.js/css` : accueil fonctionnel, navigation, cinq cartes, données lues depuis les snapshots vérifiés V2 (club, abréviation native en écusson, saison, journées réellement jouées, horodatage réel du slot). Aucun classement, calendrier ou logo officiel inventé.
- Nouvelle carrière : univers fictif ou snapshot LNR existant, choix du club et des trois niveaux IA natifs. La difficulté est enregistrée dès le premier snapshot. Aucun profil d'entraîneur ajouté au format de sauvegarde.
- Réglages : thème des écrans de gestion, réduction des animations, contraste et texte du menu, plein écran si le navigateur l'autorise. Préférences séparées des carrières ; refus d'écriture signalé. `prefers-reduced-motion` reste prioritaire.
- Clavier : lien d'évitement, focus visible, Échap, focus initial et boucle Tab dans les dialogues ; retour au bouton déclencheur après annulation, y compris après reconstruction du DOM. Pause native, chronomètre arrêté et carrière conservée au retour menu.
- Aucun changement de format de sauvegarde, de moteur rugby, de données Business ou DATA ; aucun appel LNR/ItsRugby/Firecrawl.

## Asset et provenance

`dist/assets/menu-stadium.webp` : image originale créée pour ce projet par l'outil intégré imagegen le 31 octobre 2026, puis compressée en WebP. Stade fictif, aucune photographie téléchargée, marque, sponsor ni élément de club tiers. Prompt : « cinematic empty rugby union stadium at sunset, sideline field level, deep green grass, H-shaped rugby posts, grandstands and steel roofs, orange sunset on the right, realistic materials and lighting; no text, logos, sponsors, watermark or UI ». La version SVG originale déterministe est un secours indépendant sous CC0-1.0 ; aucun logo officiel n'est revendiqué. Aucun service externe nécessaire à l'exécution.

## Validation et limites

- Tests Node du menu : métadonnées réelles, rendu sans écriture, compatibilité carrière historique, index/copie corrompus, cinq emplacements pleins, préférence refusée, difficulté native persistée.
- Scénario `tests/main-menu-v3-browser.py` : 31 contrôles Chromium, captures 1440/768/390, absence de débordement, clavier et focus, import JSON avec annulation, création de deux carrières, restauration, pause, persistance et absence de requêtes externes.
- Les captures versionnées dans `docs/menu-v3-captures/` proviennent du jeu exécuté avec une carrière fictive de test isolée. Elles ne contiennent aucune sauvegarde personnelle.
- Régression UI01 et contrastes exécutés séparément ; suite Node complète et CI finale exactes requises avant fusion. Les rapports Actions font autorité pour la livraison distante.
- Limites : pas de certification Windows native, pas de profils personnalisés d'entraîneur, pas de sauvegarde cloud ; écussons typographiques existants, pas de nouveaux emblèmes officiels. La barre mesure les journées régulières jouées, pas une progression inventée vers un titre.

Prochaine évolution proposée : étendre cette identité au bureau du manager avec le prochain match et trois décisions prioritaires réellement calculées depuis la carrière.


## Rapprochement visuel de la maquette de référence — passe V3.1

- **Grand écran** : mise en page en trois zones réelles, chacune avec sa fonction : navigation à gauche, cinq carrières en grandes lignes horizontales au centre, panneaux de raccourcis à droite. Le stade WebP original demeure visible sur tout l'arrière-plan.
- **Hiérarchie** : logo massif blanc avec soulignement orange ; action Continuer dominante ; titre « Reprenez votre carrière » ; contour lumineux orange sur la carrière active et contrôles de reprise/suppression identifiés.
- **Données authentiques** : le nom et l'abréviation d'écusson viennent du club de la carrière sauvegardée, la saison et le nombre de journées de l'état natif, la dernière sauvegarde de la date du slot V2 ; pas de classement inventé, de logo officiel téléchargé ou d'illustration spécifique à un club fictivement attribuée.
- **Illustration** : vignette de chaque carte = recadrage de la photographie de stade originale locale, avec variation de cadrage. Les panneaux droits utilisent le même asset ; ce n'est pas une image de joueurs ou d'écussons officiels. Aucune requête externe n'est déclenchée par l'interface.
- **Responsive** : trois colonnes au format large ; colonne latérale puis carrières + raccourcis empilés sur tablette ; navigation compacte et cartes adaptées au petit mobile. Tous les boutons conservent un nom accessible distinct, un focus visible et les actions natives.
- **Tests de régression** : présence de la composition à trois zones, des cinq cartes en colonne verticale, du panneau illustré et absence de débordement aux trois largeurs Chromium (1440, 768, 390 px). Les assertions précédentes de création, import JSON, reprise et pause restent obligatoires.

La maquette visuelle n'est pas une capture du jeu ; les captures réellement produites par la CI après cette passe font autorité pour le rendu livré.


## V3.2 — Ballon de rugby authentique au premier plan

Ajout d'un asset local original `dist/assets/menu-rugby-ball-muddy.svg` : ballon ivoire légèrement usé, cuir granuleux, coutures visibles, traces de terre et d'herbe, éclairage orange d'un soleil bas, ombre au sol et brins d'herbe devant le ballon. L'image n'utilise aucune marque officielle ni texte d'un club. Elle est affichée **uniquement comme décoration en bas à droite** du menu, sans modifier le moteur ou les carrières.

Le rendu CSS (`.cd3-right-bottom`) est non interactif (`pointer-events:none`) pour ne jamais masquer les commandes, et se réorganise sous les panneaux sur tablette et mobile. Aucun service d'images externe, police supplémentaire ou suivi réseau n'est chargé.

Régressions ajoutées aux tests V3 : présence de l'asset et du CSS en JS, puis contrôle Chromium de la visibilité et du non-recouvrement aux largeurs 1440, 768 et 390 px. La réalisation reste une **illustration texturée** et non une photographie de ballon officiel.


## V3 — Direction artistique photo et référence Figma (31/10/2026)

Conception structurée dans un [fichier Figma éditable](https://www.figma.com/design/Hi8W8uT1zHWyfrY0WJj3V2) : composition trois colonnes, cinq cartes horizontales, actions latérales, zones photographiques et positions du ballon. Figma est une **maquette de direction artistique**, pas une capture du jeu exécuté ; ses noms de clubs/dates illustratifs ne sont jamais injectés dans les sauvegardes du jeu.

**Nouveaux assets originaux intégrés localement au jeu :**
- `dist/assets/menu-stadium-cinematic.png` : photographie synthétique d'un stade de rugby XV au soleil couchant, projecteurs et pelouse, aucun logo ou sponsor officiel.
- `dist/assets/menu-rugby-ball-photoreal.png` : photographie synthétique d'un ballon usé, **légèrement boueux**, grain de cuir, couture et brins d'herbe. Placé à droite en bas, avec fondu de bordure pour le fond de jeu.
- Création via Figma AI / modèle image de l'éditeur. Les deux copies sont committées dans le dépôt, **sans dépendance aux URL Figma temporaires à l'exécution**.

**Fidélité / intégrité** : le style `main-menu-v3.css` substitue ces assets aux précédentes illustrations sans modifier le code de carrière, la lecture des slots, les niveaux d'IA, les confirmations d'import, la pause ou les sauvegardes. En responsive, les panneaux passent sous les cartes, et le ballon décoratif conserve `pointer-events:none`. `prefers-reduced-motion` reste respecté. Le stade photographique reste sous des voiles sombres pour la lisibilité des textes.

**Validation requise avant fusion :** test Node sur les signatures PNG et les références CSS, test Chromium du chargement local et de la visibilité du ballon aux largeurs 1440, 768 et 390 px, test de non-débordement, scénarios fonctionnels préexistants, `Tests JavaScript` avec `Validation CI` sur le SHA final ; après fusion, contrôler la CI `push` sur le nouveau `main`. Ne pas revendiquer un contrôle visuel manuel Playwright dans Work si non exécuté.
