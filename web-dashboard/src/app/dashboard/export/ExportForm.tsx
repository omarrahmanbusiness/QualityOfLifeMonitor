'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Download, FileSpreadsheet, FileJson, FileText } from 'lucide-react'
import * as XLSX from 'xlsx'

interface Patient {
  id: string
  email: string | null
  patient_code: string | null
}

type ExportFormat = 'csv' | 'json' | 'xlsx' | 'spss' | 'sas'
type DataType = 'health_samples' | 'locations' | 'screen_time' | 'heart_failure_events' | 'all'

export function ExportForm({
  patients,
  selectedPatientId,
  isSuperuser,
}: {
  patients: Patient[]
  selectedPatientId?: string
  isSuperuser: boolean
}) {
  const [patientId, setPatientId] = useState(selectedPatientId || '')
  const [dataType, setDataType] = useState<DataType>('all')
  const [format, setFormat] = useState<ExportFormat>('csv')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleExport = async () => {
    setLoading(true)
    setError('')

    try {
      const supabase = createClient()
      const data: Record<string, any[]> = {}

      const patientIds = patientId
        ? [patientId]
        : patients.map((p) => p.id)

      // Build date filter
      const dateFilter = (query: any) => {
        if (dateFrom) {
          query = query.gte('start_date', dateFrom)
        }
        if (dateTo) {
          query = query.lte('end_date', dateTo)
        }
        return query
      }

      // Fetch data based on type
      if (dataType === 'all' || dataType === 'health_samples') {
        let query = supabase
          .from('health_samples')
          .select('*')
          .in('patient_id', patientIds)
          .order('start_date', { ascending: false })
        query = dateFilter(query)
        const { data: samples } = await query
        data.health_samples = samples || []
      }

      if (dataType === 'all' || dataType === 'locations') {
        let query = supabase
          .from('locations')
          .select('*')
          .in('patient_id', patientIds)
          .order('timestamp', { ascending: false })
        if (dateFrom) query = query.gte('timestamp', dateFrom)
        if (dateTo) query = query.lte('timestamp', dateTo)
        const { data: locations } = await query
        data.locations = locations || []
      }

      if (dataType === 'all' || dataType === 'screen_time') {
        let query = supabase
          .from('screen_time')
          .select('*')
          .in('patient_id', patientIds)
          .order('date', { ascending: false })
        if (dateFrom) query = query.gte('date', dateFrom)
        if (dateTo) query = query.lte('date', dateTo)
        const { data: screenTime } = await query
        data.screen_time = screenTime || []
      }

      if (dataType === 'all' || dataType === 'heart_failure_events') {
        let query = supabase
          .from('heart_failure_events')
          .select('*')
          .in('patient_id', patientIds)
          .order('timestamp', { ascending: false })
        if (dateFrom) query = query.gte('timestamp', dateFrom)
        if (dateTo) query = query.lte('timestamp', dateTo)
        const { data: events } = await query
        data.heart_failure_events = events || []
      }

      // Export based on format
      switch (format) {
        case 'json':
          downloadJSON(data)
          break
        case 'csv':
          downloadCSV(data)
          break
        case 'xlsx':
          downloadXLSX(data)
          break
        case 'spss':
          downloadSPSS(data)
          break
        case 'sas':
          downloadSAS(data)
          break
      }
    } catch (err: any) {
      setError(err.message || 'Export failed')
    } finally {
      setLoading(false)
    }
  }

  const downloadJSON = (data: Record<string, any[]>) => {
    const blob = new Blob([JSON.stringify(data, null, 2)], {
      type: 'application/json',
    })
    downloadBlob(blob, 'qol_export.json')
  }

  const downloadCSV = (data: Record<string, any[]>) => {
    Object.entries(data).forEach(([key, rows]) => {
      if (rows.length === 0) return
      const headers = Object.keys(rows[0])
      const csv = [
        headers.join(','),
        ...rows.map((row) =>
          headers
            .map((h) => {
              const val = row[h]
              if (val === null || val === undefined) return ''
              if (typeof val === 'string' && val.includes(','))
                return `"${val}"`
              return val
            })
            .join(',')
        ),
      ].join('\n')
      const blob = new Blob([csv], { type: 'text/csv' })
      downloadBlob(blob, `qol_${key}.csv`)
    })
  }

  const downloadXLSX = (data: Record<string, any[]>) => {
    const wb = XLSX.utils.book_new()
    Object.entries(data).forEach(([key, rows]) => {
      if (rows.length === 0) return
      const ws = XLSX.utils.json_to_sheet(rows)
      XLSX.utils.book_append_sheet(wb, ws, key.slice(0, 31))
    })
    const buffer = XLSX.write(wb, { bookType: 'xlsx', type: 'array' })
    const blob = new Blob([buffer], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    })
    downloadBlob(blob, 'qol_export.xlsx')
  }

  const downloadSPSS = (data: Record<string, any[]>) => {
    // Generate SPSS syntax file for import
    Object.entries(data).forEach(([key, rows]) => {
      if (rows.length === 0) return
      const headers = Object.keys(rows[0])

      // Create data list format
      let syntax = `* SPSS Syntax for ${key}.\n`
      syntax += `DATA LIST FREE / ${headers.join(' ')}.\n`
      syntax += `BEGIN DATA.\n`

      rows.forEach(row => {
        syntax += headers.map(h => {
          const val = row[h]
          if (val === null || val === undefined) return '.'
          if (typeof val === 'string') return `"${val.replace(/"/g, '""')}"`
          return val
        }).join(' ') + '\n'
      })

      syntax += `END DATA.\n`
      syntax += `EXECUTE.\n`

      const blob = new Blob([syntax], { type: 'text/plain' })
      downloadBlob(blob, `qol_${key}.sps`)
    })
  }

  const downloadSAS = (data: Record<string, any[]>) => {
    // Generate SAS data step
    Object.entries(data).forEach(([key, rows]) => {
      if (rows.length === 0) return
      const headers = Object.keys(rows[0])

      let sas = `/* SAS Data Step for ${key} */\n`
      sas += `data ${key};\n`
      sas += `  infile datalines dsd truncover;\n`
      sas += `  input ${headers.join(' $ ')} $;\n`
      sas += `  datalines;\n`

      rows.forEach(row => {
        sas += headers.map(h => {
          const val = row[h]
          if (val === null || val === undefined) return ''
          return String(val).replace(/,/g, ';')
        }).join(',') + '\n'
      })

      sas += `;\nrun;\n`

      const blob = new Blob([sas], { type: 'text/plain' })
      downloadBlob(blob, `qol_${key}.sas`)
    })
  }

  const downloadBlob = (blob: Blob, filename: string) => {
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  const formats = [
    { id: 'csv', name: 'CSV', icon: FileText, desc: 'Comma-separated values' },
    { id: 'json', name: 'JSON', icon: FileJson, desc: 'JavaScript Object Notation' },
    { id: 'xlsx', name: 'Excel', icon: FileSpreadsheet, desc: 'Microsoft Excel workbook' },
    { id: 'spss', name: 'SPSS', icon: FileText, desc: 'SPSS syntax file' },
    { id: 'sas', name: 'SAS', icon: FileText, desc: 'SAS data step' },
  ]

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 space-y-6">
      {error && (
        <div className="p-3 bg-red-50 border border-red-200 text-red-700 rounded-lg text-sm">
          {error}
        </div>
      )}

      {/* Patient Selection */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Patient
        </label>
        <select
          value={patientId}
          onChange={(e) => setPatientId(e.target.value)}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
        >
          <option value="">All patients</option>
          {patients.map((p) => (
            <option key={p.id} value={p.id}>
              {p.patient_code || p.email || p.id.slice(0, 8)}
            </option>
          ))}
        </select>
      </div>

      {/* Data Type */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Data Type
        </label>
        <select
          value={dataType}
          onChange={(e) => setDataType(e.target.value as DataType)}
          className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
        >
          <option value="all">All Data</option>
          <option value="health_samples">Health Samples</option>
          <option value="locations">Locations</option>
          <option value="screen_time">Screen Time</option>
          <option value="heart_failure_events">Heart Failure Events</option>
        </select>
      </div>

      {/* Date Range */}
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            From Date
          </label>
          <input
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            To Date
          </label>
          <input
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          />
        </div>
      </div>

      {/* Format Selection */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Export Format
        </label>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
          {formats.map((f) => (
            <button
              key={f.id}
              type="button"
              onClick={() => setFormat(f.id as ExportFormat)}
              className={`p-3 rounded-lg border text-left transition-colors ${
                format === f.id
                  ? 'border-primary-500 bg-primary-50'
                  : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <f.icon
                className={`h-5 w-5 mb-1 ${
                  format === f.id ? 'text-primary-600' : 'text-gray-400'
                }`}
              />
              <p
                className={`text-sm font-medium ${
                  format === f.id ? 'text-primary-700' : 'text-gray-700'
                }`}
              >
                {f.name}
              </p>
              <p className="text-xs text-gray-500">{f.desc}</p>
            </button>
          ))}
        </div>
      </div>

      {/* Export Button */}
      <button
        onClick={handleExport}
        disabled={loading}
        className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:opacity-50"
      >
        <Download className="h-5 w-5" />
        {loading ? 'Exporting...' : 'Export Data'}
      </button>
    </div>
  )
}
