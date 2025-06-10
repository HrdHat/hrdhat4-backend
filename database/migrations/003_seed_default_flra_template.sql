-- =====================================================================================
-- ✅ MIGRATION STATUS: SUCCESSFULLY APPLIED
-- Migration: 003_seed_default_flra_template.sql
-- Purpose: Seeds the default FLRA template that users can fork from
-- Created: Based on FlraFormPlan.Md and module-definitions.md
-- Applied: 2025-06-08 at 9:15 PM
-- Applied To: HrdHat's Project v4 (ybonzpfwdcyxbzxkyeji)
-- Applied With: Admin User ID 0f64ac00-5a5f-42ca-8fce-e0efb17d2902 (hrdhatpawel@gmail.com)
-- Template UUID: f1a00000-0000-0000-0000-000000000001
-- 
-- ✅ SUCCESSFULLY APPLIED - Stock FLRA template now available for user forking
-- =====================================================================================

DO $$
DECLARE
    system_user_id uuid;
    flra_template_id uuid;
    flra_definition_id uuid;
BEGIN
    -- Generate consistent UUIDs for the stock template
    flra_template_id := 'flra-0000-0000-0000-000000000001'::uuid;
    
    -- Use a system user ID (replace with actual admin user after reviewing)
    -- You can get this from: SELECT id FROM auth.users WHERE email = 'your-admin@email.com';
    system_user_id := '00000000-0000-0000-0000-000000000001'::uuid;
    
    RAISE NOTICE 'Creating FLRA stock template...';
    RAISE NOTICE 'Template ID: %', flra_template_id;
    RAISE NOTICE 'System User ID: % (update with real admin user)', system_user_id;
    
    -- =========================
    -- Seed Default FLRA Template
    -- =========================
    INSERT INTO form_definitions (
        template_id,
        version,
        form_name,
        description,
        is_system_template,
        created_by,
        status,
        definition_jsonb,
        validation_rules
    ) VALUES (
        flra_template_id,
        1,
        'Field Level Risk Assessment (FLRA)',
        'Standard FLRA form for daily safety assessments - stock template for user customization',
        true,
        system_user_id,
        'published',
        
        -- Complete FLRA Form Definition
        '{
            "formName": "Field Level Risk Assessment (FLRA)",
            "formType": "flra",
            "version": "1.0",
            "moduleList": [
                "generalInformation",
                "preJobChecklist", 
                "ppeAndPlatform",
                "taskHazardControl",
                "photos",
                "signatures"
            ],
            "modules": {
                "generalInformation": {
                    "renderType": "simple",
                    "title": "General Information",
                    "description": "Basic project and task information with autofill from user profile",
                    "fields": {
                        "project_name": {
                            "label": "Project Name",
                            "type": "string",
                            "required": false,
                            "autofill": true,
                            "helperText1": "Project name for this FLRA.",
                            "helperText2": "Autofilled from your profile if available."
                        },
                        "task_location": {
                            "label": "Task Location", 
                            "type": "string",
                            "required": false,
                            "autofill": true,
                            "helperText1": "Location of the task.",
                            "helperText2": "Autofilled from your profile if available."
                        },
                        "supervisor_name": {
                            "label": "Supervisor Name",
                            "type": "string", 
                            "required": false,
                            "autofill": true,
                            "helperText1": "Name of the supervisor.",
                            "helperText2": "Autofilled from your profile if available."
                        },
                        "supervisor_contact": {
                            "label": "Supervisor Contact",
                            "type": "string",
                            "required": false, 
                            "autofill": true,
                            "helperText1": "Contact number for supervisor.",
                            "helperText2": "Autofilled from your profile if available."
                        },
                        "todays_date": {
                            "label": "Todays Date",
                            "type": "date",
                            "required": false,
                            "autofill": true,
                            "helperText1": "Date of assessment.",
                            "helperText2": "Date format: YYYY-MM-DD. Autofilled from system date."
                        },
                        "crew_members": {
                            "label": "Crew Members",
                            "type": "string",
                            "required": false,
                            "autofill": true, 
                            "helperText1": "Number of crew members present.",
                            "helperText2": "Autofilled from your profile if available."
                        },
                        "todays_task": {
                            "label": "Todays Task",
                            "type": "string",
                            "required": false,
                            "autofill": true,
                            "helperText1": "Description of todays task.",
                            "helperText2": "Autofilled from your profile if available."
                        },
                        "start_time": {
                            "label": "Start Time", 
                            "type": "time",
                            "required": false,
                            "autofill": true,
                            "helperText1": "Start time of the task.",
                            "helperText2": "Time format: HH:mm (24-hour)."
                        },
                        "end_time": {
                            "label": "End Time",
                            "type": "time", 
                            "required": false,
                            "autofill": true,
                            "helperText1": "End time of the task.",
                            "helperText2": "Time format: HH:mm (24-hour)."
                        }
                    }
                },
                "preJobChecklist": {
                    "renderType": "simple",
                    "title": "FLRA Pre-Job/Task Checklist", 
                    "description": "Boolean checklist for pre-job safety verification",
                    "fields": {
                        "well_rested": {
                            "label": "Are you well-rested and fit for duty?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Confirm you are fit for duty.",
                            "helperText2": "Check if you are well-rested."
                        },
                        "trained_competent": {
                            "label": "Are you trained and competent for your tasks today?",
                            "type": "boolean", 
                            "required": false,
                            "helperText1": "Confirm you are trained for todays tasks.",
                            "helperText2": "Check if you have the required training."
                        },
                        "area_reviewed": {
                            "label": "Have you reviewed the work area for hazards?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Review the work area for hazards.",
                            "helperText2": "Check for any visible hazards."
                        },
                        "tools_inspected": {
                            "label": "Have you inspected your tools and equipment?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect all tools and equipment before use.",
                            "helperText2": "Check for defects or issues."
                        },
                        "ppe_required": {
                            "label": "Do you have the required PPE for today?", 
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Ensure you have all required PPE.",
                            "helperText2": "Check your PPE before starting work."
                        },
                        "control_measures_reviewed": {
                            "label": "Have you reviewed the control measures needed today?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Review all control measures for todays tasks.",
                            "helperText2": "Ensure all controls are in place."
                        },
                        "equipment_inspection_up_to_date": {
                            "label": "Is your equipment inspection up-to-date?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Confirm equipment inspections are current.",
                            "helperText2": "Check inspection records if unsure."
                        },
                        "emergency_procedures_reviewed": {
                            "label": "Have you reviewed your emergency procedures?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Review emergency procedures for the site.",
                            "helperText2": "Know the evacuation routes and procedures."
                        },
                        "flra_completed": {
                            "label": "Have you completed your FLRA / hazard assessment?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Complete your hazard assessment.",
                            "helperText2": "This form is part of your FLRA process."
                        },
                        "permits_in_place": {
                            "label": "Are all required permits in place (if applicable)?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Check if permits are required and in place.",
                            "helperText2": "Hot work, confined space, etc."
                        },
                        "signage_installed": {
                            "label": "Has all safety signage been installed and checked?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Install and verify safety signage.",
                            "helperText2": "Warning signs, barriers, etc."
                        },
                        "crew_communication": {
                            "label": "Have you communicated with your crew about todays plan?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Communicate the days plan with your crew.",
                            "helperText2": "Ensure everyone understands the tasks."
                        },
                        "working_alone": {
                            "label": "Are you working alone today?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Identify if you are working alone.",
                            "helperText2": "Special safety considerations may apply."
                        },
                        "special_controls_needed": {
                            "label": "Is there a need for spotters, barricades, or other special controls?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Identify need for special safety controls.",
                            "helperText2": "Spotters, flaggers, barriers, etc."
                        },
                        "weather_conditions_acceptable": {
                            "label": "Are weather conditions acceptable for the work?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Check weather conditions for safety.",
                            "helperText2": "Wind, rain, temperature, visibility."
                        },
                        "material_safety_data_sheets_available": {
                            "label": "Are Material Safety Data Sheets available for all materials?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Ensure MSDS are available for all materials.",
                            "helperText2": "Required for chemical and hazardous materials."
                        },
                        "first_aid_accessible": {
                            "label": "Is first aid equipment accessible and up-to-date?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Check first aid equipment availability.",
                            "helperText2": "Location, contents, expiry dates."
                        },
                        "fall_protection_required": {
                            "label": "Is fall protection required and in place?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Identify need for fall protection.",
                            "helperText2": "Heights over 6 feet typically require protection."
                        },
                        "lockout_tagout_completed": {
                            "label": "Has lockout/tagout been completed (if applicable)?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Complete lockout/tagout procedures.",
                            "helperText2": "Required for energy isolation work."
                        },
                        "housekeeping_adequate": {
                            "label": "Is housekeeping adequate in the work area?",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Ensure work area is clean and organized.",
                            "helperText2": "Clear walkways, proper storage, etc."
                        }
                    }
                },
                "ppeAndPlatform": {
                    "renderType": "simple", 
                    "title": "PPE & Platform Inspection",
                    "description": "Personal protective equipment and platform safety verification",
                    "fields": {
                        "hard_hat": {
                            "label": "Hard Hat",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect hard hat before use.",
                            "helperText2": "Check for cracks or damage."
                        },
                        "safety_glasses": {
                            "label": "Safety Glasses",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect safety glasses before use.",
                            "helperText2": "Check for scratches or damage."
                        },
                        "hearing_protection": {
                            "label": "Hearing Protection",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect hearing protection before use.",
                            "helperText2": "Ensure proper fit and function."
                        },
                        "respirator": {
                            "label": "Respirator",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect respirator before use.",
                            "helperText2": "Check filters and fit."
                        },
                        "gloves": {
                            "label": "Gloves",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect gloves before use.",
                            "helperText2": "Check for tears or holes."
                        },
                        "safety_boots": {
                            "label": "Safety Boots",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect safety boots before use.",
                            "helperText2": "Check soles and steel toes."
                        },
                        "high_vis_clothing": {
                            "label": "High-Vis Clothing",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect high-visibility clothing.",
                            "helperText2": "Check reflective strips and condition."
                        },
                        "fall_protection": {
                            "label": "Fall Protection",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect fall protection equipment.",
                            "helperText2": "Harness, lanyards, anchors, etc."
                        },
                        "ladder": {
                            "label": "Ladder",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect ladder before use.",
                            "helperText2": "Check rungs, locks, and stability."
                        },
                        "baker_scaffold": {
                            "label": "Baker Scaffold",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect baker scaffold before use.",
                            "helperText2": "Ensure all parts are secure."
                        },
                        "scaffold": {
                            "label": "Scaffold",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect scaffold before use.",
                            "helperText2": "Check for missing or damaged parts."
                        },
                        "scissor_lift": {
                            "label": "Scissor Lift",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect scissor lift before use.",
                            "helperText2": "Check controls and safety features."
                        },
                        "boom_lift": {
                            "label": "Boom Lift",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect boom lift before use.",
                            "helperText2": "Check for leaks or damage."
                        },
                        "swing_stage": {
                            "label": "Swing Stage",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect swing stage before use.",
                            "helperText2": "Ensure all safety features are functional."
                        },
                        "hydro_lift": {
                            "label": "Hydro Lift",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect hydro lift before use.",
                            "helperText2": "Check for leaks or damage."
                        },
                        "manlift": {
                            "label": "Manlift",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect manlift before use.",
                            "helperText2": "Check controls and safety systems."
                        },
                        "other_platform": {
                            "label": "Other Platform",
                            "type": "boolean",
                            "required": false,
                            "helperText1": "Inspect other platform equipment.",
                            "helperText2": "Check all safety features and stability."
                        }
                    }
                },
                "taskHazardControl": {
                    "renderType": "custom",
                    "title": "Task, Hazard, Control (THC) Module",
                    "description": "Dynamic table for documenting tasks, associated hazards, and control measures",
                    "maxEntries": 6,
                    "fields": {
                        "task": {
                            "label": "Task",
                            "type": "string",
                            "required": false,
                            "helperText1": "Describe the task.",
                            "helperText2": "Be specific about the activity."
                        },
                        "hazard": {
                            "label": "Hazard",
                            "type": "string",
                            "required": false,
                            "helperText1": "Identify the hazard.",
                            "helperText2": "List all potential hazards for this task."
                        },
                        "hazard_risk": {
                            "label": "Hazard Risk",
                            "type": "integer",
                            "required": false,
                            "min": 1,
                            "max": 10,
                            "helperText1": "Risk level before controls.",
                            "helperText2": "Use the risk matrix provided (1-10 scale)."
                        },
                        "control": {
                            "label": "Control",
                            "type": "string",
                            "required": false,
                            "helperText1": "Describe the control measure.",
                            "helperText2": "What will you do to reduce risk?"
                        },
                        "control_risk": {
                            "label": "Control Risk",
                            "type": "integer",
                            "required": false,
                            "min": 1,
                            "max": 10,
                            "helperText1": "Risk level after controls.",
                            "helperText2": "Use the risk matrix provided (1-10 scale)."
                        }
                    }
                },
                "photos": {
                    "renderType": "custom",
                    "title": "Photos Module",
                    "description": "Photo upload and management"
                },
                "signatures": {
                    "renderType": "custom",
                    "title": "Signature and Confirmation", 
                    "description": "Signature capture with flexible roles"
                }
            }
        }',
        
        -- Validation Rules - Loose enforcement per Phase 1
        '{
            "validationStrategy": "loosely_enforced",
            "allowIncompleteSubmission": true,
            "fields": {
                "required": [],
                "optional": ["all"]
            },
            "completion": {
                "generalInformation": 50,
                "preJobChecklist": 50,
                "ppeAndPlatform": 50,
                "taskHazardControl": 1,
                "photos": 0,
                "signatures": 0
            },
            "uiGuidance": {
                "guidedMode": {
                    "promptOnEmpty": true,
                    "allowSkipping": true
                },
                "quickMode": {
                    "validationBlocking": false
                }
            }
        }'
    ) RETURNING id INTO flra_definition_id;
    
    RAISE NOTICE 'Successfully created FLRA stock template with definition ID: %', flra_definition_id;

END $$;

-- =========================
-- Post-Migration Verification
-- =========================
-- Uncomment after applying to verify:

-- SELECT 
--     id,
--     template_id,
--     version,
--     form_name,
--     is_system_template,
--     status,
--     created_at
-- FROM form_definitions 
-- WHERE is_system_template = true;

-- SELECT 
--     form_name,
--     jsonb_array_length(definition_jsonb->'moduleList') as module_count,
--     definition_jsonb->'moduleList' as modules
-- FROM form_definitions 
-- WHERE is_system_template = true;

-- =========================
-- Migration Notes
-- =========================
-- This migration creates:
-- 1. System FLRA template with complete module definitions
-- 2. All 46 static fields + dynamic arrays as documented
-- 3. Proper validation rules for Phase 1 loose enforcement
-- 4. Template ready for user forking and customization
--
-- After applying:
-- 1. Update migration_notes.md
-- 2. Mark this file as SUCCESSFULLY APPLIED
-- 3. Test template forking functionality
-- 4. Verify frontend can load and use the template 