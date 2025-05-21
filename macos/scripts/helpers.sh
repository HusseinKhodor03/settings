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