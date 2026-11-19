#!/usr/bin/env bash
# Batterie horaire rouge sur main (voir .github/workflows/main-rouge.yml).
# Variables : GH_TOKEN, GITHUB_REPOSITORY, RUN_ID, ATTEMPT, SHA, ESSAI (true = rien n'est écrit).
set -uo pipefail
REPO="${GITHUB_REPOSITORY:?}"
ESSAI="${ESSAI:-false}"
TABLEAU=591
RUN_URL="https://github.com/$REPO/actions/runs/$RUN_ID"
log() { echo "[main-rouge] $*"; }

if (( ATTEMPT < 2 )); then
  log "première tentative rouge : relance des seuls jobs en échec ($RUN_URL)"
  [[ "$ESSAI" == "true" ]] || gh run rerun "$RUN_ID" --repo "$REPO" --failed || log "relance impossible"
  exit 0
fi

# Main avancé depuis : la batterie horaire suivante tranchera (évite un retour arrière sur un état dépassé).
tete=$(gh api "repos/$REPO/git/ref/heads/main" --jq .object.sha)
# Dernière batterie horaire verte sur main : point de départ des suspects.
vert=$(gh api "repos/$REPO/actions/workflows/tests.yml/runs?event=schedule&branch=main&status=success&per_page=1" \
  --jq '.workflow_runs[0].head_sha // ""')
noms=$(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=50" --jq '[.jobs[] | select(.conclusion=="failure") | .name] | join(", ")')
if gh run view "$RUN_ID" --repo "$REPO" --log-failed 2>/dev/null | grep -qE 'ETIMEDOUT|ECHEC \(124\)|exit code 124|timed out|dépass'; then
  cause="délai dépassé"
else
  cause="assertion rouge"
fi
prs=()
if [[ -n "$vert" ]]; then
  mapfile -t prs < <(gh api "repos/$REPO/compare/$vert...$SHA" --jq '.commits[].commit.message | split("\n")[0]' \
    | grep -oE '\(#[0-9]+\)$' | tr -d '()#' | sort -un)
fi
liste=$(printf '#%s, ' "${prs[@]}"); liste="${liste%, }"
texte="MAIN ROUGE après relance ($cause) : batterie horaire $RUN_URL sur \`${SHA:0:8}\` (jobs : ${noms:-?}).
PR fusionnées depuis la dernière batterie horaire verte (\`${vert:0:8}\`) : ${liste:-inconnues}.
Règle : corriger main avant toute autre fusion."

revert=""
if (( ${#prs[@]} == 1 )) && [[ "$tete" == "$SHA" ]]; then
  n="${prs[0]}"
  commit=$(gh api "repos/$REPO/compare/$vert...$SHA" --jq '.commits[] | select(.commit.message | split("\n")[0] | endswith("(#'"$n"')")) | .sha' | tail -1)
  if [[ -n "$commit" && "$ESSAI" != "true" ]]; then
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    branche="revert/pr-$n-${SHA:0:8}"
    git checkout -q -B "$branche" "$SHA"
    if git revert --no-edit "$commit" >/dev/null 2>&1 && git push -q -f origin "$branche"; then
      revert=$(gh api "repos/$REPO/pulls" -f title="Retour arrière de #$n (batterie horaire rouge)" -f head="$branche" -f base=main \
        -f body="Batterie horaire rouge après relance ($cause) : $RUN_URL. Seule PR fusionnée depuis la dernière batterie horaire verte : #$n. Retour arrière automatique ; corriger #$n puis la reproposer." --jq .number) || revert=""
      [[ -n "$revert" ]] && { gh pr merge "$revert" --repo "$REPO" --auto --squash || log "fusion automatique non activée sur #$revert"; }
    else
      log "retour arrière de $commit impossible (conflit ?)"
    fi
  fi
fi
[[ -n "$revert" ]] && texte="$texte
Retour arrière automatique de #${prs[0]} : #$revert (fusion automatique dès que sa CI est verte)."
log "$texte"
[[ "$ESSAI" == "true" ]] || gh api "repos/$REPO/issues/$TABLEAU/comments" -f body="$texte" >/dev/null
exit 0
