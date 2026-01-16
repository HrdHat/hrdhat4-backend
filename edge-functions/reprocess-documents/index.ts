/**
 * Reprocess Documents Edge Function
 * Version 8 - With retry logic and rate limit handling
 * 
 * Re-runs AI classification on documents that need review.
 * Called from the Supervisor dashboard to retry classification.
 * 
 * Features:
 * - Exponential backoff retry for 503/429 errors (Gemini overload/rate limits)
 * - Inter-document delay to prevent rate limiting
 * - Continues processing server-side even if user leaves the page
 * 
 * POST /reprocess-documents
 * Body: { project_id: string, document_ids?: string[] }
 * 
 * If document_ids is provided, only those documents are reprocessed.
 * Otherwise, all 'needs_review' documents for the project are reprocessed.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { encode as base64Encode } from 'https://deno.land/std@0.208.0/encoding/base64.ts'

// Retry configuration
const RETRY_CONFIG = {
  maxRetries: 3,
  baseDelayMs: 1000,
  interDocumentDelayMs: 500,
}

// Types
interface ClassificationResult {
  classification: string
  confidence: number
  extractedData: Record<string, unknown>
  summary: string
}

interface DocumentRecord {
  id: string
  project_id: string
  folder_id: string | null
  storage_path: string
  mime_type: string | null
  status: string
}

// Initialize Supabase client with service role for full access
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

// Gemini API configuration - using the fixed model
const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? ''
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'

/**
 * Retry a function with exponential backoff
 * Retries on 503 (overloaded), 429 (rate limit), and 500 errors
 */
async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = RETRY_CONFIG.maxRetries,
  baseDelay: number = RETRY_CONFIG.baseDelayMs
): Promise<T> {
  let lastError: Error = new Error('Unknown error')
  
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error))
      
      // Check if error is retryable (rate limit or overload)
      const errorMessage = lastError.message.toLowerCase()
      const isRetryable = 
        errorMessage.includes('503') || 
        errorMessage.includes('429') ||
        errorMessage.includes('500') ||
        errorMessage.includes('overloaded') ||
        errorMessage.includes('rate limit') ||
        errorMessage.includes('quota')
      
      // If not retryable or out of retries, throw immediately
      if (!isRetryable || attempt === maxRetries) {
        throw lastError
      }
      
      // Calculate delay with exponential backoff
      const delay = baseDelay * Math.pow(2, attempt)
      console.log(`⏳ Retry ${attempt + 1}/${maxRetries} after ${delay}ms - ${lastError.message.substring(0, 50)}...`)
      
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }
  
  throw lastError
}

/**
 * Sleep for specified milliseconds
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
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

  // Only accept POST requests
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const { project_id, document_ids } = await req.json()

    if (!project_id) {
      return new Response(
        JSON.stringify({ error: 'project_id is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`🔄 Reprocessing documents for project: ${project_id}`)

    // Get project folders for AI classification
    const { data: folders } = await supabaseAdmin
      .from('project_folders')
      .select('id, folder_name, ai_classification_hint')
      .eq('project_id', project_id)

    if (!folders || folders.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No folders found for project. Create folders first.' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get documents to reprocess
    let query = supabaseAdmin
      .from('received_documents')
      .select('id, project_id, folder_id, storage_path, mime_type, status')
      .eq('project_id', project_id)

    if (document_ids && document_ids.length > 0) {
      // Reprocess specific documents
      query = query.in('id', document_ids)
    } else {
      // Reprocess all documents needing review
      query = query.in('status', ['needs_review', 'pending'])
    }

    const { data: documents, error: fetchError } = await query

    if (fetchError) {
      console.error('❌ Failed to fetch documents:', fetchError)
      throw fetchError
    }

    if (!documents || documents.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: 'No documents to reprocess', processed: 0 }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📄 Found ${documents.length} documents to reprocess`)

    const results: { id: string; status: string; classification?: string; error?: string }[] = []

    // Process each document
    for (const doc of documents) {
      console.log(`🔄 Processing document: ${doc.id}`)

      try {
        // Download file from storage
        const { data: fileData, error: downloadError } = await supabaseAdmin.storage
          .from('document-intake')
          .download(doc.storage_path)

        if (downloadError || !fileData) {
          console.error(`❌ Failed to download ${doc.storage_path}:`, downloadError)
          results.push({ id: doc.id, status: 'error', error: 'Failed to download file' })
          continue
        }

        // Convert to Uint8Array
        const arrayBuffer = await fileData.arrayBuffer()
        const content = new Uint8Array(arrayBuffer)

        // Check for empty file
        if (content.length === 0) {
          console.log(`⚠️ Document ${doc.id} is empty (0 bytes)`)
          results.push({ id: doc.id, status: 'error', error: 'Empty file' })
          continue
        }

        // Run AI classification with retry for rate limits
        const classification = await retryWithBackoff(
          () => classifyDocument(content, doc.mime_type ?? 'application/pdf', folders),
          RETRY_CONFIG.maxRetries,
          RETRY_CONFIG.baseDelayMs
        )

        console.log(`🤖 AI result: ${classification.classification} (${classification.confidence}%)`)

        // Find matching folder using improved matching logic
        let matchedFolderId: string | null = null
        if (classification.classification !== 'Unknown') {
          matchedFolderId = findMatchingFolder(classification.classification, folders)
        }

        // Update document record
        // Only mark as 'filed' if we have BOTH high confidence AND a matching folder
        const canAutoFile = classification.confidence >= 70 && matchedFolderId !== null
        const newStatus = canAutoFile ? 'filed' : 'needs_review'
        
        if (!canAutoFile && matchedFolderId === null) {
          console.log(`⚠️ Document ${doc.id}: Confidence=${classification.confidence}% but no folder match - marking as needs_review`)
        }
        
        const { error: updateError } = await supabaseAdmin
          .from('received_documents')
          .update({
            folder_id: matchedFolderId,
            ai_classification: classification.classification,
            ai_extracted_data: classification.extractedData,
            ai_summary: classification.summary,
            confidence_score: classification.confidence,
            status: newStatus,
            processed_at: new Date().toISOString()
          })
          .eq('id', doc.id)

        if (updateError) {
          console.error(`❌ Failed to update document ${doc.id}:`, updateError)
          results.push({ id: doc.id, status: 'error', error: 'Failed to update record' })
          continue
        }

        results.push({
          id: doc.id,
          status: newStatus,
          classification: classification.classification
        })

        console.log(`✅ Document ${doc.id} classified as ${classification.classification} → ${newStatus}`)

      } catch (docError) {
        console.error(`❌ Error processing document ${doc.id}:`, docError)
        results.push({ 
          id: doc.id, 
          status: 'error', 
          error: docError instanceof Error ? docError.message : 'Unknown error' 
        })
      }

      // Add delay between documents to prevent rate limiting
      if (documents.indexOf(doc) < documents.length - 1) {
        await sleep(RETRY_CONFIG.interDocumentDelayMs)
      }
    }

    const successCount = results.filter(r => r.status !== 'error').length
    const filedCount = results.filter(r => r.status === 'filed').length

    console.log(`✅ Reprocessing complete: ${successCount}/${documents.length} successful, ${filedCount} auto-filed`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${successCount} documents, ${filedCount} auto-filed`,
        processed: successCount,
        filed: filedCount,
        results
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
    console.error('❌ Error in reprocess-documents:', error)
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
 * Normalize a string for comparison (lowercase, remove special chars)
 */
function normalizeString(str: string): string {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '') // Remove special chars
    .replace(/\s+/g, ' ')        // Normalize whitespace
    .trim()
}

/**
 * Find matching folder using improved matching logic
 * Priority: 1) Exact match, 2) Normalized match, 3) Substring containment, 4) Word overlap
 */
