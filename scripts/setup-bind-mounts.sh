#!/bin/bash

# Auto-detect environment and configure bind mounts
setup_bind_mounts() {
    echo "Setting up environment-specific bind mounts..."
    
    # Detect if we're in WSL
    if grep -qi microsoft /proc/version 2>/dev/null || [[ -n "$WSL_DISTRO_NAME" ]]; then
        echo "WSL environment detected"
        # Use absolute WSL paths
        export COMPOSE_PROJECT_DIR="/mnt/$(echo $PWD | cut -d'/' -f2-3 | tr '[:upper:]' '[:lower:]')/$(basename $PWD)/app"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux environment detected"
        # Use relative paths
        export COMPOSE_PROJECT_DIR="./app"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS environment detected"
        # Use relative paths
        export COMPOSE_PROJECT_DIR="./app"
    else
        echo "Unknown environment, using relative paths"
        export COMPOSE_PROJECT_DIR="./app"
    fi
    
    echo "COMPOSE_PROJECT_DIR set to: $COMPOSE_PROJECT_DIR"
}

# Check if Laravel app directory exists
check_app_directory() {
    if [[ ! -d "./app" ]]; then
        echo "Laravel app directory not found. Please run 'make clone' first."
        exit 1
    fi
    
    if [[ ! -f "./app/artisan" ]]; then
        echo "Laravel application not found in ./app/ directory."
        echo "Please ensure the Laravel app is properly cloned."
        exit 1
    fi
}

# Main execution
main() {
    check_app_directory
    setup_bind_mounts
    
    # Create .env.local with the detected configuration
    cat > .env.local << EOF
# Auto-generated environment configuration
COMPOSE_PROJECT_DIR=$COMPOSE_PROJECT_DIR
EOF
    
    echo "Environment configuration complete!"
    echo "You can now run: docker-compose up -d"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi