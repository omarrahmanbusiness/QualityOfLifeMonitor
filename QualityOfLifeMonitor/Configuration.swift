//
//  Configuration.swift
//  QualityOfLifeMonitor
//
//  This file contains your Supabase credentials.
//  Configuration.swift is gitignored and won't be committed.
//

import Foundation

enum Config {
    // Supabase Configuration
    // TODO: Replace these with your actual Supabase credentials
    // Get these from: https://app.supabase.com/project/YOUR_PROJECT/settings/api

    static let supabaseURL = "YOUR_SUPABASE_URL"  // e.g., "https://xxxxx.supabase.co"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"  // Your anon/public key

    // Email redirect URL (for email confirmation and password reset)
    // This is the deep link URL that Supabase will redirect to after email actions
    // Format: "qualityoflifemonitor://auth/callback"
    static let emailRedirectURL = "qualityoflifemonitor://auth/callback"
}
