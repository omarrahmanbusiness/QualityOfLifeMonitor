import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { Sidebar } from '@/components/Sidebar'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  const { data: clinician } = await supabase
    .from('clinicians')
    .select('*')
    .eq('user_id', user.id)
    .single()

  if (!clinician || !clinician.is_active) {
    redirect('/login?error=not_authorized')
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Sidebar clinicianName={clinician.name} isSuperuser={clinician.is_superuser} />
      <div className="lg:pl-64">
        <main className="py-6 px-4 sm:px-6 lg:px-8 pt-16 lg:pt-6">{children}</main>
      </div>
    </div>
  )
}
