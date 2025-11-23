-- Supabase Auth Schema Additions for Quality of Life Monitor
-- Run these commands in your Supabase SQL Editor AFTER running the main schema

-- ============================================
-- INVITE CODES TABLE
-- ============================================
CREATE TABLE invite_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    max_uses INTEGER DEFAULT 1,
    current_uses INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    notes TEXT
);

-- Index for code lookup
CREATE INDEX idx_invite_codes_code ON invite_codes(code);
CREATE INDEX idx_invite_codes_active ON invite_codes(is_active) WHERE is_active = TRUE;

-- Insert the initial invite code
INSERT INTO invite_codes (code, max_uses, notes)
VALUES ('shariqomar', 999999, 'Initial beta invite code');

-- ============================================
-- UPDATE PATIENTS TABLE
-- ============================================
-- Add auth user reference to patients table
ALTER TABLE patients ADD COLUMN user_id UUID REFERENCES auth.users(id);
ALTER TABLE patients ADD COLUMN email TEXT;

-- Index for user lookup
CREATE INDEX idx_patients_user_id ON patients(user_id);

-- ============================================
-- FUNCTION TO VALIDATE INVITE CODE
-- ============================================
CREATE OR REPLACE FUNCTION validate_invite_code(p_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_valid BOOLEAN := FALSE;
BEGIN
    SELECT INTO v_valid
        EXISTS (
            SELECT 1 FROM invite_codes
            WHERE code = p_code
              AND is_active = TRUE
              AND (expires_at IS NULL OR expires_at > NOW())
              AND (max_uses IS NULL OR current_uses < max_uses)
        );
    RETURN v_valid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION TO USE INVITE CODE
-- ============================================
CREATE OR REPLACE FUNCTION use_invite_code(p_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated BOOLEAN := FALSE;
BEGIN
    UPDATE invite_codes
    SET current_uses = current_uses + 1
    WHERE code = p_code
      AND is_active = TRUE
      AND (expires_at IS NULL OR expires_at > NOW())
      AND (max_uses IS NULL OR current_uses < max_uses);

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- UPDATE RLS POLICIES FOR AUTH
-- ============================================

-- Drop existing service role only policies and add user-based policies
DROP POLICY IF EXISTS "Service role full access" ON patients;
DROP POLICY IF EXISTS "Service role full access" ON health_samples;
DROP POLICY IF EXISTS "Service role full access" ON locations;
DROP POLICY IF EXISTS "Service role full access" ON screen_time;
DROP POLICY IF EXISTS "Service role full access" ON heart_failure_events;
DROP POLICY IF EXISTS "Service role full access" ON sync_history;

-- Patients: Users can only access their own patient record
CREATE POLICY "Users can view own patient" ON patients
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own patient" ON patients
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own patient" ON patients
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Service role full access on patients" ON patients
    FOR ALL USING (auth.role() = 'service_role');

-- Health samples: Users can only access their own data
CREATE POLICY "Users can view own health_samples" ON health_samples
    FOR SELECT USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can insert own health_samples" ON health_samples
    FOR INSERT WITH CHECK (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Service role full access on health_samples" ON health_samples
    FOR ALL USING (auth.role() = 'service_role');

-- Locations: Users can only access their own data
CREATE POLICY "Users can view own locations" ON locations
    FOR SELECT USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can insert own locations" ON locations
    FOR INSERT WITH CHECK (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can delete own locations" ON locations
    FOR DELETE USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Service role full access on locations" ON locations
    FOR ALL USING (auth.role() = 'service_role');

-- Screen time: Users can only access their own data
CREATE POLICY "Users can view own screen_time" ON screen_time
    FOR SELECT USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can insert own screen_time" ON screen_time
    FOR INSERT WITH CHECK (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can delete own screen_time" ON screen_time
    FOR DELETE USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Service role full access on screen_time" ON screen_time
    FOR ALL USING (auth.role() = 'service_role');

-- Heart failure events: Users can only access their own data
CREATE POLICY "Users can view own heart_failure_events" ON heart_failure_events
    FOR SELECT USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can insert own heart_failure_events" ON heart_failure_events
    FOR INSERT WITH CHECK (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can delete own heart_failure_events" ON heart_failure_events
    FOR DELETE USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Service role full access on heart_failure_events" ON heart_failure_events
    FOR ALL USING (auth.role() = 'service_role');

-- Sync history: Users can only access their own sync records
CREATE POLICY "Users can view own sync_history" ON sync_history
    FOR SELECT USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can insert own sync_history" ON sync_history
    FOR INSERT WITH CHECK (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Service role full access on sync_history" ON sync_history
    FOR ALL USING (auth.role() = 'service_role');

-- Invite codes: Anyone can validate, only service role can manage
CREATE POLICY "Anyone can validate invite codes" ON invite_codes
    FOR SELECT USING (TRUE);

CREATE POLICY "Service role manages invite codes" ON invite_codes
    FOR ALL USING (auth.role() = 'service_role');

-- Enable RLS on invite_codes
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- ============================================
-- FUNCTION TO DELETE USER DATA
-- ============================================
CREATE OR REPLACE FUNCTION delete_user_data(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_patient_id UUID;
BEGIN
    -- Get patient ID for this user
    SELECT id INTO v_patient_id FROM patients WHERE user_id = p_user_id;

    IF v_patient_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Delete all user data (cascades from patient)
    DELETE FROM patients WHERE id = v_patient_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
