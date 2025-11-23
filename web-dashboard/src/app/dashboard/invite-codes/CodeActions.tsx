'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { Copy, Trash2, Check } from 'lucide-react'

export function CodeActions({
  code,
  codeId,
  isActive,
}: {
  code: string
  codeId: string
  isActive: boolean
}) {
  const router = useRouter()
  const [copied, setCopied] = useState(false)

  const handleCopy = async () => {
    await navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  const handleToggle = async () => {
    const supabase = createClient()
    await supabase
      .from('invite_codes')
      .update({ is_active: !isActive })
      .eq('id', codeId)
    router.refresh()
  }

  const handleDelete = async () => {
    if (!confirm('Are you sure you want to delete this invite code?')) return

    const supabase = createClient()
    await supabase.from('invite_codes').delete().eq('id', codeId)
    router.refresh()
  }

  return (
    <div className="flex items-center justify-end gap-1">
      <button
        onClick={handleCopy}
        className="p-1.5 text-gray-400 hover:text-gray-600"
        title="Copy code"
      >
        {copied ? (
          <Check className="h-4 w-4 text-green-500" />
        ) : (
          <Copy className="h-4 w-4" />
        )}
      </button>
      <button
        onClick={handleToggle}
        className={`px-2 py-1 text-xs rounded ${
          isActive
            ? 'text-gray-600 hover:bg-gray-100'
            : 'text-green-600 hover:bg-green-50'
        }`}
      >
        {isActive ? 'Disable' : 'Enable'}
      </button>
      <button
        onClick={handleDelete}
        className="p-1.5 text-gray-400 hover:text-red-600"
        title="Delete code"
      >
        <Trash2 className="h-4 w-4" />
      </button>
    </div>
  )
}
