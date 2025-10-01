#!/bin/bash

EXIT_SUCCESS=0
EXIT_FAILURE=1

ANY_CHANGES_MADE=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/flags.sh"

source_shellenv

function install_homebrew() {
	pretty_info "Checking Homebrew installation:"

	local already_installed=false
	if [[ -x /opt/homebrew/bin/brew ]] || [[ -x /usr/local/bin/brew ]] &>/dev/null; then
		already_installed=true
	fi

	if $DRY_RUN; then
		if $already_installed; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would uninstall and reinstall Homebrew verbosely"
				else
					pretty_info "[Dry Run] Would uninstall and reinstall Homebrew"
				fi
			else
				pretty_info "[Dry Run] Homebrew already installed. Would skip"
			fi
		else
			if $VERBOSE; then
				pretty_info "[Dry Run] Would install Homebrew verbosely"
			else
				pretty_info "[Dry Run] Would install Homebrew"
			fi
		fi

		print_newline
		pretty_info "Dry run complete. No changes were made."
		return
	fi

	if $already_installed && $FORCE_REINSTALL; then
		pretty_info "Reinstalling Homebrew..."
		if $VERBOSE; then
			NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
		else
			NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" >/dev/null 2>&1
		fi
		ANY_CHANGES_MADE=true
	elif $already_installed; then
		pretty_success "Homebrew already installed. Skipping..."
		return
	else
		pretty_info "Installing Homebrew..."
	fi

	if $VERBOSE; then
		NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	else
		NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
	fi

	if [[ -x /opt/homebrew/bin/brew ]] && /opt/homebrew/bin/brew --version &>/dev/null; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
		pretty_success "Homebrew installed successfully!"
		ANY_CHANGES_MADE=true
	elif [[ -x /usr/local/bin/brew ]] && /usr/local/bin/brew --version &>/dev/null; then
		eval "$(/usr/local/bin/brew shellenv)"
		pretty_success "Homebrew installed successfully!"
		ANY_CHANGES_MADE=true
	else
		pretty_error "Failed to install Homebrew"
		return $EXIT_FAILURE
	fi
}

