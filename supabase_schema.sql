-- Supabase Schema for Quality of Life Monitor
-- Run these commands in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- USERS/PATIENTS TABLE
-- ============================================
CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT UNIQUE NOT NULL,  -- Unique identifier from device
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Optional patient metadata (can be added by clinician)
    patient_code TEXT,  -- Clinician-assigned identifier
    notes TEXT
);

-- Index for device lookup
CREATE INDEX idx_patients_device_id ON patients(device_id);

-- ============================================
-- HEALTH SAMPLES TABLE
-- ============================================
CREATE TABLE health_samples (
    id UUID PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

    sample_type TEXT NOT NULL,      -- HKQuantityTypeIdentifier or HKCategoryTypeIdentifier
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    unit TEXT NOT NULL,
    source_name TEXT,
    source_bundle_id TEXT,

    synced_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(patient_id, id)  -- Prevent duplicates per patient
);

-- Indexes for common queries
CREATE INDEX idx_health_samples_patient ON health_samples(patient_id);
CREATE INDEX idx_health_samples_type ON health_samples(sample_type);
CREATE INDEX idx_health_samples_date ON health_samples(start_date DESC);
CREATE INDEX idx_health_samples_patient_type_date ON health_samples(patient_id, sample_type, start_date DESC);

-- ============================================
-- LOCATION DATA TABLE
-- ============================================
CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    altitude DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    timestamp TIMESTAMPTZ NOT NULL,
    address TEXT,
    place_name TEXT,
    category TEXT,  -- Home, Work, Healthcare, etc.

    synced_at TIMESTAMPTZ DEFAULT NOW(),

    -- Prevent duplicate locations (same patient, time, coordinates)
    UNIQUE(patient_id, timestamp, latitude, longitude)
);

-- Indexes for location queries
CREATE INDEX idx_locations_patient ON locations(patient_id);
CREATE INDEX idx_locations_timestamp ON locations(timestamp DESC);
CREATE INDEX idx_locations_category ON locations(category);
CREATE INDEX idx_locations_patient_date ON locations(patient_id, timestamp DESC);

-- ============================================
-- SCREEN TIME DATA TABLE
-- ============================================
CREATE TABLE screen_time (
    id UUID PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

    date TIMESTAMPTZ NOT NULL,
    metric_type TEXT NOT NULL,  -- 'dailySummary', 'categoryUsage', 'appUsage', 'pickup'
    total_screen_time DOUBLE PRECISION,  -- seconds (for daily summary)
    number_of_pickups INTEGER,            -- (for daily summary)
    duration DOUBLE PRECISION,            -- seconds (for category/app usage)
    app_bundle_id TEXT,
    app_name TEXT,
    category TEXT,

    synced_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(patient_id, id)
);

-- Indexes for screen time queries
CREATE INDEX idx_screen_time_patient ON screen_time(patient_id);
CREATE INDEX idx_screen_time_date ON screen_time(date DESC);
CREATE INDEX idx_screen_time_type ON screen_time(metric_type);
CREATE INDEX idx_screen_time_patient_date ON screen_time(patient_id, date DESC);

-- ============================================
-- HEART FAILURE EVENTS TABLE
-- ============================================
CREATE TABLE heart_failure_events (
    id UUID PRIMARY KEY,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

    timestamp TIMESTAMPTZ NOT NULL,
    notes TEXT,

    synced_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(patient_id, id)
);

-- Indexes for heart failure events
CREATE INDEX idx_hf_events_patient ON heart_failure_events(patient_id);
CREATE INDEX idx_hf_events_timestamp ON heart_failure_events(timestamp DESC);

-- ============================================
-- SYNC TRACKING TABLE
-- ============================================
CREATE TABLE sync_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,

    sync_type TEXT NOT NULL,  -- 'full', 'incremental', 'initial'
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL,     -- 'in_progress', 'completed', 'failed'

    records_synced INTEGER DEFAULT 0,
    error_message TEXT,

    -- Breakdown by entity type
    health_samples_count INTEGER DEFAULT 0,
    locations_count INTEGER DEFAULT 0,
    screen_time_count INTEGER DEFAULT 0,
    hf_events_count INTEGER DEFAULT 0
);

CREATE INDEX idx_sync_history_patient ON sync_history(patient_id);
CREATE INDEX idx_sync_history_date ON sync_history(started_at DESC);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================
-- Enable RLS on all tables
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE screen_time ENABLE ROW LEVEL SECURITY;
ALTER TABLE heart_failure_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_history ENABLE ROW LEVEL SECURITY;

-- ============================================
-- POLICIES FOR CLINICIAN ACCESS
-- ============================================
-- Clinicians can view all patient data (adjust based on your auth setup)
-- These policies assume you have a 'clinician' role or use service_role

