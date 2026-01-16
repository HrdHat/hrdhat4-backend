/**
 * Process Incoming Email Edge Function
 * 
 * Receives emails via SendGrid Inbound Parse webhook and:
 * 1. Extracts attachments (PDF, images)
 * 2. Stores files in Supabase Storage
 * 3. Calls Gemini AI for classification
 * 4. Creates received_documents record
 * 
 * Webhook URL: https://ybonzpfwdcyxbzxkyeji.supabase.co/functions/v1/process-incoming-email
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Types
interface ParsedEmail {
  from: string
  to: string
  subject: string
  text: string
  html: string
  attachments: AttachmentInfo[]
}

interface AttachmentInfo {
  filename: string
  content: Uint8Array
  contentType: string
  size: number
}

interface ClassificationResult {
  classification: string
  confidence: number
  extractedData: Record<string, unknown>
  summary: string
}

// Initialize Supabase client with service role for full access
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

// Gemini API configuration - using gemini-2.5-flash (current stable model)
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? ''
const GEMINI_MODEL = 'gemini-2.5-flash'
const GEMINI_API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`

/**
 * Convert Uint8Array to base64 string properly
 * Handles large files by building binary string incrementally
 */
function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = ''
  const len = bytes.byteLength
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}

/**
 * Extract individual email addresses from a potentially comma-separated "to" field
 * Handles formats like: "Name" <email@domain.com>, email@domain.com
 */
function extractEmailAddresses(toField: string): string[] {
  const rawTo = toField.toLowerCase().trim()
  
  // Split by comma and extract each email address
  return rawTo.split(',').map(addr => {
    const trimmed = addr.trim()
    // Extract email from angle brackets if present (e.g., "Name" <email@domain.com>)
    const match = trimmed.match(/<([^>]+)>/)
    return match ? match[1].trim() : trimmed
  }).filter(email => email.length > 0)
}

