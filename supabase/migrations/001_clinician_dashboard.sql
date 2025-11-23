-- Clinician Dashboard Schema Migration
-- This migration adds support for clinician accounts, patient-clinician relationships,
-- and clinician-only notes

-- =====================================================
-- 1. CLINICIANS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS clinicians (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    organization TEXT,
    is_superuser BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT clinicians_user_id_unique UNIQUE (user_id),
    CONSTRAINT clinicians_email_unique UNIQUE (email)
);

-- Indexes for clinicians
CREATE INDEX IF NOT EXISTS idx_clinicians_user_id ON clinicians(user_id);
CREATE INDEX IF NOT EXISTS idx_clinicians_email ON clinicians(email);
CREATE INDEX IF NOT EXISTS idx_clinicians_is_active ON clinicians(is_active);

-- =====================================================
-- 2. UPDATE PATIENTS TABLE - Add clinician_id
-- =====================================================

ALTER TABLE patients
ADD COLUMN IF NOT EXISTS clinician_id UUID REFERENCES clinicians(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_patients_clinician_id ON patients(clinician_id);

-- =====================================================
-- 3. CLINICIAN NOTES TABLE (clinician-only visibility)
-- =====================================================

CREATE TABLE IF NOT EXISTS clinician_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    clinician_id UUID NOT NULL REFERENCES clinicians(id) ON DELETE CASCADE,
    note TEXT NOT NULL,
    note_type TEXT DEFAULT 'general', -- 'general', 'heart_failure_event', 'observation'
    related_event_id UUID REFERENCES heart_failure_events(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for clinician_notes
CREATE INDEX IF NOT EXISTS idx_clinician_notes_patient_id ON clinician_notes(patient_id);
CREATE INDEX IF NOT EXISTS idx_clinician_notes_clinician_id ON clinician_notes(clinician_id);
CREATE INDEX IF NOT EXISTS idx_clinician_notes_created_at ON clinician_notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clinician_notes_related_event ON clinician_notes(related_event_id);

-- =====================================================
-- 4. UPDATE HEART_FAILURE_EVENTS - Add logged_by field
-- =====================================================

ALTER TABLE heart_failure_events
ADD COLUMN IF NOT EXISTS logged_by_clinician_id UUID REFERENCES clinicians(id) ON DELETE SET NULL;

ALTER TABLE heart_failure_events
ADD COLUMN IF NOT EXISTS event_source TEXT DEFAULT 'patient'; -- 'patient' or 'clinician'

CREATE INDEX IF NOT EXISTS idx_hf_events_logged_by ON heart_failure_events(logged_by_clinician_id);

-- =====================================================
-- 5. UPDATE INVITE_CODES - Link to clinician
-- =====================================================

-- Add clinician_id to invite_codes for clearer relationship
ALTER TABLE invite_codes
ADD COLUMN IF NOT EXISTS clinician_id UUID REFERENCES clinicians(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_invite_codes_clinician_id ON invite_codes(clinician_id);

-- =====================================================
-- 6. HELPER FUNCTIONS
-- =====================================================

-- Function to check if a user is a clinician
CREATE OR REPLACE FUNCTION is_clinician(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM clinicians
        WHERE user_id = user_uuid AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a user is a superuser
CREATE OR REPLACE FUNCTION is_superuser(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM clinicians
        WHERE user_id = user_uuid AND is_superuser = TRUE AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get clinician_id from user_id
CREATE OR REPLACE FUNCTION get_clinician_id(user_uuid UUID)
RETURNS UUID AS $$
DECLARE
    clin_id UUID;
BEGIN
    SELECT id INTO clin_id FROM clinicians
    WHERE user_id = user_uuid AND is_active = TRUE;
    RETURN clin_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if clinician can access patient
CREATE OR REPLACE FUNCTION clinician_can_access_patient(user_uuid UUID, patient_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Superusers can access all patients
    IF is_superuser(user_uuid) THEN
        RETURN TRUE;
    END IF;

    -- Regular clinicians can only access their own patients
    RETURN EXISTS (
        SELECT 1 FROM patients p
        JOIN clinicians c ON c.id = p.clinician_id
        WHERE p.id = patient_uuid
        AND c.user_id = user_uuid
        AND c.is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. UPDATED VIEWS FOR CLINICIAN DASHBOARD
-- =====================================================

-- Drop existing views to recreate with clinician support
DROP VIEW IF EXISTS patient_summary CASCADE;
DROP VIEW IF EXISTS daily_health_summary CASCADE;
DROP VIEW IF EXISTS daily_activity_summary CASCADE;

-- Patient summary with clinician info
CREATE VIEW patient_summary AS
SELECT
    p.id,
    p.device_id,
    p.email,
    p.patient_code,
    p.notes,
    p.created_at,
    p.clinician_id,
    c.name as clinician_name,
    c.email as clinician_email,
    (SELECT COUNT(*) FROM health_samples WHERE patient_id = p.id) as total_health_samples,
    (SELECT COUNT(*) FROM locations WHERE patient_id = p.id) as total_locations,
    (SELECT COUNT(*) FROM screen_time WHERE patient_id = p.id) as total_screen_time_records,
    (SELECT COUNT(*) FROM heart_failure_events WHERE patient_id = p.id) as total_hf_events,
    (SELECT MAX(synced_at) FROM health_samples WHERE patient_id = p.id) as last_health_sync,
    (SELECT MAX(synced_at) FROM locations WHERE patient_id = p.id) as last_location_sync
FROM patients p
LEFT JOIN clinicians c ON p.clinician_id = c.id;

-- Daily health summary
CREATE VIEW daily_health_summary AS
SELECT
    patient_id,
    DATE(start_date) as date,
    sample_type,
    COUNT(*) as sample_count,
    AVG(value) as avg_value,
    MIN(value) as min_value,
    MAX(value) as max_value,
    unit
FROM health_samples
GROUP BY patient_id, DATE(start_date), sample_type, unit;

-- Daily activity summary
CREATE VIEW daily_activity_summary AS
SELECT
    patient_id,
    DATE(start_date) as date,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierStepCount' THEN value ELSE 0 END) as total_steps,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierActiveEnergyBurned' THEN value ELSE 0 END) as total_calories,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierDistanceWalkingRunning' THEN value ELSE 0 END) as total_distance,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierFlightsClimbed' THEN value ELSE 0 END) as flights_climbed
FROM health_samples
WHERE sample_type IN (
    'HKQuantityTypeIdentifierStepCount',
    'HKQuantityTypeIdentifierActiveEnergyBurned',
    'HKQuantityTypeIdentifierDistanceWalkingRunning',
    'HKQuantityTypeIdentifierFlightsClimbed'
)
GROUP BY patient_id, DATE(start_date);

-- Clinician dashboard overview
CREATE VIEW clinician_dashboard_overview AS
SELECT
    c.id as clinician_id,
    c.user_id,
    c.name as clinician_name,
    COUNT(DISTINCT p.id) as total_patients,
    COUNT(DISTINCT CASE WHEN p.created_at > NOW() - INTERVAL '7 days' THEN p.id END) as new_patients_week,
    COUNT(DISTINCT hfe.id) as total_hf_events,
    COUNT(DISTINCT CASE WHEN hfe.timestamp > NOW() - INTERVAL '7 days' THEN hfe.id END) as hf_events_week
FROM clinicians c
LEFT JOIN patients p ON p.clinician_id = c.id
LEFT JOIN heart_failure_events hfe ON hfe.patient_id = p.id
WHERE c.is_active = TRUE
GROUP BY c.id, c.user_id, c.name;

-- =====================================================
-- 8. RLS POLICIES FOR CLINICIANS
-- =====================================================

-- Enable RLS on new tables
ALTER TABLE clinicians ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinician_notes ENABLE ROW LEVEL SECURITY;

-- Clinicians table policies
CREATE POLICY "Service role has full access to clinicians"
    ON clinicians FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Clinicians can view their own record"
    ON clinicians FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Superusers can view all clinicians"
    ON clinicians FOR SELECT
    USING (is_superuser(auth.uid()));

CREATE POLICY "Superusers can manage clinicians"
    ON clinicians FOR ALL
    USING (is_superuser(auth.uid()));

-- Clinician notes policies
CREATE POLICY "Service role has full access to clinician_notes"
    ON clinician_notes FOR ALL
    USING (auth.role() = 'service_role');

CREATE POLICY "Clinicians can view notes for their patients"
    ON clinician_notes FOR SELECT
    USING (
        is_superuser(auth.uid()) OR
        clinician_id = get_clinician_id(auth.uid()) OR
        clinician_can_access_patient(auth.uid(), patient_id)
    );

CREATE POLICY "Clinicians can create notes for their patients"
    ON clinician_notes FOR INSERT
    WITH CHECK (
        clinician_can_access_patient(auth.uid(), patient_id)
    );

CREATE POLICY "Clinicians can update their own notes"
    ON clinician_notes FOR UPDATE
    USING (clinician_id = get_clinician_id(auth.uid()));

CREATE POLICY "Clinicians can delete their own notes"
    ON clinician_notes FOR DELETE
    USING (clinician_id = get_clinician_id(auth.uid()));

-- =====================================================
-- 9. UPDATE EXISTING RLS POLICIES FOR PATIENTS
-- =====================================================

-- Drop old policies
DROP POLICY IF EXISTS "Clinicians can view all patients" ON patients;
DROP POLICY IF EXISTS "Clinicians can view all health samples" ON health_samples;
DROP POLICY IF EXISTS "Clinicians can view all locations" ON locations;
DROP POLICY IF EXISTS "Clinicians can view all screen time" ON screen_time;
DROP POLICY IF EXISTS "Clinicians can view all heart failure events" ON heart_failure_events;

-- Patients - clinicians see only their patients (or all if superuser)
CREATE POLICY "Clinicians can view their patients"
    ON patients FOR SELECT
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        clinician_id = get_clinician_id(auth.uid()) OR
        user_id = auth.uid()
    );

CREATE POLICY "Clinicians can update their patients"
    ON patients FOR UPDATE
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        clinician_id = get_clinician_id(auth.uid())
    );

-- Health samples - clinicians see only their patients' data
CREATE POLICY "Clinicians can view their patients health samples"
    ON health_samples FOR SELECT
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        clinician_can_access_patient(auth.uid(), patient_id)
    );

-- Locations - clinicians see only their patients' data
CREATE POLICY "Clinicians can view their patients locations"
    ON locations FOR SELECT
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        clinician_can_access_patient(auth.uid(), patient_id)
    );

-- Screen time - clinicians see only their patients' data
CREATE POLICY "Clinicians can view their patients screen time"
    ON screen_time FOR SELECT
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        clinician_can_access_patient(auth.uid(), patient_id)
    );

