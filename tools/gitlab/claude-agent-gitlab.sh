#!/bin/bash
#
# GitLab Agent for Claude Code Integration
# Provides GitLab API integration for issue management and project automation
#

# Configuration - will be loaded from environment
GITLAB_PROJECT_ID="${GITLAB_PROJECT_ID:-2854}"
GITLAB_API_URL="${GITLAB_API_URL:-https://git.mpi-cbg.de/api/v4}"
GITLAB_PRIVATE_TOKEN="${GITLAB_PRIVATE_TOKEN:-}"

# Load environment if available
if [ -f ".env.gitlab.local" ]; then
    source .env.gitlab.local
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check configuration
check_config() {
    if [ -z "$GITLAB_PRIVATE_TOKEN" ]; then
        log_error "GITLAB_PRIVATE_TOKEN not set"
        echo "Please set your GitLab token in .env.gitlab.local or as environment variable"
        return 1
    fi
    
    if [ -z "$GITLAB_PROJECT_ID" ]; then
        log_error "GITLAB_PROJECT_ID not set"
        return 1
    fi
    
    return 0
}

# Test API connectivity
test_api() {
    log_info "Testing GitLab API connectivity..."
    
    if ! check_config; then
        return 1
    fi
    
    # Get HTTP response and status code separately
    temp_file=$(mktemp)
    http_code=$(curl -s -w "%{http_code}" \
        --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        --output "$temp_file" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID")
    
    content=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [ "$http_code" = "200" ]; then
        project_name=$(echo "$content" | jq -r '.name // "Unknown"')
        log_success "API connection successful"
        log_info "Project: $project_name (ID: $GITLAB_PROJECT_ID)"
        return 0
    else
        log_error "API connection failed (HTTP $http_code)"
        if [ "$http_code" = "401" ]; then
            log_error "Invalid or expired token"
        elif [ "$http_code" = "404" ]; then
            log_error "Project not found or insufficient permissions"
        fi
        echo "$content"
        return 1
    fi
}

# List project labels
list_labels() {
    if ! check_config; then
        return 1
    fi
    
    curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"
}

# List issues
list_issues() {
    local state="${1:-opened}"
    
    if ! check_config; then
        return 1
    fi
    
    curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues?state=$state"
}

# Get specific issue
get_issue() {
    local issue_id="$1"
    
    if [ -z "$issue_id" ]; then
        log_error "Issue ID required"
        return 1
    fi
    
    if ! check_config; then
        return 1
    fi
    
    curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues/$issue_id"
}

# Create issue
create_issue() {
    local title="$1"
    local description="$2"
    local labels="$3"
    local assignee="$4"
    
    if [ -z "$title" ]; then
        log_error "Issue title required"
        return 1
    fi
    
    if ! check_config; then
        return 1
    fi
    
    local json_data="{\"title\":\"$title\""
    
    if [ -n "$description" ]; then
        json_data="$json_data,\"description\":\"$description\""
    fi
    
    if [ -n "$labels" ]; then
        json_data="$json_data,\"labels\":\"$labels\""
    fi
    
    if [ -n "$assignee" ]; then
        json_data="$json_data,\"assignee_id\":$assignee"
    fi
    
    json_data="$json_data}"
    
    log_info "Creating issue: $title"
    
    # Get HTTP response and status code separately
    temp_file=$(mktemp)
    http_code=$(curl -s -w "%{http_code}" \
        --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        --header "Content-Type: application/json" \
        --data "$json_data" \
        --output "$temp_file" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues")
    
    content=$(cat "$temp_file")
    rm -f "$temp_file"
    
    if [ "$http_code" = "201" ]; then
        issue_iid=$(echo "$content" | jq -r '.iid')
        issue_url=$(echo "$content" | jq -r '.web_url')
        log_success "Issue created: #$issue_iid"
        log_info "URL: $issue_url"
        return 0
    else
        log_error "Failed to create issue (HTTP $http_code)"
        echo "$content" | jq -r '.message // .error // "Unknown error"'
        return 1
    fi
}

# Update issue
update_issue() {
    local issue_id="$1"
    local title="$2"
    local description="$3"
    local labels="$4"
    local state="$5"
    
    if [ -z "$issue_id" ]; then
        log_error "Issue ID required"
        return 1
    fi
    
    if ! check_config; then
        return 1
    fi
    
    local json_data="{"
    local first=true
    
    if [ -n "$title" ]; then
        json_data="$json_data\"title\":\"$title\""
        first=false
    fi
    
    if [ -n "$description" ]; then
        [ "$first" = false ] && json_data="$json_data,"
        json_data="$json_data\"description\":\"$description\""
        first=false
    fi
    
    if [ -n "$labels" ]; then
        [ "$first" = false ] && json_data="$json_data,"
        json_data="$json_data\"labels\":\"$labels\""
        first=false
    fi
    
    if [ -n "$state" ]; then
        [ "$first" = false ] && json_data="$json_data,"
        json_data="$json_data\"state_event\":\"$state\""
        first=false
    fi
    
    json_data="$json_data}"
    
    log_info "Updating issue #$issue_id"
    
    response=$(curl -s -w "%{http_code}" \
        --request PUT \
        --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
        --header "Content-Type: application/json" \
        --data "$json_data" \
        "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues/$issue_id")
    
    http_code=$(echo "$response" | tail -n1)
    content=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        log_success "Issue updated successfully"
        return 0
    else
        log_error "Failed to update issue (HTTP $http_code)"
        echo "$content" | jq -r '.message // .error // "Unknown error"'
        return 1
    fi
}

# Main command dispatcher
main() {
    case "$1" in
        "test")
            test_api
            ;;
        "list-labels")
            list_labels
            ;;
        "list-issues")
            list_issues "$2"
            ;;
        "get-issue")
            get_issue "$2"
            ;;
        "create-issue")
            create_issue "$2" "$3" "$4" "$5"
            ;;
        "update-issue")
            update_issue "$2" "$3" "$4" "$5" "$6"
            ;;
        *)
            echo "Usage: $0 {test|list-labels|list-issues [state]|get-issue <id>|create-issue <title> [description] [labels] [assignee]|update-issue <id> [title] [description] [labels] [state]}"
            echo ""
            echo "Commands:"
            echo "  test                              Test API connectivity"
            echo "  list-labels                       List all project labels"
            echo "  list-issues [opened|closed|all]   List issues (default: opened)"
            echo "  get-issue <id>                    Get specific issue"
            echo "  create-issue <title> [desc] [labels] [assignee]  Create new issue"
            echo "  update-issue <id> [title] [desc] [labels] [state] Update issue"
            echo ""
            echo "State values for update-issue: close, reopen"
            exit 1
            ;;
    esac
}

main "$@"