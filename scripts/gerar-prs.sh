#!/usr/bin/env bash
# Gera N pull requests no repositorio atual: para cada um cria uma branch,
# acrescenta uma linha com data/hora em log/atividade.log, commita, abre o PR
# e faz o merge. Para no primeiro erro.
#
# Uso:
#   scripts/gerar-prs.sh -n 10 -c "Nome <email>"   # 10 PRs com co-autor
#   scripts/gerar-prs.sh -n 50                     # 50 PRs sem co-autor
#
# Opcoes:
#   -n N         quantidade de PRs (obrigatorio)
#   -c "N <e>"   adiciona "Co-authored-by: N <e>" em cada commit
#   -u usuario   conta gh que precisa estar ativa (padrao: mdoin)
#   -p segundos  pausa entre um PR e o proximo (padrao: 10)

set -euo pipefail

n=""
coautor=""
usuario="mdoin"
pausa=10

while getopts "n:c:u:p:" opt; do
  case "$opt" in
    n) n="$OPTARG" ;;
    c) coautor="$OPTARG" ;;
    u) usuario="$OPTARG" ;;
    p) pausa="$OPTARG" ;;
    *) echo "opcao invalida" >&2; exit 2 ;;
  esac
done

if ! [[ "$n" =~ ^[1-9][0-9]*$ ]]; then
  echo "informe -n com um numero maior que zero" >&2
  exit 2
fi

ativa="$(gh api user --jq .login)"
if [[ "$ativa" != "$usuario" ]]; then
  echo "conta ativa no gh eh '$ativa', esperado '$usuario'. rode: gh auth switch -u $usuario" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ha alteracoes nao commitadas no repositorio, abortando" >&2
  exit 1
fi

padrao="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
mergeados=0

for ((i = 1; i <= n; i++)); do
  git checkout -q "$padrao"
  git pull -q --ff-only

  agora="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  branch="atividade/$(date -u +%Y%m%d-%H%M%S)-$i"
  titulo="registrar atividade de $agora"

  git checkout -q -b "$branch"
  mkdir -p log
  echo "$agora pr $i de $n" >> log/atividade.log
  git add log/atividade.log

  if [[ -n "$coautor" ]]; then
    git commit -q -m "$titulo" -m "Co-authored-by: $coautor"
  else
    git commit -q -m "$titulo"
  fi

  git push -q -u origin "$branch"
  url="$(gh pr create --base "$padrao" --head "$branch" --title "$titulo" --body "Acrescenta uma linha em log/atividade.log.")"
  gh pr merge "$url" --merge --delete-branch
  mergeados=$((mergeados + 1))
  echo "[$i/$n] mergeado: $url"

  if ((i < n)); then
    sleep "$pausa"
  fi
done

git checkout -q "$padrao"
git pull -q --ff-only
echo "total mergeado nesta rodada: $mergeados"
