#!/usr/bin/env bash
# Status and management menu, and the resource usage menu.
# Usage: status.sh [resources]. vks.sh opens it. Exit code 10 means quit.
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
source "$INSTALL_DIR/16-control/lib-state.sh"
source "$CONTROL/menu-lib.sh"
set +e
CTL=$CONTROL/control.sh
RES=$CONTROL/resources.sh
MENU=$(t status_management)
RMENU=$(t resource_usage)

refresh() { printf '%s%s%s\n' "$GRAY" "$(t reading)" "$OFF"; scan; }
is_default() { awk -F'\t' -v i="$1" '$1==i {f=$6} END {exit f!=1}' "$CATALOG"; }
star() { is_default "$1" && printf '%s★%s' "$YELLOW" "$OFF" || printf ' '; }

# Rows "cluster state ram swap" of existing clusters.
nodes() { bash "$RES" nodes; }

# Non-system namespaces: cluster ns state apps ram. A stopped cluster gives stopped.
ns_rows() {
  local c st
  for c in ${1:-$(existing_clusters)}; do
    st=$(node_state "$c")
    awk -F'\t' -v s="$st" '$6==0 {if (s!="running") $3="stopped"; print $1"\t"$2"\t"$3"\t"$4"\t"$5}' \
      "$INV/$c.ns.tsv" 2>/dev/null
  done
}

# Non-system apps: cluster ns app kind name ready want state ram.
app_rows() {
  local c st
  for c in ${1:-$(existing_clusters)}; do
    st=$(node_state "$c")
    awk -F'\t' -v s="$st" 'BEGIN {OFS="\t"} $10==0 {if (s!="running") $8="stopped"; print $1,$2,$3,$4,$5,$6,$7,$8,$9}' \
      "$INV/$c.apps.tsv" 2>/dev/null
  done
}

# Usage: pick_with_suggest <count> <answer> <suggested index>... Sets PICKS.
pick_with_suggest() {
  local n=$1 answer=$2 extra=()
  shift 2
  [[ " $answer " != *" o "* ]] || extra=("$@")
  parse_pick "$n" "$answer" || return 1
  mapfile -t PICKS < <(printf '%s\n' "${PICKS[@]}" "${extra[@]}" | awk 'NF && !s[$0]++' | sort -n)
}

# ---------- 3.2.2 App ----------

app_detail() {
  local c=$1 ns=$2 w=$3 tmp
  {
    kc "$c" -n "$ns" get "$w" -o wide
    echo
    kc "$c" -n "$ns" get pods -o wide | awk -v n="${w#*/}-" 'NR==1 || index($1, n)==1'
    echo
    printf '%s\n' "$(t images_limits)"
    kc "$c" -n "$ns" get "$w" -o jsonpath='{range .spec.template.spec.containers[*]}  {.name}: {.image}  cpu={.resources.limits.cpu} memory={.resources.limits.memory}{"\n"}{end}'
    tmp=$(mktemp "$TMPDIR/objects.XXXXXX")
    kc "$c" -n "$ns" get deploy,sts,ds,svc,ingress,pvc -o json > "$tmp" 2>/dev/null
    printf '\n%s\n' "$(t related_objects)"
    { python3 "$CONTROL/related.py" "$w" "$tmp"; python3 "$CONTROL/related.py" "$w" "$tmp" --pvc; } | sed 's/^/  /'
    rm -f "$tmp"
    printf '\n%s\n' "$(t last_events)"
    kc "$c" -n "$ns" get events --field-selector "involvedObject.name=${w#*/}" \
      --sort-by=.lastTimestamp 2>/dev/null | tail -5
  } 2>&1 | show_text
  pause
}

app_log() {
  local c=$1 ns=$2 w=$3
  kc "$c" -n "$ns" logs "$w" --tail=100 --all-containers --prefix 2>&1 | show_text
  ask "$(t log_follow)"
  if [[ $REPLY == f ]]; then
    # Ctrl+C stops only the log.
    trap ':' INT
    kc "$c" -n "$ns" logs "$w" -f --tail=20 --all-containers --prefix
    trap - INT
  fi
}

