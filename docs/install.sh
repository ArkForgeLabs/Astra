#!/bin/bash

# Astra Installer Script
# Downloads the specified version of Astra and installs it to /usr/bin
# Supported runtimes: luajit, luajit52, luau, lua51, lua52, lua53, lua54
# Default runtime: luajit

set -e  # Exit on any error

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -r, --runtime RUNTIME    Specify runtime (luajit, luajit52, luau, lua51, lua52, lua53, lua54)"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Default runtime is luajit"
    exit 1
}

# Function to display runtime selection menu
select_runtime() {
    echo "Please select a runtime for Astra:"
    echo "1) luajit (default)"
    echo "2) luajit52"
    echo "3) luau"
    echo "4) lua51"
    echo "5) lua52"
    echo "6) lua53"
    echo "7) lua54"
    echo ""
    read -p "Enter your choice (1-7) [1]: " choice
    choice=${choice:-1}
    
    case $choice in
        1) RUNTIME="luajit" ;;
        2) RUNTIME="luajit52" ;;
        3) RUNTIME="luau" ;;
        4) RUNTIME="lua51" ;;
        5) RUNTIME="lua52" ;;
        6) RUNTIME="lua53" ;;
        7) RUNTIME="lua54" ;;
        *) 
            echo "Invalid choice. Using default luajit."
            RUNTIME="luajit"
            ;;
    esac
}

# Default runtime
RUNTIME="luajit"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--runtime)
            RUNTIME="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# If no runtime was specified via command line, prompt user
# Check if we're using the default value and no arguments were provided
if [[ "$RUNTIME" == "luajit" ]] && [[ $# -eq 0 ]]; then
    select_runtime
fi

# Validate runtime
VALID_RUNTIMES=("luajit" "luajit52" "luau" "lua51" "lua52" "lua53" "lua54")
VALID=false
for valid_runtime in "${VALID_RUNTIMES[@]}"; do
    if [[ "$RUNTIME" == "$valid_runtime" ]]; then
        VALID=true
        break
    fi
done

if [[ "$VALID" == false ]]; then
    echo "Error: Invalid runtime '$RUNTIME'. Valid runtimes are: ${VALID_RUNTIMES[*]}"
    exit 1
fi

# Configuration
DOWNLOAD_URL="https://github.com/ArkForgeLabs/Astra/releases/latest/download/astra-${RUNTIME}-linux-amd64"
INSTALL_PATH="/usr/bin/astra"
TEMP_FILE="/tmp/astra-${RUNTIME}-linux-amd64"

echo "Downloading Astra ${RUNTIME} binary..."
echo "Runtime selected: ${RUNTIME}"

# Download the binary
if ! wget -O "$TEMP_FILE" "$DOWNLOAD_URL"; then
    echo "Error: Failed to download Astra binary"
    exit 1
fi

# Make it executable
if ! chmod +x "$TEMP_FILE"; then
    echo "Error: Failed to make binary executable"
    exit 1
fi

# Install to /usr/bin
echo "Moving the binary to $INSTALL_PATH..."
if ! sudo mv "$TEMP_FILE" "$INSTALL_PATH"; then
    echo "Error: Failed to move binary to $INSTALL_PATH"
    exit 1
fi

echo "Astra ${RUNTIME} has been successfully installed to $INSTALL_PATH"
echo "You can now run 'astra' from anywhere in your terminal"