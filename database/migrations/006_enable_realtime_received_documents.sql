-- Migration: 006_enable_realtime_received_documents.sql
-- Purpose: Enable Supabase Realtime for the received_documents table
-- Status: ✅ SUCCESSFULLY APPLIED
-- Date Applied: 2026-01-13
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Applied By: AI Assistant (via MCP Supabase connection)
--
-- Description:
--   Adds the received_documents table to the supabase_realtime publication
--   so that supervisors receive real-time updates when new documents arrive
--   via email intake or when document status changes (e.g., auto-filing).
--
-- Dependencies:
--   - 005_supervisor_extension.sql (creates received_documents table)
--
-- Notes:
--   - Postgres Changes will respect existing RLS policies
--   - Supervisors only receive events for documents in their own projects
--   - No schema changes, only publication configuration
-- ============================================================================

-- Add received_documents to the supabase_realtime publication
-- This enables Postgres Changes to stream INSERT, UPDATE, DELETE events
ALTER PUBLICATION supabase_realtime ADD TABLE received_documents;

-- Verification query (run manually after migration):
-- SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