app_screen() {
  local c=$1 ns=$2 kind=$3 name=$4 line st ready want ram app tmp pvcs purge
  while true; do
    line=$(awk -F'\t' -v n="$ns" -v k="$kind" -v w="$name" '$2==n && $4==k && $5==w' "$INV/$c.apps.tsv" 2>/dev/null)
    [[ -n $line ]] || return
    IFS=$'\t' read -r _ _ app _ _ ready want st ram _ <<<"$line"
    header "$MENU" "$c" "$ns" "$app"
    printf ' %s %s · %s · %s %s/%s · RAM %s\n' "$(mark "$st")" "$(state_text "$st")" "$kind/$name" \
      "$(t pods)" "$ready" "$want" "$(size "$ram")"
    printf ' %s: %s\n\n' "$(t image)" "$(kc "$c" -n "$ns" get "$kind/$name" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)"
    item "$BLUE" 1 "$(t detail)"
    item "$BLUE" 2 "$(t log)"
    if [[ $st == stopped ]]; then item "$GREEN" 3 "$(t start)"; else item "$YELLOW" 3 "$(t stop)"; fi
    item "$YELLOW" 4 "$(t restart)"
    item "$RED" 5 "$(t delete)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) app_detail "$c" "$ns" "$kind/$name" ;;
      2) app_log "$c" "$ns" "$kind/$name" ;;
      3)
        if [[ $st == stopped ]]; then
          run_progress bash "$CTL" start app "$c/$ns/$kind/$name"
        else
          confirm "$(t stop_question "$app" "$(size "$ram")")" && run_progress bash "$CTL" stop app "$c/$ns/$kind/$name"
        fi
        pause ;;
      4) confirm "$(t restart_question "$app")" && { run_progress bash "$CTL" restart app "$c/$ns/$kind/$name"; pause; } ;;
      5)
        purge=()
        tmp=$(mktemp "$TMPDIR/objects.XXXXXX")
        kc "$c" -n "$ns" get deploy,sts,ds,pvc -o json > "$tmp" 2>/dev/null
        pvcs=$(python3 "$CONTROL/related.py" "$kind/$name" "$tmp" --pvc | paste -sd' ' -)
        rm -f "$tmp"
        if [[ -n $pvcs ]] && confirm "⚠ $(t delete_pvc_named "$pvcs")"; then purge=(--purge); fi
        if confirm_word "$name"; then
          run_progress bash "$CTL" delete app "${purge[@]}" "$c/$ns/$kind/$name"
          pause
          return
        fi ;;
    esac
  done
}

# Usage: apps_table <rows file>. Shows numbered apps.
apps_table() {
  local n=0 c ns app kind name ready want st ram
  printf '  %-4s %-18s %-20s %-26s %-6s %-8s %s\n' "#" "$(t cluster)" "$(t namespace)" "$(t app)" "$(t kind)" "$(t pods)" "RAM"
  while IFS=$'\t' read -r c ns app kind name ready want st ram; do
    n=$((n + 1))
    printf '  %-4s %-18s %-20s %-26s %-6s %-8s %-9s %s %s\n' "$n" "$c" "$ns" "$app" "$kind" "$ready/$want" \
      "$(size "$ram")" "$(mark "$st")" "$(state_text "$st")"
  done < "$1"
}

# ---------- 3.2.1 Namespaces ----------

ns_detail() {
  local c=$1 ns=$2
  {
    kc "$c" -n "$ns" get deploy,sts,ds,cronjob,svc,ingress,pvc,cm,secret -o name 2>/dev/null
    kc "$c" -n "$ns" get httproute,gateway -o name 2>/dev/null
    echo
    printf '%s: %s\n' "IPPool" "$(kc "$c" get ns "$ns" -o jsonpath='{.metadata.annotations.cni\.projectcalico\.org/ipv4pools}')"
    printf '%s: %s\n' "$(t ip_range)" "$(kc "$c" get ns "$ns" -o jsonpath="{.metadata.annotations.${NOTE//./\\.}/ip-range}")"
    printf 'VIP: %s-%s\n' "$(ns_field "$ns" vip_start)" "$(ns_field "$ns" vip_end)"
  } | show_text
  pause
}

apps_of_ns_screen() {
  local c=$1 ns=$2 rows n
  while true; do
    header "$MENU" "$c" "$ns" "$(t apps)"
    rows=$(mktemp "$TMPDIR/rows.XXXXXX")
    app_rows "$c" | awk -F'\t' -v n="$ns" '$2==n' > "$rows"
    n=$(wc -l < "$rows")
    apps_table "$rows"
    back_quit
    ask "$(t pick_one)"
    quit_check
    [[ $REPLY != 0 ]] || { rm -f "$rows"; return; }
    if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le $n ]]; then
      IFS=$'\t' read -r _ _ _ kind name _ < <(sed -n "${REPLY}p" "$rows")
      app_screen "$c" "$ns" "$kind" "$name"
      refresh >/dev/null
    fi
    rm -f "$rows"
  done
}

