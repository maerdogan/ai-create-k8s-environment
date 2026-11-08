#!/usr/bin/env bash
# Installation menu: default install, installed components, check, install, remove, verify.
# Usage: setup.sh. vks.sh opens it. Exit code 10 means quit.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
source "$INSTALL_DIR/16-control/lib-state.sh"
source "$CONTROL/menu-lib.sh"
set +e
COMPONENT=$CONTROL/component.sh
MENU=$(t installation)

# The catalog with states. Index arrays: ID TYPE CL NS DEF RAM ST LABEL.
load_catalog() {
  local id type cl ns def ram st label i=0
  ID=() TYPE=() CL=() NS=() DEF=() RAM=() ST=() LABEL=()
  declare -gA AT DEPS
  AT=() DEPS=()
  printf '%s%s%s\n' "$GRAY" "$(t reading)" "$OFF"
  while IFS=$'\t' read -r id type cl ns def ram st label; do
    ID+=("$id") TYPE+=("$type") CL+=("$cl") NS+=("$ns") DEF+=("$def")
    RAM+=("$ram") ST+=("$st") LABEL+=("$label")
    AT[$id]=$i
    i=$((i + 1))
  done < <(bash "$COMPONENT" status)
  while IFS=$'\t' read -r id _ _ _ deps _; do DEPS[$id]=$deps; done < <(tail -n +2 "$CATALOG")
  # ORDER: infrastructure first, then each cluster with its namespaces and apps.
  local -A gi=()
  local c k=1
  for c in $(clusters); do gi[$c]=$k; k=$((k + 1)); done
  mapfile -t ORDER < <(for i in "${!ID[@]}"; do
    printf '%s %s\n' "${gi[${CL[i]}]:-0}" "$i"; done | sort -n -k1,1 -k2,2 | cut -d' ' -f2)
}

installed() { [[ ${ST[$1]} != missing ]]; }
star() { [[ ${DEF[$1]} == 1 ]] && printf '%s★%s' "$YELLOW" "$OFF" || printf ' '; }
type_text() { t "type_${TYPE[$1]}"; }

# Sum of estimated RAM of ids in MiB.
ram_of() {
  local id sum=0
  for id in "$@"; do sum=$((sum + RAM[AT[$id]])); done
  echo "$sum"
}

# Prints the group of a component: infrastructure or its cluster.
group_of() { [[ ${CL[$1]} == - ]] && t group_infra || t group_cluster "${CL[$1]}"; }

# Usage: closure <id>... Prints missing ids in install order.
closure() { bash "$COMPONENT" closure "$@"; }

# Checks memory before an install. Usage: ram_ok <MiB>
ram_ok() {
  local free
  free=$(mem_free_mb)
  printf ' %s\n' "$(t ram_estimate "$(gib "$1")" "$(gib "$free")" "$(gib $((free - $1)))")"
  if (( free - $1 < 1024 )); then
    printf '%s⚠ %s%s\n' "$RED" "$(t not_enough_ram)" "$OFF"
    return 1
  fi
}

install_ids() {
  local ids=("$@") verify=()
  run_progress bash "$COMPONENT" install "${ids[@]}" || { pause; return 1; }
  for id in "${ids[@]}"; do [[ ${TYPE[AT[$id]]} == images ]] || verify+=("$id"); done
  printf '\n %s\n' "$(t verifying)"
  run_progress bash "$COMPONENT" verify "${verify[@]}"
  pause
}

# Usage: remove_flow <confirm-word> <id>...
remove_flow() {
  local word=$1 ids deps purge=() id has_app=0
  shift
  ids=("$@")
  for id in "${ids[@]}"; do
    case ${TYPE[AT[$id]]} in platform|images) printf '%s%s%s\n' "$RED" "$(t cannot_remove "$id")" "$OFF"; pause; return ;; esac
  done
  mapfile -t deps < <(bash "$COMPONENT" dependents "${ids[@]}")
  if [[ ${#deps[@]} -gt 0 ]]; then
    printf '%s⚠ %s%s\n' "$YELLOW" "$(t dependents_found)" "$OFF"
    for id in "${deps[@]}"; do printf '   %s\n' "${LABEL[AT[$id]]}"; done
    item "$RED" 1 "$(t remove_with_dependents)"
    item "$RED" 2 "$(t remove_only_selected)"
    item "$GRAY" 0 "$(t cancel)"
    ask
    case $REPLY in
      1) ids+=("${deps[@]}") ;;
      2) ;;
      *) return ;;
    esac
  fi
  for id in "${ids[@]}"; do [[ ${TYPE[AT[$id]]} == app ]] && has_app=1; done
  if [[ $has_app == 1 ]] && confirm "⚠ $(t delete_pvc_too)"; then purge=(--purge); fi
  printf '\n %s\n' "$(t will_delete)"
  for id in "${ids[@]}"; do
    printf '   %s%s%s %s\n' "$RED" "${LABEL[AT[$id]]}" "$OFF" "$(star "${AT[$id]}")"
  done
  confirm_word "$word" || return
  run_progress bash "$COMPONENT" remove "${purge[@]}" "${ids[@]}"
  pause
}

