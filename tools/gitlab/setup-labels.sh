#!/bin/bash
#
# Setup Essential GitLab Labels
# Creates the core labels needed for project management
#

# Load environment
if [ -f ".env.gitlab.local" ]; then
    source .env.gitlab.local
else
    echo "❌ .env.gitlab.local not found. Please create it with your GitLab configuration."
    exit 1
fi

# Check required variables
if [ -z "$GITLAB_PRIVATE_TOKEN" ] || [ -z "$GITLAB_PROJECT_ID" ] || [ -z "$GITLAB_API_URL" ]; then
    echo "❌ Missing required environment variables"
    echo "Required: GITLAB_PRIVATE_TOKEN, GITLAB_PROJECT_ID, GITLAB_API_URL"
    exit 1
fi

echo "🏷️  Creating essential GitLab labels..."

# Priority Labels
echo "Creating priority labels..."
curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"priority::critical","color":"#d73a4a","description":"Critical priority items"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"priority::high","color":"#fb8500","description":"High priority items"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"priority::medium","color":"#0969da","description":"Medium priority items"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"priority::low","color":"#7c3aed","description":"Low priority items"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

# Type Labels
echo "Creating type labels..."
curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::feature","color":"#1f883d","description":"New feature or functionality"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::bug","color":"#d73a4a","description":"Bug fixes"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::enhancement","color":"#8250df","description":"Enhancement to existing feature"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::documentation","color":"#0969da","description":"Documentation updates"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::refactor","color":"#6f42c1","description":"Code refactoring"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

# Status Labels
echo "Creating status labels..."
curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"status::ready","color":"#0969da","description":"Ready to work on"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"status::in-progress","color":"#fb8500","description":"Currently being worked on"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"status::done","color":"#1f883d","description":"Completed"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"status::blocked","color":"#d73a4a","description":"Blocked by external dependency"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

# Component Labels  
echo "Creating component labels..."
curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"component::plotting","color":"#28a745","description":"Plotting functionality"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"component::extensions","color":"#6f42c1","description":"Julia package extensions"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"component::ci-cd","color":"#0969da","description":"CI/CD pipeline"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"component::migration","color":"#fb8500","description":"Code migration from parent project"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels" > /dev/null

echo "✅ Essential labels created successfully!"

# List created labels
echo ""
echo "📋 Created labels:"
./tools/gitlab/claude-agent-gitlab.sh list-labels | jq -r '.[] | "- \(.name) (\(.color))"' | head -20