Deno.serve(async (req: Request) => {
  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    console.log('📧 Received incoming email webhook')

    // Parse the multipart form data from SendGrid
    const formData = await req.formData()
    const email = await parseEmailFromFormData(formData)

    console.log(`📬 Email from: ${email.from}, to: ${email.to}, subject: ${email.subject}`)
    console.log(`📎 Attachments: ${email.attachments.length}`)

    // Extract all email addresses from the "to" field
    // This handles cases where emails are sent to multiple recipients
    const toAddresses = extractEmailAddresses(email.to)
    
    console.log(`🔍 Raw 'to' field: "${email.to}"`)
    console.log(`🔍 Extracted addresses: ${JSON.stringify(toAddresses)}`)
    
    // Try each address until we find a matching project
    let project = null
    let matchedEmail = null
    
    for (const addr of toAddresses) {
      console.log(`🔍 Checking address: "${addr}"`)
      
      const { data, error } = await supabaseAdmin
        .from('supervisor_projects')
        .select('id, name')
        .eq('processing_email', addr)
        .single()
      
      if (data && !error) {
        project = data
        matchedEmail = addr
        console.log(`✅ Found project for address: ${addr}`)
        break
      }
    }

    if (!project) {
      console.error('❌ Project not found for any email:', toAddresses)
      return new Response(
        JSON.stringify({ error: 'Project not found', emails: toAddresses }),
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Found project: ${project.name} (${project.id}) via ${matchedEmail}`)

    // Get project folders for AI classification hints
    const { data: folders } = await supabaseAdmin
      .from('project_folders')
      .select('id, folder_name, ai_classification_hint')
      .eq('project_id', project.id)

    // Process each attachment
    const results = []
    for (const attachment of email.attachments) {
      console.log(`📄 Processing: ${attachment.filename} (${attachment.contentType})`)

      // 1. Store file in Supabase Storage
      const storagePath = `${project.id}/${Date.now()}-${attachment.filename}`
      
      const { error: uploadError } = await supabaseAdmin.storage
        .from('document-intake')
        .upload(storagePath, attachment.content, {
          contentType: attachment.contentType,
          upsert: false
        })

      if (uploadError) {
        console.error('❌ Upload error:', uploadError)
        continue
      }

      console.log(`✅ Stored: ${storagePath}`)

      // 2. Classify with AI (if API key is configured)
      let classification: ClassificationResult = {
        classification: 'Unknown',
        confidence: 0,
        extractedData: {},
        summary: 'AI classification not configured'
      }

      // Support PDFs and images
      const supportedTypes = ['application/pdf', 'image/png', 'image/jpeg', 'image/jpg', 'image/webp']
      const isSupported = supportedTypes.some(type => attachment.contentType.includes(type))

      if (GEMINI_API_KEY && isSupported) {
        try {
          classification = await classifyDocument(attachment, folders ?? [])
          console.log(`🤖 AI classified as: ${classification.classification} (${classification.confidence}%)`)
        } catch (aiError) {
          console.error('❌ AI classification error:', aiError)
          classification.summary = `AI error: ${aiError.message}`
        }
      } else if (!GEMINI_API_KEY) {
        console.log('⚠️ GEMINI_API_KEY not configured, skipping AI classification')
      } else if (!isSupported) {
        console.log(`⚠️ Unsupported file type for AI: ${attachment.contentType}`)
      }

      // 3. Find matching folder based on classification
      let matchedFolderId: string | null = null
      if (folders && classification.classification !== 'Unknown') {
        const matchedFolder = folders.find(f => 
          f.folder_name.toLowerCase().includes(classification.classification.toLowerCase()) ||
          classification.classification.toLowerCase().includes(f.folder_name.toLowerCase())
        )
        matchedFolderId = matchedFolder?.id ?? null
      }

      // 4. Try to match document to an active shift
      let matchedShiftId: string | null = null
      let matchedShiftWorkerId: string | null = null
      
      try {
        const shiftMatch = await matchDocumentToShift(
          project.id, 
          email.from, 
          classification.extractedData
        )
        if (shiftMatch) {
          matchedShiftId = shiftMatch.shift_id
          matchedShiftWorkerId = shiftMatch.shift_worker_id
          console.log(`🔗 Matched to shift: ${matchedShiftId}, worker: ${matchedShiftWorkerId}`)
        }
      } catch (matchError) {
        console.error('⚠️ Shift matching failed:', matchError)
        // Continue without shift linking
      }

      // 5. Create received_documents record
      const { data: doc, error: docError } = await supabaseAdmin
        .from('received_documents')
        .insert({
          project_id: project.id,
          folder_id: matchedFolderId,
          shift_id: matchedShiftId,
          original_filename: attachment.filename,
          storage_path: storagePath,
          file_size: attachment.size,
          mime_type: attachment.contentType,
          source_email: email.from,
          email_subject: email.subject,
          ai_classification: classification.classification,
          ai_extracted_data: classification.extractedData,
          ai_summary: classification.summary,
          confidence_score: classification.confidence,
          status: classification.confidence >= 70 ? 'filed' : 'needs_review'
        })
        .select()
        .single()

      if (docError) {
        console.error('❌ Database error:', docError)
        continue
      }

      // 6. If matched to a shift worker, update their form_submitted status
      if (matchedShiftWorkerId && doc) {
        const { error: updateError } = await supabaseAdmin
          .from('shift_workers')
          .update({
            form_submitted: true,
            form_submitted_at: new Date().toISOString(),
            document_id: doc.id
          })
          .eq('id', matchedShiftWorkerId)
        
        if (updateError) {
          console.error('⚠️ Failed to update shift worker:', updateError)
        } else {
          console.log(`✅ Updated shift worker form status: ${matchedShiftWorkerId}`)
        }
      }

      console.log(`✅ Document recorded: ${doc.id}`)
      results.push(doc)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Processed ${results.length} documents`,
        documents: results 
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error processing email:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

/**
 * Parse email data from SendGrid's multipart form data
 */
async function parseEmailFromFormData(formData: FormData): Promise<ParsedEmail> {
  const email: ParsedEmail = {
    from: formData.get('from')?.toString() ?? '',
    to: formData.get('to')?.toString() ?? '',
    subject: formData.get('subject')?.toString() ?? '',
    text: formData.get('text')?.toString() ?? '',
    html: formData.get('html')?.toString() ?? '',
    attachments: []
  }

  // Parse attachments from form data
  // SendGrid sends attachments as 'attachment1', 'attachment2', etc.
  let attachmentIndex = 1
  while (true) {
    const attachment = formData.get(`attachment${attachmentIndex}`)
    if (!attachment || !(attachment instanceof File)) break

    // Read file content as Uint8Array
    const arrayBuffer = await attachment.arrayBuffer()
    const uint8Array = new Uint8Array(arrayBuffer)

    email.attachments.push({
      filename: attachment.name,
      content: uint8Array,
      contentType: attachment.type,
      size: attachment.size
    })
    
    attachmentIndex++
  }

  // Also check for attachments info JSON
  const attachmentsInfo = formData.get('attachment-info')
  if (attachmentsInfo) {
    try {
      const info = JSON.parse(attachmentsInfo.toString())
      console.log('Attachment info:', info)
    } catch {
      // Ignore parse errors
    }
  }

  return email
}

/**
 * Match incoming document to an active shift worker
 * Tries to match by:
 * 1. Sender email matching shift_worker email
 * 2. AI-extracted worker name matching shift_worker name
 */
async function matchDocumentToShift(
  projectId: string,
  senderEmail: string,
  extractedData: Record<string, unknown>
): Promise<{ shift_id: string; shift_worker_id: string } | null> {
  
  // Extract email address from "Name <email>" format
  const emailMatch = senderEmail.match(/<([^>]+)>/)
  const cleanEmail = emailMatch ? emailMatch[1].toLowerCase() : senderEmail.toLowerCase()
  
  console.log(`🔍 Looking for shift worker with email: ${cleanEmail}`)
  
  // 1. Try to match by email first (most reliable)
  const { data: emailMatches } = await supabaseAdmin
    .from('shift_workers')
    .select(`
      id,
      shift_id,
      name,
      email,
      form_submitted,
      project_shifts!inner(id, project_id, status)
    `)
    .eq('project_shifts.project_id', projectId)
    .eq('project_shifts.status', 'active')
    .eq('form_submitted', false)
    .ilike('email', cleanEmail)
    .limit(1)
  
  if (emailMatches && emailMatches.length > 0) {
    const match = emailMatches[0]
    console.log(`✅ Email match found: ${match.name} (${match.id})`)
    return {
      shift_id: match.shift_id,
      shift_worker_id: match.id
    }
  }
  
  // 2. Try to match by worker name from AI extraction
  const workerName = extractedData.workerName as string | undefined
  if (workerName) {
    console.log(`🔍 Looking for shift worker by name: ${workerName}`)
    
    // Use a fuzzy match - check if the extracted name contains the shift worker name or vice versa
    const { data: allActiveWorkers } = await supabaseAdmin
      .from('shift_workers')
      .select(`
        id,
        shift_id,
        name,
        form_submitted,
        project_shifts!inner(id, project_id, status)
      `)
      .eq('project_shifts.project_id', projectId)
      .eq('project_shifts.status', 'active')
      .eq('form_submitted', false)
    
    if (allActiveWorkers && allActiveWorkers.length > 0) {
      // Normalize names for comparison
      const normalizedExtracted = workerName.toLowerCase().trim()
      
      for (const worker of allActiveWorkers) {
        const normalizedWorkerName = worker.name.toLowerCase().trim()
        
        // Check if names match (either exact or one contains the other)
        if (
          normalizedExtracted === normalizedWorkerName ||
          normalizedExtracted.includes(normalizedWorkerName) ||
          normalizedWorkerName.includes(normalizedExtracted)
        ) {
          console.log(`✅ Name match found: ${worker.name} (${worker.id})`)
          return {
            shift_id: worker.shift_id,
            shift_worker_id: worker.id
          }
        }
      }
    }
  }
  
  // 3. If no specific match, check if there's a single active shift for this project
  // and return just the shift_id (without a specific worker)
  const { data: activeShifts } = await supabaseAdmin
    .from('project_shifts')
    .select('id')
    .eq('project_id', projectId)
    .eq('status', 'active')
  
  if (activeShifts && activeShifts.length === 1) {
    console.log(`📋 Single active shift found, linking document to shift: ${activeShifts[0].id}`)
    // Note: We only return shift_id, not shift_worker_id since we couldn't match a specific worker
    // The caller should handle this case and NOT update shift_workers
    return null // Return null to indicate we found a shift but no specific worker
  }
  
  console.log(`❌ No shift match found`)
  return null
}

/**
 * Classify document using Gemini AI
 */
async function classifyDocument(
  attachment: AttachmentInfo,
  folders: Array<{ id: string; folder_name: string; ai_classification_hint: string | null }>
): Promise<ClassificationResult> {
  
  // Build folder context for AI
  const folderContext = folders.map(f => 
    `- ${f.folder_name}${f.ai_classification_hint ? `: ${f.ai_classification_hint}` : ''}`
  ).join('\n')

  const prompt = `You are a construction safety document classifier and metadata extractor.

Analyze this document and extract:
1. Document type/classification (match to available folders if possible)
2. Worker name (person who filled out or signed the form)
3. Company/Subcontractor name (the company the worker belongs to, often in header, footer, or signature)
4. Document date (the date on the form, NOT today's date)
5. Project or site name (if mentioned)
6. Key hazards or items identified

Available folder categories:
${folderContext || '- FLRA: Field Level Risk Assessment, hazard identification\n- Hot Work Permit: Welding, cutting, grinding\n- Equipment Inspection: Crane, scaffold, ladder inspection'}

IMPORTANT:
- Extract company/subcontractor from letterhead, logo, signature block, or "Company:" field
- Use ISO 8601 date format (YYYY-MM-DD) for documentDate
- If a field cannot be determined, use null instead of guessing
- Confidence should reflect how certain you are about the classification (0-100)

Respond ONLY with valid JSON in this exact format:
{
  "classification": "Form type name (e.g., FLRA, Hot Work Permit)",
  "confidence": 85,
  "extractedData": {
    "workerName": "John Smith",
    "companyName": "ABC Contractors Inc.",
    "documentDate": "2026-01-13",
    "projectName": "Downtown Tower Project",
    "hazards": ["Working at height", "Hot work nearby"]
  },
  "summary": "FLRA form completed by John Smith from ABC Contractors for roofing work, identifying 3 hazards with controls in place."
}`

  // Convert Uint8Array to base64 using our helper function
  const base64Content = uint8ArrayToBase64(attachment.content)
  console.log(`📊 Encoded ${attachment.content.length} bytes to ${base64Content.length} base64 chars`)
  
  // Determine mime type for inline data
  let mimeType = attachment.contentType
  if (mimeType === 'application/pdf') {
    mimeType = 'application/pdf'
  } else if (mimeType.startsWith('image/')) {
    // Gemini supports: image/png, image/jpeg, image/webp, image/heic, image/heif
    mimeType = attachment.contentType
  } else {
    throw new Error(`Unsupported file type: ${attachment.contentType}`)
  }

  console.log(`🚀 Calling Gemini API with model: ${GEMINI_MODEL}`)
  console.log(`📎 File mime type: ${mimeType}`)

  const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{
        parts: [
          { text: prompt },
          {
            inline_data: {
              mime_type: mimeType,
              data: base64Content
            }
          }
        ]
      }],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 2048,
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
  console.log('🤖 Gemini raw response:', JSON.stringify(result).substring(0, 500))
  
  const text = result.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
  console.log('📝 Gemini text response:', text.substring(0, 300))

  // Parse JSON from response
  try {
    const parsed = JSON.parse(text)
    return {
      classification: parsed.classification || 'Unknown',
      confidence: parsed.confidence || 0,
      extractedData: parsed.extractedData || {},
      summary: parsed.summary || 'No summary provided'
    }
  } catch (parseError) {
    console.error('Failed to parse AI response:', text)
    console.error('Parse error:', parseError)
    
    return {
      classification: 'Unknown',
      confidence: 0,
      extractedData: {},
      summary: 'Could not parse AI response'
    }
  }
}
