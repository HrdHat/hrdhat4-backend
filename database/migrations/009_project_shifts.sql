-- Migration: 009_project_shifts.sql
-- Purpose: Add shift management for supervisor projects (Start of Shift feature)
-- Status: ✅ SUCCESSFULLY APPLIED
-- Date Created: 2026-01-16
-- Date Applied: 2026-01-16
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Author: AI Assistant

-- ============================================================================
-- PROJECT SHIFTS TABLE
-- Core shift entity - tracks work shifts for a project
-- ============================================================================

CREATE TABLE IF NOT EXISTS project_shifts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES supervisor_projects(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(TRIM(name)) > 0),
  scheduled_date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'completed', 'cancelled')),
  notes TEXT,
  
  -- Closeout fields
  closeout_checklist JSONB DEFAULT '[]'::jsonb,
  closeout_notes TEXT,
  closed_at TIMESTAMPTZ,
  closed_by UUID REFERENCES auth.users(id),
  incomplete_reason TEXT,
  
  -- Audit fields
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add comments for documentation
COMMENT ON TABLE project_shifts IS 'Work shifts for supervisor projects - enables Start of Shift workflow with worker notification and form tracking.';
COMMENT ON COLUMN project_shifts.name IS 'Flexible shift name (e.g., "Morning - Jan 16", "Night Shift")';
COMMENT ON COLUMN project_shifts.status IS 'draft = not yet started, active = notifications sent, completed = closed out, cancelled = abandoned';
COMMENT ON COLUMN project_shifts.notes IS 'Pre-shift safety notes/briefing sent with notifications';
COMMENT ON COLUMN project_shifts.closeout_checklist IS 'JSON array of checklist items: [{id, label, checked}]';
COMMENT ON COLUMN project_shifts.incomplete_reason IS 'Required reason if shift closed with missing forms';

-- ============================================================================
-- SHIFT WORKERS TABLE
-- Workers assigned to a shift with notification tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS shift_workers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shift_id UUID NOT NULL REFERENCES project_shifts(id) ON DELETE CASCADE,
  
  -- Worker identification
  worker_type TEXT NOT NULL DEFAULT 'adhoc' CHECK (worker_type IN ('registered', 'adhoc')),
  user_id UUID REFERENCES auth.users(id),
  subcontractor_id UUID REFERENCES project_subcontractors(id) ON DELETE SET NULL,
  name TEXT NOT NULL CHECK (length(TRIM(name)) > 0),
  phone TEXT,
  email TEXT,
  
  -- Notification tracking
  notification_method TEXT DEFAULT 'sms' CHECK (notification_method IN ('sms', 'email', 'both')),
  notification_status TEXT DEFAULT 'pending' CHECK (notification_status IN ('pending', 'sent', 'failed', 'delivered')),
  notification_sent_at TIMESTAMPTZ,
  notification_error TEXT,
  
  -- Form submission tracking
  form_submitted BOOLEAN NOT NULL DEFAULT false,
  form_submitted_at TIMESTAMPTZ,
  document_id UUID REFERENCES received_documents(id) ON DELETE SET NULL,
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Constraints
  CONSTRAINT shift_workers_contact_required CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

-- Add comments for documentation
COMMENT ON TABLE shift_workers IS 'Workers assigned to a shift with notification and form submission tracking.';
COMMENT ON COLUMN shift_workers.worker_type IS 'registered = linked to user account, adhoc = one-time contact entry';
COMMENT ON COLUMN shift_workers.name IS 'Display name - can be overridden for adhoc workers or pulled from user_profiles';
COMMENT ON COLUMN shift_workers.notification_method IS 'sms = text message preferred, email = email preferred, both = send both';
COMMENT ON COLUMN shift_workers.notification_status IS 'pending = not sent, sent = delivered to provider, failed = error, delivered = confirmed receipt';
COMMENT ON COLUMN shift_workers.document_id IS 'Links to the received form document when auto-matched';

-- ============================================================================
-- ADD SHIFT_ID TO RECEIVED_DOCUMENTS
-- Links incoming documents to shifts for organized review
-- ============================================================================

ALTER TABLE received_documents
ADD COLUMN IF NOT EXISTS shift_id UUID REFERENCES project_shifts(id) ON DELETE SET NULL;

COMMENT ON COLUMN received_documents.shift_id IS 'Links document to a specific shift for organized review.';

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Project shifts indexes
CREATE INDEX IF NOT EXISTS idx_project_shifts_project_id 
ON project_shifts(project_id);

CREATE INDEX IF NOT EXISTS idx_project_shifts_status 
ON project_shifts(status);

CREATE INDEX IF NOT EXISTS idx_project_shifts_scheduled_date 
ON project_shifts(scheduled_date DESC);

CREATE INDEX IF NOT EXISTS idx_project_shifts_project_date 
ON project_shifts(project_id, scheduled_date DESC);

-- Shift workers indexes
CREATE INDEX IF NOT EXISTS idx_shift_workers_shift_id 
ON shift_workers(shift_id);

CREATE INDEX IF NOT EXISTS idx_shift_workers_user_id 
ON shift_workers(user_id) WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_shift_workers_email 
ON shift_workers(LOWER(email)) WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_shift_workers_phone 
ON shift_workers(phone) WHERE phone IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_shift_workers_form_submitted 
ON shift_workers(shift_id, form_submitted);

-- Received documents shift index
CREATE INDEX IF NOT EXISTS idx_received_documents_shift_id 
ON received_documents(shift_id) WHERE shift_id IS NOT NULL;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE project_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE shift_workers ENABLE ROW LEVEL SECURITY;

-- Supervisors can manage shifts in their own projects
CREATE POLICY "Supervisors can manage their project shifts"
ON project_shifts
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM supervisor_projects sp
    WHERE sp.id = project_shifts.project_id
    AND sp.supervisor_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM supervisor_projects sp
    WHERE sp.id = project_shifts.project_id
    AND sp.supervisor_id = auth.uid()
  )
);

-- Supervisors can manage shift workers in their project shifts
CREATE POLICY "Supervisors can manage shift workers"
ON shift_workers
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM project_shifts ps
    JOIN supervisor_projects sp ON sp.id = ps.project_id
    WHERE ps.id = shift_workers.shift_id
    AND sp.supervisor_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM project_shifts ps
    JOIN supervisor_projects sp ON sp.id = ps.project_id
    WHERE ps.id = shift_workers.shift_id
    AND sp.supervisor_id = auth.uid()
  )
);

-- ============================================================================
-- UPDATED_AT TRIGGERS
-- ============================================================================

-- Trigger function (reuse if exists, create if not)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for project_shifts
DROP TRIGGER IF EXISTS update_project_shifts_updated_at ON project_shifts;
CREATE TRIGGER update_project_shifts_updated_at
  BEFORE UPDATE ON project_shifts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for shift_workers
DROP TRIGGER IF EXISTS update_shift_workers_updated_at ON shift_workers;
CREATE TRIGGER update_shift_workers_updated_at
  BEFORE UPDATE ON shift_workers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ENABLE REALTIME
-- ============================================================================

-- Add to realtime publication for live dashboard updates
ALTER PUBLICATION supabase_realtime ADD TABLE project_shifts;
ALTER PUBLICATION supabase_realtime ADD TABLE shift_workers;

-- ============================================================================
-- END MIGRATION 009
-- ============================================================================
