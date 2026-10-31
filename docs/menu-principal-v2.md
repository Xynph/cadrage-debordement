# Menu principal V2 — Cadrage Débordement

Écran initial du jeu (navigateur et application portable). Aucune collecte de données, aucune mutation du moteur sportif.

## Parcours
- **Continuer** reprend la sauvegarde canonique existante `bdt-v1` seulement sur action explicite, avec reprise d'un match en pause si nécessaire.
- **Nouvelle carrière** choisit l'univers fictif ou les groupes LNR sourcés, puis le club. Si une carrière est ouverte, une confirmation conserve d'abord l'ancienne dans sa bibliothèque locale. Si l'archivage échoue, l'ancien état n'est pas effacé.
- **Mes carrières** permet jusqu'à cinq emplacements locaux, avec nom, date de mise à jour, reprise après examen, suppression confirmée et archivage de la carrière courante. La suppression d'un emplacement ne détruit jamais automatiquement la sauvegarde active `bdt-v1`.
- **Importer une sauvegarde JSON** utilise le processus de validation et de restauration préexistant (limite de taille, contrôles d'identité, copie de secours et confirmation).
- **Réglages** modifie le thème et l'animation du menu sans changer la carrière. **Pause / Options** conserve le match en pause, puis propose retour au jeu, sauvegardes ou menu principal.

## Compatibilité et intégrité
- `bdt-v1` reste l'enregistrement actif canonique ; la bibliothèque V2 utilise des clés distinctes `cd-career-slots-v2` et `cd-career-slot-v2:<id>`.
- Les snapshots ont un checksum déterministe et sont **révalidés** par `validateCareer` avant restauration. Un snapshot corrompu n'est jamais chargé automatiquement.
- La mémoire d'interface et les préférences ne sont pas ajoutées aux objets de carrière ni aux exports historiques.
- Les doubles écritures locales peuvent dépasser le quota du navigateur : les échecs sont signalés, les exports JSON restent recommandés. Les sauvegardes ne sont pas synchronisées entre appareils.
- Le mode LNR est une simulation : effectifs sourcés au 31/10/2026, finances et résultats fictifs. Aucun nouvel attribut réel n'est ajouté.

## Vérification
`node --test tests/main-menu-v2.cjs`, `node tests/main-menu.cjs` et CI complète JavaScript / Chromium. Les tests d'interface antérieurs ouvrent explicitement le menu et l'univers de carrière avant la sélection des clubs.

Limites : cinq snapshots locaux maximum ; aucune sauvegarde cloud, ni Windows natif revendiqués.