ns_screen() {
  local c=$1 ns=$2 line st apps ram
  while true; do
    line=$(ns_rows "$c" | awk -F'\t' -v n="$ns" '$2==n')
    [[ -n $line ]] || return
    IFS=$'\t' read -r _ _ st apps ram <<<"$line"
    header "$MENU" "$c" "$ns"
    printf ' %s %s · %s %s · RAM %s · NGINX %s\n\n' "$(mark "$st")" "$(state_text "$st")" \
      "$(t apps)" "$apps" "$(size "$ram")" "$(ns_field "$ns" nginx_ip)"
    item "$BLUE" 1 "$(t apps)"
    item "$BLUE" 2 "$(t detail)"
    if [[ $st == stopped ]]; then item "$GREEN" 3 "$(t start)"; else item "$YELLOW" 3 "$(t stop)"; fi
    item "$YELLOW" 4 "$(t restart)"
    item "$RED" 5 "$(t delete)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) apps_of_ns_screen "$c" "$ns" ;;
      2) ns_detail "$c" "$ns" ;;
      3)
        if [[ $st == stopped ]]; then
          run_progress bash "$CTL" start ns "$c/$ns"
        else
          confirm "$(t stop_question "$ns" "$(size "$ram")")" && run_progress bash "$CTL" stop ns "$c/$ns"
        fi
        pause ;;
      4) confirm "$(t restart_question "$ns")" && { run_progress bash "$CTL" restart ns "$c/$ns"; pause; } ;;
      5) confirm_word "$ns" && { run_progress bash "$CTL" delete ns "$c/$ns"; pause; return; } ;;
    esac
  done
}

ns_list_screen() {
  local c=$1 rows n i ns st apps ram
  while true; do
    header "$MENU" "$(t clusters)" "$c" "$(t namespaces)"
    mapfile -t rows < <(ns_rows "$c")
    n=${#rows[@]}
    printf '  %-4s %-24s %-10s %-6s %-9s %s\n' "#" "$(t namespace)" "RAM" "$(t apps)" "" "$(t ip_range)"
    for i in "${!rows[@]}"; do
      IFS=$'\t' read -r _ ns st apps ram <<<"${rows[i]}"
      printf '  %-4s %-24s %-10s %-6s %s %-9s %s\n' "$((i + 1))" "$ns" "$(size "$ram")" "$apps" \
        "$(star "ns:$ns")" "$(mark "$st")" "$(ns_field "$ns" start)-$(ns_field "$ns" end)"
    done
    back_quit
    ask "$(t pick_one)"
    quit_check
    [[ $REPLY != 0 ]] || return
    if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le $n ]]; then
      IFS=$'\t' read -r _ ns _ <<<"${rows[REPLY-1]}"
      ns_screen "$c" "$ns"
      refresh >/dev/null
    fi
  done
}

# ---------- 3.2 Clusters ----------

cluster_detail() {
  local c=$1
  {
    printf '%s: %s\n' "$(t ip_block)" "$(block_of "$c")"
    if [[ $(node_state "$c") == running ]]; then
      kc "$c" version 2>/dev/null | grep -i server
      kc "$c" get nodes -o wide
      printf '\nMetalLB: %s\n' "$(kc "$c" -n metallb-system get ipaddresspool --no-headers 2>/dev/null | wc -l)"
      printf '\nHelm:\n'
      hc "$c" list -A 2>/dev/null
    else
      printf '%s\n' "$(t last_known)"
      awk -F'\t' '$6==0 {print "  " $2}' "$INV/$c.ns.tsv" 2>/dev/null
    fi
  } | show_text
  pause
}

cluster_screen() {
  local c=$1 st ram nn na
  while true; do
    st=$(node_state "$c")
    [[ $st != missing ]] || return
    ram=$(nodes | awk -F'\t' -v c="$c" '$1==c {print $3}')
    nn=$(ns_rows "$c" | wc -l)
    na=$(app_rows "$c" | wc -l)
    header "$MENU" "$(t clusters)" "$c"
    printf ' %s %s · RAM %s GiB · %s %s · %s %s\n' "$(mark "$st")" "$(state_text "$st")" "$(gib "${ram:-0}")" \
      "$(t namespaces)" "$nn" "$(t apps)" "$na"
    printf ' Node: %s-control-plane · IP %s · API %s\n\n' "$c" "$(node_ip "$c")" \
      "$(sed -n 's/.*server: //p' "$RUNTIME/kubeconfig/$c.yaml" 2>/dev/null)"
    if [[ $st == running ]]; then
      item "$BLUE" 1 "$(t namespaces)"
      item "$BLUE" 2 "$(t detail)"
      item "$YELLOW" 3 "$(t stop)"
      item "$YELLOW" 4 "$(t restart)"
      item "$RED" 5 "$(t delete)"
    else
      item "$BLUE" 2 "$(t detail)"
      item "$GREEN" 3 "$(t start)"
      item "$RED" 5 "$(t delete)"
    fi
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) [[ $st == running ]] && ns_list_screen "$c" ;;
      2) cluster_detail "$c" ;;
      3)
        if [[ $st == running ]]; then
          confirm "$(t stop_question "$c" "$(size "${ram:-0}")")" && { run_progress bash "$CTL" stop cluster "$c"; pause; }
        else
          run_progress bash "$CTL" start cluster "$c"; pause
        fi ;;
      4) [[ $st == running ]] && confirm "$(t restart_question "$c")" && { run_progress bash "$CTL" restart cluster "$c"; pause; } ;;
      5) confirm_word "$c" && { run_progress bash "$CTL" delete cluster "$c"; pause; return; } ;;
    esac
  done
}

