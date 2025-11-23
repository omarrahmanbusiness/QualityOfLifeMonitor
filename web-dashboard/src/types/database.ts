export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      clinicians: {
        Row: {
          id: string
          user_id: string
          email: string
          name: string
          organization: string | null
          is_superuser: boolean
          is_active: boolean
          created_by: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          email: string
          name: string
          organization?: string | null
          is_superuser?: boolean
          is_active?: boolean
          created_by?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          email?: string
          name?: string
          organization?: string | null
          is_superuser?: boolean
          is_active?: boolean
          created_by?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      clinician_notes: {
        Row: {
          id: string
          patient_id: string
          clinician_id: string
          note: string
          note_type: string
          related_event_id: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          patient_id: string
          clinician_id: string
          note: string
          note_type?: string
          related_event_id?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          patient_id?: string
          clinician_id?: string
          note?: string
          note_type?: string
          related_event_id?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      patients: {
        Row: {
          id: string
          device_id: string
          user_id: string | null
          email: string | null
          patient_code: string | null
          notes: string | null
          clinician_id: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          device_id: string
          user_id?: string | null
          email?: string | null
          patient_code?: string | null
          notes?: string | null
          clinician_id?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          device_id?: string
          user_id?: string | null
          email?: string | null
          patient_code?: string | null
          notes?: string | null
          clinician_id?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      health_samples: {
        Row: {
          id: string
          patient_id: string
          sample_type: string
          start_date: string
          end_date: string
          value: number
          unit: string
          source_name: string | null
          source_bundle_id: string | null
          synced_at: string
        }
        Insert: {
          id?: string
          patient_id: string
          sample_type: string
          start_date: string
          end_date: string
          value: number
          unit: string
          source_name?: string | null
          source_bundle_id?: string | null
          synced_at?: string
        }
        Update: {
          id?: string
          patient_id?: string
          sample_type?: string
          start_date?: string
          end_date?: string
          value?: number
          unit?: string
          source_name?: string | null
          source_bundle_id?: string | null
          synced_at?: string
        }
      }
      locations: {
        Row: {
          id: string
          patient_id: string
          latitude: number
          longitude: number
          altitude: number | null
          speed: number | null
          timestamp: string
          address: string | null
          place_name: string | null
          category: string | null
          synced_at: string
        }
        Insert: {
          id?: string
          patient_id: string
          latitude: number
          longitude: number
          altitude?: number | null
          speed?: number | null
          timestamp: string
          address?: string | null
          place_name?: string | null
          category?: string | null
          synced_at?: string
        }
        Update: {
          id?: string
          patient_id?: string
          latitude?: number
          longitude?: number
          altitude?: number | null
          speed?: number | null
          timestamp?: string
          address?: string | null
          place_name?: string | null
          category?: string | null
          synced_at?: string
        }
      }
      screen_time: {
        Row: {
          id: string
          patient_id: string
          date: string
          metric_type: string
          total_screen_time: number | null
          number_of_pickups: number | null
          duration: number | null
          app_bundle_id: string | null
          app_name: string | null
          category: string | null
          synced_at: string
        }
        Insert: {
          id?: string
          patient_id: string
          date: string
          metric_type: string
          total_screen_time?: number | null
          number_of_pickups?: number | null
          duration?: number | null
          app_bundle_id?: string | null
          app_name?: string | null
          category?: string | null
          synced_at?: string
        }
        Update: {
          id?: string
          patient_id?: string
          date?: string
          metric_type?: string
          total_screen_time?: number | null
          number_of_pickups?: number | null
          duration?: number | null
          app_bundle_id?: string | null
          app_name?: string | null
          category?: string | null
          synced_at?: string
        }
      }
      heart_failure_events: {
        Row: {
          id: string
          patient_id: string
          timestamp: string
          notes: string | null
          synced_at: string
          logged_by_clinician_id: string | null
          event_source: string
        }
        Insert: {
          id?: string
          patient_id: string
          timestamp: string
          notes?: string | null
          synced_at?: string
          logged_by_clinician_id?: string | null
          event_source?: string
        }
        Update: {
          id?: string
          patient_id?: string
          timestamp?: string
          notes?: string | null
          synced_at?: string
          logged_by_clinician_id?: string | null
          event_source?: string
        }
      }
      invite_codes: {
        Row: {
          id: string
          code: string
          created_at: string
          expires_at: string | null
          max_uses: number
          current_uses: number
          is_active: boolean
          created_by: string | null
          clinician_id: string | null
          notes: string | null
        }
        Insert: {
          id?: string
          code: string
          created_at?: string
          expires_at?: string | null
          max_uses?: number
          current_uses?: number
          is_active?: boolean
          created_by?: string | null
          clinician_id?: string | null
          notes?: string | null
        }
        Update: {
          id?: string
          code?: string
          created_at?: string
          expires_at?: string | null
          max_uses?: number
          current_uses?: number
          is_active?: boolean
          created_by?: string | null
          clinician_id?: string | null
          notes?: string | null
        }
      }
      sync_history: {
        Row: {
          id: string
          patient_id: string
          sync_type: string
          started_at: string
          completed_at: string | null
          status: string
          records_synced: number
          error_message: string | null
        }
        Insert: {
          id?: string
          patient_id: string
          sync_type: string
          started_at?: string
          completed_at?: string | null
          status?: string
          records_synced?: number
          error_message?: string | null
        }
        Update: {
          id?: string
          patient_id?: string
          sync_type?: string
          started_at?: string
          completed_at?: string | null
          status?: string
          records_synced?: number
          error_message?: string | null
        }
      }
    }
    Views: {
      patient_summary: {
        Row: {
          id: string
          device_id: string
          email: string | null
          patient_code: string | null
          notes: string | null
          created_at: string
          clinician_id: string | null
          clinician_name: string | null
          clinician_email: string | null
          total_health_samples: number
          total_locations: number
          total_screen_time_records: number
          total_hf_events: number
          last_health_sync: string | null
          last_location_sync: string | null
        }
      }
      daily_health_summary: {
        Row: {
          patient_id: string
          date: string
          sample_type: string
          sample_count: number
          avg_value: number
          min_value: number
          max_value: number
          unit: string
        }
      }
      daily_activity_summary: {
        Row: {
          patient_id: string
          date: string
          total_steps: number
          total_calories: number
          total_distance: number
          flights_climbed: number
        }
      }
      clinician_dashboard_overview: {
        Row: {
          clinician_id: string
          user_id: string
          clinician_name: string
          total_patients: number
          new_patients_week: number
          total_hf_events: number
          hf_events_week: number
        }
      }
    }
    Functions: {
      is_clinician: {
        Args: { user_uuid: string }
        Returns: boolean
      }
      is_superuser: {
        Args: { user_uuid: string }
        Returns: boolean
      }
      get_clinician_id: {
        Args: { user_uuid: string }
        Returns: string
      }
      clinician_can_access_patient: {
        Args: { user_uuid: string; patient_uuid: string }
        Returns: boolean
      }
    }
  }
}
