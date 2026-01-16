-- Migration: 007_project_subcontractors.sql
-- Purpose: Add subcontractor management for supervisor projects
-- Status: ✅ SUCCESSFULLY APPLIED
-- Date Created: 2026-01-14
-- Date Applied: 2026-01-14
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Author: AI Assistant

-- ============================================================================
-- SUBCONTRACTOR TABLE
-- Tracks subcontractor companies assigned to supervisor projects
-- ============================================================================

CREATE TABLE IF NOT EXISTS project_subcontractors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES supervisor_projects(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL CHECK (length(TRIM(company_name)) > 0),
  contact_name TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  notes TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Each company name should be unique within a project
  UNIQUE(project_id, company_name)
);

-- Add comment for documentation
COMMENT ON TABLE project_subcontractors IS 'Subcontractor companies assigned to supervisor projects for form organization and tracking.';
COMMENT ON COLUMN project_subcontractors.company_name IS 'Name of the subcontractor company - matches AI-extracted companyName from documents.';
COMMENT ON COLUMN project_subcontractors.status IS 'active = currently working on project, inactive = no longer on project but retained for history.';

-- ============================================================================
-- ADD SUBCONTRACTOR LINK TO WORKERS
-- Workers can optionally be linked to a subcontractor company
-- ============================================================================

ALTER TABLE project_workers
ADD COLUMN IF NOT EXISTS subcontractor_id UUID REFERENCES project_subcontractors(id) ON DELETE SET NULL;

COMMENT ON COLUMN project_workers.subcontractor_id IS 'Optional link to the subcontractor company this worker belongs to.';

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Index for fetching subcontractors by project
CREATE INDEX IF NOT EXISTS idx_project_subcontractors_project_id 
ON project_subcontractors(project_id);

-- Index for searching by company name (for document matching)
CREATE INDEX IF NOT EXISTS idx_project_subcontractors_company_name 
ON project_subcontractors(project_id, LOWER(company_name));

-- Index for workers by subcontractor
CREATE INDEX IF NOT EXISTS idx_project_workers_subcontractor_id 
ON project_workers(subcontractor_id) WHERE subcontractor_id IS NOT NULL;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE project_subcontractors ENABLE ROW LEVEL SECURITY;

-- Supervisors can manage subcontractors in their own projects
CREATE POLICY "Supervisors can manage their project subcontractors"
ON project_subcontractors
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM supervisor_projects sp
    WHERE sp.id = project_subcontractors.project_id
    AND sp.supervisor_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM supervisor_projects sp
    WHERE sp.id = project_subcontractors.project_id
    AND sp.supervisor_id = auth.uid()
  )
);

-- ============================================================================
-- ENABLE REALTIME (optional - for live updates)
-- ============================================================================

-- Add to realtime publication for live dashboard updates
ALTER PUBLICATION supabase_realtime ADD TABLE project_subcontractors;

-- ============================================================================
-- END MIGRATION 007
-- ============================================================================