clusters_screen() {
  local rows n i c st ram nn na
  while true; do
    refresh
    header "$MENU" "$(t clusters)"
    mapfile -t rows < <(nodes)
    n=${#rows[@]}
    printf '  %-4s %-20s %-3s %-14s %-10s %-5s %s\n' "#" "$(t cluster)" "" "$(t state)" "RAM" "NS" "$(t apps)"
    for i in "${!rows[@]}"; do
      IFS=$'\t' read -r c st ram _ <<<"${rows[i]}"
      nn=$(ns_rows "$c" | wc -l)
      na=$(app_rows "$c" | wc -l)
      if [[ $st == running ]]; then ram="$(gib "$ram") GiB"; else ram=-; na=-; fi
      printf '  %-4s %-20s %s   %s %-12s %-10s %-5s %s\n' "$((i + 1))" "$c" "$(star "cluster:$c")" "$(mark "$st")" \
        "$(state_text "$st")" "$ram" "$nn" "$na"
    done
    back_quit
    ask "$(t pick_one)"
    quit_check
    [[ $REPLY != 0 ]] || return
    if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le $n ]]; then
      cluster_screen "$(cut -f1 <<<"${rows[REPLY-1]}")"
    fi
  done
}

# ---------- 3.3 / 3.4 Apps ----------

# Usage: search_screen [ask]. With "ask" the user writes a part of a name first.
search_screen() {
  local mode=${1:-} text='' rows n c stopped
  [[ $mode == ask ]] || text=
  while true; do
    refresh
    if [[ $mode == ask ]]; then
      header "$MENU" "$(t app_search)"
      ask "$(t search_prompt)"
      quit_check
      [[ $REPLY != 0 ]] || return
      text=${REPLY,,}
    fi
    while true; do
      header "$MENU" "$([[ $mode == ask ]] && t app_search || t all_apps)"
      [[ -z $text ]] || printf ' %s: %s\n' "$(t search)" "$text"
      rows=$(mktemp "$TMPDIR/rows.XXXXXX")
      app_rows "$(running_clusters)" | awk -F'\t' -v t="$text" \
        't=="" || index(tolower($1"\t"$2"\t"$3), t)' | sort -t$'\t' -k1,1 -k2,2 > "$rows"
      n=$(wc -l < "$rows")
      if [[ $n -eq 0 ]]; then printf ' %s\n' "$(t no_result)"; else apps_table "$rows"; fi
      printf ' %s\n' "$(t results "$n")"
      stopped=$(for c in $(existing_clusters); do [[ $(node_state "$c") == running ]] || printf '%s ' "$c"; done)
      [[ -z $stopped ]] || printf ' %sℹ %s%s\n' "$GRAY" "$(t not_searched "$stopped")" "$OFF"
      [[ $mode != ask ]] || item "$BLUE" y "$(t new_search)"
      back_quit
      ask "$(t pick_one)"
      quit_check
      case $REPLY in
        0) rm -f "$rows"; return ;;
        y) rm -f "$rows"; break ;;
      esac
      if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le $n ]]; then
        IFS=$'\t' read -r c ns _ kind name _ < <(sed -n "${REPLY}p" "$rows")
        app_screen "$c" "$ns" "$kind" "$name"
        refresh >/dev/null
      fi
      rm -f "$rows"
    done
  done
}

# ---------- 3.1 Summary ----------

summary_screen() {
  local cl_total cl_run nsr apps rows i c ram max
  while true; do
    refresh
    header "$MENU" "$(t summary)"
    cl_total=$(existing_clusters | wc -l)
    cl_run=$(running_clusters | wc -l)
    nsr=$(ns_rows)
    apps=$(app_rows)
    printf '  %-12s %8s %12s %8s\n' "" "$(t total)" "● $(t state_running)" "■ $(t state_stopped)"
    printf '  %-12s %8s %12s %8s\n' "$(t clusters)" "$cl_total" "$cl_run" "$((cl_total - cl_run))"
    printf '  %-12s %8s %12s %8s\n' "$(t namespaces)" "$(grep -c . <<<"$nsr")" \
      "$(awk -F'\t' '$3!="stopped"' <<<"$nsr" | grep -c .)" "$(awk -F'\t' '$3=="stopped"' <<<"$nsr" | grep -c .)"
    printf '  %-12s %8s %12s %8s\n' "$(t apps)" "$(grep -c . <<<"$apps")" \
      "$(awk -F'\t' '$8!="stopped"' <<<"$apps" | grep -c .)" "$(awk -F'\t' '$8=="stopped"' <<<"$apps" | grep -c .)"
    printf '\n  %s\n' "$(t top_clusters)"
    mapfile -t rows < <(nodes | awk -F'\t' '$2=="running"' | sort -t$'\t' -k3,3nr | head -5)
    max=$(cut -f3 <<<"${rows[0]:-x	x	1}")
    for i in "${!rows[@]}"; do
      IFS=$'\t' read -r c _ ram _ <<<"${rows[i]}"
      printf '  %-3s %-20s %6s GiB  %s\n' "$((i + 1))" "$c" "$(gib "$ram")" "$(bar "$ram" "$max")"
    done
    echo
    if low_resources; then
      printf ' %s⚠ %s%s\n' "$RED" "$(t low_warning)" "$OFF"
      item "$YELLOW" 1 "$(t goto_stop)"
      item "$PURPLE" 2 "$(t goto_resources)"
    fi
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) low_resources && action_screen stop ;;
      2) low_resources && resources_menu ;;
    esac
  done
}

