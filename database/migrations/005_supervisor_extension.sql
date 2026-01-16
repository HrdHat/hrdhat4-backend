-- =====================================================================================
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Date Applied: 2026-01-12
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Status: PRODUCTION READY - DO NOT DELETE OR EDIT THIS FILE
-- 
-- ⚠️  WARNING: THIS MIGRATION HAS BEEN SUCCESSFULLY APPLIED TO THE DATABASE
-- ⚠️  DO NOT MODIFY, DELETE, OR RE-RUN THIS MIGRATION
-- ⚠️  ANY CHANGES REQUIRE A NEW MIGRATION FILE (006_xxx.sql, etc.)
-- 
-- Migration Notes:
-- - Creates 4 new tables for HrdHat Supervisor extension
-- - Adds FK from form_instances.project_id to supervisor_projects
-- - Implements RLS policies for supervisor access to project data
-- - Existing 202 form_instances remain untouched (project_id = NULL)
-- - No destructive changes - ADD only
-- 
-- Verification Results:
-- - 4 tables created: supervisor_projects, project_workers, project_folders, received_documents
-- - All tables have RLS enabled
-- - FK constraint form_instances_supervisor_project_fkey added
-- - 202 existing forms verified untouched (all have project_id = NULL)
-- =====================================================================================

-- =========================
-- 1. supervisor_projects - Construction sites managed by supervisors
-- =========================
CREATE TABLE IF NOT EXISTS supervisor_projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supervisor_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    site_address TEXT,
    processing_email TEXT UNIQUE,  -- {project-slug}@intake.hrdhat.site
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Constraints
    CONSTRAINT project_name_not_empty CHECK (length(trim(name)) > 0)
);

COMMENT ON TABLE supervisor_projects IS 'Construction sites/projects managed by supervisors for form collection and worker management.';
COMMENT ON COLUMN supervisor_projects.processing_email IS 'Unique email address for email intake - documents sent here are automatically processed.';

-- =========================
-- 2. project_workers - Workers assigned to projects
-- =========================
CREATE TABLE IF NOT EXISTS project_workers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES supervisor_projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    added_by UUID NOT NULL REFERENCES auth.users(id),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'removed', 'pending')),
    
    -- Each worker can only be in a project once
    UNIQUE(project_id, user_id)
);

COMMENT ON TABLE project_workers IS 'Links workers to supervisor projects. Workers can be in multiple projects.';
COMMENT ON COLUMN project_workers.status IS 'active = can submit forms, removed = no longer in project, pending = invited but not confirmed';

-- =========================
-- 3. project_folders - Form type categories for organizing documents
-- =========================
CREATE TABLE IF NOT EXISTS project_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES supervisor_projects(id) ON DELETE CASCADE,
    folder_name TEXT NOT NULL,
    description TEXT,
    ai_classification_hint TEXT,  -- Helps AI route documents to this folder
    color TEXT DEFAULT '#6B7280', -- UI color for folder badge
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Folder names must be unique within a project
    UNIQUE(project_id, folder_name),
    CONSTRAINT folder_name_not_empty CHECK (length(trim(folder_name)) > 0)
);

COMMENT ON TABLE project_folders IS 'Categories for organizing forms within a project (e.g., FLRA, Hot Work Permit, Equipment Inspection).';
COMMENT ON COLUMN project_folders.ai_classification_hint IS 'Keywords/description to help AI classify incoming documents into this folder.';

-- =========================
-- 4. received_documents - Email intake documents with AI classification
-- =========================
CREATE TABLE IF NOT EXISTS received_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES supervisor_projects(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES project_folders(id) ON DELETE SET NULL,
    
    -- Source information
    original_filename TEXT,
    storage_path TEXT NOT NULL,
    file_size INTEGER,
    mime_type TEXT,
    source_email TEXT,
    email_subject TEXT,
    
    -- AI processing results
    ai_classification TEXT,          -- What the AI thinks this document is
    ai_extracted_data JSONB DEFAULT '{}',  -- Structured data extracted by AI
    ai_summary TEXT,                 -- AI-generated summary
    confidence_score INTEGER CHECK (confidence_score >= 0 AND confidence_score <= 100),
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'filed', 'needs_review', 'rejected')),
    reviewed_by UUID REFERENCES auth.users(id),
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    -- Timestamps
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    
    CONSTRAINT storage_path_not_empty CHECK (length(trim(storage_path)) > 0)
);

COMMENT ON TABLE received_documents IS 'Documents received via email intake, processed by AI for classification and data extraction.';
COMMENT ON COLUMN received_documents.confidence_score IS 'AI confidence in classification (0-100). Low scores may need manual review.';
COMMENT ON COLUMN received_documents.status IS 'pending = awaiting processing, processing = AI working, filed = in folder, needs_review = low confidence, rejected = invalid document';

