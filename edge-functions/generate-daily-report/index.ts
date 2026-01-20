/**
 * Generate Daily Report Edge Function
 * 
 * Aggregates daily project data (logs, forms, shifts) and uses Gemini AI
 * to generate a comprehensive daily report that is stored as a form_instance.
 * 
 * POST /generate-daily-report
 * Body: { project_id: string, report_date: string (YYYY-MM-DD) }
 * 
 * Returns: { success: true, form_id: string }
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Types
interface DailyLog {
  id: string
  log_type: string
  content: string
  metadata: Record<string, unknown>
  status: string
  created_at: string
}

interface FormInstance {
  id: string
  template_id: string
  title: string | null
  form_data: Record<string, unknown>
  created_at: string
  submitted_at: string | null
}

interface ShiftData {
  id: string
  name: string
  status: string
  start_time: string | null
  end_time: string | null
  worker_count: number
  forms_submitted: number
  shift_tasks: Array<{ id: string; content: string; checked: boolean }>
  shift_notes: Array<{ id: string; content: string }>
}

interface ProjectData {
  id: string
  name: string
}

interface AIGeneratedReport {
  work_summary: {
    content: string
    tasks_completed: number
    tasks_total: number
  }
  safety_summary: {
    content: string
    incidents: number
    near_misses: number
    observations: string[]
  }
  manpower_summary: {
    content: string
    total_workers: number
    total_hours: number
    companies: string[]
  }
  issues_summary: {
    content: string
    open_issues: number
    resolved_today: number
    delays: string[]
  }
  forms_summary: {
    content: string
    flra_count: number
    hot_work_count: number
    other_count: number
    form_types: Record<string, number>
  }
  weather: {
    conditions: string
    temperature: number | null
    temperature_unit: string
    notes: string
  }
}

// Initialize Supabase client with service role for full access
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

// Gemini API configuration
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? ''
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

/**
 * Retry a function with exponential backoff for rate limits
 */
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelay: number = 1000
): Promise<T> {
  let lastError: Error = new Error('Unknown error')
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error))
      
      const errorMessage = lastError.message.toLowerCase()
      const isRetryable = 
        errorMessage.includes('503') || 
        errorMessage.includes('429') ||
        errorMessage.includes('500') ||
        errorMessage.includes('overloaded') ||
        errorMessage.includes('rate limit')
      
      if (!isRetryable || attempt === maxRetries) {
        throw lastError
      }
      
      const delay = baseDelay * Math.pow(2, attempt)
      console.log(`⏳ Retry ${attempt + 1}/${maxRetries} after ${delay}ms`)
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }
  
  throw lastError
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      }
    })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const { project_id, report_date } = await req.json()

    if (!project_id || !report_date) {
      return new Response(
        JSON.stringify({ error: 'project_id and report_date are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📊 Generating daily report for project: ${project_id}, date: ${report_date}`)

    // Get authorization header to determine the user
    const authHeader = req.headers.get('Authorization')
    let userId: string | null = null
    
    if (authHeader) {
      const token = authHeader.replace('Bearer ', '')
      const { data: { user } } = await supabaseAdmin.auth.getUser(token)
      userId = user?.id ?? null
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Authentication required' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // 1. Fetch project details
    const { data: project, error: projectError } = await supabaseAdmin
      .from('supervisor_projects')
      .select('id, name')
      .eq('id', project_id)
      .eq('supervisor_id', userId)
      .single()

    if (projectError || !project) {
      console.error('❌ Project not found or access denied:', projectError)
      return new Response(
        JSON.stringify({ error: 'Project not found or access denied' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Project: ${project.name}`)

    // 2. Fetch daily logs for the date
    const { data: dailyLogs, error: logsError } = await supabaseAdmin
      .from('project_daily_logs')
      .select('*')
      .eq('project_id', project_id)
      .eq('log_date', report_date)
      .order('created_at', { ascending: true })

    if (logsError) {
      console.error('❌ Failed to fetch daily logs:', logsError)
    }

    console.log(`📝 Daily logs: ${dailyLogs?.length ?? 0}`)

    // 3. Fetch form instances submitted that day
    const { data: formInstances, error: formsError } = await supabaseAdmin
      .from('form_instances')
      .select('id, template_id, title, form_data, created_at, submitted_at')
      .eq('project_id', project_id)
      .gte('created_at', `${report_date}T00:00:00`)
      .lt('created_at', `${report_date}T23:59:59.999`)
      .neq('template_id', 'daily_report') // Exclude other daily reports
      .order('created_at', { ascending: true })

    if (formsError) {
      console.error('❌ Failed to fetch form instances:', formsError)
    }

    console.log(`📋 Form instances: ${formInstances?.length ?? 0}`)

    // 4. Fetch shifts for the date with worker counts
    const { data: shifts, error: shiftsError } = await supabaseAdmin
      .from('project_shifts')
      .select(`
        id,
        name,
        status,
        start_time,
        end_time,
        shift_tasks,
        shift_notes
      `)
      .eq('project_id', project_id)
      .eq('scheduled_date', report_date)

    if (shiftsError) {
      console.error('❌ Failed to fetch shifts:', shiftsError)
    }

    // Get worker counts for each shift
    const shiftsWithCounts: ShiftData[] = []
    if (shifts && shifts.length > 0) {
      for (const shift of shifts) {
        const { data: workers } = await supabaseAdmin
          .from('shift_workers')
          .select('id, form_submitted')
          .eq('shift_id', shift.id)

        shiftsWithCounts.push({
          ...shift,
          worker_count: workers?.length ?? 0,
          forms_submitted: workers?.filter(w => w.form_submitted).length ?? 0,
          shift_tasks: shift.shift_tasks ?? [],
          shift_notes: shift.shift_notes ?? [],
        })
      }
    }

    console.log(`👷 Shifts: ${shiftsWithCounts.length}`)

    // 5. Generate AI report using Gemini
    const aiReport = await retryWithBackoff(() => 
      generateAIReport(project, dailyLogs ?? [], formInstances ?? [], shiftsWithCounts, report_date)
    )

    console.log(`🤖 AI report generated successfully`)

    // 6. Create form_instance with the generated report
    const today = new Date()
    const dateStr = today.toISOString().slice(0, 10).replace(/-/g, '')

    // Get the highest form number for today
    const { data: existingForms } = await supabaseAdmin
      .from('form_instances')
      .select('form_number')
      .like('form_number', `${dateStr}-%`)
      .order('form_number', { ascending: false })
      .limit(1)

    let nextNumber = 1
    if (existingForms && existingForms.length > 0) {
      const match = existingForms[0].form_number.match(/-(\d+)$/)
      if (match) {
        nextNumber = parseInt(match[1]) + 1
      }
    }

    const formNumber = `${dateStr}-${nextNumber.toString().padStart(2, '0')}`

    // Build form_data structure
    const formData = {
      modules: {
        header: {
          report_date: { value: report_date },
          project_name: { value: project.name },
          generated_at: { value: new Date().toISOString() },
          ai_generated: { value: true },
        },
        weather: {
          conditions: { value: aiReport.weather.conditions },
          temperature: { value: aiReport.weather.temperature },
          temperature_unit: { value: aiReport.weather.temperature_unit },
          notes: { value: aiReport.weather.notes },
        },
        work_summary: {
          content: { value: aiReport.work_summary.content },
          tasks_completed: { value: aiReport.work_summary.tasks_completed },
          tasks_total: { value: aiReport.work_summary.tasks_total },
        },
        safety_summary: {
          content: { value: aiReport.safety_summary.content },
          incidents: { value: aiReport.safety_summary.incidents },
          near_misses: { value: aiReport.safety_summary.near_misses },
          observations: { value: aiReport.safety_summary.observations },
        },
        manpower_summary: {
          content: { value: aiReport.manpower_summary.content },
          total_workers: { value: aiReport.manpower_summary.total_workers },
          total_hours: { value: aiReport.manpower_summary.total_hours },
          companies: { value: aiReport.manpower_summary.companies },
        },
        issues_summary: {
          content: { value: aiReport.issues_summary.content },
          open_issues: { value: aiReport.issues_summary.open_issues },
          resolved_today: { value: aiReport.issues_summary.resolved_today },
          delays: { value: aiReport.issues_summary.delays },
        },
        forms_summary: {
          content: { value: aiReport.forms_summary.content },
          flra_count: { value: aiReport.forms_summary.flra_count },
          hot_work_count: { value: aiReport.forms_summary.hot_work_count },
          other_count: { value: aiReport.forms_summary.other_count },
          form_types: { value: aiReport.forms_summary.form_types },
        },
        supervisor_notes: {
          content: { value: '' },
        },
      },
      templateId: 'daily_report',
    }

    // Insert the form instance
    const { data: newForm, error: insertError } = await supabaseAdmin
      .from('form_instances')
      .insert({
        template_id: 'daily_report',
        form_number: formNumber,
        title: `Daily Report - ${report_date}`,
        created_by: userId,
        project_id: project_id,
        form_data: formData,
        status: 'active',
      })
      .select()
      .single()

    if (insertError) {
      console.error('❌ Failed to create form instance:', insertError)
      return new Response(
        JSON.stringify({ error: 'Failed to create daily report', details: insertError.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Daily report created: ${newForm.id}`)

    return new Response(
      JSON.stringify({
        success: true,
        form_id: newForm.id,
        message: 'Daily report generated successfully',
      }),
      { 
        status: 200, 
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        } 
      }
    )

  } catch (error) {
    console.error('❌ Error generating daily report:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        } 
      }
    )
  }
})

/**
 * Generate AI report using Gemini
 */
async function generateAIReport(
  project: ProjectData,
  dailyLogs: DailyLog[],
  formInstances: FormInstance[],
  shifts: ShiftData[],
  reportDate: string
): Promise<AIGeneratedReport> {
  
  if (!GEMINI_API_KEY) {
    console.log('⚠️ GEMINI_API_KEY not configured, using fallback report')
    return generateFallbackReport(dailyLogs, formInstances, shifts)
  }

  // Group logs by type
  const logsByType: Record<string, DailyLog[]> = {}
  for (const log of dailyLogs) {
    if (!logsByType[log.log_type]) {
      logsByType[log.log_type] = []
    }
    logsByType[log.log_type].push(log)
  }

  // Count forms by type
  const formsByType: Record<string, number> = {}
  for (const form of formInstances) {
    const type = form.template_id || 'unknown'
    formsByType[type] = (formsByType[type] || 0) + 1
  }

  // Calculate shift statistics
  const totalWorkers = shifts.reduce((sum, s) => sum + s.worker_count, 0)
  const totalTasks = shifts.reduce((sum, s) => sum + (s.shift_tasks?.length ?? 0), 0)
  const completedTasks = shifts.reduce((sum, s) => 
    sum + (s.shift_tasks?.filter(t => t.checked).length ?? 0), 0)

  // Build comprehensive prompt
  const prompt = `You are a construction site supervisor assistant. Generate a comprehensive daily report for a construction project.

PROJECT: ${project.name}
DATE: ${reportDate}

=== RAW DATA ===

DAILY LOGS (${dailyLogs.length} total):
${Object.entries(logsByType).map(([type, logs]) => `
${type.toUpperCase()} (${logs.length}):
${logs.map(l => `- ${l.content}${l.metadata ? ` | Metadata: ${JSON.stringify(l.metadata)}` : ''}${l.status !== 'active' ? ` [${l.status}]` : ''}`).join('\n')}
`).join('\n')}

FORMS SUBMITTED (${formInstances.length} total):
${Object.entries(formsByType).map(([type, count]) => `- ${type}: ${count}`).join('\n') || '- None'}

SHIFTS (${shifts.length} total):
${shifts.map(s => `
- ${s.name} (${s.status})
  Workers: ${s.worker_count}, Forms submitted: ${s.forms_submitted}
  Tasks: ${s.shift_tasks?.filter(t => t.checked).length ?? 0}/${s.shift_tasks?.length ?? 0} completed
  Notes: ${s.shift_notes?.map(n => n.content).join('; ') || 'None'}
`).join('')}

TOTALS:
- Total workers across shifts: ${totalWorkers}
- Total tasks: ${totalTasks}, Completed: ${completedTasks}

=== INSTRUCTIONS ===

Based on the above data, generate a structured daily report in JSON format. Write professional, concise summaries for each section. If data is missing for a section, acknowledge it briefly and note "No data recorded for this category."

For weather: If no weather data is in the logs, set conditions to "not_recorded" and leave notes explaining weather was not logged.

Respond ONLY with valid JSON in this exact format:
{
  "work_summary": {
    "content": "2-3 sentence summary of work accomplished today",
    "tasks_completed": ${completedTasks},
    "tasks_total": ${totalTasks}
  },
  "safety_summary": {
    "content": "2-3 sentence summary of safety observations and any incidents",
    "incidents": 0,
    "near_misses": 0,
    "observations": ["observation 1", "observation 2"]
  },
  "manpower_summary": {
    "content": "2-3 sentence summary of workforce for the day",
    "total_workers": ${totalWorkers},
    "total_hours": ${totalWorkers * 8},
    "companies": ["company names from logs/forms"]
  },
  "issues_summary": {
    "content": "2-3 sentence summary of site issues and delays",
    "open_issues": 0,
    "resolved_today": 0,
    "delays": ["delay descriptions if any"]
  },
  "forms_summary": {
    "content": "2-3 sentence summary of safety forms submitted",
    "flra_count": ${formsByType['flra'] || 0},
    "hot_work_count": ${formsByType['hot_work_permit'] || 0},
    "other_count": ${formInstances.length - (formsByType['flra'] || 0) - (formsByType['hot_work_permit'] || 0)},
    "form_types": ${JSON.stringify(formsByType)}
  },
  "weather": {
    "conditions": "sunny|cloudy|partly_cloudy|rain|snow|fog|windy|storm|not_recorded",
    "temperature": null,
    "temperature_unit": "F",
    "notes": "Weather notes or 'Weather not recorded'"
  }
}`

  console.log('🚀 Calling Gemini API for report generation')

  const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [{ text: prompt }]
      }],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 4096,
        responseMimeType: 'application/json'
      }
    })
  })

  if (!response.ok) {
    const errorText = await response.text()
    console.error('Gemini API error:', errorText)
    throw new Error(`Gemini API error: ${response.status} - ${errorText}`)
  }

  const result = await response.json()
  const text = result.candidates?.[0]?.content?.parts?.[0]?.text ?? ''

  try {
    const parsed = JSON.parse(text)
    return {
      work_summary: parsed.work_summary || { content: 'No work summary generated', tasks_completed: completedTasks, tasks_total: totalTasks },
      safety_summary: parsed.safety_summary || { content: 'No safety summary generated', incidents: 0, near_misses: 0, observations: [] },
      manpower_summary: parsed.manpower_summary || { content: 'No manpower summary generated', total_workers: totalWorkers, total_hours: totalWorkers * 8, companies: [] },
      issues_summary: parsed.issues_summary || { content: 'No issues summary generated', open_issues: 0, resolved_today: 0, delays: [] },
      forms_summary: parsed.forms_summary || { content: 'No forms summary generated', flra_count: 0, hot_work_count: 0, other_count: 0, form_types: {} },
      weather: parsed.weather || { conditions: 'not_recorded', temperature: null, temperature_unit: 'F', notes: 'Weather not recorded' },
    }
  } catch (parseError) {
    console.error('Failed to parse AI response:', text)
    console.error('Parse error:', parseError)
    return generateFallbackReport(dailyLogs, formInstances, shifts)
  }
}

