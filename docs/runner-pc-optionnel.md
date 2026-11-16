# Runner du PC de Léo : en option, GitHub en repli

Décision de Léo (16/11/2026) : le PC personnel sert quand il est disponible, GitHub sinon.

Tous les jobs Linux lisent la variable de dépôt `CI_RUNNER_LINUX` :

- variable absente ou vide : `ubuntu-24.04` (GitHub) ;
- PC allumé avec son runner : `["self-hosted","Linux","X64","rl27-linux"]`.

Basculer : Settings → Secrets and variables → Actions → Variables, ou
`gh variable set CI_RUNNER_LINUX --body '["self-hosted","Linux","X64","rl27-linux"]'` ;
repli : `gh variable delete CI_RUNNER_LINUX`. Une exécution déjà lancée garde son runner.

Les jobs Windows (`windows-release.yml`) ne changent pas. L'installation du runner
sur le PC reste le chantier de #743 (Codex) : elle doit seulement poser le runner
avec l'étiquette `rl27-linux`, sans retirer le repli.
