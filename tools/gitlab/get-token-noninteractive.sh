#!/bin/bash
#
# Non-interactive GitLab Token Getter
# Securely retrieves GitLab token from environment or config file
#

# Security settings
set -euo pipefail
umask 077

# Configuration
ENV_FILE=".env.gitlab.local"
CLAUDE_SETTINGS=".claude/settings.local.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Get token from environment
get_token_from_env() {
    if [ -n "${GITLAB_PRIVATE_TOKEN:-}" ]; then
        echo "$GITLAB_PRIVATE_TOKEN"
        return 0
    fi
    return 1
}

# Get token from local environment file
get_token_from_file() {
    if [ -f "$ENV_FILE" ]; then
        # Source the file in a subshell to avoid polluting current environment
        local token=$(bash -c "source '$ENV_FILE' 2>/dev/null && echo \"\$GITLAB_PRIVATE_TOKEN\"")
        if [ -n "$token" ] && [ "$token" != "undefined" ]; then
            echo "$token"
            return 0
        fi
    fi
    return 1
}

# Validate token format
validate_token() {
    local token="$1"
    # GitLab tokens are typically 20+ characters, alphanumeric with dashes/underscores
    if [[ ${#token} -ge 20 && "$token" =~ ^[A-Za-z0-9_-]+$ ]]; then
        return 0
    fi
    return 1
}

# Test token with GitLab API
test_token() {
    local token="$1"
    local gitlab_url="${GITLAB_API_URL:-https://git.mpi-cbg.de/api/v4}"
    
    # Test with user endpoint (lightweight)
    local response=$(curl -s -w "%{http_code}" \
        --max-time 10 \
        --header "PRIVATE-TOKEN: $token" \
        "$gitlab_url/user" 2>/dev/null)
    
    local http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" = "200" ]; then
        return 0
    fi
    return 1
}

# Main token retrieval function
get_gitlab_token() {
    local token=""
    local source=""
    
    # Try environment variable first
    if token=$(get_token_from_env); then
        source="environment variable"
        log_info "Token found in $source"
    # Try local file
    elif token=$(get_token_from_file); then
        source="local config file"
        log_info "Token found in $source"
    else
        log_error "No GitLab token found"
        log_info "Set GITLAB_PRIVATE_TOKEN environment variable or create $ENV_FILE"
        return 1
    fi
    
    # Validate token format
    if ! validate_token "$token"; then
        log_error "Invalid token format from $source"
        return 1
    fi
    
    # Test token if requested
    if [ "${1:-}" = "--test" ]; then
        log_info "Testing token validity..."
        if test_token "$token"; then
            log_success "Token is valid and working"
        else
            log_error "Token authentication failed"
            return 1
        fi
    fi
    
    # Output token (this goes to stdout, logs go to stderr)
    echo "$token"
    return 0
}

# Show usage
show_usage() {
    cat >&2 <<EOF
Usage: $0 [--test] [--help]

Securely retrieves GitLab private token from environment or config file.

Options:
  --test    Test token validity with GitLab API
  --help    Show this help message

Token Sources (in order of priority):
  1. GITLAB_PRIVATE_TOKEN environment variable
  2. $ENV_FILE file

Security Notes:
  - Token is only output to stdout for script consumption
  - All diagnostic messages go to stderr
  - File permissions are checked for security
  - Token format is validated before use

EOF
}

# Check file security
check_file_security() {
    if [ -f "$ENV_FILE" ]; then
        local perms=$(stat -f "%A" "$ENV_FILE" 2>/dev/null || stat -c "%a" "$ENV_FILE" 2>/dev/null)
        if [ "$perms" != "600" ]; then
            log_warning "Insecure permissions on $ENV_FILE (should be 600)"
            log_info "Run: chmod 600 $ENV_FILE"
        fi
    fi
}

# Main execution
main() {
    case "${1:-}" in
        "--help"|"-h")
            show_usage
            exit 0
            ;;
        "--test")
            check_file_security
            get_gitlab_token --test
            ;;
        "")
            check_file_security
            get_gitlab_token
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi