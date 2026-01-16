-- Migration: 010_add_worker_contact_fields.sql
-- Status: ✅ SUCCESSFULLY APPLIED
-- Date Applied: 2026-01-16
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Applied By: AI Assistant (via MCP Supabase connection)
-- 
-- Description: Adds worker contact fields to FLRA form templates
-- - worker_phone: Worker's phone number (optional, autofill from profile.phone)
-- - worker_email: Worker's email address (optional, autofill from profile.email)
-- - company_name: Company/Subcontractor name (optional, autofill from profile.company)
--
-- All fields are optional (required: false) and support autofill from user_profiles.
-- Existing form instances are unaffected - they use their saved form_data.
-- New forms created after this migration will include these fields.
--
-- Frontend changes: formService.ts getAutofillData() updated to map profile fields

-- Update all FLRA form definitions to add new contact fields to generalInformation module
UPDATE form_definitions
SET 
  definition_jsonb = jsonb_set(
    definition_jsonb,
    '{modules,generalInformation,fields}',
    definition_jsonb->'modules'->'generalInformation'->'fields' || '{
      "worker_phone": {
        "type": "text",
        "label": "Worker Phone #",
        "required": false,
        "autofill": true,
        "maxLength": 20,
        "placeholder": "Enter your phone number",
        "helperText1": "Your contact phone number.",
        "helperText2": "Can be autofilled from your profile."
      },
      "worker_email": {
        "type": "text",
        "label": "Worker Email",
        "required": false,
        "autofill": true,
        "maxLength": 100,
        "placeholder": "Enter your email address",
        "helperText1": "Your email address.",
        "helperText2": "Can be autofilled from your profile."
      },
      "company_name": {
        "type": "text",
        "label": "Company / Subcontractor",
        "required": false,
        "autofill": true,
        "maxLength": 100,
        "placeholder": "Enter company or subcontractor name",
        "helperText1": "Your company or subcontractor name.",
        "helperText2": "Can be autofilled from your profile."
      }
    }'::jsonb
  ),
  updated_at = NOW()
WHERE definition_jsonb->'formType' ? 'flra'
   OR definition_jsonb->>'formType' = 'flra';
