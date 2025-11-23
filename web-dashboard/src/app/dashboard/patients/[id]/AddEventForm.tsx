'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Plus } from 'lucide-react'

export function AddEventForm({
  patientId,
  clinicianId,
}: {
  patientId: string
  clinicianId: string
}) {
  const router = useRouter()
  const [isOpen, setIsOpen] = useState(false)
  const [notes, setNotes] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    const supabase = createClient()

    await supabase.from('heart_failure_events').insert({
      patient_id: patientId,
      timestamp: new Date().toISOString(),
      notes: notes || null,
      logged_by_clinician_id: clinicianId,
      event_source: 'clinician',
    })

    setNotes('')
    setIsOpen(false)
    setLoading(false)
    router.refresh()
  }

  if (!isOpen) {
    return (
      <div className="px-4 py-2 border-b border-gray-100">
        <button
          onClick={() => setIsOpen(true)}
          className="flex items-center gap-1 text-sm text-primary-600 hover:text-primary-700"
        >
          <Plus className="h-4 w-4" />
          Add Event
        </button>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="px-4 py-3 border-b border-gray-100 bg-gray-50">
      <textarea
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        placeholder="Event notes (optional)"
        className="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-500"
        rows={2}
      />
      <div className="flex gap-2 mt-2">
        <button
          type="submit"
          disabled={loading}
          className="px-3 py-1.5 text-sm bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50"
        >
          {loading ? 'Adding...' : 'Log Event'}
        </button>
        <button
          type="button"
          onClick={() => setIsOpen(false)}
          className="px-3 py-1.5 text-sm text-gray-600 hover:text-gray-900"
        >
          Cancel
        </button>
      </div>
    </form>
  )
}
