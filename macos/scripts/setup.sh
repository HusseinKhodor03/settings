#!/bin/bash

EXIT_SUCCESS=0
EXIT_FAILURE=1

ANY_CHANGES_MADE=false

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/flags.sh"

function install_homebrew() {
	pretty_info "Checking Homebrew installation:"

	local already_installed=false
	if command -v brew &>/dev/null 2>&1; then
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
		return
	fi

	if $already_installed && $FORCE_REINSTALL; then
		pretty_info "Reinstalling Homebrew..."
		if $VERBOSE; then
			/bin/bash -c "$(ctheme -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
		else
			/bin/bash -c "$(ctheme -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" >/dev/null 2>&1
		fi
		ANY_CHANGES_MADE=true
	elif $already_installed; then
		pretty_info "Homebrew already installed. Skipping..."
		return
	else
		pretty_info "Installing Homebrew..."
	fi

	if $VERBOSE; then
		/bin/bash -c "$(ctheme -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	else
		/bin/bash -c "$(ctheme -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
	fi
	ANY_CHANGES_MADE=true
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
				pretty_info "%s already installed. Skipping..." "$name"
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
			pretty_info "Oh My Zsh already installed. Skipping..."
			return
		fi
	else
		pretty_info "Installing Oh My Zsh..."
		ANY_CHANGES_MADE=true
	fi

	if $VERBOSE; then
		sh -c "$(ctheme -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	else
		sh -c "$(ctheme -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >/dev/null 2>&1
	fi
}

