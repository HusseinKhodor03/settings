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

function request_sudo_upfront() {
    if ! $DRY_RUN; then
        pretty_info "This script may require administrative privileges for certain operations."
        sudo -v
        print_newline

        while true; do
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
    fi
}
