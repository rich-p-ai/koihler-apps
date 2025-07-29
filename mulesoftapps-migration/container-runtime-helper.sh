#!/bin/bash
# Container Runtime Helper Script
# Automatically selects the best available container runtime

get_container_tool() {
    # Check for working Podman
    if command -v podman &> /dev/null; then
        if podman system connection list | grep -q "Default.*true" 2>/dev/null; then
            echo "podman"
            return 0
        fi
    fi
    
    # Check for working Docker
    if command -v docker &> /dev/null; then
        if docker info &>/dev/null 2>&1; then
            echo "docker"
            return 0
        fi
    fi
    
    # No working runtime found
    echo "none"
    return 1
}

# Export the function for use in other scripts
export -f get_container_tool

# If script is run directly, show the current runtime
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    runtime=$(get_container_tool)
    if [[ "$runtime" == "none" ]]; then
        echo "ERROR: No working container runtime found"
        exit 1
    else
        echo "Available container runtime: $runtime"
        $runtime --version
    fi
fi
