# Migration Notes & Tracking

**Status**: CRITICAL DOCUMENTATION - DO NOT DELETE  
**Last Updated**: January 16, 2026  
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

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2025-06-10
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Purpose**: Remove unique constraint from `form_number` in `form_instances`
- **Rationale**: Form numbers are user-editable and should not be globally unique
- **Verification**: ✅ Constraint removed, duplicates now allowed
- **Notes**: Aligns backend constraints with frontend/business requirements

### **005_supervisor_extension.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2026-01-12
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Purpose**: Add HrdHat Supervisor extension tables for project management and email intake
- **Tables Created**:
  - `supervisor_projects` - Construction sites managed by supervisors
  - `project_workers` - Workers assigned to projects
  - `project_folders` - Form type categories for organizing documents
  - `received_documents` - Email intake documents with AI classification
- **Key Features**:
  - Foreign key from `form_instances.project_id` to `supervisor_projects.id`
  - Row Level Security policies for supervisor access
  - Supervisor can see forms from workers in their projects (NEW forms only)
  - Performance indexes on all new tables
- **Verification Results**:
  - ✅ 4 tables created with RLS enabled
  - ✅ FK constraint `form_instances_supervisor_project_fkey` added
  - ✅ 202 existing forms verified untouched (all have project_id = NULL)
  - ✅ New tables empty and ready for use
- **Notes**: First step of HrdHat Supervisor MVP - enables project-based form management

### **006_enable_realtime_received_documents.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2026-01-13
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Purpose**: Enable Supabase Realtime for `received_documents` table
- **Key Features**:
  - Adds `received_documents` to `supabase_realtime` publication
  - Enables real-time INSERT, UPDATE, DELETE events for supervisors
  - Works with existing RLS policies (supervisors only see their projects)
- **Tables Modified**: None (publication configuration only)
- **Verification**: ✅ Migration applied successfully with no errors
- **Notes**: Enables live document feed in Supervisor dashboard

### **007_project_subcontractors.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2026-01-14
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Purpose**: Add subcontractor management for supervisor projects
- **Tables Created**:
  - `project_subcontractors` - Subcontractor companies assigned to projects
- **Tables Modified**:
  - `project_workers` - Added `subcontractor_id` column to link workers to subcontractors
- **Key Features**:
  - Subcontractor tracking with contact info (name, email, phone)
  - Unique constraint on (project_id, company_name)
  - Workers can optionally be linked to subcontractors
  - RLS policies for supervisor access
  - Realtime enabled for live dashboard updates
  - Indexes for efficient queries
- **Verification**: ✅ Migration applied successfully with no errors
- **Notes**: Enables subcontractor company management in Supervisor dashboard

### **008_supervisor_access_flag.sql**

- **Status**: ⏳ PENDING - PREPARED FOR FUTURE USE
- **Date Created**: 2026-01-14
- **Purpose**: Add `has_supervisor_access` flag to user_profiles for future paywall
- **Columns Added**:
  - `user_profiles.has_supervisor_access` - Boolean, default false
- **Key Features**:
  - Simple boolean flag for gating supervisor dashboard access
  - Default false (users don't automatically get access)
  - Index for efficient lookups when checking access
  - Ready for integration with Stripe/payment system
  - Can be used in RLS policies for supervisor feature gating
- **Notes**: 
  - DO NOT APPLY until paywall is ready to be implemented
  - Migration prepared as part of shared session integration work
  - See migration file comments for usage examples

### **009_project_shifts.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2026-01-16
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Purpose**: Add shift management for supervisor projects (Start of Shift feature)
- **Tables Created**:
  - `project_shifts` - Work shifts for projects with scheduling and closeout tracking
  - `shift_workers` - Workers assigned to shifts with notification and form submission tracking
- **Tables Modified**:
  - `received_documents` - Added `shift_id` column to link documents to shifts
- **Key Features**:
  - Flexible shift naming (e.g., "Morning - Jan 16", "Night Shift")
  - Worker assignment with registered users or ad-hoc contacts
  - Notification tracking (SMS/email status)
  - Form submission tracking per worker
  - Shift closeout with checklist and notes
  - RLS policies for supervisor access
  - Realtime enabled for live dashboard updates
  - Comprehensive indexes for efficient queries
- **Verification**: ✅ Migration applied successfully with no errors
- **Notes**: Core database structure for Start of Shift feature

### **010_add_worker_contact_fields.sql**

- **Status**: ✅ SUCCESSFULLY APPLIED
- **Date Applied**: 2026-01-16
- **Applied To**: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
- **Applied By**: AI Assistant (via MCP Supabase connection)
- **Purpose**: Add worker contact fields to FLRA form template's General Information module
- **Tables Modified**:
  - `form_definitions` - Updated `definition_jsonb` for FLRA templates
- **Fields Added to generalInformation module**:
  - `worker_phone` - Worker's phone number (optional, autofill from profile)
  - `worker_email` - Worker's email address (optional, autofill from profile)
  - `company_name` - Company/Subcontractor name (optional, autofill from profile)
- **Key Features**:
  - All new fields are optional (required: false)
  - All new fields support autofill from user_profiles table
  - Existing form instances are unaffected (use their saved form_data)
  - New forms will include these fields automatically
- **Frontend Changes**:
  - Updated `formService.ts` getAutofillData() to map profile fields to form fields
- **Verification**: ✅ Migration applied successfully, fields confirmed in template
- **Notes**: Enables workers to include their contact information on forms

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
| 004_remove_form_number_unique.sql  | 2025-06-10   | Development | ✅ Applied   | 0 tables      | Removes unique on form_number|
| 005_supervisor_extension.sql       | 2026-01-12   | Development | ✅ Applied   | +4 tables     | Supervisor project management|
| 006_enable_realtime_received_documents.sql | 2026-01-13 | Development | ✅ Applied | 0 tables | Enables Realtime for documents|
| 007_project_subcontractors.sql     | 2026-01-14   | Development | ✅ Applied   | +1 table      | Subcontractor management     |
| 008_supervisor_access_flag.sql     | Pending      | -           | ⏳ Pending   | 0 tables      | Paywall preparation (future) |
| 009_project_shifts.sql             | 2026-01-16   | Development | ✅ Applied   | +2 tables     | Start of Shift feature       |
| 010_add_worker_contact_fields.sql  | 2026-01-16   | Development | ✅ Applied   | 0 tables      | Worker contact fields in form|

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
