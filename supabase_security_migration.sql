-- Supabase Security Migration - Row Level Security Policies
-- Run AFTER supabase_schema.sql
-- This adds comprehensive RLS policies for patient data protection

-- ============================================
-- ENSURE RLS IS ENABLED (idempotent)
-- ============================================
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE screen_time ENABLE ROW LEVEL SECURITY;
ALTER TABLE heart_failure_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_history ENABLE ROW LEVEL SECURITY;

-- ============================================
-- DROP EXISTING POLICIES (if any)
-- ============================================
DROP POLICY IF EXISTS "Service role full access" ON patients;
DROP POLICY IF EXISTS "Service role full access" ON health_samples;
DROP POLICY IF EXISTS "Service role full access" ON locations;
DROP POLICY IF EXISTS "Service role full access" ON screen_time;
DROP POLICY IF EXISTS "Service role full access" ON heart_failure_events;
DROP POLICY IF EXISTS "Service role full access" ON sync_history;

-- ============================================
-- PATIENTS TABLE POLICIES
-- ============================================

-- Service role (app backend) can do everything
CREATE POLICY "patients_service_role_all"
ON patients FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users (clinicians) can read all patients
CREATE POLICY "patients_clinician_select"
ON patients FOR SELECT
TO authenticated
USING (true);

-- Authenticated users can update patient metadata (patient_code, notes)
CREATE POLICY "patients_clinician_update"
ON patients FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Only service role can insert/delete patients (from device sync)
CREATE POLICY "patients_service_role_insert"
ON patients FOR INSERT
TO service_role
WITH CHECK (true);

CREATE POLICY "patients_service_role_delete"
ON patients FOR DELETE
TO service_role
USING (true);

-- ============================================
-- HEALTH SAMPLES TABLE POLICIES
-- ============================================

-- Service role full access (for device sync)
CREATE POLICY "health_samples_service_role_all"
ON health_samples FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Clinicians can read all health samples
CREATE POLICY "health_samples_clinician_select"
ON health_samples FOR SELECT
TO authenticated
USING (true);

-- Clinicians cannot modify health data (read-only for integrity)
-- No INSERT/UPDATE/DELETE policies for authenticated role

-- ============================================
-- LOCATIONS TABLE POLICIES
-- ============================================

-- Service role full access
CREATE POLICY "locations_service_role_all"
ON locations FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Clinicians can read locations
CREATE POLICY "locations_clinician_select"
ON locations FOR SELECT
TO authenticated
USING (true);

-- ============================================
-- SCREEN TIME TABLE POLICIES
-- ============================================

-- Service role full access
CREATE POLICY "screen_time_service_role_all"
ON screen_time FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Clinicians can read screen time data
CREATE POLICY "screen_time_clinician_select"
ON screen_time FOR SELECT
TO authenticated
USING (true);

-- ============================================
-- HEART FAILURE EVENTS TABLE POLICIES
-- ============================================

-- Service role full access
CREATE POLICY "hf_events_service_role_all"
ON heart_failure_events FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Clinicians can read events
CREATE POLICY "hf_events_clinician_select"
ON heart_failure_events FOR SELECT
TO authenticated
USING (true);

-- ============================================
-- SYNC HISTORY TABLE POLICIES
-- ============================================

-- Service role full access
CREATE POLICY "sync_history_service_role_all"
ON sync_history FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Clinicians can view sync history (for debugging/audit)
CREATE POLICY "sync_history_clinician_select"
ON sync_history FOR SELECT
TO authenticated
USING (true);

-- ============================================
-- OPTIONAL: CLINICIAN-PATIENT ASSIGNMENT
-- ============================================
-- Uncomment this section if you want to restrict
-- clinicians to only see their assigned patients

/*
-- Create clinician-patient assignment table
CREATE TABLE IF NOT EXISTS clinician_patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clinician_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(clinician_id, patient_id)
);

ALTER TABLE clinician_patients ENABLE ROW LEVEL SECURITY;

-- Clinicians can only see their assignments
CREATE POLICY "clinician_patients_select"
ON clinician_patients FOR SELECT
TO authenticated
USING (clinician_id = auth.uid());

-- Then update other policies to use this, e.g.:
--
-- DROP POLICY "health_samples_clinician_select" ON health_samples;
-- CREATE POLICY "health_samples_clinician_select"
-- ON health_samples FOR SELECT
-- TO authenticated
-- USING (
--     patient_id IN (
--         SELECT patient_id FROM clinician_patients
--         WHERE clinician_id = auth.uid()
--     )
-- );
*/

-- ============================================
-- VERIFY RLS STATUS
-- ============================================
-- Run this query to verify RLS is properly enabled:
--
-- SELECT schemaname, tablename, rowsecurity
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- AND tablename IN ('patients', 'health_samples', 'locations',
--                   'screen_time', 'heart_failure_events', 'sync_history');
--
-- All should show rowsecurity = true
