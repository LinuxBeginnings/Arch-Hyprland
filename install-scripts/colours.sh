#!/bin/bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# 💫 https://github.com/LinuxBeginnings 💫 #
# Shared colors, icons and console helpers, sourced instead of repeated in
# every script.
#
# Colors and icons degrade gracefully:
#   - NO_COLOR, TERM=dumb, a pipe or a terminal without tput keeps the plain
#     [OK]/[ERROR]/... labels, so logs stay readable and greppable.
#   - Non UTF-8 locales fall back to ASCII icons.
# Helpers never return non-zero, because the install scripts run under `set -e`.

# Every variable and helper below is consumed by the scripts sourcing this file
# shellcheck disable=SC2034

# --- terminal capability detection ---------------------------------------
_KD_UTF8=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
*[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) _KD_UTF8=1 ;;
esac

_KD_COLOR=0
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ] &&
  command -v tput >/dev/null 2>&1 && tput setaf 2 >/dev/null 2>&1; then
  _KD_COLOR=1
fi

# tput wrappers that can never fail: a missing TERM must not abort an install
# halfway through a `set -e` script.
_kd_tput() {
  [ "$_KD_COLOR" -eq 1 ] || return 0
  tput "$@" 2>/dev/null || true
}

_kd_color() { # _kd_color <0-255>, falls back to the basic 8-color palette
  local n="$1" out=""
  [ "$_KD_COLOR" -eq 1 ] || return 0
  out="$(tput setaf "$n" 2>/dev/null)" || out=""
  if [ -z "$out" ] && [ "$n" -gt 7 ]; then
    out="$(tput setaf "$((n % 8))" 2>/dev/null)" || out=""
  fi
  printf '%s' "$out"
}

# --- colors ---------------------------------------------------------------
if [ "$_KD_COLOR" -eq 1 ]; then
  RESET="$(_kd_tput sgr0)"
  BOLD="$(_kd_tput bold)"
  DIM="$(_kd_tput dim)"
  MAGENTA="$(_kd_color 5)"
  ORANGE="$(_kd_color 214)"
  YELLOW="$(_kd_color 3)"
  GREEN="$(_kd_color 2)"
  BLUE="$(_kd_color 4)"
  SKY_BLUE="$(_kd_color 6)"
  WARNING="$(_kd_color 1)"

  OK="${GREEN}[OK]${RESET}"
  ERROR="${WARNING}[ERROR]${RESET}"
  NOTE="${YELLOW}[NOTE]${RESET}"
  INFO="${BLUE}[INFO]${RESET}"
  WARN="${WARNING}[WARN]${RESET}"
  CAT="${SKY_BLUE}[ACTION]${RESET}"
else
  RESET="" BOLD="" DIM=""
  MAGENTA="" ORANGE="" YELLOW="" GREEN="" BLUE="" SKY_BLUE="" WARNING=""

  # Keep the bracketed labels: scripts and logs are matched on them.
  OK="[OK]" ERROR="[ERROR]" NOTE="[NOTE]" INFO="[INFO]" WARN="[WARN]" CAT="[ACTION]"
fi

# --- icons ----------------------------------------------------------------
if [ "$_KD_UTF8" -eq 1 ]; then
  ICON_OK="✔"
  ICON_ERR="✖"
  ICON_WARN="⚠"
  ICON_INFO="ℹ"
  ICON_STEP="➜"
  ICON_ARROW="→"
  ICON_BULLET="•"
  ICON_GEAR="⚙"
else
  ICON_OK="[ok]"
  ICON_ERR="[x]"
  ICON_WARN="[!]"
  ICON_INFO="[i]"
  ICON_STEP="->"
  ICON_ARROW="->"
  ICON_BULLET="*"
  ICON_GEAR="*"
fi

# --- console + log helpers ------------------------------------------------
# Strip ANSI sequences so log files stay readable with grep/less.
_kd_strip_ansi() {
  sed -E $'s/\x1b\\[[0-9;]*[a-zA-Z]//g'
}

# Mirror a message into $LOG when a log file is active.
log_to_file() {
  [ -n "${LOG:-}" ] && [ "$LOG" != "/dev/null" ] || return 0
  printf '%s\n' "$1" | _kd_strip_ansi >>"$LOG" 2>/dev/null || true
}

hr() {
  if [ "$_KD_UTF8" -eq 1 ]; then
    printf '%s%s%s\n' "$DIM" "────────────────────────────────────────────────────────" "$RESET"
  else
    printf '%s%s%s\n' "$DIM" "--------------------------------------------------------" "$RESET"
  fi
}

section() {
  local title="$*"
  printf '\n%s%s %s%s\n' "$BOLD" "$SKY_BLUE" "$title" "$RESET"
  hr
  log_to_file "== $title =="
}

step() {
  printf '%s%s%s %s\n' "$SKY_BLUE" "$ICON_STEP" "$RESET" "$*"
  log_to_file "[STEP] $*"
}

ok() {
  printf '%s%s%s %s\n' "$GREEN" "$ICON_OK" "$RESET" "$*"
  log_to_file "[OK] $*"
}

info() {
  printf '%s%s%s %s\n' "$BLUE" "$ICON_INFO" "$RESET" "$*"
  log_to_file "[INFO] $*"
}

note() {
  printf '%s%s%s %s\n' "$YELLOW" "$ICON_BULLET" "$RESET" "$*"
  log_to_file "[NOTE] $*"
}

warn() {
  printf '%s%s%s %s%s%s\n' "$WARNING" "$ICON_WARN" "$RESET" "$YELLOW" "$*" "$RESET"
  log_to_file "[WARN] $*"
}

error() {
  printf '%s%s%s %s%s%s\n' "$WARNING" "$ICON_ERR" "$RESET" "$YELLOW" "$*" "$RESET" >&2
  log_to_file "[ERROR] $*"
}

die() {
  local code="${2:-1}"
  local message="$1"
  error "$message"
  exit "$code"
}

debug() {
  [ -n "${KD_DEBUG:-}" ] || return 0
  printf '%s[DEBUG] %s%s\n' "$DIM" "$*" "$RESET"
}

# Restore a normal cursor after an interrupted spinner. Only touches the
# terminal when stdout is one, so piped/redirected runs stay free of escapes.
restore_cursor() {
  [ -t 1 ] || return 0
  tput cnorm 2>/dev/null || true
}

# Shared ASCII-art header. $1 is a short subtitle, e.g. "Install • 2026".
print_banner() {
  local subtitle="${1:-Install}"
  printf '\n%s' "$MAGENTA"
  if [ "$_KD_UTF8" -eq 1 ]; then
    printf '%s\n' \
      '  ╦╔═┌─┐┌─┐╦    ╦ ╦┬ ┬┌─┐┬─┐┬  ┌─┐┌┐┌┌┬┐' \
      "  ╠╩╗│ ││ │║    ╠═╣└┬┘├─┘├┬┘│  ├─┤│││ ││ ${subtitle}" \
      '  ╩ ╩└─┘└─┘╩═╝  ╩ ╩ ┴ ┴  ┴└─┴─┘┴ ┴┘└┘─┴┘ Arch Linux'
  else
    printf '%s\n' \
      '  KooL  Arch-Hyprland' \
      "  ${subtitle}" \
      '  Arch Linux'
  fi
  printf '%s\n\n' "$RESET"
}