# 2.1 Default installation.
default_screen() {
  local i missing=() last=''
  while true; do
    load_catalog
    header "$MENU" "$(t default_install)"
    missing=() last=''
    printf '  %-3s %-32s %s\n' "" "$(t component)" "RAM~"
    for i in "${ORDER[@]}"; do
      [[ ${DEF[i]} == 1 ]] || continue
      if [[ $(group_of "$i") != "$last" ]]; then
        last=$(group_of "$i")
        printf '  %s── %s ──%s\n' "$BOLD" "$last" "$OFF"
      fi
      printf '  %s   %-32s %s\n' "$(mark "${ST[i]}")" "${LABEL[i]}" "$(size "${RAM[i]}")"
      installed "$i" || missing+=("${ID[i]}")
    done
    echo
    if [[ ${#missing[@]} -eq 0 ]]; then
      printf ' %s✔ %s%s\n\n' "$GREEN" "$(t all_installed)" "$OFF"
    else
      printf ' %s\n' "$(t missing_count "${#missing[@]}")"
      item "$GREEN" 1 "$(t install_missing)"
    fi
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1)
        [[ ${#missing[@]} -gt 0 ]] || continue
        mapfile -t missing < <(closure "${missing[@]}")
        ram_ok "$(ram_of "${missing[@]}")" || { pause; continue; }
        confirm "$(t install_question "${#missing[@]}")" && install_ids "${missing[@]}" ;;
    esac
  done
}

# 2.2 Installed components as a tree.
installed_screen() {
  local only_default=0 i c ns apps
  while true; do
    load_catalog
    declare -A ram=()
    while IFS=$'\t' read -r c _ r _; do ram[$c]=$r; done < <(bash "$CONTROL/resources.sh" nodes)
    header "$MENU" "$(t installed_components)"
    {
      local nc=0 nn=0 na=0
      for i in "${!ID[@]}"; do
        installed "$i" || continue
        case ${TYPE[i]} in cluster) nc=$((nc + 1)) ;; namespace) nn=$((nn + 1)) ;; app) na=$((na + 1)) ;; esac
      done
      printf ' %s\n\n' "$(t counts "$nc" "$nn" "$na")"
      for i in "${ORDER[@]}"; do
        installed "$i" || continue
        [[ $only_default == 0 || ${DEF[i]} == 1 ]] || continue
        case ${TYPE[i]} in
          platform|images) printf ' %s %s %s\n' "$(star "$i")" "$(mark "${ST[i]}")" "${LABEL[i]}" ;;
          cluster)
            c=${CL[i]}
            if [[ ${ST[i]} == running ]]; then
              printf ' %s %s %-28s %s GiB\n' "$(star "$i")" "$(mark "${ST[i]}")" "$c" "$(gib "${ram[$c]:-0}")"
            else
              printf ' %s %s %-28s %s\n' "$(star "$i")" "$(mark "${ST[i]}")" "$c" "$(state_text "${ST[i]}")"
            fi ;;
          namespace)
            ns=${NS[i]}
            apps=$(awk -F'\t' -v n="$ns" '$2==n && $10==0 {print $3}' "$INV/${CL[i]}.apps.tsv" 2>/dev/null | sort -u | paste -sd, - | sed 's/,/, /g')
            printf '     %s %s %-24s %s\n' "$(star "$i")" "$(mark "${ST[i]}")" "$ns" "$apps" ;;
        esac
      done
      printf '\n %s\n' "$(t legend_marks)"
    } | show_text
    if [[ $only_default == 0 ]]; then item "$BLUE" 1 "$(t only_default)"; else item "$BLUE" 1 "$(t show_all)"; fi
    item "$BLUE" 2 "$(t goto_status)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) only_default=$((1 - only_default)) ;;
      2) bash "$CONTROL/status.sh"; [[ $? -ne $QUIT ]] || exit "$QUIT" ;;
    esac
  done
}

