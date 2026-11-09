# Mentorat du staff — conception et plan

Le cycle staff existant garde ses identités, âges, contrats et salaires descriptifs. Un domaine optionnel `staffMentoring` relie un membre de terrain à un jeune et à une qualité autorisée pour son poste. Une personne ne peut encadrer qu'un jeune à la fois et un jeune n'a qu'un mentor. Les compétences de référence restent des estimations : l'expérience pédagogique nouvelle mesure uniquement des séances réellement encadrées.

L'encadrement redistribue le même budget d'XP d'entraînement : 25 % ciblés puis 50 % après huit séances observées, le reste allant à la progression générale. Aucun multiplicateur, débit, potentiel ni coefficient économique nouveau. Ce choix favorise une qualité aux dépens du niveau général. Les plans de jeunes explicites ont priorité ; les profils à courbe annuelle restent hors de ce mécanisme spécialisé. Blessure, repos, plafonds ou départ du mentor interrompent son effet. Une révision de qualité suit la règle existante de remise à zéro des XP ciblés partiels.

Choix d'architecture : domaine indépendant sérialisé dans la VM native et raccordé au manifeste par l'intégrateur. L'alternative d'un second moteur de croissance ou de salaires arbitraires est écartée. Aucune migration silencieuse : absence du champ = comportement identique.

## Plan

- [x] Tester activation/rejet, affectation, partage conservatif d'XP, progression observée, priorité des plans, départ, repos, import.
- [x] Implémenter le domaine et ses hooks autour de la séance existante.
- [x] Ajouter les commandes de mentorat à la vue Staff partagée.
- [x] Exécuter régressions ciblées et noter les raccordements d'intégration.

## Limites explicites et intégration

Le ciblage manuel natif offre déjà 50 % : l'encadrement débutant à 25 % privilégie davantage le niveau général puis rejoint cette répartition après huit séances observées. Il ne prétend pas débloquer un avantage exclusif. Les identités de référence n'ont aucune compétence officielle nouvelle ; l'expérience pédagogique est un compteur des séances réelles, pas un diplôme ou une prédiction sur une personne réelle. Les salaires et contrats staff restent descriptifs v1 ; cette tranche ne livre pas une nouvelle économie du personnel.

Les affectations inactives restent visibles avec leur motif. Une nouvelle affectation réussie libère les liens devenus indisponibles et les références des mentors partis, ce qui empêche une saturation après mobilité ; les refus ne purgent rien. Les observations conservées sont bornées à huit par mentor. Les plans jeunes explicites gardent priorité même lorsque leur qualité actuelle a divergé. L'import d'un mentorat sans cycle staff est refusé.

Raccordement root : ajouter `staffMentoring:require('./staff-mentoring.cjs')` à `domains` dans `native/engine/native-systems.cjs`. Aucun alias global ni modification de worker, de schéma browser ou de fichiers de progression nécessaire. `installHooks` enveloppe `developmentTraining`, conserve les autres marqueurs/hooks et restaure la méthode de répartition dans un `finally`. L'UI existante lit `clubLife.staffMentoring`, dans la page Staff partagée classique/immersive. Les fichiers engine/UI sont inclus automatiquement par le build natif.

Validation exécutée sous Node22 : tests du domaine (activation, conservation XP, seuil pédagogique, séances uniques, plans prioritaires, pause, départ, âge/courbe annuelle, mobilité, plafond du registre, refus sans mutation, import strict). Régressions staff-career, jeunesse et spécialisation également exécutées. La recette UI Godot4.7.2 headless valide activation, sélecteurs et commande/context ; elle utilise un modèle témoin, ne prétend pas être une carrière native complète ou une recette Windows. Le parse/import Godot a réussi avec stockage XDG temporaire (la première tentative sans XDG a exposé des dossiers système non inscriptibles, pas une erreur de script).
