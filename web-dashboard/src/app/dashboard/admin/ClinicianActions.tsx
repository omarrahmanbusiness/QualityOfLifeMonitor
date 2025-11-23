'use client'

import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Shield } from 'lucide-react'

export function ClinicianActions({
  clinicianId,
  isActive,
  isSuperuser,
  isSelf,
}: {
  clinicianId: string
  isActive: boolean
  isSuperuser: boolean
  isSelf: boolean
}) {
  const router = useRouter()

  const handleToggleActive = async () => {
    if (isSelf) {
      alert('You cannot deactivate your own account')
      return
    }

    const supabase = createClient()
    await supabase
      .from('clinicians')
      .update({ is_active: !isActive })
      .eq('id', clinicianId)
    router.refresh()
  }

  const handleToggleSuperuser = async () => {
    if (isSelf) {
      alert('You cannot change your own admin status')
      return
    }

    const supabase = createClient()
    await supabase
      .from('clinicians')
      .update({ is_superuser: !isSuperuser })
      .eq('id', clinicianId)
    router.refresh()
  }

  return (
    <div className="flex items-center justify-end gap-1">
      <button
        onClick={handleToggleSuperuser}
        disabled={isSelf}
        className={`p-1.5 rounded ${
          isSuperuser
            ? 'text-purple-500 hover:bg-purple-50'
            : 'text-gray-400 hover:bg-gray-50'
        } ${isSelf ? 'opacity-50 cursor-not-allowed' : ''}`}
        title={isSuperuser ? 'Remove admin' : 'Make admin'}
      >
        <Shield className="h-4 w-4" />
      </button>
      <button
        onClick={handleToggleActive}
        disabled={isSelf}
        className={`px-2 py-1 text-xs rounded ${
          isActive
            ? 'text-gray-600 hover:bg-gray-100'
            : 'text-green-600 hover:bg-green-50'
        } ${isSelf ? 'opacity-50 cursor-not-allowed' : ''}`}
      >
        {isActive ? 'Deactivate' : 'Activate'}
      </button>
    </div>
  )
}
