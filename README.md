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

## 🚀 Quick Start

1. **Review Proposal**: Read `backend-management-proposal.md` for our development workflow
2. **Database Schema**: Check `database/schemas/` for current table structures
3. **Migrations**: View `database/migrations/` for change history
4. **Edge Functions**: Explore `edge-functions/` for serverless functions

## 🔧 MCP Connection

This backend is managed via Supabase MCP connection configured in `.cursor/mcp.json`.

## 📖 Documentation

For detailed backend documentation, see the `docs/` directory.
