import { createClient } from '@/lib/supabase/server'
import { formatDate } from '@/lib/utils'
import { Ticket, Copy, Trash2 } from 'lucide-react'
import { CreateCodeForm } from './CreateCodeForm'
import { CodeActions } from './CodeActions'

export default async function InviteCodesPage() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const { data: clinician } = await supabase
    .from('clinicians')
    .select('*')
    .eq('user_id', user!.id)
    .single()

  // Get invite codes
  let query = supabase
    .from('invite_codes')
    .select('*, clinicians(name)')
    .order('created_at', { ascending: false })

  if (!clinician?.is_superuser) {
    query = query.eq('created_by', user!.id)
  }

  const { data: codes } = await query

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <h1 className="text-2xl font-bold text-gray-900">Invite Codes</h1>
      </div>

      {/* Create new code */}
      <CreateCodeForm clinicianId={clinician!.id} />

      {/* Codes list */}
      {codes && codes.length > 0 ? (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Code
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider hidden sm:table-cell">
                    Uses
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
                {codes.map((code: any) => (
                  <tr key={code.id}>
                    <td className="px-4 py-4">
                      <div className="flex items-center gap-2">
                        <code className="text-sm font-mono bg-gray-100 px-2 py-1 rounded">
                          {code.code}
                        </code>
                      </div>
                      {code.notes && (
                        <p className="text-xs text-gray-500 mt-1">{code.notes}</p>
                      )}
                    </td>
                    <td className="px-4 py-4 hidden sm:table-cell">
                      <span className="text-sm text-gray-600">
                        {code.current_uses} / {code.max_uses}
                      </span>
                    </td>
                    <td className="px-4 py-4 hidden md:table-cell">
                      <span className="text-sm text-gray-500">
                        {formatDate(code.created_at)}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      {code.is_active ? (
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
                      <CodeActions code={code.code} codeId={code.id} isActive={code.is_active} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-8 text-center">
          <Ticket className="h-12 w-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500">No invite codes yet</p>
          <p className="text-sm text-gray-400 mt-1">
            Create a code to invite patients
          </p>
        </div>
      )}
    </div>
  )
}