function findMatchingFolder(
  classification: string,
  folders: Array<{ id: string; folder_name: string; ai_classification_hint: string | null }>
): string | null {
  const classLower = classification.toLowerCase().trim()
  const classNormalized = normalizeString(classification)
  const classWords = classNormalized.split(' ').filter(w => w.length > 2) // Words with 3+ chars

  // 1) Exact match (case-insensitive)
  let match = folders.find(f => f.folder_name.toLowerCase().trim() === classLower)
  if (match) {
    console.log(`✅ Exact match found: "${classification}" → "${match.folder_name}"`)
    return match.id
  }

  // 2) Normalized match (remove special chars, normalize spaces)
  match = folders.find(f => normalizeString(f.folder_name) === classNormalized)
  if (match) {
    console.log(`✅ Normalized match found: "${classification}" → "${match.folder_name}"`)
    return match.id
  }

  // 3) Classification contains folder name or vice versa
  match = folders.find(f => {
    const folderLower = f.folder_name.toLowerCase()
    return classLower.includes(folderLower) || folderLower.includes(classLower)
  })
  if (match) {
    console.log(`✅ Substring match found: "${classification}" → "${match.folder_name}"`)
    return match.id
  }

  // 4) Check AI hint for matches
  match = folders.find(f => {
    if (!f.ai_classification_hint) return false
    const hintLower = f.ai_classification_hint.toLowerCase()
    // Check if classification appears in the hint
    return hintLower.includes(classLower) || classLower.split(' ').some(word => 
      word.length > 3 && hintLower.includes(word)
    )
  })
  if (match) {
    console.log(`✅ Hint match found: "${classification}" → "${match.folder_name}" (via hint)`)
    return match.id
  }

  // 5) Word overlap scoring - find best match
  if (classWords.length > 0) {
    let bestMatch: { folder: typeof folders[0]; score: number } | null = null
    
    for (const folder of folders) {
      const folderWords = normalizeString(folder.folder_name).split(' ').filter(w => w.length > 2)
      const hintWords = folder.ai_classification_hint 
        ? normalizeString(folder.ai_classification_hint).split(' ').filter(w => w.length > 2)
        : []
      const allFolderWords = [...new Set([...folderWords, ...hintWords])]
      
      // Count matching words
      const matchingWords = classWords.filter(cw => 
        allFolderWords.some(fw => fw.includes(cw) || cw.includes(fw))
      )
      const score = matchingWords.length / classWords.length
      
      if (score > 0.5 && (!bestMatch || score > bestMatch.score)) {
        bestMatch = { folder, score }
      }
    }
    
    if (bestMatch) {
      console.log(`✅ Word overlap match: "${classification}" → "${bestMatch.folder.folder_name}" (score: ${(bestMatch.score * 100).toFixed(0)}%)`)
      return bestMatch.folder.id
    }
  }

  console.log(`⚠️ No folder match found for classification: "${classification}"`)
  return null
}

/**
 * Classify document using Gemini AI
 */
async function classifyDocument(
  content: Uint8Array,
  mimeType: string,
  folders: Array<{ id: string; folder_name: string; ai_classification_hint: string | null }>
): Promise<ClassificationResult> {
  
  if (!GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY not configured')
  }

  // Build folder context for AI
  const folderContext = folders.map(f => 
    `- ${f.folder_name}${f.ai_classification_hint ? `: ${f.ai_classification_hint}` : ''}`
  ).join('\n')

  // Extract just the folder names for the prompt
  const folderNames = folders.map(f => f.folder_name)
  
  const prompt = `You are a construction safety document classifier for a site supervisor system.

TASK: Analyze this document and classify it into one of the available folder categories.

AVAILABLE FOLDERS (you MUST use one of these exact names):
${folderNames.map(name => `• "${name}"`).join('\n')}

FOLDER HINTS:
${folderContext}

INSTRUCTIONS:
1. Identify what type of safety form/document this is
2. Choose the most appropriate folder from the list above
3. Extract key information (date, worker name, company, project, hazards)
4. Provide a brief summary

IMPORTANT: The "classification" field MUST be one of the exact folder names listed above. If unsure, use "Unknown".

Respond ONLY with valid JSON in this exact format:
{
  "classification": "EXACT_FOLDER_NAME_FROM_LIST_ABOVE",
  "confidence": 85,
  "extractedData": {
    "date": "2024-01-15",
    "workerName": "John Smith",
    "companyName": "ABC Construction",
    "projectName": "Downtown Office Tower",
    "hazards": ["Working at height", "Hot work nearby"]
  },
  "summary": "FLRA form completed by John Smith from ABC Construction for roofing work, identifying 3 hazards with controls in place."
}`

  // Use Deno standard library for reliable base64 encoding
  const base64Content = base64Encode(content)

  // Validate mime type
  const supportedTypes = ['application/pdf', 'image/png', 'image/jpeg', 'image/jpg', 'image/webp']
  if (!supportedTypes.some(t => mimeType.includes(t))) {
    throw new Error(`Unsupported file type: ${mimeType}`)
  }

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
  const text = result.candidates?.[0]?.content?.parts?.[0]?.text ?? ''

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
    throw new Error('Failed to parse AI classification response')
  }
}
