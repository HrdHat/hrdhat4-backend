# Backend Management Plan for HrdHat

We have our our MCP connection capabilities and your project requirements, and how we should manage the backend development workflow:

## 🏗️ Backend Development Strategy

### 1. **Project Structure & Workspace Organization**

```
Hrdhatv4/
├── backend/                    # Backend documentation & schemas
│   ├── database/
│   │   ├── schemas/           # SQL schema files for reference
│   │   ├── migrations/        # Migration documentation
│   │   └── seeds/            # Sample data scripts
│   ├── edge-functions/        # Local Edge Function development
│   └── docs/                  # Backend documentation
├── frontend/                  # Your React app
└── .cursor/mcp.json          # Our Supabase connection
```

### 2. **Development Workflow**

#### **For Database Operations:**

```
Local Development → MCP Execution → Production
```

**Process:**

1. **Design**: We discuss schema changes in conversation
2. **Draft**: I create SQL migration files locally in `backend/database/`
3. **Review**: You review the SQL before execution
4. **Execute**: I apply migrations via MCP to your Supabase project
5. **Verify**: I check results and generate TypeScript types

#### **For Edge Functions:**

```
Local Development → MCP Deployment → Testing
```

**Process:**

1. **Develop**: I create Edge Functions in `backend/edge-functions/`
2. **Review**: You review the function code
3. **Deploy**: I deploy via MCP to your Supabase project
4. **Test**: We test the deployed function together
5. **Iterate**: Make changes and redeploy as needed

### 3. **Project Selection Strategy**

**Current Projects:**

- `ybonzpfwdcyxbzxkyeji` - HrdHat's Project v4 (us-east-2)
- `xbpdiceizfxaqzfvleqf` - HrdHat's Project (us-west-1)

**Recommended Approach:**

- **Development**: Use "HrdHat's Project v4" as our main development environment
- **Production**: Keep "HrdHat's Project" as production/stable
- **Branching**: Create development branches for major features

### 4. **Our Collaboration Model**

#### **My Responsibilities:**

- ✅ Execute database migrations via MCP
- ✅ Deploy Edge Functions via MCP
- ✅ Monitor logs and debug issues via MCP
- ✅ Generate TypeScript types for frontend
- ✅ Create and manage development branches
- ✅ Maintain backend documentation

#### **Your Responsibilities:**

- ✅ Review all SQL migrations before execution
- ✅ Review Edge Function code before deployment
- ✅ Test deployed functions from frontend
- ✅ Provide requirements and feedback
- ✅ Handle frontend integration

#### **Shared Responsibilities:**

- ✅ Architecture decisions
- ✅ Schema design discussions
- ✅ Performance optimization
- ✅ Security considerations

### 5. **Safety & Quality Controls**

#### **Before ANY Database Changes:**

1. **Branch Creation**: Create dev branch for testing major changes
2. **Migration Review**: You approve all SQL before execution
3. **Backup Strategy**: Leverage Supabase's built-in backups
4. **Rollback Plan**: Document how to revert changes

#### **Before ANY Function Deployments:**

1. **Code Review**: You review function logic
2. **Security Check**: Verify no sensitive data exposure
3. **Testing Plan**: Define how we'll test the deployed function

### 6. **Immediate Next Steps**

Let me propose our first backend setup session:

1. **Database Assessment**: I'll examine your current database structure
2. **Schema Planning**: We'll design the core tables for HrdHat (users, forms, form_instances)
3. **Migration Creation**: I'll create the initial database schema
4. **Type Generation**: I'll generate TypeScript types for your frontend
5. **First Edge Function**: We'll deploy a simple test function

## 🤝 Proposed Working Agreement

**Communication Protocol:**

- I'll always ask for approval before executing database changes
- I'll explain what each migration does before running it
- I'll provide rollback instructions for significant changes
- We'll test changes together before marking them complete

**Decision Points:**

- You have final approval on all schema changes
- We discuss architectural decisions together
- I'll flag any potential security or performance concerns

## 🔧 MCP Connection Capabilities

### What I Can Do:

#### Database Operations

- Execute SQL queries directly on your database
- Apply migrations (DDL operations like CREATE TABLE, ALTER TABLE, etc.)
- List all tables in your schemas
- List database extensions and their status
- View migration history

#### Edge Functions

- Deploy Edge Functions to your Supabase project
- List existing Edge Functions
- Upload multiple files for a function (including dependencies)
- Update existing functions with new versions

#### Project Management

- List and manage projects in your organization
- Pause/restore projects
- Get project details (status, region, database info)
- Create new projects (with cost confirmation)
- Get API URLs and keys for your projects

#### Branch Management (Development)

- Create development branches for testing
- List all branches and their status
- Merge branches to production
- Reset/rebase branches
- Delete branches

#### Monitoring & Debugging

- Get logs from different services (API, Postgres, Edge Functions, Auth, Storage, Realtime)
- Monitor project health
- Generate TypeScript types from your database schema

### What I Cannot Do:

- File uploads to Supabase Storage (no direct file storage API)
- Auth user management (create/delete users directly)
- Realtime subscriptions (this is client-side)
- Local file system operations on your Supabase instance

## 🎯 Practical Examples for HrdHat:

1. **Database Setup**: Create tables for users, forms, form_instances, modules
2. **Edge Functions**: Deploy PDF generation, form submission handlers
3. **Migrations**: Add new columns for form features
4. **Development**: Create a branch to test new form modules
5. **Debugging**: Check logs when forms aren't saving properly
6. **Types**: Generate TypeScript interfaces from your database

> **Planned Enhancement:** In Phase 2, a GIN index will be added to JSONB columns (form_definitions, form_instances) to support recall and advanced search. See form-plan/README.md and appplansteps.md for details.

---

**Status**: Proposal - Awaiting approval to begin implementation
**Created**: December 2024
**Last Updated**: December 2024
