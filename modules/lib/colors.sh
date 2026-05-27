#!/usr/bin/env bash
#
# colors.sh - Terminal colors and formatting (via tput)
# Part of Bashgency
#
# This file is sourced by bashgency-cli.sh. It sets readonly globals
# for color/font codes so they are only initialized once.
#

# Guard: run only once
if [ -n "${__BASHGENCY_COLORS_LOADED:-}" ]; then
    return 0
fi

# shellcheck disable=SC2034,SC2155

# --- Font styles ---
readonly BOLD=$(tput bold)
readonly DIM=$(tput dim)
readonly BLINK=$(tput blink)
readonly REV=$(tput rev)
readonly RESET=$(tput sgr0)

# --- Foreground ---
readonly F_BLACK=$(tput setaf 0)
readonly F_RED=$(tput setaf 1)
readonly F_GREEN=$(tput setaf 2)
readonly F_YELLOW=$(tput setaf 3)
readonly F_BLUE=$(tput setaf 4)
readonly F_MAGENTA=$(tput setaf 5)
readonly F_CYAN=$(tput setaf 6)
readonly F_WHITE=$(tput setaf 7)

# --- Background ---
readonly B_BLACK=$(tput setab 0)
readonly B_RED=$(tput setab 1)
readonly B_GREEN=$(tput setab 2)
readonly B_YELLOW=$(tput setab 3)
readonly B_BLUE=$(tput setab 4)
readonly B_MAGENTA=$(tput setab 5)
readonly B_CYAN=$(tput setab 6)
readonly B_WHITE=$(tput setab 7)

# --- Layout constants ---
readonly __BASHGENCY_PANEL_W=58

__BASHGENCY_COLORS_LOADED=1
