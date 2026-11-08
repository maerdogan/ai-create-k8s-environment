# shellcheck shell=bash
# Screen helpers of the menus: colors, texts, lists and confirmations.
# Source after lib.sh and lib-state.sh.
# shellcheck disable=SC2034,SC2059
LANG_DIR=$CONTROL/lang
MENU_CONF=$STATE/menu.conf
QUIT=10

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  GREEN=$'\e[32m' RED=$'\e[31m' YELLOW=$'\e[33m' BLUE=$'\e[94m' PURPLE=$'\e[35m'
  GRAY=$'\e[90m' BOLD=$'\e[1m' OFF=$'\e[0m'
else
  GREEN='' RED='' YELLOW='' BLUE='' PURPLE='' GRAY='' BOLD='' OFF=''
fi

# Texts. en.txt has all keys. Another language file can miss keys: English is shown then.
declare -A TXT
load_lang() {
  local code=$1 f line
  TXT=()
  for f in "$LANG_DIR/en.txt" "$LANG_DIR/$code.txt"; do
    [[ -f $f ]] || continue
    while IFS= read -r line || [[ -n $line ]]; do
      [[ $line == *=* && $line != \#* ]] || continue
      TXT[${line%%=*}]=${line#*=}
    done < "$f"
  done
  MENU_LANG=$code
}
# Usage: t <key> [printf args]
t() { local k=$1; shift; printf -- "${TXT[$k]:-$k}" "$@"; }
saved_lang() { sed -n 's/^lang=//p' "$MENU_CONF" 2>/dev/null | grep . || echo en; }
save_lang() { printf 'lang=%s\n' "$1" > "$MENU_CONF"; }
# Prints "code<TAB>name" for each language file.
# lang/order sets the order. Languages that it does not name come last.
languages() {
  local f code
  for f in "$LANG_DIR"/*.txt; do
    code=$(basename "$f" .txt)
    printf '%s\t%s\t%s\n' "$(grep -nx "$code" "$LANG_DIR/order" 2>/dev/null | cut -d: -f1 || true)" \
      "$code" "$(sed -n 's/^_name=//p' "$f")"
  done | awk -F'\t' 'BEGIN {OFS="\t"} {print ($1 == "" ? 999 : $1), $2, $3}' | sort -n -k1,1 -k2,2 | cut -f2-
}
load_lang "$(saved_lang)"

# One line about memory, swap and clusters. Red when memory is low.
status_line() {
  python3 - "$(running_clusters | wc -l)" "$(existing_clusters | wc -l)" \
    "$(t ram)" "$(t free)" "$(t swap)" "$(t clusters_running)" "$RED" "$OFF" <<'PY'
import sys
run, total, ram, free, swap, cl, red, off = sys.argv[1:]
m = {}
for line in open("/proc/meminfo"):
    k, v = line.split(":")
    m[k] = int(v.split()[0]) / 2**20
used = m["MemTotal"] - m["MemAvailable"]
su = m["SwapTotal"] - m["SwapFree"]
warn = m["MemAvailable"] < 2 or (m["SwapTotal"] and su / m["SwapTotal"] > 0.8)
text = (f" {ram} {used:.1f}/{m['MemTotal']:.1f} GiB · {free} {m['MemAvailable']:.1f} GiB"
        f" · {swap} {su:.1f}/{m['SwapTotal']:.1f} GiB · {cl} {run}/{total}")
print(f"{red}{text} ⚠{off}" if warn else text)
PY
}

# Returns 0 when memory or swap is low.
low_resources() {
  awk '/MemAvailable/ {a=$2} /SwapTotal/ {t=$2} /SwapFree/ {f=$2}
       END {exit !(a < 2097152 || (t > 0 && (t-f)/t > 0.8))}' /proc/meminfo
}

# Usage: header <crumb>... Clears the screen and shows where the user is.
header() {
  local path=VKS c
  for c in "$@"; do path+=" › $c"; done
  [[ ! -t 1 ]] || clear
  printf '%s══ %s ══%s\n' "$BOLD" "$path" "$OFF"
  status_line
  echo
}

# Usage: item <color> <key> <text>
item() { printf ' %s%s) %s%s\n' "$1" "$2" "$3" "$OFF"; }
back_quit() { printf ' %s0) %s   q) %s%s\n' "$GRAY" "$(t back)" "$(t quit)" "$OFF"; }

# Reads one answer into REPLY. Ends the menu at end of input.
ask() {
  printf '%s ' "${1:-$(t choice)}"
  IFS= read -r REPLY || { echo; exit 0; }
  REPLY=${REPLY#"${REPLY%%[![:space:]]*}"}
  REPLY=${REPLY%"${REPLY##*[![:space:]]}"}
}
# q ends all menus. vks.sh stops on exit code 10.
quit_check() { [[ $REPLY != q ]] || exit "$QUIT"; }

pause() { ask "$(t press_enter)"; }

# Usage: confirm <question>. Yes is the first letter of the yes word.
confirm() {
  local yes
  yes=$(t yes)
  ask "$1 ($(t yes_no)):"
  [[ ${REPLY,,} == "${yes:0:1}" || ${REPLY,,} == "${yes,,}" ]]
}

# Usage: confirm_word <word>. The user must write the word.
confirm_word() {
  printf '%s%s%s\n' "$RED" "$(t cannot_undo)" "$OFF"
  ask "$(t type_to_confirm "$1")"
  [[ $REPLY == "$1" ]]
}

# Usage: parse_pick <count> <answer>. Sets PICKS to the 1-based numbers.
# The answer has numbers, ranges like 2-4 and a for all. Returns 1 for bad input.
parse_pick() {
  local n=$1 word a b i
  PICKS=()
  for word in $2; do
    case $word in
      a) PICKS=(); for ((i = 1; i <= n; i++)); do PICKS+=("$i"); done ;;
      o) ;;
      *-*)
        a=${word%-*} b=${word#*-}
        [[ $a =~ ^[0-9]+$ && $b =~ ^[0-9]+$ && $a -ge 1 && $b -le $n && $a -le $b ]] || return 1
        for ((i = a; i <= b; i++)); do PICKS+=("$i"); done ;;
      *)
        [[ $word =~ ^[0-9]+$ && $word -ge 1 && $word -le $n ]] || return 1
        PICKS+=("$word") ;;
    esac
  done
  mapfile -t PICKS < <(printf '%s\n' "${PICKS[@]}" | awk 'NF && !s[$0]++')
}

# State marks.
mark() {
  case $1 in
    running) printf '%s●%s' "$GREEN" "$OFF" ;;
    stopped) printf '%s■%s' "$YELLOW" "$OFF" ;;
    starting) printf '%s◐%s' "$YELLOW" "$OFF" ;;
    missing) printf '%s✘%s' "$GRAY" "$OFF" ;;
    *) printf '%s?%s' "$GRAY" "$OFF" ;;
  esac
}
state_text() { t "state_$1"; }

# MiB as GiB with one decimal.
gib() { awk -v m="$1" 'BEGIN {printf "%.1f", m/1024}'; }
# MiB below 1 GiB, else GiB. Usage: size <MiB>
size() { awk -v m="$1" 'BEGIN {if (m < 1024) printf "%d MiB", m; else printf "%.1f GiB", m/1024}'; }

# A bar of 30 cells. Usage: bar <value> <max>
bar() {
  awk -v v="$1" -v m="$2" 'BEGIN {n = m > 0 ? int(v * 30 / m + 0.5) : 0; if (n > 30) n = 30
    s = ""; for (i = 0; i < 30; i++) s = s (i < n ? "█" : "░"); print s}'
}

# Shows long text page by page in a terminal.
show_text() {
  if [[ -t 1 ]]; then less -R -F -X; else cat; fi
}

# Usage: run_progress <command>... Runs a component.sh or control.sh command.
# Shows the progress lines. All output goes to a log file.
run_progress() {
  local log line status
  log=$LOGS/$(date +%Y%m%d-%H%M%S)-menu.log
  printf '%s$ %s%s\n' "$GRAY" "$*" "$OFF" >> "$log"
  while IFS= read -r line; do
    case $line in
      '==> START '*)
        read -r _ _ i n action id <<<"$line"
        printf ' [%s/%s] %s %s …\n' "$i" "$n" "$(t "do_$action")" "$id" ;;
      '==> OK '*) printf ' %s✔ %s%s\n' "$GREEN" "${line#==> OK }" "$OFF" ;;
      '==> FAIL '*) printf ' %s✘ %s%s\n' "$RED" "${line#==> FAIL }" "$OFF" ;;
      '==> PASS '*) printf ' %s✔ %s%s\n' "$GREEN" "${line#==> PASS }" "$OFF" ;;
      '==> SKIP '*) printf ' %s■ %s (%s)%s\n' "$YELLOW" "$(cut -d' ' -f3 <<<"$line")" "$(t skipped)" "$OFF" ;;
      '==> PROGRESS '*) printf '\r %s %%' "${line#==> PROGRESS }" ;;
      *'] stopped '*|*'] started '*|*' done') printf ' %s%s%s\n' "$GRAY" "${line#*] }" "$OFF" ;;
      *WARNING*|*'normal terminal'*) printf ' %sℹ %s%s\n' "$YELLOW" "${line#*] }" "$OFF" ;;
    esac
  done < <("$@" 2>&1 | tee -a "$log"; echo "==> EXIT ${PIPESTATUS[0]}" >> "$log")
  status=$(sed -n 's/^==> EXIT //p' "$log" | tail -1)
  if [[ ${status:-1} != 0 ]]; then
    printf '%s%s%s\n' "$RED" "$(t failed_log "$log")" "$OFF"
    grep -v '^==>' "$log" | tail -8 | sed 's/^/   /'
    return 1
  fi
  return 0
}
