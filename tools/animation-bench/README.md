# Banc de retargeting pour une célébration

Le banc compare un lever de bras écrit à la main et le même geste reconstruit à partir de repères 3D générés sur un mannequin de 22 os. Le premier passage utilise des repères exacts. Le second perturbe les chevilles et les pointes des pieds avec deux sinusoïdes d’amplitude 4 mm par axe, à 2 Hz sur X et 3 Hz sur Z. Les bras et le bassin restent des entrées exactes. Les trois clips durent 2 s et sont échantillonnés à 30 images par seconde, avec les deux extrémités incluses.

Le banc appelle `Rig.applyLandmarks` et `trackToClip` directement dans le module JavaScript de prompt2rig. Il vérifie la révision Git et l’intégrité du module avant de l’importer. Les trois clips sont exportés avec le même squelette et le même maillage synthétique. [Source de prompt2rig](https://github.com/blendi-remade/prompt2rig/blob/218ce2adff35a7c04657768a85ff002ebd461c78/public/retarget.js)

## Rejouer le banc sous Windows

Depuis la racine du dépôt, avec Git et Node.js 22 ou supérieur. Utiliser un nouveau dossier de travail à chaque exécution ou choisir un nouveau nom de dossier de sortie.

```powershell
$bench = Join-Path $env:TEMP 'oval-animation-bench'
$source = Join-Path $bench 'prompt2rig'
$out = Join-Path $bench 'output'
New-Item -ItemType Directory -Path $bench
git clone https://github.com/blendi-remade/prompt2rig.git $source
git -C $source checkout --detach 218ce2adff35a7c04657768a85ff002ebd461c78
npm.cmd install --prefix $bench --no-save --ignore-scripts --no-package-lock three@0.169.0
node tools/animation-bench/compare.mjs $source $out
```

Le programme écrit `report.json` et trois GLB dans `$out`. Le rapport inclut les tailles et les SHA-256. Les trois GLB et le rapport ont donné les mêmes SHA-256 avec Node 22 et 26 sur la machine de test.

Pour vérifier la lecture native, définir `$godot` sur le chemin de l’exécutable console de Godot 4.7.2. La validation ouvre les GLB hors du projet Oval Legacy et vérifie le squelette et l’animation de chacun.

```powershell
@'
config_version=5

[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $out 'project.godot') -Encoding utf8NoBOM
Copy-Item tools/animation-bench/validate-godot.gd $out
& $godot --headless --path $out --script res://validate-godot.gd
```

## Mesures observées

| Variante | Dérive XZ du pied (mm) | Écart vertical du pied (mm) | Erreur maximale du poignet (mm) | Écart de boucle (° / mm) | Taille (octets) |
|---|---:|---:|---:|---:|---:|
| Écrite à la main | 0 | 0 | Référence | 0 / 0 | 73 012 |
| Retargeting avec repères exacts | 0 | 0 | 0 | 0 / 0 | 73 444 |
| Retargeting avec repères des pieds perturbés | 9,634 | 0,481 | 0 | 0 / 0 | 73 944 |

La dérive et l’écart vertical comparent les pointes des pieds à leur propre position initiale. L’erreur du poignet compare sa position au clip de référence, image par image. L’écart de boucle mesure la plus grande différence de rotation des os, et la plus grande différence de position parmi les pieds et les poignets, entre la première et la dernière image. Les trois variantes comptent 61 images finies et le plus grand écart angulaire entre deux images consécutives est de 6,0131°. Avec les repères de pied perturbés, le clip produit une dérive mesurable alors que la pose de référence garde les pieds fixes.

## Audit du lot

- Présents et contrôlés pour les trois variantes. Noms en minuscules séparés par des traits de soulignement, en-tête GLB 2.0, taille, SHA-256, clip nommé, 23 canaux, squelette de 22 os et maillage de 264 triangles. Import confirmé sous Windows avec Godot 4.7.2 en mode headless.
- Non évalués. Budget de taille pour les personnages Oval Legacy, références dans le jeu, performances et mémoire GPU, qualité sur une capture réelle et sur le rig final. Le banc utilise des repères calculés directement, donc sans détection MediaPipe ni traitement SMPL/GVHMR. Il fonctionne avec un mannequin riggé par script, sans capture vidéo ni service hébergé.

La grille reprend les contrôles de format et de taille du guide `asset-audit` de Claude Code Game Studios, en séparant les observations des points qui demandent une ressource ou un seuil propre à Oval Legacy. [Guide `asset-audit`](https://github.com/Donchitos/Claude-Code-Game-Studios/blob/abc0de79d6ceb0b5d7aa693945849b3937afbe6a/.claude/skills/asset-audit/SKILL.md)
