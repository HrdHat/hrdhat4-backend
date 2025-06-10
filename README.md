# HrdHat Backend

This directory contains all backend-related documentation, schemas, and Edge Functions for the HrdHat application.

## 📁 Directory Structure

```
backend/
├── README.md                           # This file
├── backend-management-proposal.md      # Our MCP workflow proposal
├── database/
│   ├── schemas/                       # SQL schema files for reference
│   ├── migrations/                    # Migration documentation
│   └── seeds/                         # Sample data scripts
├── edge-functions/                    # Local Edge Function development
└── docs/                             # Backend documentation
```

## 🔗 Supabase Projects

**Development Environment:**

- Project: HrdHat's Project v4
- ID: `ybonzpfwdcyxbzxkyeji`
- Region: us-east-2

**Production Environment:**

- Project: HrdHat's Project
- ID: `xbpdiceizfxaqzfvleqf`
- Region: us-west-1

## Git Workflow & Repository Structure

### Repository Organization

HrdHat uses a **multi-repository architecture**:

```
Hrdhatv4/
├── frontend/    # Separate repository (React app)
├── backend/     # This repository (Supabase functions/schemas)
├── .cursor/     # Global Cursor IDE configuration
└── .vscode/     # Global VS Code configuration
```

### Important Git Rules

⚠️ **CRITICAL: Each directory has its own git repository**

- `frontend/` → `https://github.com/HrdHat/hrdhatv4-frontend.git`
- `backend/` → `https://github.com/HrdHat/hrdhat4-backend.git`
- Root directory (`Hrdhatv4/`) is **NOT** a git repository

### Automated Git Workflow

Both frontend and backend repositories include automated git scripts:

#### Quick Usage

```bash
# Option 1: Auto-timestamp commit
./git-auto-push.sh

# Option 2: Custom commit message
./git-auto-push.sh "your commit message"

# Option 3: Windows batch version
git-auto-push.bat "your commit message"

# Option 4: Use Cursor snippet
# Type @git-auto-push in Cursor, then say "run git auto-push"
```

#### Automation Features

- ✅ **Retry Logic**: 5 attempts with exponential backoff
- ✅ **Conflict Resolution**: Auto-fetches and rebases remote changes
- ✅ **Safety Checks**: Validates repository and checks for changes
- ✅ **Color Output**: Status messages for easy debugging
- ✅ **Zero Disruption**: Guarantees completion or safe failure

#### What the Automation Does

1. Validates you're in a git repository
2. Checks for uncommitted changes
3. Fetches and rebases remote changes if needed
4. Stages all changes (`git add .`)
5. Commits with your message (or auto-timestamp)
6. Pushes to current branch with retry logic

### Backend-Specific Workflow

When working with backend changes:

#### Database Changes

```bash
# 1. Make schema changes or add migrations
# 2. Document in database/migrations/
# 3. Test with MCP connection
# 4. Commit changes
./git-auto-push.sh "Add user authentication tables"
```

#### Edge Functions

```bash
# 1. Develop function in edge-functions/
# 2. Test locally if possible
# 3. Deploy via MCP
# 4. Commit changes
./git-auto-push.sh "Add PDF generation edge function"
```

### Working Across Repositories

When working on features that span frontend and backend:

1. **Make backend changes** in `backend/` directory
2. **Commit and push** from `backend/` directory
3. **Switch to frontend** directory: `cd ../frontend`
4. **Make frontend changes** in `frontend/` directory
5. **Commit and push** from `frontend/` directory

#### Example Workflow

```bash
# Working on authentication feature
cd backend/
# ... make database/API changes ...
./git-auto-push.sh "Add authentication endpoints and user table"

cd ../frontend/
# ... make UI changes ...
./git-auto-push.sh "Add login form UI"
```

### Common Mistakes to Avoid

❌ **DON'T** create git repositories in the root `Hrdhatv4/` directory
❌ **DON'T** try to commit both frontend and backend changes together
❌ **DON'T** work in the wrong directory when making commits
❌ **DON'T** commit database migrations without testing via MCP first

✅ **DO** always check your current directory before committing
✅ **DO** use the automated scripts for consistent workflow
✅ **DO** commit frontend and backend changes separately
✅ **DO** test database changes via MCP before committing

### Troubleshooting Git Issues

If you encounter git problems:

1. **Check your location**: `pwd` (should be in `backend/` directory)
2. **Check git status**: `git status`
3. **Remove lock files**: `rm -f .git/index.lock` (if git operations hang)
4. **Use automation**: The scripts handle most edge cases automatically

## 🚀 Quick Start

1. **Review Proposal**: Read `backend-management-proposal.md` for our development workflow
2. **Database Schema**: Check `database/schemas/` for current table structures
3. **Migrations**: View `database/migrations/` for change history
4. **Edge Functions**: Explore `edge-functions/` for serverless functions

## 🔧 MCP Connection

This backend is managed via Supabase MCP connection configured in `.cursor/mcp.json`.

## 🔑 Signature Role Definitions

The form signature system supports flexible role definitions sent by the frontend via the `signer_role` field:

### Core Roles

- **`worker`** - General construction worker
- **`supervisor`** - Site supervisor or team lead
- **`management`** - Project management or company management
- **`safety_officer`** - Dedicated safety personnel
- **`foreman`** - Construction foreman
- **`apprentice`** - Apprentice or trainee worker
- **`subcontractor`** - External contractor personnel
- **`inspector`** - Quality or safety inspector

### Implementation Notes

- **Frontend Flexibility**: Frontend can send any string value for `signer_role`
- **Database Storage**: All roles stored as text - no database validation constraints
- **Legacy Compatibility**: `signer_type` field maintained for backwards compatibility (worker/supervisor only)
- **Role Grouping**: Frontend groups roles into logical categories (workers vs. supervisors) for UI display
- **Custom Roles**: Organizations can define custom roles as needed (e.g., 'crane_operator', 'safety_coordinator')

### Database Structure

```sql
-- form_signatures table
signer_type: text,  -- legacy: 'worker' | 'supervisor'
signer_role: text,  -- flexible: any role string from frontend
```

### Usage Example

```javascript
// Frontend sends flexible role data
const signatureData = {
  signer_name: "John Smith",
  signer_type: "worker", // maps to legacy categories
  signer_role: "crane_operator", // specific role for this signature
  // ... other fields
};
```

## 📖 Documentation

For detailed backend documentation, see the `docs/` directory.
