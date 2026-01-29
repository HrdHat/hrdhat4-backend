-- =====================================================================================
-- Migration: 018_notes_and_meeting_minutes.sql
-- Purpose: Add 'note' and 'meeting_minutes' log types to project_daily_logs
-- 
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Date Created: 2026-01-29
-- Date Applied: 2026-01-29
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Status: PRODUCTION READY - DO NOT DELETE OR EDIT THIS FILE
-- Author: AI Assistant
-- 
-- ⚠️  WARNING: THIS MIGRATION HAS BEEN SUCCESSFULLY APPLIED TO THE DATABASE
-- ⚠️  DO NOT MODIFY, DELETE, OR RE-RUN THIS MIGRATION
-- ⚠️  ANY CHANGES REQUIRE A NEW MIGRATION FILE (019_xxx.sql)
-- 
-- Migration Notes:
-- - Added 'note' to support quick supervisor notes with categories
-- - Added 'meeting_minutes' to support meeting documentation with attendees
-- - Now supports 8 log types: visitor, delivery, site_issue, manpower, schedule_delay, observation, note, meeting_minutes
-- 
-- Note Categories (stored in metadata.category):
--   phone, email, drawing, follow_up, safety, quality, change_order
-- 
-- Meeting Types (stored in metadata.meeting_type):
--   safety_briefing, progress, coordination, owner, subcontractor, preconstruction,
--   kickoff, closeout, inspection, design, site_walk, general, other
-- =====================================================================================

-- =========================
-- 1. Update log_type constraint
-- =========================

-- Drop the existing constraint
ALTER TABLE project_daily_logs DROP CONSTRAINT IF EXISTS project_daily_logs_log_type_check;

-- Add the updated constraint with 'note' and 'meeting_minutes' included
ALTER TABLE project_daily_logs ADD CONSTRAINT project_daily_logs_log_type_check 
  CHECK (log_type = ANY (ARRAY[
    'visitor'::text, 
    'delivery'::text, 
    'site_issue'::text, 
    'manpower'::text, 
    'schedule_delay'::text, 
    'observation'::text,
    'note'::text,
    'meeting_minutes'::text
  ]));

-- Update the column comment
COMMENT ON COLUMN project_daily_logs.log_type IS 'Type of log: visitor, delivery, site_issue, manpower, schedule_delay, observation, note, meeting_minutes';

-- =========================
-- END MIGRATION 018
-- =========================
