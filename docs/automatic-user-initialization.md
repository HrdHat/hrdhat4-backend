# Automatic User Initialization System

**Status**: ✅ DEPLOYED AND READY  
**Created**: 2025-06-08  
**Components**: Database Functions + Edge Function

---

## 🎯 Overview

When a new user successfully creates an account, the system automatically:

1. ✅ **Creates user profile** in `public.user_profiles`
2. ✅ **Forks stock FLRA template** to create user's personal working template
3. ✅ **User can immediately start creating forms** using their personal template

## 🏗️ Architecture

```
User Registration (Supabase Auth)
    ↓ Triggers Auth Hook
user-initialization Edge Function
    ↓ Calls Database Functions
1. initialize_user_setup()
    ├── Creates user_profiles record
    └── Calls fork_stock_flra_template()
        └── Creates personal template copy
    ↓ Result
✅ User Ready to Use App
```

## 📦 Deployed Components

### **1. Database Functions (Migration 004)**

- ✅ `user_has_flra_template(user_id)` - Check if user has personal template
- ✅ `fork_stock_flra_template(user_id)` - Create user's template fork
- ✅ `get_user_flra_template(user_id)` - Get user's personal template
- ✅ `initialize_user_setup(user_id, email, full_name)` - Complete initialization

### **2. Edge Function**

- ✅ **Function Name**: `user-initialization`
- ✅ **URL**: `https://ybonzpfwdcyxbzxkyeji.supabase.co/functions/v1/user-initialization`
- ✅ **Status**: ACTIVE
- ✅ **Version**: 1

## 🔧 Setup Instructions

### **Step 1: Configure Supabase Auth Hooks**

In your Supabase Dashboard:

1. Go to **Auth → Hooks**
2. Create new hook:
   - **Hook Type**: `user.created`
   - **URL**: `https://ybonzpfwdcyxbzxkyeji.supabase.co/functions/v1/user-initialization`
   - **HTTP Method**: `POST`
   - **Enable**: ✅

### **Step 2: Test the System**

```bash
# Test user registration
curl -X POST 'https://ybonzpfwdcyxbzxkyeji.supabase.co/auth/v1/signup' \
  -H 'Content-Type: application/json' \
  -H 'apikey: YOUR_ANON_KEY' \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "data": {
      "full_name": "Test User"
    }
  }'
```

Expected result:

- ✅ User created in `auth.users`
- ✅ Profile created in `public.user_profiles`
- ✅ Personal FLRA template forked in `public.form_definitions`

## 📋 What Happens Automatically

### **During User Registration:**

1. **Supabase Auth** creates user in `auth.users`
2. **Auth Hook** triggers `user-initialization` Edge Function
3. **Edge Function** calls `initialize_user_setup()` with:
   - User ID from auth.users
   - Email from registration
   - Full name from user_metadata (if provided)

### **Database Changes:**

```sql
-- 1. User profile created
INSERT INTO user_profiles (id, email, full_name, created_at, updated_at)
VALUES (user_id, user_email, user_full_name, now(), now());

-- 2. Personal template forked from stock
INSERT INTO form_definitions (
  template_id,              -- New UUID for user's template group
  version,                  -- 1 (user's first version)
  form_name,               -- Copied from stock template
  description,             -- "Personal FLRA template (forked from stock)"
  is_system_template,      -- false (user template)
  created_by,              -- user_id
  status,                  -- 'published' (ready to use)
  forked_from_template_id, -- Reference to stock template
  forked_from_version,     -- Reference to stock version
  definition_jsonb,        -- Complete form structure copied
  validation_rules,        -- Validation rules copied
  -- timestamps auto-set
) SELECT ... FROM stock_template;
```

### **User Can Immediately:**

- ✅ Login and access the app
- ✅ Create new form instances using their personal template
- ✅ Fill out FLRA forms with all 6 modules
- ✅ Upload photos and signatures
- ✅ View their form history
- ✅ Customize their template (Phase 2)

## 🧪 Testing & Verification

### **Manual Test:**

```sql
-- After user registration, verify:

-- 1. User profile exists
SELECT * FROM user_profiles WHERE email = 'test@example.com';

-- 2. User has personal template
SELECT user_has_flra_template('USER_ID_HERE');

-- 3. User's template details
SELECT * FROM get_user_flra_template('USER_ID_HERE');

-- 4. Template is properly forked
SELECT
  id,
  template_id,
  version,
  is_system_template,
  forked_from_template_id,
  created_by
FROM form_definitions
WHERE created_by = 'USER_ID_HERE';
```

### **Edge Function Logs:**

Check function logs for debugging:

```typescript
// View logs via MCP
const logs = await supabase.functions.logs("user-initialization");
```

## 🛡️ Security & Permissions

### **RLS (Row Level Security):**

- ✅ Users can only access their own profiles
- ✅ Users can only access their own templates
- ✅ Users can only create forms from their own templates

### **Function Permissions:**

- ✅ `authenticated` role can call user functions
- ✅ `service_role` can call functions (for Edge Functions)

## 🔄 Fallback Options

### **If Auth Hooks Fail:**

**Option 1: Frontend Initialization**

```typescript
// In your auth store after successful registration
const initializeUser = async (user) => {
  const { data } = await supabase.rpc("initialize_user_setup", {
    user_id: user.id,
    user_email: user.email,
    user_full_name: user.user_metadata?.full_name,
  });

  if (!data.success) {
    console.error("User initialization failed:", data.error);
  }
};
```

**Option 2: Manual Check on Login**

```typescript
// Check if user needs initialization on login
const checkUserSetup = async (userId) => {
  const { data: hasTemplate } = await supabase.rpc("user_has_flra_template", {
    user_id: userId,
  });

  if (!hasTemplate) {
    // Initialize user
    await initializeUser(user);
  }
};
```

## 📝 Maintenance

### **Database Functions:**

- Functions are versioned and immutable
- New changes require new migration files
- Test functions individually before deployment

### **Edge Function:**

- Version controlled in `backend/edge-functions/`
- Deploy updates via MCP connection
- Monitor logs for errors

---

## ✅ System Status

- ✅ **Migration 004**: Applied successfully
- ✅ **Database Functions**: Created and tested
- ✅ **Edge Function**: Deployed and active
- ⚠️ **Auth Hook**: **NEEDS CONFIGURATION** (manual step)
- ⚠️ **Testing**: **NEEDS VERIFICATION** (manual step)

**Next Steps:**

1. Configure Auth Hook in Supabase Dashboard
2. Test with new user registration
3. Verify automatic initialization works
4. Monitor Edge Function logs

The system is ready for automatic user initialization!
