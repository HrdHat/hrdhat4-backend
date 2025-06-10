# Migration Notes & Tracking

**Status**: CRITICAL DOCUMENTATION - DO NOT DELETE  
**Last Updated**: January 6, 2025  
**Purpose**: Track all database migrations applied to HrdHat backend

---

## 🚨 CRITICAL MIGRATION RULES

### **BEFORE APPLYING ANY MIGRATION:**

1. **NEVER** edit existing migration files after they've been applied
2. **ALWAYS** create new migration files for changes (001, 002, 003, etc.)
3. **ALWAYS** document the migration here BEFORE applying it
4. **ALWAYS** test migration on development environment first
5. **ALWAYS** backup database before applying to production

### **AFTER APPLYING MIGRATION:**

1. **IMMEDIATELY** update the migration file header with success status
2. **IMMEDIATELY** update this documentation with application details
3. **NEVER** delete or modify the applied migration file
4. **ALWAYS** verify the migration worked correctly

---

## 📋 Applied Migrations

### **001_initial_schema.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: December 2024 (confirmed from Daily Log 2025-01-06)
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Tables Created**:
  - `user_profiles` - User metadata and autofill data
  - `form_definitions` - Versioned form templates (immutable)
  - `form_instances` - User-submitted forms with JSONB data
  - `form_photos` - Photo metadata with Supabase Storage references
- **Key Features**:
  - Row Level Security (RLS) policies for creator-only access
  - Auto-generation triggers for form numbers (YYYYMMDD-NN format)
  - Performance-critical indexes for Phase 1
  - Versioned form template architecture with template_id + version constraints
  - JSONB validation constraints for form structure integrity
- **Edge Functions Deployed**: archive-forms, stale-forms
- **Verification**: Backend infrastructure confirmed operational in Daily Log
- **Notes**: Phase 1 simplified approach - no supervisor/admin complexity

### **002_add_form_signatures.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2025-06-06
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Tables Created**:
  - `form_signatures` - Signature metadata with Supabase Storage references
- **Key Features**:
  - Immutable signatures (no delete capability for audit compliance)
  - Flexible signer_role field (worker, supervisor, management, etc.)
  - Legacy signer_type field for backwards compatibility
  - File size constraints (100KB max per signature)
  - Row Level Security following form_photos pattern
  - Performance indexes for form lookup and type/date queries
  - Helper function get_signature_count for frontend use
- **Verification**: Migration applied successfully with no errors
- **Notes**: Signature system now ready for frontend integration

### **003_seed_default_flra_template.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2025-06-08 at 9:15 PM
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Purpose**: Seeds the default FLRA template that all users will fork from
- **Key Features**:
  - Creates stock FLRA template (is_system_template = true)
  - Includes all 6 modules: generalInformation, preJobChecklist, ppeAndPlatform, taskHazardControl, photos, signatures
  - Complete field definitions with helper texts (46+ fields total)
  - Clean module structure (constraints moved to frontend config)
  - Validation rules for Phase 1 loose enforcement
  - Ready for user template forking and customization
- **Applied With**:
  - Admin user ID: 0f64ac00-5a5f-42ca-8fce-e0efb17d2902 (hrdhatpawel@gmail.com)
  - Template UUID: f1a00000-0000-0000-0000-000000000001
- **Verification**: ✅ Migration applied successfully with no errors
- **Notes**: FLRA stock template now available for user template initialization and customization workflow

### **004 & 005: User Initialization Functions (CANCELLED MIGRATIONS)**

- **Status**: 🔄 CANCELLED - PERFECT CANCELLATION APPLIED
- **Date Applied & Removed**: 2025-06-09 at 8:41 AM
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Rule Variance Applied**: Cancelling migrations removed when they perfectly cancel each other
- **Migration 004**: Added 4 user initialization functions
- **Migration 005**: Removed same 4 user initialization functions
- **Result**: Database state returned to exact pre-migration-004 state
- **Verification**: ✅ Zero functions remain, only tables from migrations 001-003 exist
- **Files Status**: Both migration files removed from codebase (cancellation rule)
- **Notes**:
  - Architecture changed to form-creation workflow instead of user initialization
  - Functions were never used in production code
  - Perfect cancellation verified: no data loss, no side effects
  - Clean migration history maintained

### **004_remove_form_number_unique.sql**

- **Status**: ⏳ PENDING (not yet applied)
- **Date Created**: June 10, 2025
- **Purpose**: Remove unique constraint from `form_number` in `form_instances`
- **Rationale**: Form numbers are user-editable and should not be globally unique. This change allows users to set any form number, including duplicates, as required by business logic and frontend flexibility.
- **Key Steps**:
  - Drops the unique constraint (`form_instances_form_number_key`) from the `form_number` column
  - Leaves the NOT NULL constraint and auto-generation trigger in place
  - No impact on existing data except allowing duplicates going forward
- **To Apply**:
  1. Review migration file thoroughly
  2. Apply to development environment first and verify
  3. Update this entry with application status and date
  4. Apply to production after successful verification
- **Verification**: _Pending_
- **Notes**: This migration is required to align backend constraints with frontend and business requirements for flexible form numbering.

---

## 🔄 Migration Application Process

### **Development Environment Application:**

1. Review migration file thoroughly
2. Connect to development Supabase project via MCP
3. Apply migration using `mcp_supabase_apply_migration`
4. Verify tables/functions created correctly
5. Test basic CRUD operations
6. Document results here

### **Production Environment Application:**

1. Ensure development testing is complete
2. Create database backup
3. Connect to production Supabase project via MCP
4. Apply migration during low-traffic window
5. Verify migration success
6. Update migration file header immediately
7. Update this documentation immediately

---

## 📊 Migration History Summary

| Migration                          | Date Applied | Environment | Status       | Tables        | Notes                        |
| ---------------------------------- | ------------ | ----------- | ------------ | ------------- | ---------------------------- |
| 001_initial_schema.sql             | Dec 2024     | Development | ✅ Applied   | 4 tables      | Core schema with RLS         |
| 002_add_form_signatures.sql        | 2025-06-06   | Development | ✅ Applied   | +1 table      | Immutable signatures         |
| 003_seed_default_flra_template.sql | 2025-06-08   | Development | ✅ Applied   | 0 tables      | Seeds stock FLRA template    |
| 004 & 005 (Cancelled Migrations)   | 2025-06-09   | Development | 🔄 Cancelled | Net: 0 change | Perfect cancellation applied |

---

## 🛡️ Backup & Recovery

### **Before Major Migrations:**

- Always create full database backup
- Document backup location and timestamp
- Verify backup can be restored if needed

### **Rollback Procedures:**

- For schema changes: Restore from backup (migrations are not reversible)
- For data issues: Use point-in-time recovery if available
- Document any rollback procedures specific to each migration

---

## 📝 Migration File Naming Convention

- **Format**: `XXX_descriptive_name.sql`
- **Examples**:
  - `001_initial_schema.sql`
  - `002_add_form_signatures.sql`
  - `003_add_user_permissions.sql`
- **Rules**:
  - Sequential numbering (001, 002, 003...)
  - Descriptive names (snake_case)
  - Always include `.sql` extension

---

**⚠️ REMEMBER: This documentation is CRITICAL for tracking database state and ensuring safe migrations. Always keep it up to date!**
