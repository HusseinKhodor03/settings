#!/bin/bash

# Colors
BOLD="\033[1m"
RESET="\033[0m"
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"

function pretty_info() {
    printf "${BOLD}${BLUE}➤ $1${RESET}\n" "${@:2}"
}

function pretty_success() {
    printf "${BOLD}${GREEN}✔ $1${RESET}\n" "${@:2}"
}

function pretty_warn() {
    printf "${BOLD}${YELLOW}⚠ $1${RESET}\n" "${@:2}"
}

function pretty_error() {
    printf "${BOLD}${RED}✖ $1${RESET}\n" "${@:2}"
}

function print_newline() {
	printf "\n"
}

function restart_terminal() {
	pretty_warn "Some changes require restarting Terminal to take effect. This will close all open Terminal windows and restart the program."
	read -p "Would you like to restart now? [y/N]: " response

	if [[ "$response" != "y" && "$response" != "Y" ]]; then
		exit $EXIT_SUCCESS
	fi

	local restart_id="terminal_restart_$(date +%s)"

	launchctl submit -l "$restart_id" -- /bin/bash -c \
	"sleep 2; \
	open -a Terminal; \
	launchctl remove \"$restart_id\""

	killall -9 Terminal
	exit $EXIT_SUCCESS
}
