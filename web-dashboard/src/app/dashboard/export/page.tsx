import { createClient } from '@/lib/supabase/server'
import { ExportForm } from './ExportForm'

export default async function ExportPage({
  searchParams,
}: {
  searchParams: { patient?: string }
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

  // Get patients for selection
  let query = supabase
    .from('patient_summary')
    .select('id, email, patient_code')
    .order('created_at', { ascending: false })

  if (!clinician?.is_superuser) {
    query = query.eq('clinician_id', clinician?.id)
  }

  const { data: patients } = await query

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Export Data</h1>
        <p className="text-gray-600">
          Export patient data in various formats for analysis
        </p>
      </div>

      <ExportForm
        patients={patients || []}
        selectedPatientId={searchParams.patient}
        isSuperuser={clinician?.is_superuser || false}
      />
    </div>
  )
}
