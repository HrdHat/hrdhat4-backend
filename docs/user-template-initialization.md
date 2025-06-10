# User Template Initialization Workflow

**Status**: Implementation Ready  
**Last Updated**: January 6, 2025  
**Prerequisites**: Migration 003_seed_default_flra_template.sql applied

---

## 🎯 Overview

After seeding the stock FLRA template, users need personal copies to customize. This document outlines the initialization workflow.

## 🏗️ Architecture

```
Stock Template (Read-Only)
    ↓ Fork on first use
User's Personal Template (Editable)
    ↓ Create instances from
User's Form Instances (Daily forms)
```

## 📋 Template Initialization Functions

### 1. Check if User Needs Template Initialization

```sql
-- Function to check if user has personal FLRA template
CREATE OR REPLACE FUNCTION user_has_flra_template(user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM form_definitions
        WHERE created_by = user_id
        AND is_system_template = false
        AND definition_jsonb->>'formType' = 'flra'
        AND status = 'published'
    );
END;
$$ LANGUAGE plpgsql;
```

### 2. Fork Stock Template for User

```sql
-- Function to fork stock FLRA template for a user
CREATE OR REPLACE FUNCTION fork_stock_flra_template(user_id uuid)
RETURNS uuid AS $$
DECLARE
    stock_template form_definitions;
    new_template_id uuid;
    new_definition_id uuid;
BEGIN
    -- Get the stock FLRA template
    SELECT * INTO stock_template
    FROM form_definitions
    WHERE is_system_template = true
    AND definition_jsonb->>'formType' = 'flra'
    AND status = 'published'
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock FLRA template not found. Run migration 003 first.';
    END IF;

    -- Generate new template ID for user's fork
    new_template_id := gen_random_uuid();

    -- Create user's personal copy
    INSERT INTO form_definitions (
        template_id,
        version,
        form_name,
        description,
        is_system_template,
        created_by,
        status,
        forked_from_template_id,
        forked_from_version,
        definition_jsonb,
        validation_rules
    ) VALUES (
        new_template_id,
        1, -- User's version 1
        stock_template.form_name,
        'Personal FLRA template (forked from stock)',
        false, -- User template
        user_id,
        'published',
        stock_template.template_id,
        stock_template.version,
        stock_template.definition_jsonb,
        stock_template.validation_rules
    ) RETURNING id INTO new_definition_id;

    RETURN new_definition_id;
END;
$$ LANGUAGE plpgsql;
```

### 3. Get User's FLRA Template

```sql
-- Function to get user's personal FLRA template
CREATE OR REPLACE FUNCTION get_user_flra_template(user_id uuid)
RETURNS form_definitions AS $$
DECLARE
    user_template form_definitions;
BEGIN
    SELECT * INTO user_template
    FROM form_definitions
    WHERE created_by = user_id
    AND is_system_template = false
    AND definition_jsonb->>'formType' = 'flra'
    AND status = 'published'
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User has no FLRA template. Call fork_stock_flra_template() first.';
    END IF;

    RETURN user_template;
END;
$$ LANGUAGE plpgsql;
```

## 🔄 Frontend Integration Workflow

### 1. User Sign-up/First Login

```typescript
// In your auth store or user initialization
const initializeUserDefaults = async (userId: string) => {
  try {
    // Check if user needs template initialization
    const { data: hasTemplate } = await supabase.rpc("user_has_flra_template", {
      user_id: userId,
    });

    if (!hasTemplate) {
      // Fork stock template for user
      const { data: templateId } = await supabase.rpc(
        "fork_stock_flra_template",
        { user_id: userId }
      );

      console.log("Created personal FLRA template:", templateId);
    }
  } catch (error) {
    console.error("Failed to initialize user template:", error);
  }
};
```

### 2. Form Creation

```typescript
// When user creates a new form
const createNewForm = async (userId: string) => {
  try {
    // Get user's personal template
    const { data: userTemplate } = await supabase.rpc(
      "get_user_flra_template",
      { user_id: userId }
    );

    // Create form instance from user's template
    const { data: formInstance } = await supabase
      .from("form_instances")
      .insert({
        form_definition_id: userTemplate.id,
        form_definition_version: userTemplate.version,
        created_by: userId,
        form_data: getDefaultFormData(), // Empty form structure
      })
      .select()
      .single();

    return formInstance;
  } catch (error) {
    console.error("Failed to create form:", error);
    throw error;
  }
};
```

