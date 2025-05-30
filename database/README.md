# Database Management

This directory contains all database-related files for HrdHat backend management.

## 📁 Directory Structure

```
database/
├── README.md           # This file
├── schemas/           # SQL schema files for reference
├── migrations/        # Migration documentation
└── seeds/            # Sample data scripts
```

## 📋 Schemas

The `schemas/` directory contains SQL files that define our database structure:

- **Reference Only**: These files document the current database state
- **Not Executed**: Schema files are for documentation and planning
- **Generated**: Can be auto-generated from live database

## 🔄 Migrations

The `migrations/` directory tracks all database changes:

- **Applied via MCP**: Migrations are executed through our MCP connection
- **Documented**: Each migration is documented before execution
- **Versioned**: Follows chronological naming convention

## 🌱 Seeds

The `seeds/` directory contains sample data for development:

- **Test Data**: Sample forms, users, and modules for testing
- **Development**: Initial data for local development
- **Reference**: Example data structures for frontend development

## 🔧 Workflow

1. **Schema Design**: Create/update schema files for planning
2. **Migration Creation**: Document changes in migrations/
3. **MCP Execution**: Apply migrations via MCP connection
4. **Verification**: Confirm changes and update documentation

## 📝 Naming Conventions

### Migrations

- Format: `YYYYMMDD_HHMMSS_description.sql`
- Example: `20241201_143000_create_users_table.sql`

### Schema Files

- Format: `table_name.sql`
- Example: `users.sql`, `form_instances.sql`

### Seed Files

- Format: `seed_table_name.sql`
- Example: `seed_users.sql`, `seed_form_modules.sql`
