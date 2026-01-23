-- =====================================================================================
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Date Applied: 2026-01-23
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Status: PRODUCTION READY - DO NOT DELETE OR EDIT THIS FILE
-- 
-- ⚠️  WARNING: THIS MIGRATION HAS BEEN SUCCESSFULLY APPLIED TO THE DATABASE
-- ⚠️  DO NOT MODIFY, DELETE, OR RE-RUN THIS MIGRATION
-- ⚠️  ANY CHANGES REQUIRE A NEW MIGRATION FILE (018_xxx.sql)
-- 
-- Migration Notes:
-- - Created partial index idx_form_instances_worker_forms
-- - Optimizes HrdHat Frontend queries for worker forms (project_id IS NULL)
-- - Complements existing idx_form_instances_project_id_supervisor for supervisor forms
-- =====================================================================================

-- =========================
-- Migration: 017_add_worker_forms_index.sql
-- Purpose: Add partial index to optimize Frontend queries for worker forms (project_id IS NULL)
-- Date Created: 2026-01-23
-- Dependencies: 001_initial_schema.sql (form_instances table)
-- =========================

-- =========================
-- Context
-- =========================
-- HrdHat Frontend has a 5 active form limit for workers.
-- The limit query filters: created_by = userId AND status = 'active' AND project_id IS NULL
-- 
-- Previously, only supervisor forms (project_id IS NOT NULL) had a partial index.
-- This migration adds a complementary index for worker forms to optimize Frontend queries.
--
-- Existing index (from 005_supervisor_extension.sql):
--   idx_form_instances_project_id_supervisor ON form_instances(project_id) WHERE project_id IS NOT NULL
--
-- New index (this migration):
--   idx_form_instances_worker_forms ON form_instances(created_by, status) WHERE project_id IS NULL

-- =========================
-- Create Partial Index for Worker Forms
-- =========================

CREATE INDEX IF NOT EXISTS idx_form_instances_worker_forms 
ON form_instances(created_by, status) 
WHERE project_id IS NULL;

COMMENT ON INDEX idx_form_instances_worker_forms IS 
'Partial index for worker forms (project_id IS NULL). Optimizes HrdHat Frontend queries for form limit checking and active forms listing.';

-- =========================
-- Verification
-- =========================
-- After applying, verify with:
-- SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'form_instances' AND indexname LIKE '%worker%';