function install_homebrew_packages() {
    local brew_file="$HOME/settings/macos/manifests/homebrew_packages.txt"
	local any_installed=false

	if [[ ! -f "$brew_file" ]]; then
		pretty_error "No brew file found"
		return
	fi

	print_newline
	pretty_info "Installing Homebrew packages:"

	local packages=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        packages+=("$line")
    done < <(grep -vE '^\s*#' "$brew_file")

	local total=${#packages[@]}
	local current=1

	for package in "${packages[@]}"; do
		print_newline

		pretty_info "Package $current of $total: Processing %s..." "$package"
		((current++))

		if $DRY_RUN; then
			if brew list "$package" &>/dev/null; then
				if $FORCE_REINSTALL; then
					if $VERBOSE; then
						pretty_info "[Dry Run] Would reinstall %s verbosely" "$package"
					else
						pretty_info "[Dry Run] Would reinstall %s" "$package"
					fi
				else
					pretty_info "[Dry Run] %s already installed. Would skip" "$package"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would install %s verbosely" "$package"
				else
					pretty_info "[Dry Run] Would install %s" "$package"
				fi
			fi
			continue
		fi

		if brew list "$package" &>/dev/null; then
			if $FORCE_REINSTALL; then
				pretty_info "Reinstalling %s..." "$package"
				cmd="reinstall"
			else
				pretty_success "%s already installed. Skipping..." "$package"
				continue
			fi
		else
			pretty_info "Installing %s..." "$package"
			cmd="install"
		fi

		if $VERBOSE; then
			brew "$cmd" "$package" </dev/null
		else
			brew "$cmd" -q "$package" >/dev/null 2>&1
		fi

		if [[ $? -eq 0 ]]; then
			pretty_success "%s %sed successfully" "$package" "$cmd"
			any_installed=true
			ANY_CHANGES_MADE=true
		else
			pretty_error "Failed to %s %s" "$cmd" "$package"
			return $EXIT_FAILURE
		fi
	done
        
	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_installed; then
		pretty_success "All packages installed successfully!"
	else
    	pretty_info "No packages needed to be installed."
	fi
}

function install_vim_plugins() {
	local plugins_file="$HOME/settings/macos/manifests/vim_plugins.txt"
	local plugins_dir="$HOME/.vim/pack/plugins/start"
	local any_installed=false

	print_newline
	pretty_info "Installing Vim plugins:"

	if [[ ! -f "$plugins_file" ]]; then
		pretty_error "No plugins file found"
		return
	fi

	local plugins=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        plugins+=("$line")
    done < <(grep -vE '^\s*#' "$plugins_file")

	local total=${#plugins[@]}
	local current=1

	for plugin in "${plugins[@]}"; do
		local name="$(basename "$plugin" .git)"
		local plugin_dir="$plugins_dir/$name"

		print_newline
		pretty_info "Plugin $current of $total: Processing %s..." "$name"
		((current++))

		local already_installed=false
		if [[ -d "$plugin_dir" ]]; then
			already_installed=true
		fi

		if $DRY_RUN; then
			if $already_installed; then
				if $FORCE_REINSTALL; then
					if $VERBOSE; then
						pretty_info "[Dry Run] Would uninstall and reinstall %s verbosely" "$name"
					else
						pretty_info "[Dry Run] Would uninstall and reinstall %s" "$name"
					fi
				else
					pretty_info "[Dry Run] %s already installed. Would skip" "$name"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would install %s verbosely" "$name"
				else
					pretty_info "[Dry Run] Would install %s" "$name"
				fi
			fi
			continue
		fi

		if $already_installed; then
			if $FORCE_REINSTALL; then
				pretty_info "Reinstalling %s..." "$name"
				if $VERBOSE; then
					pretty_info "Removing %s from %s" "$name" "$plugin_dir"
					printf "Command: rm -rf \"%s\"\n" "$plugin_dir"
				fi
				rm -rf "$plugin_dir"
				ANY_CHANGES_MADE=true
			else
				pretty_success "%s already installed. Skipping..." "$name"
				continue
			fi
		else
			pretty_info "Installing %s..." "$name"
		fi

		if $VERBOSE; then
			git clone --depth=1 "$plugin" "$plugin_dir"
		else
			git clone --depth=1 "$plugin" "$plugin_dir" >/dev/null 2>&1
		fi

		if [[ $? -eq 0 ]]; then
			pretty_success "%s installed successfully" "$name"
			any_installed=true
			ANY_CHANGES_MADE=true
		else
			pretty_error "Failed to install %s" "$name"
			return $EXIT_FAILURE
		fi
	done
        
	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_installed; then
		pretty_success "All Vim plugins installed successfully!"
	else
    	pretty_info "No plugins needed to be installed."
	fi
}

function install_omz() {
	print_newline
	pretty_info "Checking Oh My Zsh installation:"

	local zsh_path="$(command -v zsh)"
	local current_shell="$(dscl . -read "$HOME" UserShell | awk '{print $2}')"
	local already_installed=false

	if [[ -d "$HOME/.oh-my-zsh" ]]; then
		already_installed=true
	fi

	if $DRY_RUN; then
		if $already_installed; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would uninstall and reinstall Oh My Zsh verbosely"
				else
					pretty_info "[Dry Run] Would uninstall and reinstall Oh My Zsh"
				fi
			else
				pretty_info "[Dry Run] Oh My Zsh already installed. Would skip"
			fi
		else
			if $VERBOSE; then
				pretty_info "[Dry Run] Would install Oh My Zsh verbosely"
			else
				pretty_info "[Dry Run] Would install Oh My Zsh"
			fi
		fi

		print_newline
		pretty_info "Dry run complete. No changes were made."
		return
	fi

	if $already_installed; then
		if $FORCE_REINSTALL; then
			pretty_info "Reinstalling Oh My Zsh..."
			if $VERBOSE; then
				pretty_info "Removing ~/.oh-my-zsh..."
				printf "Command: rm -rf \"%s\"\n" "$HOME/.oh-my-zsh"
			fi
			rm -rf "$HOME/.oh-my-zsh"
			ANY_CHANGES_MADE=true
		else
			pretty_success "Oh My Zsh already installed. Skipping..."
			return
		fi
	else
		pretty_info "Installing Oh My Zsh..."
	fi

	if $VERBOSE; then
		git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
	else
		git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" >/dev/null 2>&1
	fi

	if [[ -d "$HOME/.oh-my-zsh" ]]; then
		pretty_success "Oh My Zsh installed successfully!"
		ANY_CHANGES_MADE=true
	else
		pretty_error "Failed to install Oh My Zsh"
		return $EXIT_FAILURE
	fi
}

function manage_etc_shells() {
	print_newline
	pretty_info "Ensuring shell is in /etc/shells:"

	local zsh_path="$(command -v zsh)"

	local already_in_etc_shells=false
	if grep -qFx "$zsh_path" /etc/shells; then
		already_in_etc_shells=true
	fi

	if $DRY_RUN; then
		if $already_in_etc_shells; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would remove and re-add %s to /etc/shells verbosely" "$zsh_path"
				else
					pretty_info "[Dry Run] Would remove and re-add %s to /etc/shells" "$zsh_path"
				fi
			else
				pretty_info "[Dry Run] %s already in /etc/shells. Would skip" "$zsh_path"
			fi
		else
			if $VERBOSE; then
				pretty_info "[Dry Run] Would add %s to /etc/shells verbosely" "$zsh_path"
			else
				pretty_info "[Dry Run] Would add %s to /etc/shells" "$zsh_path"
			fi
		fi

		print_newline
		pretty_info "Dry run complete. No changes were made."
		return
	fi

	if $already_in_etc_shells && $FORCE_REINSTALL; then
		if $VERBOSE; then
			pretty_info "Removing %s from /etc/shells..." "$zsh_path"
			printf "Command: grep -vFx \"%s\" /etc/shells | sudo tee /etc/shells\n" "$zsh_path"
		fi
		grep -vFx "$zsh_path" /etc/shells | sudo tee /etc/shells >/dev/null
		ANY_CHANGES_MADE=true
	elif $already_in_etc_shells; then
		pretty_success "%s already in /etc/shells. Skipping..." "$zsh_path"
		return
	else
		pretty_info "Configuring shell..."
	fi

	if $VERBOSE; then
		pretty_info "Adding %s to /etc/shells..." "$zsh_path"
		printf "Command: printf \"%%s\\n\" \"%s\" | sudo tee -a /etc/shells\n" "$zsh_path"
	fi
	echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
	ANY_CHANGES_MADE=true

	if grep -qFx "$zsh_path" /etc/shells; then
		pretty_success "%s added to /etc/shells successfully!" "$zsh_path"
	else
		pretty_error "Failed to add %s to /etc/shells" "$zsh_path"
		return $EXIT_FAILURE
	fi
}

function set_zsh_as_default() {
	print_newline
	pretty_info "Checking default shell:"

	local zsh_path="$(command -v zsh)"
	local current_shell="$(dscl . -read "$HOME" UserShell | awk '{print $2}')"
	local fallback_shell="/bin/bash"

	local already_default=false
	if [[ "$current_shell" == "$zsh_path" ]]; then
		already_default=true
	fi

	if $DRY_RUN; then
		if $already_default; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would unset and re-set %s as the default shell verbosely" "$zsh_path"
				else
					pretty_info "[Dry Run] Would unset and re-set %s as the default shell" "$zsh_path"
				fi
			else
				pretty_info "[Dry Run] %s already set to default shell. Would skip" "$zsh_path"
			fi
		else
			if $VERBOSE; then
				pretty_info "[Dry Run] Would change default shell to %s verbosely" "$zsh_path"
			else
				pretty_info "[Dry Run] Would change default shell to %s" "$zsh_path"
			fi
		fi

		print_newline
		pretty_info "Dry run complete. No changes were made."
		return
	fi

	if $already_default && $FORCE_REINSTALL; then
		if $VERBOSE; then
			pretty_info "Unsetting %s as default shell..." "$zsh_path"
			printf "Command: chsh -s \"%s\"\n" "$fallback_shell"
		fi
		chsh -s "$fallback_shell"
		ANY_CHANGES_MADE=true
	elif $already_default; then
		pretty_success "%s already set to default shell. Skipping..." "$zsh_path"
		return
	else
		pretty_info "Configuring default..."
	fi

	if $VERBOSE; then
		pretty_info "Changing default shell to %s..." "$zsh_path"
		printf "Command: chsh -s \"%s\"\n" "$zsh_path"
	fi
	chsh -s "$zsh_path"
	ANY_CHANGES_MADE=true

	current_shell="$(dscl . -read "$HOME" UserShell | awk '{print $2}')"
	if [[ "$current_shell" == "$zsh_path" ]]; then
		pretty_success "%s set as default shell successfully!" "$zsh_path"
	else
		pretty_error "Failed to set %s as default shell" "$zsh_path"
		return $EXIT_FAILURE
	fi
}

function install_custom_omz_themes() {
	local themes_file="$HOME/settings/macos/manifests/custom_omz_themes.txt"
	local themes_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes"
	local any_installed=false

	print_newline
	pretty_info "Installing custom Oh My Zsh themes:"

	if [[ ! -f "$themes_file" ]]; then
		pretty_error "No themes file found"
		return
	fi

	local themes=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        themes+=("$line")
    done < <(grep -vE '^\s*#' "$themes_file")

	local total=${#themes[@]}
	local current=1

	for theme in "${themes[@]}"; do
		local name="$(basename "$theme" .git)"
		local dotfile="$themes_dir/$name"

		print_newline
		pretty_info "Theme $current of $total: Processing %s..." "$name"
		((current++))

		local already_installed=false
		if [[ -d "$dotfile" ]]; then
			already_installed=true
		fi

		if $DRY_RUN; then
			if $already_installed; then
				if $FORCE_REINSTALL; then
					if $VERBOSE; then
						pretty_info "[Dry Run] Would uninstall and reinstall %s verbosely" "$name"
					else
						pretty_info "[Dry Run] Would uninstall and reinstall %s" "$name"
					fi
				else
					pretty_info "[Dry Run] %s already installed. Would skip" "$name"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would install %s verbosely" "$name"
				else
					pretty_info "[Dry Run] Would install %s" "$name"
				fi
			fi
			continue
		fi

		if $already_installed; then
			if $FORCE_REINSTALL; then
				pretty_info "Reinstalling %s..." "$name"
				if $VERBOSE; then
					pretty_info "Removing %s from %s" "$name" "$dotfile"
					printf "Command: rm -rf \"%s\"\n" "$dotfile"
				fi
				rm -rf "$dotfile"
				ANY_CHANGES_MADE=true
			else
				pretty_success "%s already installed. Skipping..." "$name"
				continue
			fi
		else
			pretty_info "Installing %s..." "$name"
		fi

		if $VERBOSE; then
			git clone --depth=1 "$theme" "$dotfile"
		else
			git clone --depth=1 "$theme" "$dotfile" >/dev/null 2>&1
		fi

		if [[ $? -eq 0 ]]; then
			pretty_success "%s installed successfully" "$name"
			any_installed=true
			ANY_CHANGES_MADE=true
		else
			pretty_error "Failed to install %s" "$name"
			return $EXIT_FAILURE
		fi
	done
        
	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_installed; then
		pretty_success "All custom Oh My Zsh themes installed successfully!"
	else
    	pretty_info "No themes needed to be installed."
	fi
}

function install_custom_omz_plugins() {
	local plugins_file="$HOME/settings/macos/manifests/custom_omz_plugins.txt"
	local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
	local any_installed=false

	print_newline
	pretty_info "Installing custom Oh My Zsh plugins:"

	if [[ ! -f "$plugins_file" ]]; then
		pretty_error "No plugins file found"
		return
	fi

	local plugins=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        plugins+=("$line")
    done < <(grep -vE '^\s*#' "$plugins_file")

	local total=${#plugins[@]}
	local current=1

	for plugin in "${plugins[@]}"; do
		local name="$(basename "$plugin" .git)"
		local plugin_dir="$plugins_dir/$name"

		print_newline
		pretty_info "Plugin $current of $total: Processing %s..." "$name"
		((current++))

		local already_installed=false
		if [[ -d "$plugin_dir" ]]; then
			already_installed=true
		fi

		if $DRY_RUN; then
			if $already_installed; then
				if $FORCE_REINSTALL; then
					if $VERBOSE; then
						pretty_info "[Dry Run] Would uninstall and reinstall %s verbosely" "$name"
					else
						pretty_info "[Dry Run] Would uninstall and reinstall %s" "$name"
					fi
				else
					pretty_info "[Dry Run] %s already installed. Would skip" "$name"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would install %s verbosely" "$name"
				else
					pretty_info "[Dry Run] Would install %s" "$name"
				fi
			fi
			continue
		fi

		if $already_installed; then
			if $FORCE_REINSTALL; then
				pretty_info "Reinstalling %s..." "$name"
				if $VERBOSE; then
					pretty_info "Removing %s from %s" "$name" "$plugin_dir"
					printf "Command: rm -rf \"%s\"\n" "$plugin_dir"
				fi
				rm -rf "$plugin_dir"
				ANY_CHANGES_MADE=true
			else
				pretty_success "%s already installed. Skipping..." "$name"
				continue
			fi
		else
			pretty_info "Installing %s..." "$name"
		fi

		if $VERBOSE; then
			git clone --depth=1 "$plugin" "$plugin_dir"
		else
			git clone --depth=1 "$plugin" "$plugin_dir" >/dev/null 2>&1
		fi

		if [[ $? -eq 0 ]]; then
			pretty_success "%s installed successfully" "$name"
			any_installed=true
			ANY_CHANGES_MADE=true
		else
			pretty_error "Failed to install %s" "$name"
			return $EXIT_FAILURE
		fi
	done
        
	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_installed; then
		pretty_success "All custom Oh My Zsh plugins installed successfully!"
	else
    	pretty_info "No plugins needed to be installed."
	fi
}

function install_meslo_nerd_fonts() {
	local fonts_file="$HOME/settings/macos/manifests/meslo_nerd_fonts.txt"
	local fonts_dir="$HOME/Library/Fonts"
	local any_installed=false

	print_newline
	pretty_info "Installing Meslo Nerd Fonts:"

	if [[ ! -f "$fonts_file" ]]; then
		pretty_error "No fonts file found"
		return
	fi

	local fonts=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        fonts+=("$line")
    done < <(grep -vE '^\s*#' "$fonts_file")

	local total=${#fonts[@]}
	local current=1

	for font in "${fonts[@]}"; do
		local encoded_name="$(basename "$font")"
		local filename="$(printf '%b' "${encoded_name//%/\\x}")"
		local font_dir="$fonts_dir/$filename"

		print_newline
		pretty_info "Font $current of $total: Processing %s..." "$filename"
		((current++))

		local already_installed=false
		if [[ -f "$font_dir" ]]; then
			already_installed=true
		fi

		if $DRY_RUN; then
			if $already_installed; then
				if $FORCE_REINSTALL; then
					if $VERBOSE; then
						pretty_info "[Dry Run] Would uninstall and reinstall %s verbosely" "$filename"
					else
						pretty_info "[Dry Run] Would uninstall and reinstall %s" "$filename"
					fi
				else
					pretty_info "[Dry Run] %s already installed. Would skip" "$filename"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would install %s verbosely" "$filename"
				else
					pretty_info "[Dry Run] Would install %s" "$filename"
				fi
			fi
			continue
		fi

		if $already_installed; then
			if $FORCE_REINSTALL; then
				pretty_info "Reinstalling %s..." "$name"
				if $VERBOSE; then
					pretty_info "Removing %s from %s" "$filename" "$font_dir"
					printf "Command: rm -rf \"%s\"\n" "$font_dir"
				fi
				rm -rf "$font_dir"
				ANY_CHANGES_MADE=true
			else
				pretty_success "%s already installed. Skipping..." "$filename"
				continue
			fi
		else
			pretty_info "Installing %s..." "$filename"
		fi

		if $VERBOSE; then
			curl -Lo "$font_dir" "$font"
		else
			curl -sLo "$font_dir" "$font"
		fi

		if [[ $? -eq 0 ]]; then
			pretty_success "%s installed successfully" "$filename"
			any_installed=true
			ANY_CHANGES_MADE=true
		else
			pretty_error "Failed to install %s" "$filename"
			return $EXIT_FAILURE
		fi
	done
        
	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_installed; then
		pretty_success "All Meslo Nerd Fonts installed successfully!"
	else
    	pretty_info "No fonts needed to be installed."
	fi
}

function import_terminal_profile() {
	local profile_name="Coolnight"
	local profile_file="$HOME/settings/macos/terminal_profiles/${profile_name}.terminal"
	local terminal_plist="$HOME/Library/Preferences/com.apple.Terminal.plist"
	local already_imported=false
	local desired_font="MesloLGS NF"
	local desired_font_size=18

	print_newline
	pretty_info "Checking terminal profile installation:"

	if ! [[ -f "$profile_file" ]]; then
		pretty_error "Terminal profile '$profile_name' not found"
		return
	fi

	if /usr/libexec/PlistBuddy -c "Print :'Window Settings':'$profile_name'" "$terminal_plist" &>/dev/null; then
		already_imported=true
	fi

	if $DRY_RUN; then
		if $already_imported; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would uninstall and reinstall terminal profile '$profile_name' verbosely"
				else
					pretty_info "[Dry Run] Would uninstall and reinstall terminal profile '$profile_name'"
				fi
			else
				pretty_info "[Dry Run] Terminal profile '$profile_name' already installed. Would skip"
			fi
		else
			if $VERBOSE; then
				pretty_info "[Dry Run] Would install terminal profile '$profile_name' verbosely"
			else
				pretty_info "[Dry Run] Would install terminal profile '$profile_name'"
			fi
		fi

		print_newline
		pretty_info "Dry run complete. No changes were made."
		return
	fi

	if $already_imported; then
		if $FORCE_REINSTALL; then
			pretty_info "Reinstalling terminal profile '$profile_name'..."
			if $VERBOSE; then
				pretty_info "Removing existing profile '$profile_name' from $terminal_plist"
				printf "Command: /usr/libexec/PlistBuddy -c \"Delete :'Window Settings':'$profile_name'\" \"$terminal_plist\"\n"
			fi
			/usr/libexec/PlistBuddy -c "Delete :'Window Settings':'$profile_name'" "$terminal_plist"
			ANY_CHANGES_MADE=true
		else
			pretty_success "Terminal profile '$profile_name' already installed. Skipping..."
			return
		fi
	else
		pretty_info "Installing terminal profile '$profile_name'..."
	fi

	if $VERBOSE; then
		pretty_info "Opening profile file $profile_file to import"
		printf "Command: open \"$profile_file\"\n"
	fi
	open "$profile_file"

	local max_wait=20
	local interval=0.25
	local attempts=$(awk "BEGIN {print int(${max_wait} / ${interval})}")

	for ((i = 1; i <= attempts; i++)); do
		if /usr/libexec/PlistBuddy -c "Print :'Window Settings':'$profile_name'" "$terminal_plist" &>/dev/null; then
			pretty_success "Terminal profile '${profile_name}' imported successfully."
			ANY_CHANGES_MADE=true
			break
		fi
		sleep "$interval"
	done

	if (( i > attempts )); then
		pretty_error "Terminal profile ${profile_name} could not be imported, attempt timed out."
		return
	fi

	osascript <<EOF
tell application "Terminal"
	try
		close (every window whose name of current settings is "$profile_name")
		set font name of settings set "$profile_name" to "$desired_font"
		set font size of settings set "$profile_name" to $desired_font_size
	end try
end tell
EOF
}

function set_terminal_profile_as_default() {
	local profile_name="Coolnight"
	local current_default=$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null)
	local current_startup=$(defaults read com.apple.Terminal "Startup Window Settings" 2>/dev/null)

	local already_default=false
	local already_startup=false

	print_newline
	pretty_info "Checking default terminal profile:"

	if [[ "$current_default" == "$profile_name" ]]; then
		already_default=true
	fi

	if [[ "$current_startup" == "$profile_name" ]]; then
		already_startup=true
	fi

	if $DRY_RUN; then
		if $already_default && $already_startup; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would unset and reset terminal profile '$profile_name' as both default and startup window settings verbosely"
				else
					pretty_info "[Dry Run] Would unset and reset terminal profile '$profile_name' as both default and startup window settings"
				fi
			else
				pretty_info "[Dry Run] Terminal profile '$profile_name' already set as default and startup window profile. Would skip"
			fi
		else
			if ! $already_default && ! $already_startup; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would set terminal profile '$profile_name' as both default and startup window settings verbosely"
				else
					pretty_info "[Dry Run] Would set terminal profile '$profile_name' as both default and startup window settings"
				fi
			elif ! $already_default; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would set terminal profile '$profile_name' as default window settings verbosely"
				else
					pretty_info "[Dry Run] Would set terminal profile '$profile_name' as default window settings"
				fi
			elif ! $already_startup; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would set terminal profile '$profile_name' as startup window settings verbosely"
				else
					pretty_info "[Dry Run] Would set terminal profile '$profile_name' as startup window settings"
				fi
			fi
		fi

		print_newline
		pretty_info "Dry run complete. No changes were made."
		return
	fi

	if $already_default && $already_startup; then
		if $FORCE_REINSTALL; then
			pretty_info "Unsetting and resetting terminal profile '$profile_name' as both default and startup window settings..."
			if $VERBOSE; then
				pretty_info "Removing existing profile '$profile_name' from default and startup window settings"
				printf "Command: defaults delete com.apple.Terminal 'Default Window Settings'\n"
				printf "Command: defaults delete com.apple.Terminal 'Startup Window Settings'\n"
			fi
			defaults delete com.apple.Terminal "Default Window Settings" 2>/dev/null || true
			defaults delete com.apple.Terminal "Startup Window Settings" 2>/dev/null || true
			ANY_CHANGES_MADE=true
		else
			pretty_success "Terminal profile '$profile_name' already set as default and startup window profile. Skipping..."
			return
		fi
	fi

	if ! $already_default && ! $already_startup; then
		pretty_info "Setting terminal profile '$profile_name' as both default and startup window settings..."
		if $VERBOSE; then
			printf "Command: defaults write com.apple.Terminal 'Default Window Settings' -string '$profile_name'\n"
			printf "Command: defaults write com.apple.Terminal 'Startup Window Settings' -string '$profile_name'\n"
		fi
		defaults write com.apple.Terminal "Default Window Settings" -string "$profile_name"
		defaults write com.apple.Terminal "Startup Window Settings" -string "$profile_name"
		pretty_success "Terminal profile '$profile_name' set as both default and startup window settings successfully."
		ANY_CHANGES_MADE=true
	elif ! $already_default; then
		pretty_info "Setting terminal profile '$profile_name' as default window settings..."
		if $VERBOSE; then
			printf "Command: defaults write com.apple.Terminal 'Default Window Settings' -string '$profile_name'\n"
		fi
		defaults write com.apple.Terminal "Default Window Settings" -string "$profile_name"
		pretty_success "Terminal profile '$profile_name' set as default window setting successfully."
		ANY_CHANGES_MADE=true
	elif ! $already_startup; then
		pretty_info "Setting terminal profile '$profile_name' as startup window settings..."
		if $VERBOSE; then
			printf "Command: defaults write com.apple.Terminal 'Startup Window Settings' -string '$profile_name'\n"
		fi
		defaults write com.apple.Terminal "Startup Window Settings" -string "$profile_name"
		pretty_success "Terminal profile '$profile_name' set as startup window setting successfully."
		ANY_CHANGES_MADE=true
	fi
}

function backup_dotfiles() {
	print_newline
	pretty_info "Backing up existing dotfiles:"
	local dotfiles_dir="$HOME/settings/macos/dotfiles"
	local backup_dir="$HOME/dotfiles_baks"
	local any_backed_up=false

	local files=()
	while IFS= read -r -d $'\0' file; do
		files+=("$file")
	done < <(find "$dotfiles_dir" -type f \( -name ".*" -o -path "*/.config/*" \) -print0)

	local total=${#files[@]}
	local current=1

	for file in "${files[@]}"; do
		local target="${file#$dotfiles_dir/}"
		local dotfile="$HOME/$target"
		local backup_path="$backup_dir/$target"
		local target_dir="$(dirname "$backup_path")"

		print_newline
		pretty_info "File $current of $total: Processing %s..." "$target"
		((current++))

		if $DRY_RUN; then
			if [[ -e "$backup_path" && $FORCE_REINSTALL == false ]]; then
				pretty_info "[Dry Run] %s already backed up. Would skip" "$target"
			elif [[ -L "$dotfile" ]]; then
				pretty_info "[Dry Run] %s is a symlink. Would skip" "$target"
			elif [[ ! -e "$dotfile" ]]; then
				pretty_info "[Dry Run] No existing %s found to back up. Would skip" "$target"
			elif [[ -e "$backup_path" && $FORCE_REINSTALL == true ]]; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would overwrite backup of %s at %s verbosely" "$target" "$backup_path"
				else
					pretty_info "[Dry Run] Would overwrite backup of %s at %s" "$target" "$backup_path"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would move %s to %s verbosely" "$dotfile" "$backup_path"
				else
					pretty_info "[Dry Run] Would move %s to %s" "$dotfile" "$backup_path"
				fi
			fi
			continue
		fi

		if [[ -e "$backup_path" && $FORCE_REINSTALL == false ]]; then
			pretty_success "%s already backed up. Skipping..." "$target"
			continue
		elif [[ -L "$dotfile" ]]; then
			pretty_info "%s is a symlink. Skipping..." "$target"
			continue
		elif [[ ! -e "$dotfile" ]]; then
			pretty_info "No existing %s found to back up. Skipping..." "$target"
			continue
		fi

		mkdir -p "$target_dir"

		if $VERBOSE; then
			if [[ -e "$backup_path" && $FORCE_REINSTALL == true ]]; then
				pretty_info "Overwriting backup of %s at %s" "$target" "$backup_path"
			else
				pretty_info "Moving %s to %s" "$dotfile" "$backup_path"
			fi
			printf "Command: mv \"%s\" \"%s\"\n" "$dotfile" "$backup_path"
		fi

		mv "$dotfile" "$backup_path"
		pretty_success "Backed up %s to %s" "$target" "$backup_path"
		any_backed_up=true
		ANY_CHANGES_MADE=true
	done

	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_backed_up; then
		pretty_success "All dotfiles backed up successfully!"
	else
		pretty_info "No dotfiles needed to be backed up."
	fi
}

function link_dotfiles() {
	print_newline
	pretty_info "Linking dotfiles:"
	local dotfiles_dir="$HOME/settings/macos/dotfiles"
	local any_linked=false

	local files=()
	while IFS= read -r -d $'\0' file; do
		files+=("$file")
	done < <(find "$dotfiles_dir" -type f \( -name ".*" -o -path "*/.config/*" \) -print0)
	
	local total=${#files[@]}
	local current=1

	for file in "${files[@]}"; do
		local target="${file#$dotfiles_dir/}"
		local dotfile="$HOME/$target"
		local target_dir="$HOME/$(dirname "$target")"

		print_newline
		pretty_info "File $current of $total: Processing %s..." "$target"
		((current++))

		if $DRY_RUN; then
			if [[ -L "$dotfile" && "$(readlink "$dotfile")" == "$file" ]]; then
				if $FORCE_REINSTALL; then
					if $VERBOSE; then
						pretty_info "[Dry Run] Would relink %s -> %s verbosely" "$dotfile" "$file"
					else
						pretty_info "[Dry Run] Would relink %s -> %s" "$dotfile" "$file"
					fi
				else
					pretty_info "[Dry Run] %s already linked. Would skip" "$target"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would link %s -> %s verbosely" "$dotfile" "$file"
				else
					pretty_info "[Dry Run] Would link %s -> %s" "$dotfile" "$file"
				fi
			fi
			continue
		fi

		mkdir -p "$target_dir"

		if [[ -L "$dotfile" && "$(readlink "$dotfile")" == "$file" ]]; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "Relinking %s -> %s" "$dotfile" "$file"
					printf "Command: ln -sf \"%s\" \"%s\"\n" "$file" "$dotfile"
				fi
				ln -sf "$file" "$dotfile"
				pretty_success "%s relinked successfully" "$target"
				any_linked=true
				ANY_CHANGES_MADE=true
			else
				pretty_success "%s already linked. Skipping..." "$target"
			fi
			continue
		fi

		if $FORCE_REINSTALL; then
			pretty_info "Relinking %s..." "$target"
		else
			pretty_info "Linking %s..." "$target"
		fi

		if $VERBOSE; then
			pretty_info "Linking %s -> %s" "$dotfile" "$file"
			printf "Command: ln -sf \"%s\" \"%s\"\n" "$file" "$dotfile"
		fi

		ln -sf "$file" "$dotfile"
		if [[ $? -eq 0 ]]; then
			pretty_success "%s linked successfully" "$target"
			any_linked=true
			ANY_CHANGES_MADE=true
		else
			pretty_error "Failed to link %s" "$target"
		fi
	done

	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_linked; then
		pretty_success "All dotfiles linked successfully!"
	else
		pretty_info "No dotfiles needed to be linked."
	fi
}

function main() {
	install_homebrew
	install_homebrew_packages
	install_vim_plugins
 	install_omz
	manage_etc_shells
	set_zsh_as_default
	install_custom_omz_themes
	install_custom_omz_plugins
	install_meslo_nerd_fonts
	import_terminal_profile
	set_terminal_profile_as_default
	backup_dotfiles
	link_dotfiles

	if $ANY_CHANGES_MADE; then
		print_newline
		pretty_success "Setup complete!"
		print_newline
		pretty_warn "Some changes require Terminal to be restarted to take effect."
		print_newline
		pretty_info "To ensure all changes properly take effect:"
		print_newline
		pretty_info "1. Close all open Terminal windows manually"
		pretty_info "2. Quit the Terminal app"
		pretty_info "3. Reopen the Terminal app"
	else
		print_newline
		pretty_info "No changes were made."
	fi
}

parse_flags "$@"
request_sudo_upfront
main
