-- =====================================================================================
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Date Applied: 2025-06-06
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Status: PRODUCTION READY - DO NOT DELETE OR EDIT THIS FILE
-- 
-- ⚠️  WARNING: THIS MIGRATION HAS BEEN SUCCESSFULLY APPLIED TO THE DATABASE
-- ⚠️  DO NOT MODIFY, DELETE, OR RE-RUN THIS MIGRATION
-- ⚠️  ANY CHANGES REQUIRE A NEW MIGRATION FILE (003_xxx.sql, 004_xxx.sql, etc.)
-- 
-- Migration Notes:
-- - Created form_signatures table with flexible role field (signer_role)
-- - Implemented immutable signatures (no delete capability for audit compliance)
-- - Added Row Level Security policies following form_photos pattern
-- - Created indexes for performance (form lookup, type/date queries)
-- - Added helper function get_signature_count for frontend use
-- - Signature storage: max 100KB per signature in Supabase Storage
-- =====================================================================================

-- =========================
-- 3b. form_signatures - SIGNATURE STORAGE TABLE
-- =========================
create table if not exists form_signatures (
    id uuid primary key default gen_random_uuid(),
    form_instance_id uuid not null references form_instances(id) on delete cascade,
    signer_type text not null check (signer_type in ('worker', 'supervisor')), -- kept for backwards compatibility
    signer_role text not null, -- flexible role field sent by frontend (e.g., 'worker', 'supervisor', 'management', 'safety_officer', etc.)
    signer_name text not null,
    signer_email text, -- optional, for linking to user profiles
    storage_path text not null, -- Supabase Storage path to PNG file
    file_size integer not null check (file_size <= 102400), -- 100KB max per signature
    signature_metadata jsonb default '{}', -- canvas dimensions, compression info, etc.
    signed_at timestamptz not null default now(),
    created_by uuid not null references auth.users(id), -- who captured this signature
    
    -- Constraints
    constraint signature_name_not_empty check (length(trim(signer_name)) > 0),
    constraint signature_storage_path_not_empty check (length(trim(storage_path)) > 0),
    constraint signature_role_not_empty check (length(trim(signer_role)) > 0)
);

comment on table form_signatures is 'Stores signature metadata and references to Supabase Storage files. Signatures are IMMUTABLE once created for audit compliance - no deletions allowed.';
comment on column form_signatures.signer_type is 'Legacy field kept for backwards compatibility - maps to worker/supervisor';
comment on column form_signatures.signer_role is 'Flexible role field sent by frontend (e.g., worker, supervisor, management, safety_officer, foreman, etc.)';

-- =========================
-- Row Level Security (RLS) for form_signatures
-- =========================
alter table form_signatures enable row level security;

-- Users can only view signatures for forms they created
create policy select_own_form_signatures on form_signatures
    for select using (
        exists (
            select 1 from form_instances fi 
            where fi.id = form_signatures.form_instance_id 
            and fi.created_by = auth.uid()
        )
    );

-- Users can only create signatures for forms they created
create policy insert_own_form_signatures on form_signatures
    for insert with check (
        exists (
            select 1 from form_instances fi 
            where fi.id = form_signatures.form_instance_id 
            and fi.created_by = auth.uid()
        )
    );

-- ✅ NO DELETE POLICY - Signatures are immutable once created for audit compliance
-- Signatures cannot be deleted once signed to maintain audit trail

-- =========================
-- Indexes for Performance
-- =========================

-- Index for finding signatures by form (matches photo table pattern)
create index idx_form_signatures_form_instance_id 
    on form_signatures(form_instance_id);

-- Index for finding signatures by type and date
create index idx_form_signatures_type_date 
    on form_signatures(form_instance_id, signer_type, signed_at desc);

-- =========================
-- Helper Functions
-- =========================

-- Function to get signature count for a form
create or replace function get_signature_count(p_form_instance_id uuid, p_signer_type text default null)
returns integer as $$
begin
    if p_signer_type is null then
        return (select count(*) from form_signatures where form_instance_id = p_form_instance_id);
    else
        return (select count(*) from form_signatures where form_instance_id = p_form_instance_id and signer_type = p_signer_type);
    end if;
end;
$$ language plpgsql; 