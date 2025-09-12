# GitLab Infrastructure Setup

This repository now includes the recommended GitLab infrastructure from `docs/infrastructure_gitlab.md`.

## Quick Start

1. **Create your environment file:**
   ```bash
   cp .env.gitlab.local.template .env.gitlab.local
   chmod 600 .env.gitlab.local
   ```

2. **Edit `.env.gitlab.local` with your GitLab token:**
   ```bash
   # Edit the file and replace "your-gitlab-token-here" with your actual token
   nano .env.gitlab.local
   ```

3. **Test GitLab API connectivity:**
   ```bash
   ./tools/gitlab/claude-agent-gitlab.sh test
   ```

4. **Create essential GitLab labels:**
   ```bash
   ./tools/gitlab/setup-labels.sh
   ```

5. **Test issue creation:**
   ```bash
   ./tools/gitlab/claude-agent-gitlab.sh create-issue "Test Issue" "Testing setup" "type::feature,priority::medium"
   ```

## What's Included

✅ **Tools Directory:**
- `tools/gitlab/claude-agent-gitlab.sh` - GitLab API integration
- `tools/gitlab/get-token-noninteractive.sh` - Secure token management
- `tools/gitlab/setup-labels.sh` - Create essential project labels

✅ **Environment Configuration:**
- `.env.gitlab.local.template` - Template for GitLab configuration
- Added `.env.gitlab.local` to `.gitignore`

✅ **Claude Code Integration:**
- Updated `.claude/settings.local.json` with GitLab permissions
- Added pre/post git hooks for OAuth2 authentication
- Auto-commit functionality for bulk changes

✅ **Git Configuration:**
- Updated remote URL to correct repository
- Ready for token-based authentication

## Missing (Requires Your Token)

❌ **Actual environment file** - You need to create `.env.gitlab.local` with your token
❌ **GitLab labels** - Run `./tools/gitlab/setup-labels.sh` after setting up token  
❌ **OAuth2 git remote** - Will be set automatically when you provide token

## Next Steps

1. Get your GitLab token from https://git.mpi-cbg.de/-/profile/personal_access_tokens
2. Create `.env.gitlab.local` with your token (scope: `api`)
3. Run the setup scripts above
4. The Claude Code hooks will automatically configure OAuth2 authentication

## Usage Examples

```bash
# List current issues
./tools/gitlab/claude-agent-gitlab.sh list-issues

# Create a feature request  
./tools/gitlab/claude-agent-gitlab.sh create-issue "Add new plot type" "Description here" "type::feature,priority::high"

# Close an issue
./tools/gitlab/claude-agent-gitlab.sh update-issue 5 "" "" "" "close"
```