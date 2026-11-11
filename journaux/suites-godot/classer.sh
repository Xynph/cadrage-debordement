#!/usr/bin/env bash
# Classe les suites rejouées seules : usage classer.sh <dossier résultats>
cd "$1" || exit 1
while IFS=$'\t' read -r r t d code; do
  n=$(basename "$t" .cjs); log="logs/$n.log"
  if [ "$r" = PASS ]; then cat=REUSSITE
  elif grep -q 'contextual_flow.gd" does not exist' "$log"; then cat=AIDE_NON_INSTALLEE
  elif [ "$r" = TIMEOUT ] || grep -qE "ETIMEDOUT|null !== 0|status: null|SIGTERM" "$log"; then cat=DELAI_MACHINE
  elif grep -q "not a child of the calling process" "$log"; then cat=PLATEFORME_LINUX
  elif grep -q "SCRIPT ERROR" "$log"; then cat=ERREUR_SCRIPT
  else cat=ASSERTION; fi
  msg=$(grep -m1 -E 'SCRIPT ERROR|FAIL[: ]|not ok|ERROR:' "$log" | cut -c1-140)
  printf "%s\t%s\t%ss\t%s\n" "$cat" "$n" "$d" "$msg"
done < results.tsv | sort