# Prints the dependencies of one id, deepest first.
all_deps() {
  local id=$1 d
  for d in ${DEPS[$id]//,/ }; do
    [[ $d == - ]] && continue
    all_deps "$d"
    echo "$d"
  done | awk '!s[$0]++'
}

# One component: state, dependencies and actions.
component_screen() {
  local i=$1 id d deps need
  id=${ID[i]}
  while true; do
    header "$MENU" "$(t check_component)" "${LABEL[i]}"
    printf ' %s %s · %s: %s · %s: %s · %s: %s\n' "$(mark "${ST[i]}")" "$(state_text "${ST[i]}")" \
      "$(t type)" "$(type_text "$i")" "$(t cluster)" "${CL[i]}" "$(t namespace)" "${NS[i]}"
    mapfile -t deps < <(all_deps "$id")
    if [[ ${#deps[@]} -gt 0 ]]; then
      printf ' %s\n' "$(t dependencies)"
      for d in "${deps[@]}"; do printf '   %s %s\n' "$(mark "${ST[AT[$d]]}")" "${LABEL[AT[$d]]}"; done
    fi
    echo
    if ! installed "$i"; then
      mapfile -t need < <(closure "$id")
      ram_ok "$(ram_of "${need[@]}")"
      item "$GREEN" 1 "$(t install_with_deps)"
    else
      mapfile -t deps < <(bash "$COMPONENT" dependents "$id")
      if [[ ${#deps[@]} -eq 0 ]]; then
        printf ' %s %s\n\n' "$(t needed_by)" "$(t none)"
      else
        printf ' %s %s\n\n' "$(t needed_by)" "$(for d in "${deps[@]}"; do printf '%s ' "${LABEL[AT[$d]]}"; done)"
      fi
      item "$BLUE" 1 "$(t verify)"
      item "$RED" 2 "$(t delete)"
    fi
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1)
        if installed "$i"; then
          run_progress bash "$COMPONENT" verify "$id"; pause
        else
          ram_ok "$(ram_of "${need[@]}")" && confirm "$(t install_question "${#need[@]}")" && install_ids "${need[@]}"
        fi
        load_catalog ;;
      2) installed "$i" && { remove_flow "${LABEL[i]%% *}" "$id"; load_catalog; } ;;
    esac
  done
}

# 2.3 Check one component.
check_screen() {
  local text hits i
  load_catalog
  while true; do
    header "$MENU" "$(t check_component)"
    ask "$(t search_prompt)"
    quit_check
    [[ $REPLY != 0 ]] || return
    text=${REPLY,,}
    hits=()
    for i in "${!ID[@]}"; do
      [[ -z $text || ${ID[i],,} == *"$text"* || ${LABEL[i],,} == *"$text"* ]] && hits+=("$i")
    done
    if [[ ${#hits[@]} -eq 0 ]]; then printf ' %s\n' "$(t no_result)"; pause; continue; fi
    printf '\n  %-3s %-34s %-10s %-20s %s\n' "#" "$(t component)" "$(t type)" "$(t cluster)" "$(t state)"
    for i in "${!hits[@]}"; do
      local k=${hits[i]}
      printf '  %-3s %-34s %-10s %-20s %s %s\n' "$((i + 1))" "${LABEL[k]}" "$(type_text "$k")" "${CL[k]}" \
        "$(mark "${ST[k]}")" "$(state_text "${ST[k]}")"
    done
    back_quit
    ask
    quit_check
    [[ $REPLY != 0 ]] || continue
    if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le ${#hits[@]} ]]; then
      component_screen "${hits[REPLY-1]}"
    fi
  done
}

# Prints the indexes of the list, filtered. Usage: list_rows <installed-only 0|1>
list_rows() {
  local i f=${FILTER,,}
  for i in "${ORDER[@]}"; do
    [[ $1 == 0 ]] || { installed "$i" && [[ ${TYPE[i]} != platform && ${TYPE[i]} != images ]]; } || continue
    [[ -z $f || ${ID[i],,} == *"$f"* || ${LABEL[i],,} == *"$f"* || ${CL[i]} == *"$f"* \
      || $(type_text "$i") == *"$f"* ]] || continue
    echo "$i"
  done
}

# Prints a grouped list with numbers. Usage: print_list <index>...
print_list() {
  local n=0 i last='' box
  printf '  %-4s %-5s %-34s %-10s %s\n' "#" "" "$(t component)" "$(t type)" "RAM~"
  for i in "$@"; do
    n=$((n + 1))
    if [[ $(group_of "$i") != "$last" ]]; then
      last=$(group_of "$i")
      printf '  %s── %s ──%s\n' "$BOLD" "$last" "$OFF"
    fi
    if installed "$i"; then box="${GREEN}[x]${OFF}"; else box="[ ]"; fi
    printf '  %-4s %s %s %-34s %-10s %s\n' "$n" "$box" "$(star "$i")" "${LABEL[i]}" "$(type_text "$i")" "$(size "${RAM[i]}")"
  done
}

# Suggests a new name: the next number of a name that ends with -<number>.
suggest_name() {
  local c=$1
  namespaces "$c" | python3 -c '
import re, sys
names = [n.strip() for n in sys.stdin if n.strip()]
for n in names:
    m = re.fullmatch(r"(.*)-([0-9]+)", n)
    if m:
        k = int(m.group(2)) + 1
        while f"{m.group(1)}-{k}" in names:
            k += 1
        print(f"{m.group(1)}-{k}")
        break
else:
    print(f"{names[0]}-2" if names else "")'
}

new_namespace() {
  local all=() c name i need
  header "$MENU" "$(t select_install)" "$(t new_namespace)"
  mapfile -t all < <(clusters)
  for i in "${!all[@]}"; do item "$GRAY" "$((i + 1))" "${all[i]}"; done
  back_quit
  ask "$(t pick_cluster)"
  quit_check
  [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le ${#all[@]} ]] || return
  c=${all[REPLY-1]}
  name=$(suggest_name "$c")
  ask "$(t name_prompt "$name")"
  quit_check
  [[ -z $REPLY ]] || name=$REPLY
  [[ -n $name ]] || return
  cp "$INSTALL_DIR/00-common/plan.json" "$STATE/plan.json.bak"
  if ! python3 "$CONTROL/plan-edit.py" add "$c" "$name" || ! python3 "$INSTALL_DIR/00-common/plan.py" >/dev/null; then
    cp "$STATE/plan.json.bak" "$INSTALL_DIR/00-common/plan.json"
    python3 "$INSTALL_DIR/00-common/plan.py" >/dev/null
    pause
    return
  fi
  printf ' %s: %s-%s\n' "$(t ip_range)" "$(ns_field "$name" start)" "$(ns_field "$name" end)"
  if confirm "$(t add_and_install)"; then
    load_catalog
    mapfile -t need < <(closure "ns:$name")
    install_ids "${need[@]}"
  else
    cp "$STATE/plan.json.bak" "$INSTALL_DIR/00-common/plan.json"
    python3 "$INSTALL_DIR/00-common/plan.py" >/dev/null
  fi
}

# 2.4 Select and install.
select_install_screen() {
  local rows picks=() p want extra
  FILTER=
  while true; do
    load_catalog
    header "$MENU" "$(t select_install)"
    [[ -z $FILTER ]] || printf ' %s: %s\n' "$(t filter)" "$FILTER"
    mapfile -t rows < <(list_rows 0)
    print_list "${rows[@]}" | show_text
    printf ' %s\n' "$(t legend_boxes)"
    item "$BLUE" f "$(t filter_hint)"
    item "$GREEN" n "$(t new_namespace)"
    back_quit
    ask "$(t pick_prompt)"
    quit_check
    case $REPLY in
      0) return ;;
      f) ask "$(t filter):"; FILTER=$REPLY; continue ;;
      n) new_namespace; continue ;;
    esac
    parse_pick "${#rows[@]}" "$REPLY" || { printf ' %s\n' "$(t bad_input)"; pause; continue; }
    picks=()
    for p in "${PICKS[@]}"; do installed "${rows[p-1]}" || picks+=("${ID[rows[p-1]]}"); done
    [[ ${#picks[@]} -gt 0 ]] || { printf ' %s\n' "$(t nothing_to_do)"; pause; continue; }
    mapfile -t want < <(closure "${picks[@]}")
    extra=()
    for p in "${want[@]}"; do [[ " ${picks[*]} " == *" $p "* ]] || extra+=("${LABEL[AT[$p]]}"); done
    printf '\n %s %s\n' "$(t selected)" "$(for p in "${picks[@]}"; do printf '%s, ' "${LABEL[AT[$p]]}"; done | sed 's/, $//')"
    [[ ${#extra[@]} -eq 0 ]] || printf ' %s⚠ %s %s%s\n' "$YELLOW" "$(t added_deps)" "$(printf '%s, ' "${extra[@]}" | sed 's/, $//')" "$OFF"
    ram_ok "$(ram_of "${want[@]}")" || { pause; continue; }
    confirm "$(t install_question "${#want[@]}")" && install_ids "${want[@]}"
  done
}

# 2.5 Select and remove.
select_remove_screen() {
  local rows ids p
  FILTER=
  while true; do
    load_catalog
    header "$MENU" "$(t select_remove)"
    printf ' %s\n' "$(t only_installed)"
    [[ -z $FILTER ]] || printf ' %s: %s\n' "$(t filter)" "$FILTER"
    mapfile -t rows < <(list_rows 1)
    print_list "${rows[@]}" | show_text
    item "$BLUE" f "$(t filter_hint)"
    back_quit
    ask "$(t pick_prompt)"
    quit_check
    case $REPLY in
      0) return ;;
      f) ask "$(t filter):"; FILTER=$REPLY; continue ;;
    esac
    parse_pick "${#rows[@]}" "$REPLY" || { printf ' %s\n' "$(t bad_input)"; pause; continue; }
    [[ ${#PICKS[@]} -gt 0 ]] || continue
    ids=()
    for p in "${PICKS[@]}"; do ids+=("${ID[rows[p-1]]}"); done
    remove_flow "$(t delete_word)" "${ids[@]}"
  done
}

# 2.6 Verify.
verify_screen() {
  local ids=() i rows bad
  while true; do
    load_catalog
    header "$MENU" "$(t verify)"
    item "$BLUE" 1 "$(t verify_all)"
    item "$BLUE" 2 "$(t verify_default)"
    item "$BLUE" 3 "$(t verify_select)"
    back_quit
    ask
    quit_check
    ids=()
    case $REPLY in
      0) return ;;
      1) for i in "${!ID[@]}"; do installed "$i" && ids+=("${ID[i]}"); done ;;
      2) for i in "${!ID[@]}"; do [[ ${DEF[i]} == 1 ]] && ids+=("${ID[i]}"); done ;;
      3)
        mapfile -t rows < <(for i in "${ORDER[@]}"; do installed "$i" && echo "$i"; done)
        print_list "${rows[@]}" | show_text
        ask "$(t pick_prompt)"
        parse_pick "${#rows[@]}" "$REPLY" || continue
        for i in "${PICKS[@]}"; do ids+=("${ID[rows[i-1]]}"); done ;;
      *) continue ;;
    esac
    [[ ${#ids[@]} -gt 0 ]] || continue
    run_progress bash "$COMPONENT" verify "${ids[@]}"
    local log
    log=$(ls -t "$LOGS"/*-menu.log | head -1)
    printf '\n %s\n' "$(t verify_counts "$(grep -c '^==> PASS' "$log")" "$(grep -c '^==> FAIL' "$log")" "$(grep -c '^==> SKIP' "$log")")"
    mapfile -t bad < <(sed -n 's/^==> FAIL \([^ ]*\).*/\1/p' "$log")
    if [[ ${#bad[@]} -gt 0 ]]; then
      item "$BLUE" 1 "$(t show_error)"
      item "$GREEN" 2 "$(t reinstall_failed)"
      back_quit
      ask
      quit_check
      case $REPLY in
        1) show_text < "$log"; pause ;;
        2) install_ids "${bad[@]}" ;;
      esac
    else
      pause
    fi
  done
}

while true; do
  header "$MENU"
  item "$GREEN" 1 "$(t default_install)"
  item "$BLUE" 2 "$(t installed_components)"
  item "$BLUE" 3 "$(t check_component)"
  item "$GREEN" 4 "$(t select_install)"
  item "$RED" 5 "$(t select_remove)"
  item "$BLUE" 6 "$(t verify)"
  back_quit
  ask
  quit_check
  case $REPLY in
    0) exit 0 ;;
    1) default_screen ;;
    2) installed_screen ;;
    3) check_screen ;;
    4) select_install_screen ;;
    5) select_remove_screen ;;
    6) verify_screen ;;
  esac
done