/**
 * Generate a fallback report when AI is unavailable
 */
function generateFallbackReport(
  dailyLogs: DailyLog[],
  formInstances: FormInstance[],
  shifts: ShiftData[]
): AIGeneratedReport {
  const totalWorkers = shifts.reduce((sum, s) => sum + s.worker_count, 0)
  const totalTasks = shifts.reduce((sum, s) => sum + (s.shift_tasks?.length ?? 0), 0)
  const completedTasks = shifts.reduce((sum, s) => 
    sum + (s.shift_tasks?.filter(t => t.checked).length ?? 0), 0)

  // Count forms by type
  const formsByType: Record<string, number> = {}
  for (const form of formInstances) {
    const type = form.template_id || 'unknown'
    formsByType[type] = (formsByType[type] || 0) + 1
  }

  // Count logs by type
  const visitorCount = dailyLogs.filter(l => l.log_type === 'visitor').length
  const deliveryCount = dailyLogs.filter(l => l.log_type === 'delivery').length
  const issueCount = dailyLogs.filter(l => l.log_type === 'site_issue').length
  const openIssues = dailyLogs.filter(l => l.log_type === 'site_issue' && l.status !== 'resolved').length
  const resolvedIssues = dailyLogs.filter(l => l.log_type === 'site_issue' && l.status === 'resolved').length

  // Extract companies from manpower logs
  const companies: string[] = []
  dailyLogs
    .filter(l => l.log_type === 'manpower')
    .forEach(l => {
      const company = (l.metadata as { company?: string })?.company
      if (company && !companies.includes(company)) {
        companies.push(company)
      }
    })

  return {
    work_summary: {
      content: `${shifts.length} shift(s) scheduled with ${completedTasks} of ${totalTasks} tasks completed. ${deliveryCount} deliveries received, ${visitorCount} visitors logged.`,
      tasks_completed: completedTasks,
      tasks_total: totalTasks,
    },
    safety_summary: {
      content: `${formInstances.length} safety forms submitted. ${issueCount} site issues logged.`,
      incidents: 0,
      near_misses: 0,
      observations: dailyLogs.filter(l => l.log_type === 'observation').map(l => l.content),
    },
    manpower_summary: {
      content: `${totalWorkers} workers across ${shifts.length} shift(s). ${companies.length > 0 ? `Companies on site: ${companies.join(', ')}` : 'Company information not recorded.'}`,
      total_workers: totalWorkers,
      total_hours: totalWorkers * 8,
      companies,
    },
    issues_summary: {
      content: `${openIssues} open issue(s), ${resolvedIssues} resolved today.`,
      open_issues: openIssues,
      resolved_today: resolvedIssues,
      delays: dailyLogs.filter(l => l.log_type === 'schedule_delay').map(l => l.content),
    },
    forms_summary: {
      content: `${formInstances.length} form(s) submitted: ${Object.entries(formsByType).map(([k, v]) => `${v} ${k}`).join(', ') || 'None'}`,
      flra_count: formsByType['flra'] || 0,
      hot_work_count: formsByType['hot_work_permit'] || 0,
      other_count: formInstances.length - (formsByType['flra'] || 0) - (formsByType['hot_work_permit'] || 0),
      form_types: formsByType,
    },
    weather: {
      conditions: 'not_recorded',
      temperature: null,
      temperature_unit: 'F',
      notes: 'Weather not recorded. Please update manually.',
    },
  }
}