-- Heart failure events - clinicians see and manage their patients' events
CREATE POLICY "Clinicians can view their patients heart failure events"
    ON heart_failure_events FOR SELECT
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        clinician_can_access_patient(auth.uid(), patient_id)
    );

CREATE POLICY "Clinicians can create heart failure events for their patients"
    ON heart_failure_events FOR INSERT
    WITH CHECK (
        auth.role() = 'service_role' OR
        clinician_can_access_patient(auth.uid(), patient_id)
    );

CREATE POLICY "Clinicians can update heart failure events they logged"
    ON heart_failure_events FOR UPDATE
    USING (
        auth.role() = 'service_role' OR
        logged_by_clinician_id = get_clinician_id(auth.uid())
    );

-- Sync history - clinicians see their patients' sync history
CREATE POLICY "Clinicians can view their patients sync history"
    ON sync_history FOR SELECT
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        clinician_can_access_patient(auth.uid(), patient_id)
    );

-- Invite codes - clinicians manage their own codes
DROP POLICY IF EXISTS "Anyone can view invite codes" ON invite_codes;

CREATE POLICY "Clinicians can view their invite codes"
    ON invite_codes FOR SELECT
    USING (
        auth.role() = 'service_role' OR
        is_superuser(auth.uid()) OR
        created_by = auth.uid()
    );

