#!/bin/bash

# Git Auto Push Script
# Automates git add, commit, and push with retry logic and error handling

set -e  # Exit on any error (but we'll handle errors manually)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_RETRIES=5
RETRY_DELAY=2
DEFAULT_MESSAGE="Auto-commit: $(date '+%Y-%m-%d %H:%M:%S')"

# Function to print colored output
print_status() {
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

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository!"
        exit 1
    fi
}

# Function to check for uncommitted changes
check_changes() {
    if git diff-index --quiet HEAD --; then
        print_warning "No changes to commit"
        return 1
    fi
    return 0
}

# Function to get commit message
get_commit_message() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        echo "$DEFAULT_MESSAGE"
    fi
}

# Function to retry with exponential backoff
retry_with_backoff() {
    local command="$1"
    local description="$2"
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        print_status "Attempt $attempt/$MAX_RETRIES: $description"
        
        if eval "$command"; then
            print_success "$description completed successfully"
            return 0
        else
            if [ $attempt -eq $MAX_RETRIES ]; then
                print_error "$description failed after $MAX_RETRIES attempts"
                return 1
            fi
            
            local delay=$((RETRY_DELAY * attempt))
            print_warning "$description failed, retrying in $delay seconds..."
            sleep $delay
            ((attempt++))
        fi
    done
}

# Function to handle git pull conflicts
handle_pull_conflicts() {
    print_status "Checking for remote changes..."
    
    # Fetch latest changes
    if ! retry_with_backoff "git fetch origin" "Fetching remote changes"; then
        return 1
    fi
    
    # Check if we need to pull
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null || echo "")
    
    if [ -n "$remote_commit" ] && [ "$local_commit" != "$remote_commit" ]; then
        print_status "Remote changes detected, attempting to pull..."
        
        # Try to pull with rebase
        if ! retry_with_backoff "git pull --rebase origin $(git branch --show-current)" "Pulling remote changes"; then
            print_error "Failed to pull remote changes. Manual intervention required."
            return 1
        fi
    fi
    
    return 0
}

# Main execution function
main() {
    local commit_message=$(get_commit_message "$1")
    
    print_status "Starting automated git workflow..."
    print_status "Commit message: $commit_message"
    
    # Check if we're in a git repo
    check_git_repo
    
    # Check for changes
    if ! check_changes; then
        exit 0
    fi
    
    # Handle potential conflicts with remote
    if ! handle_pull_conflicts; then
        exit 1
    fi
    
    # Stage all changes
    if ! retry_with_backoff "git add ." "Staging changes"; then
        exit 1
    fi
    
    # Commit changes
    if ! retry_with_backoff "git commit -m \"$commit_message\"" "Committing changes"; then
        exit 1
    fi
    
    # Push changes
    local current_branch=$(git branch --show-current)
    if ! retry_with_backoff "git push origin $current_branch" "Pushing to origin/$current_branch"; then
        exit 1
    fi
    
    print_success "All operations completed successfully!"
    print_status "Changes pushed to origin/$current_branch"
}

# Help function
show_help() {
    echo "Git Auto Push Script"
    echo ""
    echo "Usage: $0 [commit_message]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           # Use default commit message"
    echo "  $0 \"Fix user authentication\"  # Use custom commit message"
    echo ""
    echo "Features:"
    echo "  - Automatic retry with exponential backoff"
    echo "  - Handles merge conflicts with remote"
    echo "  - Color-coded status messages"
    echo "  - Error handling and recovery"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$1"
        ;;
esac 