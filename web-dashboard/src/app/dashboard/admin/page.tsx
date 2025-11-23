import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { formatDate } from '@/lib/utils'
import { Shield, UserPlus, Users } from 'lucide-react'
import { CreateClinicianForm } from './CreateClinicianForm'
import { ClinicianActions } from './ClinicianActions'

export default async function AdminPage() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { data: clinician } = await supabase
    .from('clinicians')
    .select('*')
    .eq('user_id', user!.id)
    .single()

  // Only superusers can access this page
  if (!clinician?.is_superuser) {
    redirect('/dashboard')
  }

  // Get all clinicians
  const { data: clinicians } = await supabase
    .from('clinicians')
    .select('*')
    .order('created_at', { ascending: false })

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Admin</h1>
          <p className="text-gray-600">Manage clinician accounts</p>
        </div>
      </div>

      {/* Create new clinician */}
      <CreateClinicianForm />

      {/* Clinicians list */}
      {clinicians && clinicians.length > 0 ? (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Clinician
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider hidden sm:table-cell">
                    Organization
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider hidden md:table-cell">
                    Created
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {clinicians.map((c) => (
                  <tr key={c.id}>
                    <td className="px-4 py-4">
                      <div>
                        <div className="flex items-center gap-2">
                          <p className="text-sm font-medium text-gray-900">
                            {c.name}
                          </p>
                          {c.is_superuser && (
                            <Shield className="h-4 w-4 text-purple-500" title="Superuser" />
                          )}
                        </div>
                        <p className="text-xs text-gray-500">{c.email}</p>
                      </div>
                    </td>
                    <td className="px-4 py-4 hidden sm:table-cell">
                      <span className="text-sm text-gray-600">
                        {c.organization || '-'}
                      </span>
                    </td>
                    <td className="px-4 py-4 hidden md:table-cell">
                      <span className="text-sm text-gray-500">
                        {formatDate(c.created_at)}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      {c.is_active ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                          Active
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-600">
                          Inactive
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-4 text-right">
                      <ClinicianActions
                        clinicianId={c.id}
                        isActive={c.is_active}
                        isSuperuser={c.is_superuser}
                        isSelf={c.user_id === user!.id}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
          <Users className="h-12 w-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500">No clinicians yet</p>
        </div>
      )}
    </div>
  )
}
