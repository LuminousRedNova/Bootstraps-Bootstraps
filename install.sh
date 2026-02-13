#!/bin/zsh

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Exit if non zero status returned
set -e

echo "This script requires administrative priveleges."
echo "Please enter your password below..."

sudo -v

echo "Beginning development environment setup!"

# Installing xcode-select
if ! xcode-select -p &>/dev/null; then
  echo "Installing xcode-select..."
  xcode-select --install

  sleep 1
  osascript -e 'tell application "System Events"' \
    -e 'tell process "Install Command Line Developer Tools"' \
    -e 'keystroke return' \
    -e 'click button "Agree" of window "License Agreement"' \
    -e 'end tell' \
    -e 'end tell'

  echo "Waiting for Xcode command lines tools to install..."
  while ! xcode-select -p $ >/dev/null; do sleep 10; done
  echo "Xcode CLI tools installed!"
else
  echo "Xcode command line tools already installed!"
fi

# Installing Homebrew
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo "Homebrew installed!"
else
  echo "Homebrew already installed. Updating..."
  brew update
fi

BREWFILE_PATH="$SCRIPT_DIR/Brewfile"
if [ -f "$BREWFILE_PATH" ]; then
  echo "Installing Brew Formulae..."
  brew bundle --file="$BREWFILE_PATH"
else
  echo "Brewfile not found! Skipping installation!"
fi

echo "Installing Nerdfonts..."
wget -O /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip
unzip /tmp/FiraCode.zip -d /tmp/FiraCode/
cp -n /tmp/FiraCode/*.ttf ~/Library/Fonts/
rm -rf /tmp/FiraCode.zip
rm -rf /tmp/FiraCode/
echo "Nerdfonts Installed!"

# Install Oh My ZSH
if ! command -v omz &>/dev/null; then
  echo "Installing Oh My ZSH..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  echo "OMZ installed!"
else
  echo "Oh My ZSH Already Installed"
fi

ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Installing Oh My ZSH Plugins
echo "Installing plugins..."
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  echo "Syntax Highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  echo "Auto Suggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  echo "Plugins downloaded!"
fi

echo "Configuring OMZ Plugins..."
awk '
!in_plugin && /^plugins=\(/{
  print "plugins=(\n git\n zsh-syntax-highlighting\n zsh-autosuggestions\n brew\n macos\n aws\n mvn\n gradle\n kubectl\n jfrog\n sdk\n)\n"
  in_plugin=1
}
in_plugin && /\)/{
  in_plugin=0
  next
}
!in_plugin { print }
' ~/.zshrc >~/.zshrc.tmp
echo "OMZ plugins configured!"

echo "Installing Spaceship Theme for OMZ..."
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
awk -v theme="spaceship" '/^ZSH_THEME=/ { $0 = "ZSH_THEME=\"" theme "\"" } { print }' ~/.zshrc.tmp >~/.zshrc.tmp2
echo "Spaceship theme installed!"

echo "Modifying zshrc file..."
cp ~/.zshrc ~/.zshrc.bk
mv ~/.zshrc.tmp2 ~/.zshrc
rm ~/.zshrc.tmp
echo "Zshrc modification complete!"

echo "Adding personal aliases..."
if ! grep -q "# --- Custom Aliases ---" ~/.zshrc; then
  cat <<'EOF' >>~/.zshrc

# --- Custom Aliases ---
alias c='clear'
alias gdc='git diff --cached'
alias hook='python3 ~/.commit-helper/prepare-commit-msg --install'
alias unhook='rm -rfv .git/hooks/prepare-commit-msg'
alias undocommit='git reset HEAD~1 --soft && git restore --staged .'
EOF
  echo "Aliases added!"
else
  echo "Aliases block already exists!"
fi

echo "Adding custom functions..."
if ! grep -q "# --- Custom Functions ---" ~/.zshrc; then
  cat <<'EOF' >>~/.zshrc

# --- Custom Functions ---
# Decoding JWT Token
# https://www.pgrs.net/2022/06/02/simple-command-line-function-to-decode-jwts/
jwt-decode() {
  jq -R 'split(".") |.[0:2] | map(gsub("-"; "+") | gsub("_"; "/") | gsub("%3D"; "=") | @base64d) | map(fromjson)' <<< $1
}
EOF
  echo "Functions added!"
else
  echo "Function block already exists"
fi

if ! command -v sdk &>/dev/null; then
  echo "Installing sdkman..."
  curl -s "https://get.sdkman.io?ci=true" | bash
  source "$HOME/.sdkman/bin/sdkman-init.sh"
else
  echo "SDKMan already installed!"
fi

echo "Installing Java Versions..."
yes | sdk install java 8.0.452-amzn
yes | sdk install java 21.0.7-tem

# Download and install nvm:
if ! command -v nvm &>/dev/null; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
  echo "NVM already installed!"
fi