CREATE POLICY "Clinicians can create invite codes"
    ON invite_codes FOR INSERT
    WITH CHECK (
        auth.role() = 'service_role' OR
        is_clinician(auth.uid())
    );

CREATE POLICY "Clinicians can update their invite codes"
    ON invite_codes FOR UPDATE
    USING (
        auth.role() = 'service_role' OR
        created_by = auth.uid()
    );

CREATE POLICY "Clinicians can delete their invite codes"
    ON invite_codes FOR DELETE
    USING (
        auth.role() = 'service_role' OR
        created_by = auth.uid()
    );

-- =====================================================
-- 10. TRIGGER FOR PATIENT-CLINICIAN ASSIGNMENT
-- =====================================================

-- When a patient uses an invite code, assign them to the clinician
CREATE OR REPLACE FUNCTION assign_patient_to_clinician()
RETURNS TRIGGER AS $$
DECLARE
    invite_clinician_id UUID;
BEGIN
    -- This would be called when we have invite code tracking
    -- For now, this is a placeholder for the assignment logic
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_clinicians_updated_at
    BEFORE UPDATE ON clinicians
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clinician_notes_updated_at
    BEFORE UPDATE ON clinician_notes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 11. INITIAL SUPERUSER SETUP
-- =====================================================
-- Note: Run this manually after creating the first admin user in Supabase Auth
--
-- INSERT INTO clinicians (user_id, email, name, is_superuser, is_active)
-- VALUES (
--     'YOUR-ADMIN-USER-UUID',
--     'admin@example.com',
--     'Admin User',
--     TRUE,
--     TRUE
-- );
