import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import { formatDate, formatDateTime } from '@/lib/utils'
import Link from 'next/link'
import { ArrowLeft, Activity, MapPin, Smartphone, AlertTriangle, Plus, Download } from 'lucide-react'
import { AddEventForm } from './AddEventForm'
import { AddNoteForm } from './AddNoteForm'

export default async function PatientDetailPage({
  params,
}: {
  params: { id: string }
}) {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { data: clinician } = await supabase
    .from('clinicians')
    .select('*')
    .eq('user_id', user!.id)
    .single()

  // Get patient summary
  const { data: patient } = await supabase
    .from('patient_summary')
    .select('*')
    .eq('id', params.id)
    .single()

  if (!patient) {
    notFound()
  }

  // Check access
  if (!clinician?.is_superuser && patient.clinician_id !== clinician?.id) {
    notFound()
  }

  // Get daily activity for last 7 days
  const { data: activityData } = await supabase
    .from('daily_activity_summary')
    .select('*')
    .eq('patient_id', params.id)
    .gte('date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString())
    .order('date', { ascending: false })

  // Get heart failure events
  const { data: hfEvents } = await supabase
    .from('heart_failure_events')
    .select('*, clinicians(name)')
    .eq('patient_id', params.id)
    .order('timestamp', { ascending: false })
    .limit(10)

  // Get clinician notes
  const { data: notes } = await supabase
    .from('clinician_notes')
    .select('*, clinicians(name)')
    .eq('patient_id', params.id)
    .order('created_at', { ascending: false })
    .limit(10)

  // Get recent health metrics
  const { data: recentMetrics } = await supabase
    .from('daily_health_summary')
    .select('*')
    .eq('patient_id', params.id)
    .in('sample_type', [
      'HKQuantityTypeIdentifierHeartRate',
      'HKQuantityTypeIdentifierStepCount',
      'HKQuantityTypeIdentifierOxygenSaturation',
    ])
    .gte('date', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .order('date', { ascending: false })

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link
          href="/dashboard/patients"
          className="p-2 rounded-lg hover:bg-gray-100"
        >
          <ArrowLeft className="h-5 w-5 text-gray-600" />
        </Link>
        <div className="flex-1">
          <h1 className="text-2xl font-bold text-gray-900">
            {patient.patient_code || patient.email || 'Patient'}
          </h1>
          <p className="text-sm text-gray-500">
            Enrolled {formatDate(patient.created_at)}
          </p>
        </div>
        <Link
          href={`/dashboard/export?patient=${params.id}`}
          className="flex items-center gap-2 px-3 py-2 bg-primary-600 text-white rounded-lg text-sm hover:bg-primary-700"
        >
          <Download className="h-4 w-4" />
          Export
        </Link>
      </div>

      {/* Stats Overview */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center gap-2 text-gray-600 mb-1">
            <Activity className="h-4 w-4" />
            <span className="text-xs">Health Samples</span>
          </div>
          <p className="text-xl font-semibold text-gray-900">
            {patient.total_health_samples}
          </p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center gap-2 text-gray-600 mb-1">
            <MapPin className="h-4 w-4" />
            <span className="text-xs">Locations</span>
          </div>
          <p className="text-xl font-semibold text-gray-900">
            {patient.total_locations}
          </p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center gap-2 text-gray-600 mb-1">
            <Smartphone className="h-4 w-4" />
            <span className="text-xs">Screen Time</span>
          </div>
          <p className="text-xl font-semibold text-gray-900">
            {patient.total_screen_time_records}
          </p>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center gap-2 text-gray-600 mb-1">
            <AlertTriangle className="h-4 w-4" />
            <span className="text-xs">HF Events</span>
          </div>
          <p className="text-xl font-semibold text-gray-900">
            {patient.total_hf_events}
          </p>
        </div>
      </div>

      {/* Recent Activity */}
      {activityData && activityData.length > 0 && (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <h2 className="font-semibold text-gray-900 mb-3">Recent Activity (7 days)</h2>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="text-left text-gray-500">
                  <th className="pb-2">Date</th>
                  <th className="pb-2">Steps</th>
                  <th className="pb-2">Calories</th>
                  <th className="pb-2">Distance (m)</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {activityData.map((day) => (
                  <tr key={day.date}>
                    <td className="py-2">{formatDate(day.date)}</td>
                    <td className="py-2">{Math.round(day.total_steps || 0)}</td>
                    <td className="py-2">{Math.round(day.total_calories || 0)}</td>
                    <td className="py-2">{Math.round(day.total_distance || 0)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Two Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Heart Failure Events */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="px-4 py-3 border-b border-gray-200 flex justify-between items-center">
            <h2 className="font-semibold text-gray-900">Heart Failure Events</h2>
          </div>

          <AddEventForm patientId={params.id} clinicianId={clinician!.id} />

          <div className="divide-y divide-gray-100">
            {hfEvents && hfEvents.length > 0 ? (
              hfEvents.map((event: any) => (
                <div key={event.id} className="px-4 py-3">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs text-gray-500">
                      {formatDateTime(event.timestamp)}
                    </span>
                    {event.event_source === 'clinician' && (
                      <span className="text-xs bg-blue-100 text-blue-700 px-1.5 py-0.5 rounded">
                        by {event.clinicians?.name || 'Clinician'}
                      </span>
                    )}
                  </div>
                  {event.notes && (
                    <p className="text-sm text-gray-700">{event.notes}</p>
                  )}
                </div>
              ))
            ) : (
              <p className="px-4 py-6 text-center text-sm text-gray-500">
                No events recorded
              </p>
            )}
          </div>
        </div>

        {/* Clinician Notes */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="px-4 py-3 border-b border-gray-200">
            <h2 className="font-semibold text-gray-900">Clinician Notes</h2>
          </div>

          <AddNoteForm patientId={params.id} clinicianId={clinician!.id} />

          <div className="divide-y divide-gray-100">
            {notes && notes.length > 0 ? (
              notes.map((note: any) => (
                <div key={note.id} className="px-4 py-3">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-xs font-medium text-gray-600">
                      {note.clinicians?.name || 'Unknown'}
                    </span>
                    <span className="text-xs text-gray-500">
                      {formatDateTime(note.created_at)}
                    </span>
                  </div>
                  <p className="text-sm text-gray-700">{note.note}</p>
                </div>
              ))
            ) : (
              <p className="px-4 py-6 text-center text-sm text-gray-500">
                No notes yet
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
