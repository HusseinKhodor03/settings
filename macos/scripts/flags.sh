#!/bin/bash

# Flags
VERBOSE=false
DRY_RUN=false
FORCE_REINSTALL=false
SHOW_HELP=false

function print_help() {
	pretty_info "Usage: ./setup.sh [options]"
	pretty_info ""
	pretty_info "Options:"
	pretty_info "  -v, --verbose      Enable verbose output"
	pretty_info "  -d, --dry-run      Preview installs without making changes"
	pretty_info "  -f, --force        Reinstall packages even if already installed"
	pretty_info "  -h, --help         Print this help message"
}

function validate_flags() {
	if $SHOW_HELP && { $VERBOSE || $DRY_RUN || $FORCE_REINSTALL; }; then
		pretty_error "The --help flag cannot be combined with any other options."
		exit $EXIT_FAILURE
	fi

	if $SHOW_HELP; then
		print_help
		exit $EXIT_SUCCESS
	fi

	if $FORCE_REINSTALL && ! $DRY_RUN; then
		pretty_warn "You are using --force: this will reinstall all packages and overwrite existing configurations."
		read -p "Are you sure you want to continue? (y/N): " confirm
		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			exit $EXIT_SUCCESS
		fi
	fi
}

function parse_flags() {
	for arg in "$@"; do
		if [[ "$arg" == --* ]]; then
			case "$arg" in
				--verbose) VERBOSE=true ;;
				--dry-run) DRY_RUN=true ;;
				--force) FORCE_REINSTALL=true ;;
				--help) SHOW_HELP=true ;;
				*)
					pretty_error "Unknown option: $arg"
					exit $EXIT_FAILURE
					;;
			esac
		elif [[ "$arg" == -* ]]; then
			# Handle short flags (can be combined)
			for (( i=1; i<${#arg}; i++ )); do
				case "${arg:$i:1}" in
					v) VERBOSE=true ;;
					d) DRY_RUN=true ;;
					f) FORCE_REINSTALL=true ;;
					h) SHOW_HELP=true ;;
					*)
						pretty_error "Unknown option: -${arg:$i:1}"
						exit $EXIT_FAILURE
						;;
				esac
			done
		else
			pretty_error "Unknown argument: $arg"
			exit $EXIT_FAILURE
		fi
	done

	validate_flags
}