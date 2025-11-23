import { createClient } from '@/lib/supabase/server'
import { Users, Activity, AlertTriangle, Clock } from 'lucide-react'
import Link from 'next/link'
import { formatRelativeTime } from '@/lib/utils'

export default async function DashboardPage() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  // Get clinician info
  const { data: clinician } = await supabase
    .from('clinicians')
    .select('*')
    .eq('user_id', user!.id)
    .single()

  // Get dashboard overview - use clinician_dashboard_overview view if superuser
  // Otherwise filter by clinician_id
  let patientsQuery = supabase.from('patient_summary').select('*')

  if (!clinician?.is_superuser) {
    patientsQuery = patientsQuery.eq('clinician_id', clinician?.id)
  }

  const { data: patients } = await patientsQuery

  // Calculate stats
  const totalPatients = patients?.length || 0
  const activePatients = patients?.filter(p => {
    const lastSync = p.last_health_sync || p.last_location_sync
    if (!lastSync) return false
    const daysSinceSync = (Date.now() - new Date(lastSync).getTime()) / (1000 * 60 * 60 * 24)
    return daysSinceSync < 7
  }).length || 0

  const totalHfEvents = patients?.reduce((sum, p) => sum + (p.total_hf_events || 0), 0) || 0

  // Get recent heart failure events
  let eventsQuery = supabase
    .from('heart_failure_events')
    .select('*, patients(email, patient_code)')
    .order('timestamp', { ascending: false })
    .limit(5)

  if (!clinician?.is_superuser) {
    const patientIds = patients?.map(p => p.id) || []
    if (patientIds.length > 0) {
      eventsQuery = eventsQuery.in('patient_id', patientIds)
    }
  }

  const { data: recentEvents } = await eventsQuery

  const stats = [
    {
      name: 'Total Patients',
      value: totalPatients,
      icon: Users,
      color: 'bg-blue-500',
    },
    {
      name: 'Active (7 days)',
      value: activePatients,
      icon: Activity,
      color: 'bg-green-500',
    },
    {
      name: 'HF Events',
      value: totalHfEvents,
      icon: AlertTriangle,
      color: 'bg-red-500',
    },
  ]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-600">Welcome back, {clinician?.name}</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        {stats.map((stat) => (
          <div
            key={stat.name}
            className="bg-white rounded-lg shadow-sm border border-gray-200 p-4"
          >
            <div className="flex items-center gap-3">
              <div className={`${stat.color} p-2 rounded-lg`}>
                <stat.icon className="h-5 w-5 text-white" />
              </div>
              <div>
                <p className="text-sm text-gray-600">{stat.name}</p>
                <p className="text-2xl font-semibold text-gray-900">{stat.value}</p>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Patients */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="px-4 py-3 border-b border-gray-200 flex justify-between items-center">
            <h2 className="font-semibold text-gray-900">Recent Patients</h2>
            <Link
              href="/dashboard/patients"
              className="text-sm text-primary-600 hover:text-primary-700"
            >
              View all
            </Link>
          </div>
          <div className="divide-y divide-gray-100">
            {patients && patients.length > 0 ? (
              patients.slice(0, 5).map((patient) => (
                <Link
                  key={patient.id}
                  href={`/dashboard/patients/${patient.id}`}
                  className="flex items-center justify-between px-4 py-3 hover:bg-gray-50"
                >
                  <div>
                    <p className="text-sm font-medium text-gray-900">
                      {patient.patient_code || patient.email || 'Unknown'}
                    </p>
                    <p className="text-xs text-gray-500">
                      {patient.total_health_samples} samples
                    </p>
                  </div>
                  {patient.last_health_sync && (
                    <div className="flex items-center gap-1 text-xs text-gray-500">
                      <Clock className="h-3 w-3" />
                      {formatRelativeTime(patient.last_health_sync)}
                    </div>
                  )}
                </Link>
              ))
            ) : (
              <p className="px-4 py-8 text-center text-sm text-gray-500">
                No patients yet
              </p>
            )}
          </div>
        </div>

        {/* Recent HF Events */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200">
          <div className="px-4 py-3 border-b border-gray-200">
            <h2 className="font-semibold text-gray-900">Recent HF Events</h2>
          </div>
          <div className="divide-y divide-gray-100">
            {recentEvents && recentEvents.length > 0 ? (
              recentEvents.map((event: any) => (
                <div key={event.id} className="px-4 py-3">
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-medium text-gray-900">
                      {event.patients?.patient_code || event.patients?.email || 'Unknown'}
                    </p>
                    <span className="text-xs text-gray-500">
                      {formatRelativeTime(event.timestamp)}
                    </span>
                  </div>
                  {event.notes && (
                    <p className="mt-1 text-xs text-gray-600 line-clamp-2">
                      {event.notes}
                    </p>
                  )}
                </div>
              ))
            ) : (
              <p className="px-4 py-8 text-center text-sm text-gray-500">
                No heart failure events recorded
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
