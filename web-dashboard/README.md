# QoL Monitor - Clinician Dashboard

Mobile-first web dashboard for clinicians to monitor patient health data from the Quality of Life Monitor iOS app.

## Features

- **Patient Management**: View and monitor patients assigned via invite codes
- **Health Data Visualization**: View health samples, activity, locations, and screen time
- **Heart Failure Events**: Log and track heart failure events for patients
- **Clinician Notes**: Add private notes for each patient (only visible to clinicians)
- **Invite Codes**: Generate and manage patient invite codes
- **Data Export**: Export data in CSV, JSON, Excel, SPSS, and SAS formats
- **Admin Panel**: Manage clinician accounts (superusers only)

## Setup

1. Copy environment variables:
   ```bash
   cp .env.local.example .env.local
   ```

2. Update `.env.local` with your Supabase credentials:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

4. Run the development server:
   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000)

## Database Setup

Run the migration in `/supabase/migrations/001_clinician_dashboard.sql` to create the necessary tables and RLS policies.

After running the migration, create the first superuser by:
1. Creating a user in Supabase Auth
2. Running the INSERT statement at the bottom of the migration with the user's UUID

## Tech Stack

- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- Supabase (Auth & Database)
- XLSX for Excel export
- Lucide React for icons
