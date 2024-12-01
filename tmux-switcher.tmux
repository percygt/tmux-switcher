#!/usr/bin/env bash

basedir="$(cd "$(dirname "$0")" && pwd)"
. "${basedir}/lib/tmux.bash"

key="$(get_tmux_option '@tmux-switcher-bind' '0')"
if [[ -n "$key" ]]; then
	tmux bind-key "$key" run-shell -b "${basedir}/libexec/switcher.bash"
fi
