-- =====================================================================================
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Date Applied: 2026-01-20
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Status: PRODUCTION READY - DO NOT DELETE OR EDIT THIS FILE
-- 
-- ⚠️  WARNING: THIS MIGRATION HAS BEEN SUCCESSFULLY APPLIED TO THE DATABASE
-- ⚠️  DO NOT MODIFY, DELETE, OR RE-RUN THIS MIGRATION
-- ⚠️  ANY CHANGES REQUIRE A NEW MIGRATION FILE (016_xxx.sql, etc.)
-- =====================================================================================
-- MIGRATION: 015_supervisor_forms_flexibility.sql
-- Purpose: Allow form_instances to work without formal form_definitions (supervisor forms)
-- 
-- Background:
-- The supervisor app creates forms directly in form_instances without requiring
-- form_definitions records. This is simpler for supervisor-specific forms like
-- toolbox_talk, weekly_inspection, and worker_orientation where the form structure
-- is hardcoded in the React UI rather than defined in the database.
--
-- Changes:
-- 1. Allow NULL for form_definition_id (supervisor forms don't need definitions)
-- 2. Allow NULL for form_definition_version
-- 3. Change template_id from UUID to TEXT (to support string IDs like 'toolbox_talk')
-- 4. Drop constraints that require form_definitions linkage
-- 
-- ⚠️ WARNING: Apply only to development first. Test thoroughly before production.
-- =====================================================================================

-- =========================
-- 1. Drop CHECK constraints that require form_definitions
-- =========================
ALTER TABLE form_instances 
DROP CONSTRAINT IF EXISTS form_definition_version_exists;

ALTER TABLE form_instances 
DROP CONSTRAINT IF EXISTS template_id_consistency;

-- =========================
-- 2. Allow NULL for form_definition_id
-- =========================
ALTER TABLE form_instances 
ALTER COLUMN form_definition_id DROP NOT NULL;

-- =========================
-- 3. Allow NULL for form_definition_version
-- =========================
ALTER TABLE form_instances 
ALTER COLUMN form_definition_version DROP NOT NULL;

-- =========================
-- 4. Change template_id from UUID to TEXT
-- =========================
-- First, drop the NOT NULL constraint temporarily
ALTER TABLE form_instances 
ALTER COLUMN template_id DROP NOT NULL;

-- Change the column type from UUID to TEXT
-- Existing UUID values will be cast to their string representation
ALTER TABLE form_instances 
ALTER COLUMN template_id TYPE TEXT USING template_id::TEXT;

-- Re-add NOT NULL constraint (template_id should always be set)
ALTER TABLE form_instances 
ALTER COLUMN template_id SET NOT NULL;

-- =========================
-- 5. Add index for template_id (TEXT) queries
-- =========================
DROP INDEX IF EXISTS idx_form_instances_template_id;
CREATE INDEX idx_form_instances_template_id ON form_instances(template_id);

-- =========================
-- 6. Add comment documenting the change
-- =========================
COMMENT ON COLUMN form_instances.form_definition_id IS 
'References form_definitions.id. NULL for supervisor-created forms that use hardcoded UI.';

COMMENT ON COLUMN form_instances.form_definition_version IS 
'Version of the form definition. NULL for supervisor-created forms.';

COMMENT ON COLUMN form_instances.template_id IS 
'Form type identifier. For worker forms: UUID referencing form_definitions.template_id. For supervisor forms: string ID like ''toolbox_talk'', ''worker_orientation''.';
