-- =====================================================================================
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Date Applied: 2026-01-20
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Status: PRODUCTION READY - DO NOT DELETE OR EDIT THIS FILE
-- 
-- ⚠️  WARNING: THIS MIGRATION HAS BEEN SUCCESSFULLY APPLIED TO THE DATABASE
-- ⚠️  DO NOT MODIFY, DELETE, OR RE-RUN THIS MIGRATION
-- ⚠️  ANY CHANGES REQUIRE A NEW MIGRATION FILE (017_xxx.sql, etc.)
-- =====================================================================================
-- MIGRATION: 016_fix_set_template_id_trigger.sql
-- Purpose: Fix set_template_id trigger to support supervisor forms without form_definitions
-- 
-- Background:
-- The existing set_template_id() trigger always tries to look up template_id from
-- form_definitions based on form_definition_id. This fails when form_definition_id
-- is NULL (supervisor forms). The trigger should only do the lookup when
-- form_definition_id is provided, and otherwise keep the template_id that was passed.
--
-- Changes:
-- 1. Modify set_template_id() to only lookup when form_definition_id is NOT NULL
-- 2. Keep provided template_id when form_definition_id is NULL (supervisor forms)
-- 3. Validate that template_id is provided in either case
-- 
-- ⚠️ WARNING: Apply only to development first. Test thoroughly before production.
-- =====================================================================================

-- =========================
-- 1. Replace the set_template_id function
-- =========================
CREATE OR REPLACE FUNCTION public.set_template_id()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    -- For forms WITH form_definition_id: lookup template_id from form_definitions
    IF NEW.form_definition_id IS NOT NULL THEN
        SELECT template_id INTO NEW.template_id
        FROM form_definitions
        WHERE id = NEW.form_definition_id;
        
        IF NEW.template_id IS NULL THEN
            RAISE EXCEPTION 'Could not find template_id for form_definition_id %', NEW.form_definition_id;
        END IF;
    END IF;
    
    -- For ALL forms: ensure template_id is set (either from lookup or provided directly)
    IF NEW.template_id IS NULL THEN
        RAISE EXCEPTION 'template_id is required. Either provide form_definition_id or template_id directly.';
    END IF;
    
    RETURN NEW;
END;
$function$;

-- Add comment documenting the updated behavior
COMMENT ON FUNCTION public.set_template_id() IS 
'Trigger function that sets template_id for form_instances. 
For worker forms: looks up template_id from form_definitions using form_definition_id.
For supervisor forms: keeps the template_id provided directly (form_definition_id is NULL).';