-- =========================
-- 5. Add FK from form_instances.project_id to supervisor_projects
-- =========================
-- Note: The project_id column already exists in form_instances (Phase 2 stub)
-- We just need to add the foreign key constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'form_instances_supervisor_project_fkey'
    ) THEN
        ALTER TABLE form_instances 
        ADD CONSTRAINT form_instances_supervisor_project_fkey 
        FOREIGN KEY (project_id) REFERENCES supervisor_projects(id) ON DELETE SET NULL;
    END IF;
END $$;

-- =========================
-- 6. Indexes for performance
-- =========================
CREATE INDEX IF NOT EXISTS idx_supervisor_projects_supervisor_id ON supervisor_projects(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_project_workers_project_id ON project_workers(project_id);
CREATE INDEX IF NOT EXISTS idx_project_workers_user_id ON project_workers(user_id);
CREATE INDEX IF NOT EXISTS idx_project_folders_project_id ON project_folders(project_id);
CREATE INDEX IF NOT EXISTS idx_received_documents_project_id ON received_documents(project_id);
CREATE INDEX IF NOT EXISTS idx_received_documents_folder_id ON received_documents(folder_id);
CREATE INDEX IF NOT EXISTS idx_received_documents_status ON received_documents(status);
CREATE INDEX IF NOT EXISTS idx_received_documents_received_at ON received_documents(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_form_instances_project_id_supervisor ON form_instances(project_id) WHERE project_id IS NOT NULL;

-- =========================
-- 7. Triggers for updated_at
-- =========================
CREATE TRIGGER update_supervisor_projects_updated_at
    BEFORE UPDATE ON supervisor_projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================
-- 8. Row Level Security (RLS)
-- =========================

-- Enable RLS on all new tables
ALTER TABLE supervisor_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE received_documents ENABLE ROW LEVEL SECURITY;

-- ---- supervisor_projects policies ----
-- Supervisors can see/manage their own projects
CREATE POLICY supervisor_own_projects_select ON supervisor_projects
    FOR SELECT USING (supervisor_id = auth.uid());

CREATE POLICY supervisor_own_projects_insert ON supervisor_projects
    FOR INSERT WITH CHECK (supervisor_id = auth.uid());

CREATE POLICY supervisor_own_projects_update ON supervisor_projects
    FOR UPDATE USING (supervisor_id = auth.uid());

CREATE POLICY supervisor_own_projects_delete ON supervisor_projects
    FOR DELETE USING (supervisor_id = auth.uid());

-- Workers can see projects they're assigned to (limited info)
CREATE POLICY worker_view_assigned_projects ON supervisor_projects
    FOR SELECT USING (
        id IN (SELECT project_id FROM project_workers WHERE user_id = auth.uid() AND status = 'active')
    );

-- ---- project_workers policies ----
-- Supervisors can manage workers in their projects
CREATE POLICY supervisor_manage_workers ON project_workers
    FOR ALL USING (
        project_id IN (SELECT id FROM supervisor_projects WHERE supervisor_id = auth.uid())
    );

-- Workers can see their own assignments
CREATE POLICY worker_view_own_assignment ON project_workers
    FOR SELECT USING (user_id = auth.uid());

-- ---- project_folders policies ----
-- Supervisors can manage folders in their projects
CREATE POLICY supervisor_manage_folders ON project_folders
    FOR ALL USING (
        project_id IN (SELECT id FROM supervisor_projects WHERE supervisor_id = auth.uid())
    );

-- Workers can see folders in projects they're assigned to
CREATE POLICY worker_view_folders ON project_folders
    FOR SELECT USING (
        project_id IN (SELECT project_id FROM project_workers WHERE user_id = auth.uid() AND status = 'active')
    );

-- ---- received_documents policies ----
-- Supervisors can manage documents in their projects
CREATE POLICY supervisor_manage_documents ON received_documents
    FOR ALL USING (
        project_id IN (SELECT id FROM supervisor_projects WHERE supervisor_id = auth.uid())
    );

-- ---- form_instances additional policy for supervisor access ----
-- Supervisors can VIEW forms from workers in their projects (NEW forms only - project_id NOT NULL)
CREATE POLICY supervisor_view_project_forms ON form_instances
    FOR SELECT USING (
        project_id IS NOT NULL AND
        project_id IN (SELECT id FROM supervisor_projects WHERE supervisor_id = auth.uid())
    );

-- =====================================================================================
-- END OF MIGRATION 005 - SUPERVISOR EXTENSION
-- =====================================================================================
