/**
 * Send Shift Notifications Edge Function
 * 
 * Sends SMS (via Twilio) and/or email (via SendGrid) notifications to workers
 * assigned to a shift, prompting them to fill out their safety forms.
 * 
 * POST /functions/v1/send-shift-notifications
 * Body: { shift_id: string }
 * 
 * Required environment variables:
 * - SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-provided)
 * - TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER (for SMS)
 * - SENDGRID_API_KEY, SENDGRID_FROM_EMAIL (for email)
 * 
 * If Twilio is not configured, workers with SMS preference will fall back to email.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Types
interface ShiftWorker {
  id: string
  shift_id: string
  name: string
  phone: string | null
  email: string | null
  notification_method: 'sms' | 'email' | 'both'
  notification_status: string
}

interface Shift {
  id: string
  name: string
  scheduled_date: string
  start_time: string | null
  notes: string | null
  project_id: string
}

interface Project {
  id: string
  name: string
  site_address: string | null
}

interface NotificationResult {
  worker_id: string
  name: string
  sms_sent: boolean
  email_sent: boolean
  error?: string
}

// Initialize Supabase client with service role for full access
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

// Twilio configuration
const TWILIO_ACCOUNT_SID = Deno.env.get('TWILIO_ACCOUNT_SID')
const TWILIO_AUTH_TOKEN = Deno.env.get('TWILIO_AUTH_TOKEN')
const TWILIO_PHONE_NUMBER = Deno.env.get('TWILIO_PHONE_NUMBER')

// SendGrid configuration
const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')
const SENDGRID_FROM_EMAIL = Deno.env.get('SENDGRID_FROM_EMAIL') ?? 'noreply@hrdhat.site'

// HrdHat app URL (for the form link)
const HRDHAT_APP_URL = Deno.env.get('HRDHAT_APP_URL') ?? 'https://hrdhat.site'

// Check if providers are configured
const isTwilioConfigured = !!(TWILIO_ACCOUNT_SID && TWILIO_AUTH_TOKEN && TWILIO_PHONE_NUMBER)
const isSendGridConfigured = !!SENDGRID_API_KEY

Deno.serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    // Verify authentication
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Parse request body
    const { shift_id } = await req.json()
    
    if (!shift_id) {
      return new Response(JSON.stringify({ error: 'shift_id is required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`📧 Sending notifications for shift: ${shift_id}`)

    // Fetch shift details
    const { data: shift, error: shiftError } = await supabaseAdmin
      .from('project_shifts')
      .select('*')
      .eq('id', shift_id)
      .single()

    if (shiftError || !shift) {
      console.error('Shift not found:', shiftError)
      return new Response(JSON.stringify({ error: 'Shift not found' }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    // Fetch project details
    const { data: project } = await supabaseAdmin
      .from('supervisor_projects')
      .select('*')
      .eq('id', shift.project_id)
      .single()

    // Fetch workers to notify (only pending ones)
    const { data: workers, error: workersError } = await supabaseAdmin
      .from('shift_workers')
      .select('*')
      .eq('shift_id', shift_id)
      .eq('notification_status', 'pending')

    if (workersError) {
      console.error('Error fetching workers:', workersError)
      return new Response(JSON.stringify({ error: 'Failed to fetch workers' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    if (!workers || workers.length === 0) {
      return new Response(JSON.stringify({ 
        success: true,
        message: 'No workers pending notification',
        sent: 0,
        failed: 0
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    console.log(`📋 Found ${workers.length} workers to notify`)

    // Provider status info
    console.log(`📱 Twilio configured: ${isTwilioConfigured}`)
    console.log(`📧 SendGrid configured: ${isSendGridConfigured}`)

    // Process notifications for each worker
    const results: NotificationResult[] = []

    for (const worker of workers) {
      const result: NotificationResult = {
        worker_id: worker.id,
        name: worker.name,
        sms_sent: false,
        email_sent: false
      }

      try {
        // Determine notification method
        const shouldSendSms = (worker.notification_method === 'sms' || worker.notification_method === 'both') && worker.phone
        const shouldSendEmail = (worker.notification_method === 'email' || worker.notification_method === 'both') && worker.email

        // Send SMS if configured and phone available
        if (shouldSendSms && isTwilioConfigured) {
          try {
            await sendSms(worker.phone!, shift, project)
            result.sms_sent = true
            console.log(`✅ SMS sent to ${worker.name}`)
          } catch (smsError) {
            console.error(`❌ SMS failed for ${worker.name}:`, smsError)
            result.error = `SMS: ${smsError.message}`
          }
        } else if (shouldSendSms && !isTwilioConfigured) {
          console.log(`⚠️ Twilio not configured, falling back to email for ${worker.name}`)
        }

        // Send email if configured and email available
        // Also send email as fallback if SMS was intended but Twilio isn't configured
        const emailFallback = shouldSendSms && !isTwilioConfigured && !result.sms_sent && worker.email
        if ((shouldSendEmail || emailFallback) && isSendGridConfigured) {
          try {
            await sendEmail(worker.email!, worker.name, shift, project)
            result.email_sent = true
            console.log(`✅ Email sent to ${worker.name}`)
          } catch (emailError) {
            console.error(`❌ Email failed for ${worker.name}:`, emailError)
            result.error = result.error 
              ? `${result.error}; Email: ${emailError.message}`
              : `Email: ${emailError.message}`
          }
        }

        // Update notification status in database
        const notificationSent = result.sms_sent || result.email_sent
        await supabaseAdmin
          .from('shift_workers')
          .update({
            notification_status: notificationSent ? 'sent' : 'failed',
            notification_sent_at: notificationSent ? new Date().toISOString() : null,
            notification_error: result.error ?? null
          })
          .eq('id', worker.id)

      } catch (workerError) {
        console.error(`Error processing worker ${worker.name}:`, workerError)
        result.error = workerError.message
        
        await supabaseAdmin
          .from('shift_workers')
          .update({
            notification_status: 'failed',
            notification_error: workerError.message
          })
          .eq('id', worker.id)
      }

      results.push(result)
    }

    // Update shift status to active if it was in draft
    if (shift.status === 'draft') {
      await supabaseAdmin
        .from('project_shifts')
        .update({ status: 'active' })
        .eq('id', shift_id)
    }

    // Calculate summary
    const sent = results.filter(r => r.sms_sent || r.email_sent).length
    const failed = results.filter(r => !r.sms_sent && !r.email_sent).length

    console.log(`✅ Notifications complete: ${sent} sent, ${failed} failed`)

    return new Response(JSON.stringify({
      success: true,
      message: `Sent ${sent} notification(s), ${failed} failed`,
      sent,
      failed,
      results
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })

  } catch (error) {
    console.error('❌ Error sending notifications:', error)
    return new Response(JSON.stringify({ 
      error: 'Internal server error', 
      details: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

/**
 * Send SMS via Twilio
 */