# ---------- 3.5 / 3.6 Stop and start ----------

# Usage: action_level <stop|start> <cluster|ns|app>
action_level() {
  local action=$1 level=$2 rows=() labels=() rams=() suggest=() targets=() i c ns st ram n line defaults=() sum=0
  local suggest_on=0
  [[ $action == stop ]] && low_resources && suggest_on=1
  refresh
  case $level in
    cluster)
      while IFS=$'\t' read -r c st ram _; do
        [[ ($action == stop && $st == running) || ($action == start && $st != running) ]] || continue
        rows+=("$c") labels+=("$c") rams+=("$ram")
      done < <(nodes | sort -t$'\t' -k3,3nr) ;;
    ns)
      while IFS=$'\t' read -r c ns st _ ram; do
        [[ $(node_state "$c") == running ]] || continue
        [[ ($action == stop && $st != stopped) || ($action == start && $st == stopped) ]] || continue
        rows+=("$c/$ns") labels+=("$c / $ns") rams+=("$ram")
      done < <(ns_rows | sort -t$'\t' -k5,5nr) ;;
    app)
      while IFS=$'\t' read -r c ns app kind name _ _ st ram; do
        [[ ($action == stop && $st != stopped) || ($action == start && $st == stopped) ]] || continue
        rows+=("$c/$ns/$kind/$name") labels+=("$c / $ns / $app") rams+=("$ram")
      done < <(app_rows "$(running_clusters)" | sort -t$'\t' -k9,9nr) ;;
  esac
  header "$MENU" "$(t "$action")" "$(t "level_$level")"
  n=${#rows[@]}
  if [[ $n -eq 0 ]]; then printf ' %s\n' "$(t nothing_to_do)"; pause; return; fi
  printf '  %-4s %-48s %-10s %s\n' "#" "" "RAM" "$([[ $suggest_on == 1 ]] && t suggestion)"
  for i in "${!rows[@]}"; do
    local id=${rows[i]} def=0 tag=
    case $level in
      cluster) is_default "cluster:$id" && def=1 ;;
      ns) is_default "ns:${id#*/}" && def=1 ;;
      app) [[ $(awk -F'\t' -v n="$(cut -d/ -f2 <<<"$id")" '$4==n && $2=="app" && $6==1' "$CATALOG") ]] && def=1 ;;
    esac
    if [[ $def == 1 ]]; then tag="${YELLOW}★ $(t default)${OFF}"
    elif [[ $suggest_on == 1 ]]; then tag="${PURPLE}◆${OFF}"; suggest+=("$((i + 1))"); fi
    printf '  %-4s %-48s %-10s %s\n' "$((i + 1))" "${labels[i]}" "$([[ $action == stop ]] && size "${rams[i]}" || echo -)" "$tag"
  done
  [[ $suggest_on == 0 ]] || printf ' %s◆ %s%s\n' "$PURPLE" "$(t suggest_legend)" "$OFF"
  back_quit
  ask "$([[ $suggest_on == 1 ]] && t pick_prompt_suggest || t pick_prompt)"
  quit_check
  [[ $REPLY != 0 && -n $REPLY ]] || return
  pick_with_suggest "$n" "$REPLY" "${suggest[@]}" || { printf ' %s\n' "$(t bad_input)"; pause; return; }
  [[ ${#PICKS[@]} -gt 0 ]] || return
  for i in "${PICKS[@]}"; do
    targets+=("${rows[i-1]}")
    sum=$((sum + ${rams[i-1]:-0}))
    case $level in
      cluster) is_default "cluster:${rows[i-1]}" && defaults+=("${rows[i-1]}") ;;
      ns) is_default "ns:${rows[i-1]#*/}" && defaults+=("${rows[i-1]#*/}") ;;
    esac
  done
  line=$(t "${action}_count_$level" "${#targets[@]}")
  [[ $action != stop ]] || line+=", $(t frees "$(gib "$sum")")"
  [[ ${#defaults[@]} -eq 0 ]] || line+=" ($(t default_selected "${defaults[*]}"))"
  if confirm "⚠ $line."; then
    run_progress bash "$CTL" "$action" "$level" "${targets[@]}"
    printf ' %s\n' "$(t free_now "$(gib "$(mem_free_mb)")")"
    pause
  fi
}

action_screen() {
  local action=$1 color=$YELLOW n
  [[ $action == start ]] && color=$GREEN
  while true; do
    header "$MENU" "$(t "$action")"
    printf ' %s\n' "$(t "${action}_what")"
    item "$color" 1 "$(t level_cluster)"
    item "$color" 2 "$(t level_ns)"
    item "$color" 3 "$(t level_app)"
    item "$color" 4 "$(t level_all)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) action_level "$action" cluster ;;
      2) action_level "$action" ns ;;
      3) action_level "$action" app ;;
      4)
        if [[ $action == stop ]]; then n=$(running_clusters | wc -l); else n=$(( $(existing_clusters | wc -l) - $(running_clusters | wc -l) )); fi
        [[ $n -gt 0 ]] || { printf ' %s\n' "$(t nothing_to_do)"; pause; continue; }
        confirm "⚠ $(t "${action}_count_cluster" "$n")." && { run_progress bash "$CTL" "$action" all; printf ' %s\n' "$(t free_now "$(gib "$(mem_free_mb)")")"; pause; } ;;
    esac
  done
}

