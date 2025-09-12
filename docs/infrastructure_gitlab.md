# GitLab Infrastructure Replication Guide

**Purpose**: Streamlined setup to replicate the exact working GitLab infrastructure and Claude Code integration from this repository. Requires only PROJECT_ID and GitLab token.

## Step-by-Step Setup

**Prerequisites**: GitLab project with Developer/Maintainer role, GitLab API token

**Required Information**:
- PROJECT_ID (GitLab → Project → Settings → General)
- GITLAB_TOKEN (GitLab → User Settings → Access Tokens, scope: `api`)
- GITLAB_URL (e.g., `https://gitlab.com` or `https://git.mpi-cbg.de`)

## Table of Contents

1. [Step-by-Step Setup](#step-by-step-setup)
2. [Task List](#task-list)
3. [Claude Code Integration](#claude-code-integration)
4. [Essential Labels](#essential-labels)
5. [Troubleshooting](#troubleshooting)

## Quick Setup

This creates an exact replica of the working GitLab infrastructure from this repository:

- **Secure API Access**: Environment variable + local config file (proven reliable)
- **Automated Git Workflow**: OAuth2 token authentication with auto-commit hooks
- **Essential Label System**: Core labels that work (priority, type, status, component)
- **Claude Code Integration**: Exact hook configuration for GitLab agents
- **Project Management**: Automated issue creation and updates

### Required Information
- **GitLab Project ID**: Found in GitLab → Project → Settings → General
- **GitLab API Token**: GitLab → User Settings → Access Tokens (scope: `api`)
- **GitLab URL**: e.g., `https://gitlab.com` or `https://git.mpi-cbg.de`

### Required Software  
- **Git** (2.30+)
- **curl** and **jq** (for API calls)
- **Bash** (for automation)

## Task List

Execute these tasks one by one to replicate the working GitLab infrastructure:

### Task 1: Create Directory Structure

```bash
# In your new repository root
mkdir -p tools/gitlab
mkdir -p .claude
```

### Task 2: Create Environment Configuration

```bash
# Replace with your actual values
PROJECT_ID="your-project-id"
GITLAB_TOKEN="your-gitlab-token"
GITLAB_URL="your-gitlab-url"  # e.g., https://git.mpi-cbg.de

# Create environment file
cat > .env.gitlab.local << EOF
# GitLab Configuration - DO NOT COMMIT
export GITLAB_API_URL="$GITLAB_URL/api/v4"
export GITLAB_PROJECT_ID="$PROJECT_ID"
export GITLAB_PRIVATE_TOKEN="$GITLAB_TOKEN"
EOF

# Secure the file
chmod 600 .env.gitlab.local

# Add to .gitignore
echo ".env.gitlab.local" >> .gitignore
```

### Task 3: Copy Working Scripts

Copy these exact working scripts from this repository:

```bash
# Copy the essential working scripts
# (You need to manually copy these from the source repository)
curl -o tools/gitlab/get-token-noninteractive.sh [SOURCE_REPO_URL]/tools/gitlab/get-token-noninteractive.sh
curl -o tools/gitlab/claude-agent-gitlab.sh [SOURCE_REPO_URL]/tools/gitlab/claude-agent-gitlab.sh

# OR if you have access to the source repository locally:
cp /path/to/source/tools/gitlab/get-token-noninteractive.sh tools/gitlab/
cp /path/to/source/tools/gitlab/claude-agent-gitlab.sh tools/gitlab/

# Set permissions
chmod +x tools/gitlab/*.sh
chmod 700 tools/gitlab/get-token-noninteractive.sh
```

### Task 4: Update Script Configuration

```bash
# Update claude-agent-gitlab.sh with your project details
sed -i "s/GITLAB_PROJECT_ID=\"2545\"/GITLAB_PROJECT_ID=\"$PROJECT_ID\"/" tools/gitlab/claude-agent-gitlab.sh
sed -i "s|https://git.mpi-cbg.de|$GITLAB_URL|g" tools/gitlab/claude-agent-gitlab.sh

# Test the configuration
source .env.gitlab.local
./tools/gitlab/claude-agent-gitlab.sh test
```

### Task 5: Create Essential Labels

```bash
# Source your environment
source .env.gitlab.local

# Create the core labels that work in this project
# Priority Labels
curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"priority::critical","color":"#d73a4a"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"priority::high","color":"#fb8500"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"priority::medium","color":"#0969da"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

# Type Labels
curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::feature","color":"#1f883d"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::bug","color":"#d73a4a"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"type::enhancement","color":"#8250df"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

# Status Labels
curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"status::ready","color":"#0969da"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"status::in-progress","color":"#fb8500"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

curl -s --header "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
     --header "Content-Type: application/json" \
     --data '{"name":"status::done","color":"#1f883d"}' \
     "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/labels"

echo "✅ Essential labels created"
```


### Task 6: Test GitLab Integration

```bash
# Test API connectivity
./tools/gitlab/claude-agent-gitlab.sh test

# List existing labels
./tools/gitlab/claude-agent-gitlab.sh list-labels | jq '.[].name'

# Create a test issue
./tools/gitlab/claude-agent-gitlab.sh create-issue "Test Issue" "Testing GitLab integration" "type::feature,priority::medium"
```

## Claude Code Integration

### Task 7: Create Claude Hooks Configuration

Create the exact working Claude Code hooks configuration:

```bash
# Create Claude settings file
cat > .claude/settings.local.json << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(./tools/gitlab/claude-agent-gitlab.sh:*)",
      "Bash(./tools/gitlab/get-token-noninteractive.sh:*)"
    ],
    "deny": [],
    "ask": [],
    "defaultMode": "acceptEdits"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "git",
        "hooks": [
          {
            "type": "command",
            "command": "#!/bin/bash\nif [[ \"$CLAUDE_TOOL_NAME\" != *\"git\"* ]] && [[ \"$CLAUDE_COMMAND\" != *\"git\"* ]]; then exit 0; fi\nif ! git rev-parse --git-dir > /dev/null 2>&1; then exit 0; fi\nif [ -f .env.gitlab.local ]; then\n  source .env.gitlab.local\n  current_url=$(git remote get-url origin 2>/dev/null)\n  if [[ \"$current_url\" != *\"oauth2:\"* ]]; then\n    echo \"🔧 Setting up OAuth2 authentication\"\n    git remote set-url origin \"https://oauth2:${GITLAB_PRIVATE_TOKEN}@YOUR_GITLAB_HOST/YOUR_USERNAME/YOUR_REPO.git\"\n    echo \"✅ Git remote configured for token authentication\"\n  fi\nfi",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "git",
        "hooks": [
          {
            "type": "command",
            "command": "#!/bin/bash\nif ! git rev-parse --git-dir > /dev/null 2>&1; then exit 0; fi\ngit_status=$(git status --porcelain)\nif [ -z \"$git_status\" ]; then exit 0; fi\nfile_count=$(echo \"$git_status\" | wc -l | tr -d ' ')\nif [ \"$file_count\" -ge 5 ] || [[ \"$CLAUDE_CONTEXT\" == *\"commit\"* ]] || [[ \"$CLAUDE_CONTEXT\" == *\"push\"* ]]; then\n  if [ -f .env.gitlab.local ]; then\n    source .env.gitlab.local\n    if [[ \"$(git remote get-url origin)\" != *\"oauth2:\"* ]]; then\n      git remote set-url origin \"https://oauth2:${GITLAB_PRIVATE_TOKEN}@YOUR_GITLAB_HOST/YOUR_USERNAME/YOUR_REPO.git\"\n    fi\n  fi\n  git add .\n  commit_msg=\"feat: Auto-commit development progress\n\n🔄 Changes Summary:\n- $file_count files modified/added\n- Context: $CLAUDE_CONTEXT\n\n🤖 Generated with [Claude Code](https://claude.ai/code)\n\nCo-Authored-By: Claude <noreply@anthropic.com>\"\n  git commit -m \"$commit_msg\"\n  git push\n  echo \"✅ Auto-committed and pushed $file_count files\"\nfi",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
EOF
```

**Important**: Replace `YOUR_GITLAB_HOST`, `YOUR_USERNAME`, and `YOUR_REPO` with your actual values.

### Task 8: Update Git Remote for Token Authentication

```bash
# Source your environment
source .env.gitlab.local

# Update git remote URL to use token authentication
# Replace with your actual repository URL
git remote set-url origin "https://oauth2:${GITLAB_PRIVATE_TOKEN}@your-gitlab-host/your-username/your-repo.git"

# Verify the setup
git remote -v
```

### Task 9: Test Complete Integration

```bash
# Test Claude Code GitLab integration
./tools/gitlab/claude-agent-gitlab.sh create-issue "Integration Test" "Testing complete GitLab infrastructure setup" "type::feature,priority::medium"

# Test git workflow with token authentication
git add .
git commit -m "test: GitLab infrastructure setup complete"
git push

# Verify issue was created in GitLab web interface
echo "Check your GitLab project issues to verify the integration test issue was created"
```

### Task 10: Configure Claude Code Agents (Optional)

If you want Claude to automatically manage GitLab issues:

```bash
# Test the project-task-updater agent integration
# This allows Claude to automatically update GitLab issues when completing tasks
echo "Claude Code agents are now configured to use your GitLab infrastructure"
echo "The project-task-updater agent will automatically create and update issues"
```

## Verification Checklist

Ensure all components are working:

- [ ] Environment file created and secured (`.env.gitlab.local`)
- [ ] GitLab API scripts working (`./tools/gitlab/claude-agent-gitlab.sh test`)
- [ ] Essential labels created in GitLab project
- [ ] Claude hooks configured (`.claude/settings.local.json`)
- [ ] Git remote uses token authentication
- [ ] Test issue created successfully
- [ ] Auto-commit hooks functional (if desired)

### Usage Examples

```bash
# Create GitLab issues from Claude
./tools/gitlab/claude-agent-gitlab.sh create-issue "New Feature" "Description" "type::feature,priority::high"

# List current issues
./tools/gitlab/claude-agent-gitlab.sh list-issues opened

# Get specific issue
./tools/gitlab/claude-agent-gitlab.sh get-issue 15

# Close an issue
./tools/gitlab/claude-agent-gitlab.sh update-issue 15 "" "" "" "close"
```

## Working Development Workflow

Once set up, this is how you work with the integrated system:

### Issue-Based Development

```bash
# Create an issue for new work
./tools/gitlab/claude-agent-gitlab.sh create-issue "Implement user login" "Add authentication system" "type::feature,priority::high"

# Work on your code...
# When you commit with many changes, the hooks will auto-commit and push

# Reference issues in commits
git commit -m "Add login form, refs #15"

# Close issues when complete
git commit -m "Complete authentication system, closes #15"
```

### Claude Code Integration

With the hooks configured, Claude Code will:
- Automatically use secure GitLab authentication
- Auto-commit and push when working on multiple files
- Create and update GitLab issues when completing tasks
- Use the project-task-updater agent for issue management



## Troubleshooting

### Common Issues

#### 1. "Token not found" Error
```bash
# Check token is set
echo $GITLAB_PRIVATE_TOKEN
source .env.gitlab.local && echo $GITLAB_PRIVATE_TOKEN

# Test token access
./tools/gitlab/claude-agent-gitlab.sh test
```

#### 2. "403 Forbidden" API Errors
```bash
# Verify project ID and permissions
curl -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID"
```

#### 3. Labels Not Created
```bash
# Check if labels exist
./tools/gitlab/claude-agent-gitlab.sh list-labels

# Re-run label creation commands from Task 5
```

#### 4. Claude Hooks Not Working
```bash
# Check .claude/settings.local.json exists and is valid JSON
cat .claude/settings.local.json | jq .

# Verify git remote uses token authentication
git remote -v
```

#### 5. Git Authentication Issues
```bash
# Reset git remote with token
source .env.gitlab.local
git remote set-url origin "https://oauth2:${GITLAB_PRIVATE_TOKEN}@your-gitlab-host/your-username/your-repo.git"
```


## Summary

This streamlined guide replicates the exact working GitLab infrastructure from this repository. After completing all tasks, you'll have:

- **Secure API Access**: Token-based authentication with environment variables
- **Essential Labels**: Core priority, type, and status labels for issue management
- **Claude Code Integration**: Automatic GitLab integration with Claude Code agents
- **Git Workflow**: OAuth2 token authentication with auto-commit hooks
- **Issue Management**: Command-line tools for creating and managing GitLab issues

The setup requires only your PROJECT_ID, GITLAB_TOKEN, and GITLAB_URL to replicate the working infrastructure exactly as it functions in this repository.

---

**Source**: GlobTim Project Working GitLab Infrastructure  
**Last Updated**: September 12, 2025  
**Repository**: https://git.mpi-cbg.de/scholten/globtim