-- Allow service role (your app backend) full access
CREATE POLICY "Service role full access" ON patients
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON health_samples
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON locations
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON screen_time
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON heart_failure_events
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access" ON sync_history
    FOR ALL USING (auth.role() = 'service_role');

-- ============================================
-- USEFUL VIEWS FOR CLINICIANS
-- ============================================

-- View: Patient summary with latest sync
CREATE VIEW patient_summary AS
SELECT
    p.id,
    p.device_id,
    p.patient_code,
    p.created_at,
    (SELECT COUNT(*) FROM health_samples WHERE patient_id = p.id) as total_health_samples,
    (SELECT COUNT(*) FROM locations WHERE patient_id = p.id) as total_locations,
    (SELECT COUNT(*) FROM screen_time WHERE patient_id = p.id) as total_screen_time_records,
    (SELECT COUNT(*) FROM heart_failure_events WHERE patient_id = p.id) as total_hf_events,
    (SELECT MAX(synced_at) FROM health_samples WHERE patient_id = p.id) as last_health_sync,
    (SELECT MAX(synced_at) FROM locations WHERE patient_id = p.id) as last_location_sync
FROM patients p;

-- View: Daily health metrics aggregation
CREATE VIEW daily_health_summary AS
SELECT
    patient_id,
    DATE(start_date) as date,
    sample_type,
    COUNT(*) as sample_count,
    AVG(value) as avg_value,
    MIN(value) as min_value,
    MAX(value) as max_value
FROM health_samples
GROUP BY patient_id, DATE(start_date), sample_type
ORDER BY patient_id, date DESC, sample_type;

-- View: Heart rate trends (common for heart failure monitoring)
CREATE VIEW heart_rate_trends AS
SELECT
    patient_id,
    DATE(start_date) as date,
    EXTRACT(HOUR FROM start_date) as hour,
    sample_type,
    AVG(value) as avg_bpm,
    MIN(value) as min_bpm,
    MAX(value) as max_bpm,
    COUNT(*) as readings
FROM health_samples
WHERE sample_type IN ('HKQuantityTypeIdentifierHeartRate',
                       'HKQuantityTypeIdentifierRestingHeartRate',
                       'HKQuantityTypeIdentifierWalkingHeartRateAverage')
GROUP BY patient_id, DATE(start_date), EXTRACT(HOUR FROM start_date), sample_type
ORDER BY patient_id, date DESC, hour;

-- View: Activity summary
CREATE VIEW daily_activity_summary AS
SELECT
    patient_id,
    DATE(start_date) as date,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierStepCount' THEN value ELSE 0 END) as total_steps,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierActiveEnergyBurned' THEN value ELSE 0 END) as active_calories,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierDistanceWalkingRunning' THEN value ELSE 0 END) as distance_meters,
    SUM(CASE WHEN sample_type = 'HKQuantityTypeIdentifierFlightsClimbed' THEN value ELSE 0 END) as flights_climbed
FROM health_samples
WHERE sample_type IN ('HKQuantityTypeIdentifierStepCount',
                      'HKQuantityTypeIdentifierActiveEnergyBurned',
                      'HKQuantityTypeIdentifierDistanceWalkingRunning',
                      'HKQuantityTypeIdentifierFlightsClimbed')
GROUP BY patient_id, DATE(start_date)
ORDER BY patient_id, date DESC;

-- View: Location patterns
CREATE VIEW location_patterns AS
SELECT
    patient_id,
    DATE(timestamp) as date,
    category,
    COUNT(*) as visit_count,
    SUM(CASE WHEN speed > 0 THEN 1 ELSE 0 END) as moving_records
FROM locations
GROUP BY patient_id, DATE(timestamp), category
ORDER BY patient_id, date DESC, visit_count DESC;

-- ============================================
-- FUNCTIONS FOR DATA ANALYSIS
-- ============================================

-- Function: Get patient's data for date range
CREATE OR REPLACE FUNCTION get_patient_health_data(
    p_patient_id UUID,
    p_start_date TIMESTAMPTZ,
    p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
    sample_type TEXT,
    start_date TIMESTAMPTZ,
    value DOUBLE PRECISION,
    unit TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT hs.sample_type, hs.start_date, hs.value, hs.unit
    FROM health_samples hs
    WHERE hs.patient_id = p_patient_id
      AND hs.start_date >= p_start_date
      AND hs.start_date <= p_end_date
    ORDER BY hs.start_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate 6-minute walk test distance (if recorded)
CREATE OR REPLACE FUNCTION get_6mwt_results(p_patient_id UUID)
RETURNS TABLE (
    test_date DATE,
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        DATE(start_date) as test_date,
        value as distance_meters
    FROM health_samples
    WHERE patient_id = p_patient_id
      AND sample_type = 'HKQuantityTypeIdentifierSixMinuteWalkTestDistance'
    ORDER BY start_date DESC;
END;
$$ LANGUAGE plpgsql;
