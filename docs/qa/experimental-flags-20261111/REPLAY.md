# Rejouer les sondes isolées

Aucune sonde n'utilise une carrière utilisateur. Employer des copies isolées des
SHA cités dans le rapport, Node 22.23.4 et Godot 4.7.2 Linux. Effectuer le staging
natif officiel (`scripts/build-godot-prototype.py --stage-only --node ...`) puis
l'import Godot avant les sondes d'interface. Acquérir
`/tmp/rg27-godot-sdk.lock` séparément pour chaque invocation Godot.

- `worker-probe.cjs /copie-source /tmp/resultat.json` : création, semaine jouée,
  export/import et reprise ; le drapeau salarial vient de l'environnement du
  processus appelant. Le résultat inclut les quatre textes complets et leurs
  empreintes ; les fichiers JSON conservés ici retirent uniquement ces textes.
- `resume-probe.cjs /copie-source` : active une création commune club29/graine27,
  ferme, retire le drapeau et compare le premier modèle d'un nouveau bridge.
- `environment-probe.gd` : le chemin absolu du worker dans
  `ProjectSettings.set_setting` pointe vers la copie locale exacte utilisée
  pendant l'audit. Adapter **cette ligne dans une copie QA du pilote** vers le
  worker candidat avant de rejouer ailleurs. Le projet Godot reste celui de la
  PR554 ; ce montage sert à isoler le transport, sans modifier la production.
  Fournir `CD_NODE_EXECUTABLE` et un nouveau dossier absolu
  `CD_ENV_PROBE_PROFILE`. Lancer une fois avec `CD_MATCH_GESTES` et
  `CD_SALAIRES_PAR_NIVEAU` absents, puis une autre fois avec ces deux valeurs à
  `1`, en utilisant deux profils neufs. Chaque exécution ouvre ensuite un nouveau
  bridge sur son profil pour observer le premier modèle de reprise.
- `socle-env-probe.gd` : projet de la PR550, trois invocations indépendantes avec
  `CD_SOCLE_EFFECTIF` absent, `0`, puis `1`. Le pilote observe aussi l'activation
  explicite par métadonnée, qui n'est pas le défaut.
- `socle-off-ui-probe.gd` : même projet, drapeau socle absent,
  `CD_GODOT_SELF_TEST=0`, `CD_GODOT_GUIDE_MODULE_TEST=1`,
  `CD_NODE_EXECUTABLE` et nouveau `CD_GODOT_DATA_DIR` absolu. Vérifie le véritable
  ancien écran `CarnetSquad`, l'absence du nouveau et le profil inchangé.

Invocation Godot commune :

```sh
flock /tmp/rg27-godot-sdk.lock "$GODOT" --headless --audio-driver Dummy --max-fps 60 --path /copie-source/native/godot --script /copie-qa/pilote.gd
```

Les journaux `environment-*.log` montrent une activation correcte, puis un budget
et plancher absents lors de la reprise ON : cette dernière observation est la
**reproduction du défaut**, pas un résultat produit attendu. Les pilotes de
transport impriment des faits ; les assertions interprétant leurs sorties ont
été exécutées séparément pendant l'audit et les faits sont conservés dans
`environment-chain.json`. Aucun compteur de parole n'est affirmé.