# ---------- 4 Resources ----------

host_screen() {
  local k v
  while true; do
    declare -A h=()
    while IFS='=' read -r k v; do h[$k]=$v; done < <(bash "$RES" host)
    header "$RMENU" "$(t host)"
    local other=$(( h[mem_used] - h[k8s_ram] )) sother=$(( h[swap_used] - h[k8s_swap] ))
    (( other >= 0 )) || other=0
    (( sother >= 0 )) || sother=0
    printf '  %-8s %s  %s / %s GiB\n' "RAM" "$(bar "${h[mem_used]}" "${h[mem_total]}")" "$(gib "${h[mem_used]}")" "$(gib "${h[mem_total]}")"
    printf '  %-8s %-26s %6s GiB\n' "" "$(t k8s_clusters "${h[clusters_running]}")" "$(gib "${h[k8s_ram]}")"
    printf '  %-8s %-26s %6s GiB\n' "" "$(t other_programs)" "$(gib "$other")"
    printf '  %-8s %-26s %6s GiB  %s\n' "" "$(t cache)" "$(gib "${h[cache]}")" "$(t cache_note)"
    printf '  %-8s %-26s %6s GiB\n' "" "$(t free)" "$(gib "${h[mem_free]}")"
    printf '  %-8s %s  %s / %s GiB\n' "Swap" "$(bar "${h[swap_used]}" "${h[swap_total]}")" "$(gib "${h[swap_used]}")" "$(gib "${h[swap_total]}")"
    printf '  %-8s %-26s %6s GiB\n' "" "Kubernetes" "$(gib "${h[k8s_swap]}")"
    printf '  %-8s %-26s %6s GiB\n' "" "$(t other_programs)" "$(gib "$sother")"
    printf '  %-8s %s: %s · %s %s\n' "CPU" "$(t load)" "${h[load]// / \/ }" "${h[cpus]}" "$(t cores)"
    printf '  %-8s %s  %s / %s GiB\n\n' "Disk" "$(bar "${h[disk_used]}" "${h[disk_total]}")" "$(gib "${h[disk_used]}")" "$(gib "${h[disk_total]}")"
    if low_resources; then
      printf ' %s⚠ %s%s\n' "$RED" "$(t low_hint)" "$OFF"
      item "$YELLOW" 1 "$(t goto_stop)"
      item "$PURPLE" 2 "$(t swap_empty)"
    fi
    item "$BLUE" 3 "$(t reload)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) low_resources && action_screen stop ;;
      2) low_resources && swap_screen ;;
    esac
  done
}

cluster_res_screen() {
  local c=$1 ns ram sys
  while true; do
    header "$RMENU" "$(t level_cluster)" "$c"
    printf '  %-28s %s\n' "$(t namespace)" "RAM"
    sys=0
    while IFS=$'\t' read -r ns ram s; do
      if [[ $s == 1 ]]; then sys=$((sys + ram)); continue; fi
      printf '  %-28s %s\n' "$ns" "$(size "$ram")"
    done < <(bash "$RES" namespaces "$c")
    printf '  %-28s %s GiB\n\n' "$(t system_ns)" "$(gib "$sys")"
    item "$YELLOW" 1 "$(t stop_this_cluster)"
    item "$YELLOW" 2 "$(t restart_this_cluster)"
    item "$BLUE" 3 "$(t goto_cluster)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) confirm "$(t stop_question "$c" "-")" && { run_progress bash "$CTL" stop cluster "$c"; pause; return; } ;;
      2) confirm "$(t restart_question "$c")" && { run_progress bash "$CTL" restart cluster "$c"; pause; } ;;
      3) cluster_screen "$c"; return ;;
    esac
  done
}

