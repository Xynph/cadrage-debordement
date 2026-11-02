# FAST LANE — développement plus rapide (2 novembre 2026)

## But
Augmenter le temps consacré aux fonctionnalités réellement jouables de Cadrage Débordement, sans diminuer la sécurité. Une seule session GitHub active entre les deux comptes ; toute PR doit être autorisée explicitement avant sa fusion ; CI complète, Validation CI, release gate et contrôle post-fusion 7/7 restent inchangés.

## Audit des frictions réelles

- **Lectures fragmentées :** le même main, AGENTS.md, DEVELOPPEMENT.md, issue #73, PR, runs et jobs sont parfois relus séparément à chaque phase. Le référentiel AGENTS.md demande déjà une lecture groupée en ouverture.
- **Précontrôle exhaustif :** le script existant ci/delivery-readiness.cjs lit deux fois main et PR, réinterroge les runs PR et main pour se protéger des courses, et interroge les jobs de chaque workflow. Compter au moins environ 12 appels REST dans un cas simple ; davantage s'il y a plusieurs workflows. **Ce précontrôle renforcé n'est pas supprimé.**
- **Passations longues :** #73 impose une prise et une passation, mais pas de recopier systématiquement tous les anciens résultats. Conserver les SHAs, le lot de fichiers, les liens de CI, le verdict et le rôle ; réserver les détails aux erreurs.
- **Tests :** les chantiers CI #205 à #207 ont éliminé des installations et des jobs redondants. La validation générale sur le HEAD exact et les 7 jobs post-fusion restent obligatoires, sans scrutation répétitive.
- **Décisions utilisateur :** distinguer l'autorisation de développer (départ) et l'autorisation explicite de fusion (PR + HEAD). Tous les autres contrôles techniques se font en autonomie.

## Nouveau diagnostic express (quatre lectures maximum)

    node ci/development-snapshot.cjs 207
    node ci/development-snapshot.cjs 207 --handoff
    node ci/development-snapshot.cjs 207 --json

Exige Node 22 et GitHub CLI authentifié (gh auth login), utilisable dans un checkout du dépôt. La commande effectue uniquement des GET, jamais un POST, et ne lance pas de test :

1. SHA réel de main.
2. Métadonnées PR et HEAD exact.
3. Derniers workflows pull_request associés à ce HEAD.
4. Les sept jobs du workflow principal Tests JavaScript, dont Validation CI.

Sortie compacte : CONTROLE_POSSIBLE, EN_ATTENTE ou STOP, run principal, statuts des workflows spécialisés, problèmes et SHA. L'option --handoff produit un texte à copier dans l'issue #73, **mais ne poste rien**. L'option --json permet l'exploitation par un assistant. Un nom de workflow redondant, une CI rouge, une tête obsolète, un run en cours, un dépôt étranger ou plus de 100 runs sur ce SHA sont traités avec prudence.

**Limitation de sécurité assumée :** il s'agit d'un **instantané informatif non atomique**, non d'une autorisation de fusion. Il ne certifie pas la dernière CI de main ni les rulesets, et peut être périmé aussitôt lu. Le gate officiel conservé dans ci/release-gate.cjs et ci/chat-release.cjs revalide les SHAs, CI et protections au moment d'une fusion. Le précontrôle complet ci/delivery-readiness.cjs reste disponible pour les réceptions exigeant une preuve exhaustive.

En mode Chat sans terminal, les quatre lectures équivalentes se groupent dans une seule session de connecteur GitHub ; il n'est pas nécessaire de multiplier les demandes ou les commentaires de progression.

## Nouvelle méthode de travail

| Phase | Action unique | Sécurité conservée |
| --- | --- | --- |
| 1. Demande de Léo | Lire main + règles + journal + dernière passation en un seul lot ; annoncer le chantier une fois dans #73 | Session exclusive ; fichiers réservés |
| 2. Développement | Un gros lot cohérent, tests ciblés, journal et tests dans le même commit | Moteur, rugby, sauvegardes et DATA vérifiés selon les fichiers changés |
| 3. Livraison PR | Un commit final et une PR ; une CI complète du HEAD final | Validation CI obligatoire ; logs détaillés seulement si échec |
| 4. Bilan | Un diagnostic express, passation courte, bouton d'autorisation ciblant la PR | Aucun droit de fusion implicitement transmis |
| 5. Intégration | Après autorisation distincte, /cd-check puis /cd-merge dans la même session réceptrice | Gate officiel sans bypass, SHA figé |
| 6. Contrôle final | Une CI post-fusion sur le SHA réel ; sept jobs verts puis passation | Jamais déclarer une fusion livrée avec un post-run rouge ou absent |

Ne jamais travailler simultanément avec le second compte sur le dépôt. Son prochain lot peut être **préparé** hors GitHub pendant la session active puis réservé et développé après la PASSATION #73.

## Gains quantifiables et limites

- **Budget de lectures :** 4 GET maximum pour un bilan informatif courant, contre environ 12 ou plus pour le précontrôle exhaustif avec relectures. Ce gain est mesuré en appels API structurels, **pas en secondes économisées** et non à périmètre de sécurité équivalent.
- **Cible pour les trois prochains cycles jouables :** 0 approbation intermédiaire en plus de la demande initiale et de la décision de fusion, 1 PR + 1 HEAD stable, 1 campagne CI complète par HEAD final, 0 commit cosmétique après tests, 1 bilan des statuts et logs approfondis uniquement en cas d'échec.
- **KPI à mesurer ensuite :** délai demande→PR, délai PR verte→fusion, temps total runners, nombre de lectures manuelles et de passations. Il serait trompeur d'affirmer un gain réel en délai de développement avant ces trois cycles.
- **Ne pas réduire les protections :** le raccourci n'affaiblit ni les règles GitHub, ni les sauvegardes, ni l'autorisation de Léo, ni la CI officielle.

Aucun nouveau workflow Actions automatique, aucune permission en écriture, aucun changement du code du jeu, ni du release gate.
