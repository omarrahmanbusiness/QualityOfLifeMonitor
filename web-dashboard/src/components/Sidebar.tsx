'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import {
  LayoutDashboard,
  Users,
  Ticket,
  Download,
  Settings,
  LogOut,
  Heart,
  Menu,
  X,
} from 'lucide-react'
import { useState } from 'react'

interface SidebarProps {
  clinicianName: string
  isSuperuser: boolean
}

export function Sidebar({ clinicianName, isSuperuser }: SidebarProps) {
  const pathname = usePathname()
  const router = useRouter()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

  const navigation = [
    { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
    { name: 'Patients', href: '/dashboard/patients', icon: Users },
    { name: 'Invite Codes', href: '/dashboard/invite-codes', icon: Ticket },
    { name: 'Export Data', href: '/dashboard/export', icon: Download },
  ]

  if (isSuperuser) {
    navigation.push({ name: 'Admin', href: '/dashboard/admin', icon: Settings })
  }

  const handleSignOut = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
    router.refresh()
  }

  const NavContent = () => (
    <>
      <div className="flex items-center gap-2 px-4 py-6">
        <div className="bg-primary-600 p-2 rounded-lg">
          <Heart className="h-5 w-5 text-white" />
        </div>
        <span className="font-semibold text-gray-900">QoL Monitor</span>
      </div>

      <nav className="flex-1 space-y-1 px-2">
        {navigation.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(item.href + '/')
          return (
            <Link
              key={item.name}
              href={item.href}
              onClick={() => setMobileMenuOpen(false)}
              className={cn(
                'flex items-center gap-3 px-3 py-2 text-sm font-medium rounded-lg transition-colors',
                isActive
                  ? 'bg-primary-50 text-primary-700'
                  : 'text-gray-700 hover:bg-gray-100'
              )}
            >
              <item.icon className="h-5 w-5" />
              {item.name}
            </Link>
          )
        })}
      </nav>

      <div className="p-4 border-t border-gray-200">
        <div className="mb-3">
          <p className="text-sm font-medium text-gray-900 truncate">{clinicianName}</p>
          {isSuperuser && (
            <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800">
              Admin
            </span>
          )}
        </div>
        <button
          onClick={handleSignOut}
          className="flex items-center gap-2 text-sm text-gray-600 hover:text-gray-900"
        >
          <LogOut className="h-4 w-4" />
          Sign out
        </button>
      </div>
    </>
  )

  return (
    <>
      {/* Mobile menu button */}
      <div className="lg:hidden fixed top-4 left-4 z-50">
        <button
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          className="p-2 rounded-lg bg-white shadow-md"
        >
          {mobileMenuOpen ? (
            <X className="h-6 w-6 text-gray-600" />
          ) : (
            <Menu className="h-6 w-6 text-gray-600" />
          )}
        </button>
      </div>

      {/* Mobile sidebar */}
      {mobileMenuOpen && (
        <div className="lg:hidden fixed inset-0 z-40">
          <div className="fixed inset-0 bg-gray-600 bg-opacity-75" onClick={() => setMobileMenuOpen(false)} />
          <div className="fixed inset-y-0 left-0 flex flex-col w-64 bg-white">
            <NavContent />
          </div>
        </div>
      )}

      {/* Desktop sidebar */}
      <div className="hidden lg:flex lg:flex-col lg:w-64 lg:fixed lg:inset-y-0 lg:border-r lg:border-gray-200 lg:bg-white">
        <NavContent />
      </div>
    </>
  )
}
