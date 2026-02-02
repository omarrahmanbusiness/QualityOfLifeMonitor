# Fix Supabase Table Editor Schema Error

## The Problem
You're seeing this error in the Supabase Table Editor dashboard:
**"The schema must be one of the following: public, graphql_public, graphql"**

## Quick Fixes (Try in Order)

### Fix 1: Check Schema Selector in Dashboard
1. Open Supabase Dashboard → **Table Editor**
2. Look at the top of the page - there's a schema dropdown (shows "schema: public")
3. Make sure it's set to **public** (not blank or other value)
4. If it shows something else, click it and select **public**

### Fix 2: Verify Your Tables Exist
1. Go to **SQL Editor** in Supabase
2. Run this query:
```sql
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('patients', 'health_samples', 'locations', 'screen_time', 'heart_failure_events', 'sync_history', 'invite_codes')
ORDER BY tablename;
```
3. You should see all 7 tables in the 'public' schema
4. If tables are missing, run the SQL scripts in this order:
   - `supabase_schema.sql`
   - `supabase_auth_schema.sql`
   - `supabase_security_migration.sql`

### Fix 3: Clear Browser Cache
1. Open browser DevTools (F12)
2. Right-click the refresh button → **Empty Cache and Hard Reload**
3. Or clear cache for `supabase.com`:
   - Chrome: Settings → Privacy → Clear browsing data
   - Firefox: Preferences → Privacy → Clear Data
4. Log out and log back into Supabase

### Fix 4: Try Different Browser
Sometimes the Supabase dashboard has caching issues:
1. Open Supabase in an **Incognito/Private window**
2. Or try a different browser entirely
3. Log in and check if Table Editor works

### Fix 5: Verify Project URL
If you recently reset your Supabase URL:
1. Go to **Project Settings** → **General**
2. Check your **Reference ID**
3. Your URL should be: `https://[reference-id].supabase.co`
4. Make sure you're accessing the correct project

### Fix 6: Check if Tables Were Created in Wrong Schema
1. Go to **SQL Editor**
2. Run this to see ALL your tables:
```sql
SELECT schemaname, tablename
FROM pg_tables
WHERE tablename IN ('patients', 'health_samples', 'locations', 'screen_time')
ORDER BY schemaname, tablename;
```
3. If tables are in a different schema (e.g., `auth`, `graphql_public`), you need to move them:
```sql
-- Example: Move table from wrong schema to public
ALTER TABLE wrong_schema.patients SET SCHEMA public;
```

## Still Not Working?

### Nuclear Option: Recreate Tables
**⚠️ WARNING: This will delete all data in these tables!**

1. **Backup your data first** if you have any
2. Go to **SQL Editor**
3. Drop all tables:
```sql
DROP TABLE IF EXISTS sync_history CASCADE;
DROP TABLE IF EXISTS heart_failure_events CASCADE;
DROP TABLE IF EXISTS screen_time CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS health_samples CASCADE;
DROP TABLE IF EXISTS invite_codes CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
```
4. Re-run the schema files:
   - `supabase_schema.sql`
   - `supabase_auth_schema.sql`

## For Next.js Dashboard (If You're Building One)

If you're planning to build a Next.js web dashboard for viewing patient data, you'll need:

### Create `.env.local` file:
```env
# Supabase Configuration (Get from: Project Settings → API)
NEXT_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here

# Service Role Key (Get from: Project Settings → API → service_role key)
# ⚠️ NEVER expose this in client-side code! Only use server-side
SUPABASE_SERVICE_ROLE=your-service-role-key-here

# JWT Secret (Get from: Project Settings → API → JWT Settings)
JWT_SECRET=your-jwt-secret-here

# Site URL (your Next.js app URL)
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

### Get Your Supabase Credentials:
1. Go to Supabase Dashboard
2. Click **Project Settings** (gear icon in left sidebar)
3. Click **API**
4. Copy:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **anon/public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - **service_role key** (click "Reveal") → `SUPABASE_SERVICE_ROLE`
5. Click **JWT Settings** section
6. Copy **JWT Secret** → `JWT_SECRET`

### Security Notes:
- The **anon key** is safe to expose in client-side code (it's public)
- The **service_role key** must NEVER be exposed to clients - only use server-side
- Add `.env.local` to your `.gitignore` (if building Next.js app)

## Current Project Status

Right now, your repository only has:
- ✅ iOS Swift app (`QualityOfLifeMonitor/`)
- ✅ Supabase SQL schema files
- ✅ Configuration template for iOS app

If you want to build a Next.js dashboard, that would be a separate app (or subdirectory).
