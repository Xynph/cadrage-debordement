# Déblocage des feuilles IA dans le mode historique à14 clubs

## Défaut et preuve

Diagnostic réel, sans UI : E:/Cadrage-Debordement/artefacts/session-autonome-20261107/diagnostic-banc/RAPPORT.txt. Graines1 et5 échouent au deuxième begin_match. Minimum graine5 : new_career{club:0}, begin_match, delegate, finish_round, begin_match. Le club12 a un spécialiste blessé ; buildSheet renvoie null dans le banc et22 joueurs désignés. validateCareer refuse légitimement le live ; rollback et disque restent inchangés. Rejeu VM exact à la graine enregistrée, SHA des états et RNG concordants. Le correctif ne doit pas transformer un test aléatoire en test chanceux en choisissant une graine qui passe.

## Résultat et limites

Avant de créer une rencontre native fiction14 dont la gestion IA est active, compléter la feuille adverse avec le mécanisme de couverture existant CDFranceCareer.ensureAISheet, comme dans le mode France actuel. Les cas1 et5 sont déjà résolus dans le diagnostic VM : un renfort, mêmes joueurs existants et blessures, pas de RNG consommé par la couverture, pas de mutation immédiate de trésorerie, appel idempotent et validation complète. Le salaire et le contrat du renfort ont un effet futur réel ; ne pas le masquer.

Limiter l'appel aux structures prises en charge. Le helper lit S.aiRoster.academies ; ne pas l'appeler aveuglément sur les anciennes carrières sans aiRoster actif, ni si le module n'est pas disponible dans un contexte ancien. Vérifier la frontière managers/aiRoster des anciens formats. Garder le parcours France existant et la validation stricte des groupes ; aucun assouplissement de saves.js, hausse des plafonds ou soin artificiel. Ne pas compléter automatiquement la feuille du joueur humain.

## Règles

Lire docs/rugby-rules-reference.md avant modification. Profil de match inchangé fr-pro-2025 et saison abstraite du mode historique. La loi3 World Rugby (source officielle consultée7/8novembre2026) distingue quinze sur terrain, remplaçants désignés et premières lignes entraînées ; elle n'impose pas notre algorithme de génération. Source https://passport.world.rugby/fr/les-regles-du-jeu/regles-du-jeu-par-numero/3-l-equipe/ , paragraphes3.4–3.12. Ne pas adopter ses mises à jour ultérieures ou variantesM19. Le défaut concerne le format23 interne attendu par le moteur, pas une nouvelle interprétation réglementaire. Le renfort académique existant, parfois âgé17ans, demeure une abstraction de gestion sans certification administrative ou médicale. Aucune prétention de conformité intégrale.

## Tâches

1. Écrire tests/native-fiction-sheet.cjs avec vrais bridges graine1/5, démontrer le rouge sur le code de base et préserver le cas sain avant blocage. Cas strict refusant toujours une feuille falsifiée avec null, sans mutation/disque/RNG.
2. Raccord borné avant construction des feuilles dans dist/rugby.js ; factoriser uniquement si indispensable. Préserver les blessures, IDs uniques/qualifications, événements de renfort, contrat/salaire, plafonds et calendrier. Comparer état/RNG de la couverture et idempotence.
3. Tester finJ1/débutJ2, export/import et redémarrage, vraie continuation avec contrôle RNG ; cas France/common inchangés ; ancien format sans aiRoster et absence de module inchangés/erreur explicite selon contrat existant, pas de migration implicite.
4. Tests ciblés natif gestion/rugby/sauvegardes pertinents, pas de campagne CI exhaustive aveugle. Documenter cause, abstraction, limites et preuves dans docs/native-fiction-sheet-20261108.md, puis commit local Codex. Rapport .superpowers/sdd/2026-11-08-native-fiction-sheet/task-report.md.

## Coordination

Worktree Eci, branche fix/native-fiction-ai-sheet-20261108, base7abdfa9. Chemins dist/rugby.js, tests/native-fiction-sheet.cjs, documentation et plan de ce correctif. Extension dist/france-career.js ou ai-roster-cycle.js seulement si besoin prouvé et signalé au parent. Exclure tout Godot, main, BDD, README/DEVELOPPEMENT (parent), formats de sauvegarde et worker. Parent intègre avec UI/coach dans principal après revue indépendante renforcée et réception Windows. Aucun push, GitHub ou sous-agent par le producteur.
