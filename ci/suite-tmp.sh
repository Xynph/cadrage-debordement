#!/usr/bin/env bash
# Dossier temporaire dédié à chaque suite (à « source » depuis les lanceurs).
# Les suites créent leurs dossiers de travail avec fs.mkdtempSync(os.tmpdir()) ou mktemp : sous TMPDIR
# propre à la suite, tout ce qu'elles laissent (échec, délai 124, SIGKILL) est supprimé d'un bloc après la suite.
#   cd_suite_tmp_new <base>  -> crée <base>/suite.XXXXXX et affiche son chemin
#   cd_suite_tmp_drop <dir>  -> supprime ce dossier, sauf CD_KEEP_TMP=1 (débogage : le chemin est affiché)
cd_suite_tmp_new() { mktemp -d "${1:?base requise}/suite.XXXXXX"; }
cd_suite_tmp_drop() {
  local dir="${1:-}"
  [[ -n "$dir" && -d "$dir" ]] || return 0
  if [[ "${CD_KEEP_TMP:-0}" == 1 ]]; then
    echo "CD_KEEP_TMP=1 : dossiers temporaires conservés dans $dir" >&2
    return 0
  fi
  rm -rf "$dir"
}
