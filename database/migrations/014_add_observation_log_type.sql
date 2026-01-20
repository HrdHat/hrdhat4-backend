-- =====================================================================================
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Date Applied: 2026-01-20
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Status: PRODUCTION READY - DO NOT DELETE OR EDIT THIS FILE
-- 
-- ⚠️  WARNING: THIS MIGRATION HAS BEEN SUCCESSFULLY APPLIED TO THE DATABASE
-- ⚠️  DO NOT MODIFY, DELETE, OR RE-RUN THIS MIGRATION
-- ⚠️  ANY CHANGES REQUIRE A NEW MIGRATION FILE (015_xxx.sql)
-- 
-- Migration Notes:
-- - Added 'observation' to the project_daily_logs.log_type check constraint
-- - Enables observation logs with location, area, and photo metadata
-- - Now supports 6 log types: visitor, delivery, site_issue, manpower, schedule_delay, observation
-- =====================================================================================

-- =========================
-- Migration: 014_add_observation_log_type.sql
-- Purpose: Add 'observation' to the project_daily_logs.log_type check constraint
-- Date Created: 2026-01-20
-- Dependencies: 013_project_daily_reports.sql
-- =========================

-- Add 'observation' to the project_daily_logs.log_type check constraint

-- Drop the existing constraint
ALTER TABLE project_daily_logs DROP CONSTRAINT IF EXISTS project_daily_logs_log_type_check;

-- Add the updated constraint with 'observation' included
ALTER TABLE project_daily_logs ADD CONSTRAINT project_daily_logs_log_type_check 
  CHECK (log_type = ANY (ARRAY['visitor'::text, 'delivery'::text, 'site_issue'::text, 'manpower'::text, 'schedule_delay'::text, 'observation'::text]));

-- Update the column comment
COMMENT ON COLUMN project_daily_logs.log_type IS 'Type of log: visitor, delivery, site_issue, manpower, schedule_delay, observation';
