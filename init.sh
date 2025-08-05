# !/bin/bash
#
# Description: This script automates the setup of a powerful Zsh environment,
#              including Oh My Zsh, essential plugins, and a user-specified Miniforge installation.
#
# Usage:
# Run the script:
#    bash init.sh
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

check_dependencies() {
    echo -e "${BLUE}---> Checking dependencies...${NC}"
    local deps=("git" "curl" "zsh")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${YELLOW}Error: Required dependency '$dep' is not installed.${NC}" >&2
            exit 1
        fi
    done
    echo -e "${GREEN}All dependencies are satisfied.${NC}"
}

install_oh_my_zsh() {
    echo -e "${BLUE}---> Installing Oh My Zsh...${NC}"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo -e "${YELLOW}Oh My Zsh is already installed. Skipping.${NC}"
    else
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended
        echo -e "${GREEN}Oh My Zsh installed successfully.${NC}"
    fi
}

install_zsh_plugins() {
    local ZSH_CUSTOM_PLUGINS="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    
    echo -e "${BLUE}---> Installing Zsh plugins...${NC}"
    # zsh-autosuggestions
    if [ ! -d "${ZSH_CUSTOM_PLUGINS}/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM_PLUGINS}/zsh-autosuggestions"
    else
        echo -e "${YELLOW}zsh-autosuggestions already installed. Skipping.${NC}"
    fi

    # zsh-syntax-highlighting
    if [ ! -d "${ZSH_CUSTOM_PLUGINS}/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM_PLUGINS}/zsh-syntax-highlighting"
    else
        echo -e "${YELLOW}zsh-syntax-highlighting already installed. Skipping.${NC}"
    fi
    echo -e "${GREEN}Zsh plugins installed.${NC}"
}

install_autojump() {
    echo -e "${BLUE}---> Installing autojump...${NC}"
    if command -v "autojump" &> /dev/null; then
        echo -e "${YELLOW}autojump appears to be already installed. Skipping.${NC}"
    else
        local temp_dir
        temp_dir=$(mktemp -d)
        git clone https://github.com/wting/autojump.git "$temp_dir"
        cd "$temp_dir"
        python3 ./install.py
        cd "$HOME"
        rm -rf "$temp_dir"
        echo -e "${GREEN}autojump installed.${NC}"
    fi
}

install_fzf() {
    echo -e "${BLUE}---> Installing fzf (Fuzzy Finder)...${NC}"
    if [ -d "$HOME/.fzf" ]; then
        echo -e "${YELLOW}fzf already installed. Skipping.${NC}"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
        echo -e "${GREEN}fzf installed.${NC}"
    fi
}

install_miniforge() {
    local install_path="$1"
    if [ -z "$install_path" ]; then
        echo -e "${YELLOW}Error: Miniforge installation path not provided.${NC}" >&2
        return 1
    fi
    
    echo -e "${BLUE}---> Installing Miniforge3 to '$install_path'...${NC}"
    if [ -d "$install_path" ]; then
        echo -e "${YELLOW}Directory '$install_path' already exists. Skipping installation.${NC}"
    else
        local MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
        local INSTALLER_SCRIPT="Miniforge3-Installer.sh"
        
        echo "Downloading from $MINIFORGE_URL"
        curl -L -o "$INSTALLER_SCRIPT" "$MINIFORGE_URL"
        
        bash "$INSTALLER_SCRIPT" -b -p "$install_path"
        
        rm "$INSTALLER_SCRIPT"
        echo -e "${GREEN}Miniforge3 installed successfully.${NC}"
    fi
}

configure_zshrc() {
    local miniforge_path="$1"
    if [ -z "$miniforge_path" ]; then
        echo -e "${YELLOW}Error: Miniforge path not provided for .zshrc configuration.${NC}" >&2
        return 1
    fi

    echo -e "${BLUE}---> Configuring ~/.zshrc...${NC}"
    local ZSHRC_FILE="$HOME/.zshrc"

    if [ ! -f "$ZSHRC_FILE" ]; then
        echo -e "${YELLOW}.zshrc not found. It will be created by Oh My Zsh.${NC}"
        return
    fi
    
    cp "$ZSHRC_FILE" "${ZSHRC_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    echo "Backup of .zshrc created."
    
    local PLUGINS="git autojump fzf zsh-autosuggestions zsh-syntax-highlighting"
    sed -i -E "s/^plugins=\(.*\)$/plugins=($PLUGINS)/" "$ZSHRC_FILE"
    echo "Plugins updated in .zshrc."

    local AUTJUMP_LINE='[[ -s "$HOME/.autojump/etc/profile.d/autojump.sh" ]] && . "$HOME/.autojump/etc/profile.d/autojump.sh"'
    if ! grep -q "autojump.sh" "$ZSHRC_FILE"; then
      echo -e "\n# Load autojump" >> "$ZSHRC_FILE"
      echo "$AUTJUMP_LINE" >> "$ZSHRC_FILE"
      echo "Autojump configuration added."
    fi

    if [ -f "$miniforge_path/bin/conda" ]; then
        echo "Initializing conda for Zsh..."
        "$miniforge_path/bin/conda" init zsh
        echo "Conda for Zsh initialized."
    fi
    
    echo -e "${GREEN}.zshrc configuration complete.${NC}"
}

main() {
    check_dependencies
    
    install_oh_my_zsh
    install_zsh_plugins
    install_autojump
    install_fzf
    
    echo -e "-----------------------------------------------------"
    echo -e "${BLUE}Miniforge Installation Path Setup${NC}"
    echo "To avoid taking up too much space in the home directory, you can specify a custom installation path."
    echo ""
    echo "Current disk usage:"
    df -hT
    echo ""
    
    local DEFAULT_PATH="$HOME/miniforge3"
    read -p "Enter installation path for Miniforge [default: ${DEFAULT_PATH}]: " MINIFORGE_PATH
    
    MINIFORGE_PATH=${MINIFORGE_PATH:-"$DEFAULT_PATH"}
    
    MINIFORGE_PATH="${MINIFORGE_PATH/#\~/$HOME}"
    
    mkdir -p "$(dirname "$MINIFORGE_PATH")"

    echo -e "${GREEN}Miniforge will be installed in: ${MINIFORGE_PATH}${NC}"
    echo -e "-----------------------------------------------------"

    install_miniforge "$MINIFORGE_PATH"
    configure_zshrc "$MINIFORGE_PATH"

    echo -e "\n${GREEN}🚀 All installations and configurations are complete!${NC}"
    echo -e "${YELLOW}Please start a new terminal session or run 'exec zsh' to apply all changes.${NC}"
}

main