res_clusters_screen() {
  local rows n i c st ram swap cpu pods tr=0 ts=0
  while true; do
    header "$RMENU" "$(t by_cluster)"
    printf '%s%s%s\n' "$GRAY" "$(t reading)" "$OFF"
    mapfile -t rows < <(bash "$RES" clusters)
    header "$RMENU" "$(t by_cluster)"
    n=${#rows[@]} tr=0 ts=0
    printf '  %-4s %-20s %-3s %-4s %-10s %-10s %-6s %s\n' "#" "$(t cluster)" "" "" "RAM" "Swap" "CPU" "Pod"
    for i in "${!rows[@]}"; do
      IFS=$'\t' read -r c st ram swap cpu pods <<<"${rows[i]}"
      tr=$((tr + ram)) ts=$((ts + swap))
      if [[ $st == running ]]; then
        printf '  %-4s %-20s %s   %s    %-10s %-10s %-6s %s\n' "$((i + 1))" "$c" "$(star "cluster:$c")" "$(mark "$st")" \
          "$(gib "$ram") GiB" "$(gib "$swap") GiB" "${cpu%.*}%" "$pods"
      else
        printf '  %-4s %-20s %s   %s    %-10s %-10s %-6s %s\n' "$((i + 1))" "$c" "$(star "cluster:$c")" "$(mark "$st")" - - - -
      fi
    done
    printf '  %-4s %-20s %-8s  %-10s %s\n\n' "" "$(t total)" "" "$(gib "$tr") GiB" "$(gib "$ts") GiB"
    back_quit
    ask "$(t pick_detail)"
    quit_check
    [[ $REPLY != 0 ]] || return
    if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le $n ]]; then
      IFS=$'\t' read -r c st _ <<<"${rows[REPLY-1]}"
      [[ $st == running ]] && cluster_res_screen "$c"
    fi
  done
}

# Usage: pods_list [--system]. Prints numbered top pods. Sets POD_ROWS.
pods_list() {
  local i c ns pod app ram limit ref color
  mapfile -t POD_ROWS < <(bash "$RES" pods "$@")
  printf '  %-4s %-18s %-20s %-36s %-10s %s\n' "#" "$(t cluster)" "$(t namespace)" "Pod" "RAM" "Limit"
  for i in "${!POD_ROWS[@]}"; do
    IFS=$'\t' read -r c ns pod app ram limit ref <<<"${POD_ROWS[i]}"
    color=
    (( limit > 0 && ram * 10 >= limit * 9 )) && color=$YELLOW
    printf '  %s%-4s %-18s %-20s %-36s %-10s %s%s\n' "$color" "$((i + 1))" "$c" "$ns" "${pod:0:36}" \
      "$(size "$ram")" "$(size "$limit")" "$OFF"
  done
}

