import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import { formatRelativeTime } from '@/lib/utils'
import { Search, User, Activity, Clock } from 'lucide-react'

export default async function PatientsPage({
  searchParams,
}: {
  searchParams: { search?: string }
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

  // Get patients
  let query = supabase.from('patient_summary').select('*')

  if (!clinician?.is_superuser) {
    query = query.eq('clinician_id', clinician?.id)
  }

  const { data: patients } = await query

  // Filter by search if provided
  let filteredPatients = patients || []
  const search = searchParams.search?.toLowerCase()
  if (search) {
    filteredPatients = filteredPatients.filter(
      (p) =>
        p.email?.toLowerCase().includes(search) ||
        p.patient_code?.toLowerCase().includes(search) ||
        p.device_id?.toLowerCase().includes(search)
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <h1 className="text-2xl font-bold text-gray-900">Patients</h1>

        <form className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            name="search"
            defaultValue={searchParams.search}
            placeholder="Search patients..."
            className="pl-10 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent w-full sm:w-64"
          />
        </form>
      </div>

      {filteredPatients.length > 0 ? (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Patient
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider hidden sm:table-cell">
                    Samples
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider hidden md:table-cell">
                    HF Events
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Last Sync
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredPatients.map((patient) => (
                  <tr key={patient.id} className="hover:bg-gray-50">
                    <td className="px-4 py-4">
                      <Link
                        href={`/dashboard/patients/${patient.id}`}
                        className="flex items-center gap-3"
                      >
                        <div className="bg-gray-100 p-2 rounded-full">
                          <User className="h-4 w-4 text-gray-600" />
                        </div>
                        <div>
                          <p className="text-sm font-medium text-gray-900">
                            {patient.patient_code || 'No code'}
                          </p>
                          <p className="text-xs text-gray-500">
                            {patient.email || patient.device_id.slice(0, 8) + '...'}
                          </p>
                        </div>
                      </Link>
                    </td>
                    <td className="px-4 py-4 hidden sm:table-cell">
                      <div className="flex items-center gap-1 text-sm text-gray-600">
                        <Activity className="h-4 w-4" />
                        {patient.total_health_samples}
                      </div>
                    </td>
                    <td className="px-4 py-4 hidden md:table-cell">
                      <span
                        className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                          patient.total_hf_events > 0
                            ? 'bg-red-100 text-red-800'
                            : 'bg-gray-100 text-gray-600'
                        }`}
                      >
                        {patient.total_hf_events}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      {patient.last_health_sync ? (
                        <div className="flex items-center gap-1 text-xs text-gray-500">
                          <Clock className="h-3 w-3" />
                          {formatRelativeTime(patient.last_health_sync)}
                        </div>
                      ) : (
                        <span className="text-xs text-gray-400">Never</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
          <User className="h-12 w-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500">
            {searchParams.search ? 'No patients match your search' : 'No patients yet'}
          </p>
          {!searchParams.search && (
            <p className="text-sm text-gray-400 mt-1">
              Create invite codes and share them with patients to get started
            </p>
          )}
        </div>
      )}
    </div>
  )
}