### 3. Template Management UI

```typescript
// Template customization interface
const TemplateManager = () => {
  const [userTemplate, setUserTemplate] = useState(null);
  const [stockTemplate, setStockTemplate] = useState(null);

  const copyStockForm = async () => {
    try {
      // Re-fork from stock template (resets customizations)
      const { data: newTemplateId } = await supabase.rpc(
        "fork_stock_flra_template",
        { user_id: currentUserId }
      );

      // Reload user template
      loadUserTemplate();
    } catch (error) {
      console.error("Failed to copy stock form:", error);
    }
  };

  return (
    <div>
      <h2>My FLRA Form Template</h2>
      <button onClick={copyStockForm}>
        📋 Copy Stock Form (Reset to Default)
      </button>
      {/* Template customization UI */}
    </div>
  );
};
```

## 🛠️ Utility Functions

### Default Form Data Structure

```typescript
// Function to generate empty form data structure
const getDefaultFormData = () => ({
  modules: {
    generalInformation: {
      project_name: { value: "", helperText1: "", helperText2: "" },
      task_location: { value: "", helperText1: "", helperText2: "" },
      supervisor_name: { value: "", helperText1: "", helperText2: "" },
      supervisor_contact: { value: "", helperText1: "", helperText2: "" },
      todays_date: { value: "", helperText1: "", helperText2: "" },
      crew_members: { value: "", helperText1: "", helperText2: "" },
      todays_task: { value: "", helperText1: "", helperText2: "" },
      start_time: { value: "", helperText1: "", helperText2: "" },
      end_time: { value: "", helperText1: "", helperText2: "" },
    },
    preJobChecklist: {
      // All 20 boolean fields with false default
      well_rested: { value: false, helperText1: "", helperText2: "" },
      trained_competent: { value: false, helperText1: "", helperText2: "" },
      // ... etc for all 20 fields
    },
    ppeAndPlatform: {
      // All 17 boolean fields with false default
      hard_hat: { value: false, helperText1: "", helperText2: "" },
      safety_glasses: { value: false, helperText1: "", helperText2: "" },
      // ... etc for all 17 fields
    },
    taskHazardControl: {
      entries: [], // Empty array, user adds entries dynamically
    },
    photos: [], // Array of form_photos.id references
    signatures: [], // Array of form_signatures.id references
  },
});
```

### Module Constraints Configuration

**Important**: Module constraints (file sizes, limits, etc.) are stored in frontend config, not database templates:

```typescript
// frontend/src/config/moduleConstraints.ts
import { MODULE_CONSTRAINTS } from "@/config/moduleConstraints";

// Photo constraints
const maxPhotos = MODULE_CONSTRAINTS.photos.maxPhotos; // 5
const maxFileSize = MODULE_CONSTRAINTS.photos.maxFileSize; // 5MB

// Signature constraints
const signerRoles = MODULE_CONSTRAINTS.signatures.signerRoles;
const signatureFileSize = MODULE_CONSTRAINTS.signatures.maxFileSize; // 100KB
```

This approach keeps templates clean and business rules maintainable.

## 📝 Implementation Checklist

- [ ] Apply migration 003_seed_default_flra_template.sql
- [ ] Update system_user_id with real admin user UUID
- [ ] Add template management functions to database
- [ ] Implement frontend initialization logic
- [ ] Add template customization UI
- [ ] Test complete user workflow:
  - [ ] New user signup
  - [ ] Template fork creation
  - [ ] Form instance creation
  - [ ] Template customization
  - [ ] Stock template reset

## 🔧 Testing

### Manual Test Sequence

1. **Apply Migration**: Run 003_seed_default_flra_template.sql
2. **Verify Stock Template**: Check is_system_template = true exists
3. **Test Fork Function**: Call fork_stock_flra_template() with test user
4. **Verify User Template**: Check user has personal template
5. **Test Form Creation**: Create form instance from user template
6. **Test Reset**: Fork again to test "copy stock form" functionality

---

**This workflow enables the complete user template initialization system as outlined in your documentation.**
