-- Verify Supabase Schema Configuration
-- Run this in your Supabase SQL Editor to verify everything is set up correctly

-- ============================================
-- 1. Check if all tables exist in the public schema
-- ============================================
SELECT
    schemaname,
    tablename
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'patients',
        'health_samples',
        'locations',
        'screen_time',
        'heart_failure_events',
        'sync_history',
        'invite_codes'
    )
ORDER BY tablename;

-- Expected result: You should see 7 tables all in the 'public' schema

-- ============================================
-- 2. Verify RLS (Row Level Security) is enabled
-- ============================================
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'patients',
        'health_samples',
        'locations',
        'screen_time',
        'heart_failure_events',
        'sync_history',
        'invite_codes'
    )
ORDER BY tablename;

-- Expected result: All tables should have rls_enabled = true

-- ============================================
-- 3. Check RLS policies exist
-- ============================================
SELECT
    schemaname,
    tablename,
    policyname
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Expected result: Should see multiple policies for each table

-- ============================================
-- 4. Verify functions exist
-- ============================================
SELECT
    n.nspname as schema,
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname IN (
        'validate_invite_code',
        'use_invite_code',
        'get_patient_health_data',
        'get_6mwt_results',
        'delete_user_data'
    )
ORDER BY p.proname;

-- Expected result: Should see all 5 functions

-- ============================================
-- 5. Check invite codes table
-- ============================================
SELECT
    code,
    is_active,
    max_uses,
    current_uses,
    expires_at
FROM invite_codes
WHERE is_active = true;

-- Expected result: Should see at least the 'shariqomar' invite code

-- ============================================
-- 6. Verify search_path (current schema setting)
-- ============================================
SHOW search_path;

-- Expected result: Should include 'public' in the search path
-- Typical result: "$user", public

-- ============================================
-- 7. Check database role
-- ============================================
SELECT current_user, current_schema();

-- Expected result:
--   current_user: Your role (e.g., postgres, authenticator, etc.)
--   current_schema: public

-- ============================================
-- FIXES (Run these if needed)
-- ============================================

-- If tables are missing, you need to run:
-- 1. supabase_schema.sql
-- 2. supabase_auth_schema.sql

-- If RLS is not enabled, run:
-- ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
-- (repeat for all tables)

-- If you need to reset the schema setting:
-- ALTER DATABASE postgres SET search_path TO "$user", public;

-- If the anon or authenticated roles can't access the schema:
-- GRANT USAGE ON SCHEMA public TO anon, authenticated;
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
-- GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
-- GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
