# Load Homebrew
/opt/homebrew/bin/brew &>/dev/null && eval "$(/opt/homebrew/bin/brew shellenv)"

# Ensure Homebrew packages are preferred over system defaults
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

# Add JetBrains Toolbox scripts
export PATH="$PATH:$HOME/Library/Application Support/JetBrains/Toolbox/scripts"

# Setting PATH for Python
if [[ -d /Library/Frameworks/Python.framework/Versions/3.11/bin ]]; then
	export PATH="/Library/Frameworks/Python.framework/Versions/3.11/bin:$PATH"
elif [[ -d /Library/Frameworks/Python.framework/Versions/3.9/bin ]]; then
	export PATH="/Library/Frameworks/Python.framework/Versions/3.9/bin:$PATH"
fi