pods_screen() {
  local sys=() c ns ref
  while true; do
    header "$RMENU" "$(t top_pods)"
    printf '%s%s%s\n' "$GRAY" "$(t reading)" "$OFF"
    header "$RMENU" "$(t top_pods)"
    pods_list "${sys[@]}"
    printf '\n'
    if [[ ${#sys[@]} -eq 0 ]]; then item "$BLUE" s "$(t show_system)"; else item "$BLUE" s "$(t hide_system)"; fi
    back_quit
    ask "$(t pick_one)"
    quit_check
    case $REPLY in
      0) return ;;
      s) if [[ ${#sys[@]} -eq 0 ]]; then sys=(--system); else sys=(); fi; continue ;;
    esac
    if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le ${#POD_ROWS[@]} ]]; then
      IFS=$'\t' read -r c ns _ _ _ _ ref <<<"${POD_ROWS[REPLY-1]}"
      if [[ $ref == pod/* ]]; then printf ' %s\n' "$(t no_workload)"; pause; continue; fi
      app_screen "$c" "$ns" "${ref%%/*}" "${ref#*/}"
    fi
  done
}

refresh_screen() {
  local before rows i c ns pod
  while true; do
    header "$RMENU" "$(t memory_refresh)"
    item "$YELLOW" 1 "$(t restart_pod)"
    item "$YELLOW" 2 "$(t restart_cluster)"
    item "$PURPLE" 3 "$(t apply_tuning)"
    item "$PURPLE" 4 "$(t drop_cache)"
    back_quit
    ask
    quit_check
    before=$(mem_free_mb)
    case $REPLY in
      0) return ;;
      1)
        header "$RMENU" "$(t memory_refresh)" "$(t restart_pod)"
        pods_list
        ask "$(t pick_prompt)"
        parse_pick "${#POD_ROWS[@]}" "$REPLY" || continue
        [[ ${#PICKS[@]} -gt 0 ]] || continue
        confirm "⚠ $(t restart_pods_question "${#PICKS[@]}")" || continue
        for i in "${PICKS[@]}"; do
          IFS=$'\t' read -r c ns pod _ <<<"${POD_ROWS[i-1]}"
          kc "$c" -n "$ns" delete pod "$pod" --wait=false && printf ' %s✔ %s/%s%s\n' "$GREEN" "$ns" "$pod" "$OFF"
        done ;;
      2)
        mapfile -t rows < <(nodes | awk -F'\t' '$2=="running"' | sort -t$'\t' -k3,3nr)
        header "$RMENU" "$(t memory_refresh)" "$(t restart_cluster)"
        for i in "${!rows[@]}"; do
          IFS=$'\t' read -r c _ ram _ <<<"${rows[i]}"
          printf '  %-4s %-20s %s GiB\n' "$((i + 1))" "$c" "$(gib "$ram")"
        done
        ask "$(t pick_prompt)"
        parse_pick "${#rows[@]}" "$REPLY" || continue
        [[ ${#PICKS[@]} -gt 0 ]] || continue
        local list=()
        for i in "${PICKS[@]}"; do list+=("$(cut -f1 <<<"${rows[i-1]}")"); done
        confirm "⚠ $(t restart_clusters_question "${list[*]}")" || continue
        run_progress bash "$CTL" restart cluster "${list[@]}" ;;
      3) confirm "⚠ $(t tuning_question)" || continue; run_progress bash "$RES" tune ;;
      4) confirm "$(t drop_cache_question)" || continue; bash "$RES" drop-cache ;;
      *) continue ;;
    esac
    printf ' %s\n' "$(t free_before_after "$(gib "$before")" "$(gib "$(mem_free_mb)")")"
    pause
  done
}

swap_screen() {
  local k v rows i c st ram swap suggest=() list=()
  while true; do
    declare -A s=()
    for k in $(bash "$RES" swap-check); do s[${k%%=*}]=${k#*=}; done
    header "$RMENU" "$(t swap_empty)"
    printf ' %s\n' "$(t swap_status "$(gib "${s[used]}")" "$(gib "${s[free]}")")"
    printf ' %s\n' "$(t swap_need "$(gib "${s[need]}")")"
    if [[ ${s[ok]} == 1 ]]; then
      printf ' %s✔ %s%s\n\n' "$GREEN" "$(t enough)" "$OFF"
      if confirm "$(t swap_question)"; then
        run_progress bash "$RES" swap-off
        echo
        printf ' %s\n' "$(t swap_status "$(gib "$(awk '/SwapTotal/ {t=$2} /SwapFree/ {f=$2} END {print int((t-f)/1024)}' /proc/meminfo)")" "$(gib "$(mem_free_mb)")")"
      fi
      pause
      return
    fi
    printf ' %s✘ %s%s\n\n' "$RED" "$(t not_enough "$(gib $(( s[need] - s[free] )))")" "$OFF"
    printf '  %s\n' "$(t stop_suggestion)"
    mapfile -t rows < <(nodes | awk -F'\t' 'BEGIN {OFS="\t"} $2=="running" {print $1, $3+$4}' | sort -t$'\t' -k2,2nr)
    suggest=()
    for i in "${!rows[@]}"; do
      IFS=$'\t' read -r c ram <<<"${rows[i]}"
      local tag=
      if is_default "cluster:$c"; then tag="${YELLOW}★ $(t default)${OFF}"; else tag="${PURPLE}◆${OFF}"; suggest+=("$((i + 1))"); fi
      printf '  %-4s %-20s %s GiB  %s\n' "$((i + 1))" "$c" "$(gib "$ram")" "$tag"
    done
    back_quit
    ask "$(t pick_prompt_suggest)"
    quit_check
    [[ $REPLY != 0 && -n $REPLY ]] || return
    pick_with_suggest "${#rows[@]}" "$REPLY" "${suggest[@]}" || continue
    list=()
    for i in "${PICKS[@]}"; do list+=("$(cut -f1 <<<"${rows[i-1]}")"); done
    [[ ${#list[@]} -gt 0 ]] || continue
    confirm "⚠ $(t stop_count_cluster "${#list[@]}")." && run_progress bash "$CTL" stop cluster "${list[@]}"
  done
}

resources_menu() {
  while true; do
    header "$RMENU"
    item "$BLUE" 1 "$(t host)"
    item "$BLUE" 2 "$(t by_cluster)"
    item "$BLUE" 3 "$(t top_pods)"
    item "$PURPLE" 4 "$(t memory_refresh)"
    item "$PURPLE" 5 "$(t swap_empty)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) host_screen ;;
      2) res_clusters_screen ;;
      3) pods_screen ;;
      4) refresh_screen ;;
      5) swap_screen ;;
    esac
  done
}

status_menu() {
  while true; do
    header "$MENU"
    item "$BLUE" 1 "$(t summary)"
    item "$BLUE" 2 "$(t clusters)"
    item "$BLUE" 3 "$(t app_search)"
    item "$BLUE" 4 "$(t all_apps)"
    item "$YELLOW" 5 "$(t stop)"
    item "$GREEN" 6 "$(t start)"
    back_quit
    ask
    quit_check
    case $REPLY in
      0) return ;;
      1) summary_screen ;;
      2) clusters_screen ;;
      3) search_screen ask ;;
      4) search_screen ;;
      5) action_screen stop ;;
      6) action_screen start ;;
    esac
  done
}

if [[ ${1:-} == resources ]]; then resources_menu; else status_menu; fi
exit 0
