#!/bin/bash
# OCPAZ Login Helper Script
# This script helps with OCPAZ cluster authentication

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if already logged into OCPAZ
check_current_login() {
    if oc whoami --show-server 2>/dev/null | grep -q "ocpaz.kohlerco.com"; then
        print_success "Already logged into OCPAZ cluster"
        print_info "Current user: $(oc whoami)"
        print_info "Server: $(oc whoami --show-server)"
        return 0
    else
        return 1
    fi
}

# Login using bash profile
login_with_profile() {
    print_section "LOGGING INTO OCPAZ CLUSTER"
    
    print_info "Attempting to use bash profile 'ocpaz'..."
    
    # Source bash profile if it exists
    if [[ -f ~/.bash_profile ]]; then
        print_info "Sourcing ~/.bash_profile..."
        source ~/.bash_profile
    fi
    
    # Try to login using profile
    if oc login https://api.ocpaz.kohlerco.com:6443 --insecure-skip-tls-verify 2>/dev/null; then
        print_success "Login successful using profile"
        return 0
    else
        return 1
    fi
}

# Token-based login
login_with_token() {
    print_section "TOKEN-BASED LOGIN"
    
    print_warning "Interactive login failed. Using token-based authentication."
    print_info "Please follow these steps:"
    echo ""
    echo -e "${YELLOW}1. Open your browser and go to:${NC}"
    echo -e "${BLUE}   https://oauth-openshift.apps.ocpaz.kohlerco.com/oauth/token/request${NC}"
    echo ""
    echo -e "${YELLOW}2. Click 'Request another token'${NC}"
    echo -e "${YELLOW}3. Copy the 'oc login' command shown${NC}"
    echo -e "${YELLOW}4. Paste it below when prompted${NC}"
    echo ""
    
    read -p "Enter the oc login command: " login_command
    
    if [[ -z "$login_command" ]]; then
        print_error "No login command provided"
        return 1
    fi
    
    # Execute the login command
    if eval "$login_command"; then
        print_success "Token-based login successful"
        return 0
    else
        print_error "Token-based login failed"
        return 1
    fi
}

# Main login function
main() {
    print_section "OCPAZ CLUSTER LOGIN HELPER"
    
    # Check if already logged in
    if check_current_login; then
        exit 0
    fi
    
    # Try login with profile first
    if login_with_profile; then
        print_success "Successfully logged into OCPAZ cluster using profile"
    else
        print_warning "Profile-based login failed, trying token-based login..."
        if login_with_token; then
            print_success "Successfully logged into OCPAZ cluster using token"
        else
            print_error "All login methods failed"
            echo ""
            echo -e "${YELLOW}Manual login options:${NC}"
            echo -e "${BLUE}1. Use token from: https://oauth-openshift.apps.ocpaz.kohlerco.com/oauth/token/request${NC}"
            echo -e "${BLUE}2. Set up bash profile 'ocpaz' with credentials${NC}"
            echo -e "${BLUE}3. Use oc login --token=<your-token> --server=https://api.ocpaz.kohlerco.com:6443${NC}"
            exit 1
        fi
    fi
    
    # Verify final login status
    print_section "LOGIN VERIFICATION"
    print_info "Current user: $(oc whoami)"
    print_info "Server: $(oc whoami --show-server)"
    print_info "Token expires: $(oc whoami --show-token | cut -c1-20)..."
    
    # Check for mulesoftapps-prod namespace
    if oc get namespace mulesoftapps-prod &>/dev/null; then
        print_success "✅ mulesoftapps-prod namespace found"
    else
        print_warning "⚠️ mulesoftapps-prod namespace not found"
        print_info "Available namespaces with 'mule' or 'apps':"
        oc get namespaces | grep -E "(mule|apps)" || echo "No matching namespaces found"
    fi
    
    print_success "🎉 Ready to run migration script!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
