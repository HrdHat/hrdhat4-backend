-- =====================================================================================
-- MIGRATION STATUS: PENDING - NOT YET APPLIED
-- Purpose: Add has_supervisor_access flag to user_profiles for future paywall
-- Date Created: 2026-01-14
-- 
-- ⚠️  DO NOT APPLY THIS MIGRATION UNTIL PAYWALL IS READY TO BE IMPLEMENTED
-- ⚠️  This is a preparatory migration for future supervisor access gating
-- 
-- Migration Notes:
-- - Adds has_supervisor_access boolean column to user_profiles
-- - Default value is false (users don't automatically get supervisor access)
-- - Can be updated via Supabase dashboard, API, or Stripe webhook
-- - Future: RLS policies can use this flag to gate supervisor features
-- =====================================================================================

-- =========================
-- 1. Add has_supervisor_access column to user_profiles
-- =========================
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS has_supervisor_access BOOLEAN DEFAULT false;

COMMENT ON COLUMN user_profiles.has_supervisor_access IS 'Whether the user has paid for supervisor dashboard access. Default false.';

-- =========================
-- 2. Create index for efficient lookups
-- =========================
CREATE INDEX IF NOT EXISTS idx_user_profiles_supervisor_access 
ON user_profiles(has_supervisor_access) 
WHERE has_supervisor_access = true;

-- =========================
-- 3. (Optional) Grant existing project owners supervisor access
-- Uncomment and run if you want to automatically grant access to users
-- who already have supervisor_projects
-- =========================
-- UPDATE user_profiles 
-- SET has_supervisor_access = true 
-- WHERE id IN (
--     SELECT DISTINCT supervisor_id 
--     FROM supervisor_projects 
--     WHERE is_active = true
-- );

-- =====================================================================================
-- USAGE NOTES:
-- 
-- To grant supervisor access to a user:
--   UPDATE user_profiles SET has_supervisor_access = true WHERE id = 'user-uuid';
--
-- To check if user has supervisor access in RLS:
--   CREATE POLICY supervisor_only ON some_table
--     FOR ALL USING (
--       EXISTS (
--         SELECT 1 FROM user_profiles 
--         WHERE id = auth.uid() 
--         AND has_supervisor_access = true
--       )
--     );
--
-- To check in frontend:
--   const { data } = await supabase
--     .from('user_profiles')
--     .select('has_supervisor_access')
--     .eq('id', user.id)
--     .single();
--
-- =====================================================================================
-- END OF MIGRATION 008 - SUPERVISOR ACCESS FLAG
-- =====================================================================================
