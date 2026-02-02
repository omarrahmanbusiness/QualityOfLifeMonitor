# Supabase Setup and Troubleshooting Guide

## Initial Setup

### 1. Create Configuration.swift

A `Configuration.swift` file has been created for you with placeholder values. You need to update it with your actual Supabase credentials:

1. Open `QualityOfLifeMonitor/Configuration.swift`
2. Go to your Supabase project dashboard: https://app.supabase.com
3. Navigate to: **Project Settings** → **API**
4. Copy the following values:
   - **Project URL** → Replace `YOUR_SUPABASE_URL`
   - **anon/public key** → Replace `YOUR_SUPABASE_ANON_KEY`

Example:
```swift
enum Config {
    static let supabaseURL = "https://abcdefghijklmno.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    static let emailRedirectURL = "qualityoflifemonitor://auth/callback"
}
```

### 2. Set Up Database Schema

Run the following SQL scripts **in order** in your Supabase SQL Editor:

1. **First:** `supabase_schema.sql` - Creates all tables, indexes, and views
2. **Second:** `supabase_auth_schema.sql` - Adds authentication and RLS policies
3. **Third:** `supabase_security_migration.sql` - Additional security settings

To run these:
1. Go to your Supabase dashboard
2. Click **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy and paste the contents of each file
5. Click **Run** or press `Cmd/Ctrl + Enter`

### 3. Verify Schema Setup

After running the schema files, verify everything is correct:

1. Go to Supabase SQL Editor
2. Run the verification script: `verify_supabase_schema.sql`
3. Check that all 7 queries return the expected results

---

## Troubleshooting Schema Error

### Issue: "The schema must be one of the following: public, graphql_public, graphql"

This error in the Supabase Table Editor can be caused by several issues:

#### Solution 1: Check Schema Setting in Table Editor

1. In the Supabase dashboard, go to **Table Editor**
2. Look at the top where it says `schema: public`
3. Make sure it's set to **public** (not graphql_public or graphql)
4. If it's set to something else, click the dropdown and select **public**

#### Solution 2: Clear Browser Cache

Sometimes the Supabase dashboard caches schema information incorrectly:

1. Clear your browser cache and cookies for `supabase.com`
2. Log out of Supabase
3. Log back in
4. Try accessing the Table Editor again

#### Solution 3: Verify Project URL

If you recently reset your Supabase URL:

1. Double-check you're using the correct project URL
2. Go to: **Project Settings** → **General** → **Reference ID**
3. Your URL should be: `https://[reference-id].supabase.co`
4. Update `Configuration.swift` if the URL changed

#### Solution 4: Check Database Schema

Verify tables are in the correct schema:

1. Go to **SQL Editor**
2. Run this query:
```sql
SELECT schemaname, tablename
FROM pg_tables
WHERE tablename IN ('patients', 'health_samples', 'locations', 'screen_time', 'heart_failure_events')
ORDER BY tablename;
```
3. All tables should show `schemaname = public`

#### Solution 5: Recreate Missing Tables

If tables are missing or in the wrong schema:

1. **Backup any existing data first!**
2. Drop the incorrect tables (if any):
```sql
DROP TABLE IF EXISTS [schema_name].[table_name] CASCADE;
```
3. Re-run `supabase_schema.sql` and `supabase_auth_schema.sql`

#### Solution 6: Check for Multiple Projects

If you have multiple Supabase projects:

1. Make sure you're viewing the correct project
2. Check the project name in the top-left of the dashboard
3. Verify the project URL in **Project Settings** → **API**
4. Update `Configuration.swift` with the correct project's credentials

---

## Common Setup Issues

### Issue: "Could not connect to Supabase"

**Possible causes:**
- Missing or incorrect `Configuration.swift`
- Wrong Supabase URL or API key
- Network connectivity issues

**Solutions:**
1. Verify `Configuration.swift` has correct values
2. Check that your Supabase project is active (not paused)
3. Try accessing your Supabase dashboard to confirm it's working
4. Check your device has internet connectivity

### Issue: "Unauthorized" or "JWT expired"

**Possible causes:**
- RLS policies not set up correctly
- Invalid or expired access token

**Solutions:**
1. Re-run `supabase_auth_schema.sql` to recreate RLS policies
2. Sign out and sign back in to get a fresh token
3. Verify RLS policies with:
```sql
SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';
```

### Issue: "Patient creation failed"

**Possible causes:**
- RLS policies blocking insert
- Missing user_id column
- Invalid foreign key reference

**Solutions:**
1. Verify the `patients` table has the `user_id` column:
```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'patients' AND table_schema = 'public';
```
2. Check RLS policies allow inserts:
```sql
SELECT * FROM pg_policies WHERE tablename = 'patients' AND cmd = 'INSERT';
```

---

## Testing Your Setup

After completing the setup, test the connection:

1. Build and run the iOS app
2. Sign up with a new account using the invite code: `shariqomar`
3. Grant the required permissions (Location, Health, Screen Time)
4. Check the **Profile** tab to verify your user ID
5. Tap **Sync Now** to test data synchronization
6. Go to your Supabase dashboard → **Table Editor**
7. Check that data appears in the `patients` table

---

## Deep Link Configuration

For password reset and email confirmation to work:

### 1. Configure Redirect URLs in Supabase

1. Go to **Authentication** → **URL Configuration**
2. Add to **Redirect URLs**:
   - `qualityoflifemonitor://auth/callback`
   - `qualityoflifemonitor://reset-password`

### 2. Verify Info.plist

Check that your `Info.plist` includes:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>qualityoflifemonitor</string>
        </array>
    </dict>
</array>
```

---

## Need More Help?

If you're still experiencing issues:

1. Check the Supabase logs:
   - Go to **Logs** → **API Logs** in your dashboard
   - Look for error messages related to your requests

2. Check the app logs:
   - Run the app in Xcode
   - Look for log messages from `FileLogger` or `AuthManager`

3. Verify your schema matches the expected structure:
   - Run `verify_supabase_schema.sql` in SQL Editor
   - Compare results with the "Expected result" comments

4. Common fix for most schema issues:
   ```sql
   -- Reset search path
   ALTER DATABASE postgres SET search_path TO "$user", public;

   -- Grant permissions
   GRANT USAGE ON SCHEMA public TO anon, authenticated;
   GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
   ```
