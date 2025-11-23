'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { UserPlus } from 'lucide-react'

export function CreateClinicianForm() {
  const router = useRouter()
  const [isOpen, setIsOpen] = useState(false)
  const [email, setEmail] = useState('')
  const [name, setName] = useState('')
  const [organization, setOrganization] = useState('')
  const [password, setPassword] = useState('')
  const [isSuperuser, setIsSuperuser] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    setSuccess('')

    try {
      const supabase = createClient()

      const {
        data: { user: currentUser },
      } = await supabase.auth.getUser()

      // Create auth user via edge function or admin API
      // For now, we'll create the user directly (in production, use admin API)
      const response = await fetch(
        `${process.env.NEXT_PUBLIC_SUPABASE_URL}/auth/v1/signup`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            apikey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
          },
          body: JSON.stringify({
            email,
            password,
          }),
        }
      )

      const authData = await response.json()

      if (authData.error || !authData.id) {
        throw new Error(authData.error?.message || authData.msg || 'Failed to create user')
      }

      // Create clinician record
      const { error: clinicianError } = await supabase.from('clinicians').insert({
        user_id: authData.id,
        email,
        name,
        organization: organization || null,
        is_superuser: isSuperuser,
        is_active: true,
        created_by: currentUser!.id,
      })

      if (clinicianError) {
        throw new Error(clinicianError.message)
      }

      setSuccess(`Clinician ${name} created successfully. They can now sign in with their email and password.`)
      setEmail('')
      setName('')
      setOrganization('')
      setPassword('')
      setIsSuperuser(false)
      router.refresh()
    } catch (err: any) {
      setError(err.message || 'Failed to create clinician')
    } finally {
      setLoading(false)
    }
  }

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="flex items-center gap-2 px-4 py-2 bg-primary-600 text-white rounded-lg text-sm hover:bg-primary-700"
      >
        <UserPlus className="h-4 w-4" />
        Add Clinician
      </button>
    )
  }

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <h2 className="font-semibold text-gray-900 mb-4">Add New Clinician</h2>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      {success && (
        <div className="mb-4 p-3 bg-green-50 border border-green-200 text-green-700 rounded-lg text-sm">
          {success}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Name *
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Email *
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Password *
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
              required
              minLength={6}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Organization
            </label>
            <input
              type="text"
              value={organization}
              onChange={(e) => setOrganization(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
            />
          </div>
        </div>

        <div className="flex items-center gap-2">
          <input
            type="checkbox"
            id="isSuperuser"
            checked={isSuperuser}
            onChange={(e) => setIsSuperuser(e.target.checked)}
            className="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
          />
          <label htmlFor="isSuperuser" className="text-sm text-gray-700">
            Grant admin privileges
          </label>
        </div>

        <div className="flex gap-2">
          <button
            type="submit"
            disabled={loading}
            className="px-4 py-2 bg-primary-600 text-white rounded-lg text-sm hover:bg-primary-700 disabled:opacity-50"
          >
            {loading ? 'Creating...' : 'Create Clinician'}
          </button>
          <button
            type="button"
            onClick={() => {
              setIsOpen(false)
              setError('')
              setSuccess('')
            }}
            className="px-4 py-2 text-gray-600 hover:text-gray-900 text-sm"
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  )
}
