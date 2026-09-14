#!/usr/bin/env bash
# Shared helpers for percy scripts. Meant to be sourced, not executed.

# Sources $PERCY_CONFIG_FILE (default ~/.config/percy/config) to fill in
# PERCY_* defaults, without letting it override variables already present
# in the environment: Environment= (systemd) > config file > script default.
load_percy_config() {
    local config_file="${PERCY_CONFIG_FILE:-$HOME/.config/percy/config}"
    [[ -r "$config_file" ]] || return 0

    local name preset_names=()
    while IFS= read -r name; do
        preset_names+=("$name")
    done < <(compgen -v | grep '^PERCY_' || true)

    local -A preset_values=()
    for name in "${preset_names[@]}"; do
        preset_values["$name"]="${!name}"
    done

    # shellcheck disable=SC1090
    source "$config_file"

    # Restore any PERCY_* vars that were already set before sourcing, so an
    # explicitly-set environment variable always wins over the config file.
    for name in "${preset_names[@]}"; do
        export "$name=${preset_values[$name]}"
    done
}
