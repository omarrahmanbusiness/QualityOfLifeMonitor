'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { generateInviteCode } from '@/lib/utils'
import { Plus, RefreshCw } from 'lucide-react'

export function CreateCodeForm({ clinicianId }: { clinicianId: string }) {
  const router = useRouter()
  const [isOpen, setIsOpen] = useState(false)
  const [code, setCode] = useState(generateInviteCode())
  const [maxUses, setMaxUses] = useState(1)
  const [notes, setNotes] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    const supabase = createClient()

    const {
      data: { user },
    } = await supabase.auth.getUser()

    const { error: insertError } = await supabase.from('invite_codes').insert({
      code,
      max_uses: maxUses,
      notes: notes || null,
      created_by: user!.id,
      clinician_id: clinicianId,
      is_active: true,
      current_uses: 0,
    })

    if (insertError) {
      if (insertError.code === '23505') {
        setError('This code already exists. Please generate a new one.')
      } else {
        setError(insertError.message)
      }
      setLoading(false)
      return
    }

    setCode(generateInviteCode())
    setMaxUses(1)
    setNotes('')
    setIsOpen(false)
    setLoading(false)
    router.refresh()
  }

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="flex items-center gap-2 px-4 py-2 bg-primary-600 text-white rounded-lg text-sm hover:bg-primary-700"
      >
        <Plus className="h-4 w-4" />
        Create Invite Code
      </button>
    )
  }

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
      <h2 className="font-semibold text-gray-900 mb-4">Create Invite Code</h2>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Code
          </label>
          <div className="flex gap-2">
            <input
              type="text"
              value={code}
              onChange={(e) => setCode(e.target.value.toUpperCase())}
              className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            />
            <button
              type="button"
              onClick={() => setCode(generateInviteCode())}
              className="p-2 text-gray-500 hover:text-gray-700"
              title="Generate new code"
            >
              <RefreshCw className="h-5 w-5" />
            </button>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Max Uses
          </label>
          <input
            type="number"
            min="1"
            value={maxUses}
            onChange={(e) => setMaxUses(parseInt(e.target.value) || 1)}
            className="w-32 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Notes (optional)
          </label>
          <input
            type="text"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="e.g., Study Group A"
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>

        <div className="flex gap-2">
          <button
            type="submit"
            disabled={loading}
            className="px-4 py-2 bg-primary-600 text-white rounded-lg text-sm hover:bg-primary-700 disabled:opacity-50"
          >
            {loading ? 'Creating...' : 'Create Code'}
          </button>
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            className="px-4 py-2 text-gray-600 hover:text-gray-900 text-sm"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  )
}
