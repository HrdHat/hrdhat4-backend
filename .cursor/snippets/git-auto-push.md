# Title: Git Auto-Push Workflow

## Prompt:

Execute the automated git workflow to add, commit, and push all changes without disruption.

**Available Scripts:**

- `./git-auto-push.sh` - Bash version (Git Bash/WSL)
- `git-auto-push.bat` - Windows batch version

**Usage Options:**

- Run with auto-timestamp: `./git-auto-push.sh`
- Run with custom message: `./git-auto-push.sh "your commit message"`
- Windows version: `git-auto-push.bat "your commit message"`

**Features:**

- Automatic retry logic (5 attempts with exponential backoff)
- Handles remote conflicts with auto-rebase
- Color-coded status messages
- Safety checks (validates git repo, checks for changes)
- Zero-disruption completion guarantee

**What It Does:**

1. Validates git repository
2. Checks for uncommitted changes
3. Fetches and rebases remote changes
4. Stages all changes (`git add .`)
5. Commits with message
6. Pushes to current branch with retries

Just say "run git auto-push" and I'll execute it for you.

## Tags:

git, automation, commit, push, workflow, deployment