function set_zsh_as_default() {
	local zsh_path="$(command -v zsh)"
	local current_shell="$(dscl . -read "$HOME" UserShell | awk '{print $2}')"

	print_newline
	pretty_info "Checking default shell:"

	if $DRY_RUN; then
		if $FORCE_REINSTALL; then
			if $VERBOSE; then
				pretty_info "[Dry Run] Would remove and re-add %s to /etc/shells verbosely" "$zsh_path"
			else
				pretty_info "[Dry Run] Would remove and re-add %s to /etc/shells" "$zsh_path"
			fi
		elif ! grep -q "$zsh_path" /etc/shells; then
			if $VERBOSE; then
				pretty_info "[Dry Run] Would add %s to /etc/shells verbosely" "$zsh_path"
			else
				pretty_info "[Dry Run] Would add %s to /etc/shells" "$zsh_path"
			fi
		else
			pretty_info "[Dry Run] %s already in /etc/shells. Would skip" "$zsh_path"
		fi

		if [[ "$current_shell" != "$zsh_path" ]]; then
			if $VERBOSE; then
				pretty_info "[Dry Run] Would change default shell to %s verbosely" "$zsh_path"
			else
				pretty_info "[Dry Run] Would change default shell to %s" "$zsh_path"
			fi
		elif $FORCE_REINSTALL; then
			if $VERBOSE; then
				pretty_info "[Dry Run] Would re-set %s as the default shell verbosely" "$zsh_path"
			else
				pretty_info "[Dry Run] Would re-set %s as the default shell" "$zsh_path"
			fi
		else
			pretty_info "[Dry Run] %s already set to default shell. Would skip" "$zsh_path"
		fi

		return
	fi

	if $FORCE_REINSTALL && grep -q "$zsh_path" /etc/shells; then
		if $VERBOSE; then
			pretty_info "Removing %s from /etc/shells..." "$zsh_path"
			printf "Command: grep -vFx \"%s\" /etc/shells | sudo tee /etc/shells\n" "$zsh_path"
		fi
		grep -vFx "$zsh_path" /etc/shells | sudo tee /etc/shells >/dev/null
		ANY_CHANGES_MADE=true
	fi

	if ! grep -q "$zsh_path" /etc/shells; then
		if $VERBOSE; then
			pretty_info "Adding %s to /etc/shells..." "$zsh_path"
			printf "Command: printf \"%%s\\n\" \"%s\" | sudo tee -a /etc/shells\n" "$zsh_path"
		fi
		echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
		ANY_CHANGES_MADE=true
	else
		pretty_info "%s already in /etc/shells. Skipping..." "$zsh_path"
	fi

	if [[ "$current_shell" != "$zsh_path" ]]; then
		if $VERBOSE; then
			pretty_info "Changing default shell to %s..." "$zsh_path"
			printf "Command: chsh -s \"%s\"\n" "$zsh_path"
		fi
		chsh -s "$zsh_path"
		ANY_CHANGES_MADE=true
	else
		pretty_info "%s already set to default shell. Skipping..." "$zsh_path"
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
		local theme_dir="$themes_dir/$name"

		print_newline
		pretty_info "Theme $current of $total: Processing %s..." "$name"
		((current++))

		local already_installed=false
		if [[ -d "$theme_dir" ]]; then
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
					pretty_info "Removing %s from %s" "$name" "$theme_dir"
					printf "Command: rm -rf \"%s\"\n" "$theme_dir"
				fi
				rm -rf "$theme_dir"
				ANY_CHANGES_MADE=true
			else
				pretty_info "%s already installed. Skipping..." "$name"
				continue
			fi
		else
			pretty_info "Installing %s..." "$name"
		fi

		if $VERBOSE; then
			git clone --depth=1 "$theme" "$theme_dir"
		else
			git clone --depth=1 "$theme" "$theme_dir" >/dev/null 2>&1
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
				pretty_info "%s already installed. Skipping..." "$name"
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
				pretty_info "%s already installed. Skipping..." "$filename"
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

function backup_dotfiles() {
	print_newline
	pretty_info "Backing up existing dotfiles:"
	local dotfiles_dir="$HOME/settings/macos/dotfiles"
	local backup_dir="$HOME/dotfiles_baks"
	local any_backed_up=false

	mkdir -p "$backup_dir"

	local files=()
	while IFS= read -r -d $'\0' file; do
		files+=("$file")
	done < <(find "$dotfiles_dir" -type f \( -name ".*" -o -path "*/.config/*" \) -print0)

	local total=${#files[@]}
	local current=1

	for file in "${files[@]}"; do
		local target="${file#$dotfiles_dir/}"
		local theme_dir="$HOME/$target"
		local backup_path="$backup_dir/$target"
		local target_dir="$(dirname "$backup_path")"

		print_newline
		pretty_info "File $current of $total: Processing %s..." "$target"
		((current++))

		if $DRY_RUN; then
			if [[ ! -e "$theme_dir" || -L "$theme_dir" ]]; then
				pretty_info "[Dry Run] %s already backed up. Would skip" "$target"
			elif [[ -e "$backup_path" && ! $FORCE_REINSTALL ]]; then
				pretty_info "[Dry Run] %s already backed up. Would skip" "$target"
			elif [[ -e "$backup_path" && $FORCE_REINSTALL ]]; then
				if $VERBOSE; then
					pretty_info "[Dry Run] Would overwrite backup of %s at %s verbosely" "$target" "$backup_path"
				else
					pretty_info "[Dry Run] Would overwrite backup of %s at %s" "$target" "$backup_path"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would move %s to %s verbosely" "$theme_dir" "$backup_path"
				else
					pretty_info "[Dry Run] Would move %s to %s" "$theme_dir" "$backup_path"
				fi
			fi
			continue
		fi

		if [[ ! -e "$theme_dir" || -L "$theme_dir" ]]; then
			pretty_info "%s already backed up. Skipping..." "$target"
			continue
		elif [[ -e "$backup_path" && ! $FORCE_REINSTALL ]]; then
			pretty_info "%s already backed up. Skipping..." "$target"
			continue
		fi

		mkdir -p "$target_dir"

		if $VERBOSE; then
			if [[ -e "$backup_path" && $FORCE_REINSTALL ]]; then
				pretty_info "Overwriting backup of %s at %s" "$target" "$backup_path"
			else
				pretty_info "Moving %s to %s" "$theme_dir" "$backup_path"
			fi
			printf "Command: mv \"%s\" \"%s\"\n" "$theme_dir" "$backup_path"
		fi

		mv "$theme_dir" "$backup_path"
		pretty_success "Backed up %s to %s" "$target" "$backup_path"
		any_backed_up=true
		ANY_CHANGES_MADE=true
	done

	print_newline
	if $DRY_RUN; then
		pretty_info "Dry run complete. No changes were made."
	elif $any_backed_up; then
		print_newline
		pretty_success "All dotfiles backed up successfully!"
	else
		print_newline
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
		local theme_dir="$HOME/$target"
		local target_dir="$HOME/$(dirname "$target")"

		print_newline
		pretty_info "File $current of $total: Processing %s..." "$target"
		((current++))

		if $DRY_RUN; then
			if [[ -L "$theme_dir" && "$(readlink "$theme_dir")" == "$file" ]]; then
				if $FORCE_REINSTALL; then
					if $VERBOSE; then
						pretty_info "[Dry Run] Would relink %s -> %s verbosely" "$theme_dir" "$file"
					else
						pretty_info "[Dry Run] Would relink %s -> %s" "$theme_dir" "$file"
					fi
				else
					pretty_info "[Dry Run] %s already linked. Would skip" "$target"
				fi
			else
				if $VERBOSE; then
					pretty_info "[Dry Run] Would link %s -> %s verbosely" "$theme_dir" "$file"
				else
					pretty_info "[Dry Run] Would link %s -> %s" "$theme_dir" "$file"
				fi
			fi
			continue
		fi

		mkdir -p "$target_dir"

		if [[ -L "$theme_dir" && "$(readlink "$theme_dir")" == "$file" ]]; then
			if $FORCE_REINSTALL; then
				if $VERBOSE; then
					pretty_info "Relinking %s -> %s" "$theme_dir" "$file"
					printf "Command: ln -sf \"%s\" \"%s\"\n" "$file" "$theme_dir"
				fi
				ln -sf "$file" "$theme_dir"
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
			pretty_info "Linking %s -> %s" "$theme_dir" "$file"
			printf "Command: ln -sf \"%s\" \"%s\"\n" "$file" "$theme_dir"
		fi

		ln -sf "$file" "$theme_dir"
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
	set_zsh_as_default
	install_custom_omz_themes
	install_custom_omz_plugins
	install_meslo_nerd_fonts
	backup_dotfiles
	link_dotfiles

	if $ANY_CHANGES_MADE; then
		print_newline
		pretty_success "Setup complete!"
		pretty_info "Changes were made. Restart your terminal by running 'exec zsh' for changes to take effect."
	else
		print_newline
		pretty_info "No changes were made."
	fi
}

parse_flags "$@"
main