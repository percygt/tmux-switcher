#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$BASE_DIR/lib/tmux.bash"

HOME_REPLACER=""
echo "$HOME" | grep -E "^[a-zA-Z0-9\-_/.@]+$" &>/dev/null
HOME_SED_SAFE=$?
if [ "$HOME_SED_SAFE" -eq 0 ]; then
  HOME_REPLACER="s|^$HOME/|~/|"
fi

handle_tmux_opts() {
  bind_kill_session=$(get_tmux_option "@tmuxinoicer-kill-session" "alt-bspace")
  bind_exit=$(get_tmux_option "@tmuxinoicer-abort" "esc")
  bind_accept=$(get_tmux_option "@tmuxinoicer-accept" "enter")
  bind_delete_char=$(get_tmux_option "@tmuxinoicer-delete-char" "bspace")

  window_size=$(get_tmux_option "@tmuxinoicer-window-size" "50%,50%")

  find_rooters=$(get_tmux_option '@tmuxinoicer-find-rooters' '.git')
  zoxide_excludes=$(get_tmux_option "@tmuxinoicer-zoxide-excludes" ".git,/nix")
  add_list_opt=$(get_tmux_option "@tmuxinoicer-extras" "find,zoxide")
}

get_find_list() {
  local -a base_dirs rooters rooter_opts

  IFS=',' read -ra rooters <<<"$find_rooters"

  for rooter in "${rooters[@]}"; do
    rooter_opts+=("-o" "-name" "$rooter")
  done
  rooter_opts=('(' "${rooter_opts[@]:1}" ')')

  for base_dir in "${base_dirs[@]}"; do
    # If the base_dir is empty, skip it
    if [[ -z "$base_dir" ]]; then
      continue
    fi

    local -a tmp
    IFS=':' read -ra tmp <<<"$base_dir"
    path="${tmp[0]}"
    min_depth="${tmp[1]:-0}"
    max_depth="${tmp[2]:-${min_depth}}"

    if [[ min_depth -eq 0 && max_depth -eq 0 ]]; then
      # If min_depth and max_depth are both 0, that means we
      # want to add the base_dir itself as a project.
      # In that case, add the base_dir as a project even if it
      # contains no rooter.
      if [[ -d "$path" || -L "$path" ]]; then
        echo "$path"
      fi
    else
      find "$path" -mindepth "$((min_depth + 1))" \
        -maxdepth "$((max_depth + 1))" \
        "${rooter_opts[@]}" \
        -printf '%h\n'
    fi
  done
}

get_sessions_list() {
  if [ "$1" = "windows" ]; then
    tmux list-windows -aF '#{session_last_attached}, #S:#I' | sort --numeric-sort --reverse | awk -F', ' '{print $2}' | grep -v "$(tmux list-windows -F '#S:#I')" || tmux list-windows -F '#S:#I'
  elif [ "$1" = "sessions" ]; then
    tmux list-sessions -F '#{session_last_attached}, #S' | sort --numeric-sort --reverse | awk -F', ' '{print $2}' | grep -v "$(tmux display-message -p '#S')" || tmux display-message -p '#S'
  fi
}

get_zoxide_list() {
  excluded_dirs="$(echo "$zoxide_excludes" | tr ',' '\|')"
  zoxide query -l | grep -vE "$excluded_dirs"
}

menu() {
  local unique_list zoxide_list find_list add_list add_option session_list
  IFS=',' read -ra add_option <<<"$add_list_opt"
  find_list=$(get_find_list | sed -e "$HOME_REPLACER")
  zoxide_list=$(get_zoxide_list | sed -e "$HOME_REPLACER")
  if [ ${#add_option[@]} -gt 0 ]; then
    for list_type in "${add_option[@]}"; do
      [ "$add_list" = "" ] || add_list+=" "
      if [[ $list_type == "find" ]] && [[ -n "$find_list" ]]; then
        add_list+="$find_list"
      fi
      if [[ $list_type == "zoxide" ]] && [[ -n "$zoxide_list" ]]; then
        add_list+="$zoxide_list"
      fi
    done

    unique_list=$(echo "$add_list" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ',')
    session_list=$(tmux list-sessions -F '#S' | awk '!seen[$0]++' | tr '\n' ',')
    IFS=',' read -ra add_list_dir <<<"$unique_list"
    IFS=',' read -ra session_names <<<"$session_list"
    result=()
    if [ ${#add_list_dir[@]} -gt 0 ]; then
      for path in "${add_list_dir[@]}"; do
        # Extract the basename from the full path
        # basename=$(to_session_name "$path")
        basename=$(to_session_name "$path")
        # Remove leading "." if present in the basename
        found=false
        for session in "${session_names[@]}"; do
          if [ "$basename" == "$session" ]; then
            found=true
            break
          fi
        done
        if [ "$found" == false ]; then
          result+=("$path")
        fi
      done
    fi
    # get_sessions_list "$1" && printf '\e[1;34m%-6s\e[m\n' "${result[@]}"
    get_sessions_list "$1" && echo "${result[@]}"
  else
    get_sessions_list "$1"
  fi
}

convert_keys() {
  local keybind
  IFS='-' read -ra keys <<<"$1"
  if [ "${#keys[@]}" -le 2 ]; then
    first_key=${keys[0]}
    second_key=${keys[1]}
    fchar="${first_key:0:1}"
    keybind="<$fchar-${second_key}>"
  else
    keybind="<$1>"
  fi
  echo "$keybind"
}
handle_fzf_args() {
  local switcher_path
  path_dir="${TMUX_PLUGIN_MANAGER_PATH%/}"
  switcher_path="$path_dir/tmuxinoicer/libexec/switcher.bash"
  current_session="$(tmux display-message -p '#S')"
  kill_session="$bind_kill_session:execute(tmux kill-session -t {})+reload(${switcher_path} menu sessions)"

  accept="$bind_accept:replace-query+print-query"
  delete="$bind_delete_char:backward-delete-char"
  exit="$bind_exit:abort"
}

run_fzf() {
  local menu_arg
  menu_arg="sessions"

  selected_path=$(
    menu "$menu_arg" | fzf-tmux \
      --bind "$kill_session" \
      --bind "$delete" \
      --bind "$exit" \
      --bind "$accept" \
      --bind 'change:first' \
      --exit-0 \
      --no-sort \
      -p "$window_size" \
      --print-query \
      --border-label="Current session: $current_session "
  )
}

main() {
  handle_tmux_opts
  handle_fzf_args
  if [ $# -ge 1 ]; then
    if [ "$1" = "menu" ]; then
      menu "$2"
    fi
  else
    run_fzf

    if [[ -z $selected_path ]]; then
      return 0
    fi
    if [ "$HOME_SED_SAFE" -eq 0 ]; then
      # shellcheck disable=2001
      selected_path=$(echo "$selected_path" | sed -e "s|^~/|$HOME/|") # get real home path back
    fi

    zoxide add "$selected_path" &>/dev/null

    session_name=$(to_session_name "$selected_path")

    # If the session already exists, attach to it. Otherwise, create a new
    # session and attach to it.
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
      # Return 0 even if creating the session fails.
      tmux new-session -d -s "$session_name" -c "$selected_path" \; \
        set -t "$session_name" destroy-unattached off || :
    fi
    tmux switch-client -t "$session_name"
  fi
}

main "$@"