async function sendSms(phone: string, shift: Shift, project: Project | null): Promise<void> {
  const projectName = project?.name ?? 'HrdHat Project'
  const formLink = `${HRDHAT_APP_URL}/forms/new`
  
  const message = `HrdHat Safety Alert
${projectName} - ${shift.name}
${formatDate(shift.scheduled_date)}${shift.start_time ? ` at ${formatTime(shift.start_time)}` : ''}

Please complete your safety form before starting work.

${shift.notes ? `Note: ${shift.notes.substring(0, 100)}${shift.notes.length > 100 ? '...' : ''}\n\n` : ''}Open app: ${formLink}`

  const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json`
  
  const response = await fetch(twilioUrl, {
    method: 'POST',
    headers: {
      'Authorization': 'Basic ' + btoa(`${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}`),
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      To: phone,
      From: TWILIO_PHONE_NUMBER!,
      Body: message
    })
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`Twilio API error: ${response.status} - ${errorText}`)
  }
}

/**
 * Send email via SendGrid
 */
async function sendEmail(email: string, name: string, shift: Shift, project: Project | null): Promise<void> {
  const projectName = project?.name ?? 'HrdHat Project'
  const siteAddress = project?.site_address ?? ''
  const formLink = `${HRDHAT_APP_URL}/forms/new`
  
  const subject = `Safety Form Required - ${shift.name}`
  
  const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #1e40af; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
    .content { background: #f9fafb; padding: 24px; border: 1px solid #e5e7eb; border-top: none; }
    .shift-details { background: white; padding: 16px; border-radius: 8px; margin: 16px 0; }
    .detail-row { display: flex; margin: 8px 0; }
    .detail-label { font-weight: 600; width: 120px; color: #6b7280; }
    .detail-value { color: #111827; }
    .notes { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 12px; margin: 16px 0; }
    .cta-button { display: inline-block; background: #1e40af; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 16px 0; }
    .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 24px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0; font-size: 24px;">🦺 HrdHat Safety Alert</h1>
    </div>
    <div class="content">
      <p>Hi ${name},</p>
      
      <p>You've been assigned to an upcoming shift and need to complete your safety form before starting work.</p>
      
      <div class="shift-details">
        <div class="detail-row">
          <span class="detail-label">Project:</span>
          <span class="detail-value">${projectName}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Shift:</span>
          <span class="detail-value">${shift.name}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Date:</span>
          <span class="detail-value">${formatDate(shift.scheduled_date)}</span>
        </div>
        ${shift.start_time ? `
        <div class="detail-row">
          <span class="detail-label">Start Time:</span>
          <span class="detail-value">${formatTime(shift.start_time)}</span>
        </div>
        ` : ''}
        ${siteAddress ? `
        <div class="detail-row">
          <span class="detail-label">Location:</span>
          <span class="detail-value">${siteAddress}</span>
        </div>
        ` : ''}
      </div>
      
      ${shift.notes ? `
      <div class="notes">
        <strong>Safety Notes from Supervisor:</strong><br>
        ${shift.notes}
      </div>
      ` : ''}
      
      <p>Please open the HrdHat app and complete your safety form:</p>
      
      <a href="${formLink}" class="cta-button">Open HrdHat App →</a>
      
      <p style="color: #6b7280; font-size: 14px; margin-top: 24px;">
        After completing your form, make sure to email it to your project's intake address.
      </p>
    </div>
    <div class="footer">
      <p>This is an automated message from HrdHat Safety Management.</p>
      <p>If you believe you received this in error, please contact your supervisor.</p>
    </div>
  </div>
</body>
</html>
`

  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SENDGRID_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      personalizations: [{
        to: [{ email, name }]
      }],
      from: {
        email: SENDGRID_FROM_EMAIL,
        name: 'HrdHat Safety'
      },
      subject,
      content: [
        { type: 'text/html', value: htmlContent }
      ]
    })
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`SendGrid API error: ${response.status} - ${errorText}`)
  }
}

/**
 * Format date for display
 */
function formatDate(dateStr: string): string {
  const date = new Date(dateStr + 'T00:00:00')
  return date.toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric'
  })
}

/**
 * Format time for display
 */
function formatTime(timeStr: string): string {
  const [hours, minutes] = timeStr.split(':')
  const hour = parseInt(hours, 10)
  const ampm = hour >= 12 ? 'PM' : 'AM'
  const hour12 = hour % 12 || 12
  return `${hour12}:${minutes} ${ampm}`
}
