#!/usr/bin/env bash
# Shows the keys that a language file does not have. English is the reference.
# Usage: lang-check.sh [code...]   for example: lang-check.sh ur
# To add a language: cp lang/en.txt lang/<code>.txt, translate, run this script.
set -euo pipefail
DIR=$(dirname "$(readlink -f "$0")")/lang
keys() { grep -oE '^[a-z_]+=' "$1" | tr -d = | LC_ALL=C sort -u; }
codes=("$@")
[[ ${#codes[@]} -gt 0 ]] || mapfile -t codes < <(ls "$DIR" | sed -n 's/\.txt$//p' | grep -vx en)
bad=0
for code in "${codes[@]}"; do
  f=$DIR/$code.txt
  [[ -f $f ]] || { echo "$code: no file $f"; bad=1; continue; }
  missing=$(LC_ALL=C comm -23 <(keys "$DIR/en.txt") <(keys "$f"))
  extra=$(LC_ALL=C comm -13 <(keys "$DIR/en.txt") <(keys "$f"))
  # A text must have the same number of %s as the English text.
  args=$(awk -F= 'NR==FNR {if (/^[a-z_]+=/) n[$1]=gsub(/%s/,"&"); next}
    /^[a-z_]+=/ && ($1 in n) && gsub(/%s/,"&") != n[$1] {print $1}' "$DIR/en.txt" "$f")
  if [[ -z $missing && -z $extra && -z $args ]]; then
    echo "$code: OK ($(sed -n 's/^_name=//p' "$f"))"
    continue
  fi
  bad=1
  [[ -z $missing ]] || printf '%s: missing keys (English is shown):\n%s\n' "$code" "$(sed 's/^/  /' <<<"$missing")"
  [[ -z $extra ]] || printf '%s: unknown keys:\n%s\n' "$code" "$(sed 's/^/  /' <<<"$extra")"
  [[ -z $args ]] || printf '%s: wrong number of %%s:\n%s\n' "$code" "$(sed 's/^/  /' <<<"$args")"
done
exit "$bad"
