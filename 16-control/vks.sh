#!/usr/bin/env bash
# Main menu of VKS. Opens the installation, status and resource menus.
# Usage: vks.sh
source "$(dirname "$(readlink -f "$0")")/../00-common/lib.sh"
source "$INSTALL_DIR/16-control/lib-state.sh"
source "$CONTROL/menu-lib.sh"
set +e

# Runs a menu script. Exit code 10 means: the user chose quit.
open_menu() {
  bash "$CONTROL/$1" "${@:2}"
  [[ $? -ne $QUIT ]] || exit 0
}

language_menu() {
  local codes=() code name i=0
  header "$(t main_menu)" "$(t language)"
  while IFS=$'\t' read -r code name; do
    codes+=("$code")
    i=$((i + 1))
    item "$GRAY" "$i" "$name"
  done < <(languages)
  back_quit
  ask
  quit_check
  if [[ $REPLY =~ ^[0-9]+$ && $REPLY -ge 1 && $REPLY -le ${#codes[@]} ]]; then
    save_lang "${codes[REPLY-1]}"
    load_lang "${codes[REPLY-1]}"
  fi
}

while true; do
  header "$(t main_menu)"
  item "$GREEN" 1 "$(t installation)"
  item "$BLUE" 2 "$(t status_management)"
  item "$PURPLE" 3 "$(t resource_usage)"
  item "$GRAY" L "$(t language): $(t _name)"
  item "$GRAY" q "$(t quit)"
  ask
  case $REPLY in
    1) open_menu setup.sh ;;
    2) open_menu status.sh ;;
    3) open_menu status.sh resources ;;
    L|l) language_menu ;;
    q|0) exit 0 ;;
  esac
done
