# Edge Functions

This directory contains Edge Functions for the HrdHat backend, deployed to Supabase.

## 📁 Directory Structure

```
edge-functions/
├── README.md                      # This file
├── archive-forms/                 # Archive old form instances
├── process-incoming-email/        # Process email intake via SendGrid webhook
├── reprocess-documents/           # Reprocess documents with AI classification
├── send-shift-notifications/      # Send SMS/email notifications for shifts
├── stale-forms/                   # Handle stale form data
└── shared/                        # Shared utilities across functions
```

## 🚀 Deployed Edge Functions

### 1. process-incoming-email

**Purpose**: Receives emails via SendGrid Inbound Parse webhook and processes documents.

- Extracts attachments (PDF, images)
- Stores files in Supabase Storage
- Calls Gemini AI for classification
- Creates received_documents record

**Endpoint**: `POST /functions/v1/process-incoming-email`

**Environment Variables**:
- `GEMINI_API_KEY` - Google Gemini API key for AI classification

---

### 2. reprocess-documents

**Purpose**: Reprocesses documents with AI classification when folders are updated.

**Endpoint**: `POST /functions/v1/reprocess-documents`
**Body**: `{ project_id: string }`

**Environment Variables**:
- `GEMINI_API_KEY` - Google Gemini API key

---

### 3. send-shift-notifications (NEW - Start of Shift Feature)

**Purpose**: Sends SMS and/or email notifications to workers assigned to a shift.

**Endpoint**: `POST /functions/v1/send-shift-notifications`
**Body**: `{ shift_id: string }`

**Process**:
1. Fetches shift and pending workers
2. Sends SMS via Twilio (preferred) or email via SendGrid
3. Updates notification_status for each worker
4. Marks shift as 'active' if it was 'draft'

**Environment Variables**:
```env
# Twilio (for SMS notifications)
TWILIO_ACCOUNT_SID=ACxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxx
TWILIO_PHONE_NUMBER=+1xxxxxxxxxx

# SendGrid (for email notifications)
SENDGRID_API_KEY=SG.xxxxxxxxx
SENDGRID_FROM_EMAIL=noreply@hrdhat.site

# HrdHat App URL (for form links in notifications)
HRDHAT_APP_URL=https://hrdhat.site
```

**Response**:
```json
{
  "success": true,
  "message": "Sent 8 notification(s), 2 failed",
  "sent": 8,
  "failed": 2,
  "results": [
    { "worker_id": "...", "name": "John Smith", "sms_sent": true, "email_sent": false },
    { "worker_id": "...", "name": "Jane Doe", "sms_sent": false, "email_sent": true, "error": "..." }
  ]
}
```

**Fallback Behavior**: If Twilio is not configured, workers with SMS preference will receive email instead.

---

### 4. archive-forms / stale-forms

**Purpose**: Utility functions for form lifecycle management.

---

## 📱 Twilio Setup Guide (for SMS)

1. Create a Twilio account at https://www.twilio.com/
2. Get your Account SID and Auth Token from the console
3. Purchase a phone number with SMS capabilities
4. Add environment variables to Supabase:
   - Go to Project Settings → Edge Functions → Add Secret
   - Add TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER
5. Test with a small batch of notifications first

## 🔧 Development Workflow

1. **Create Function**: Develop locally in this directory
2. **Review**: Code review before deployment
3. **Deploy via MCP**: Use MCP connection to deploy to Supabase
4. **Test**: Test deployed function
5. **Monitor**: Check logs via MCP connection

## 📝 Function Template

```typescript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

interface RequestBody {
  // Define your request body type
}

interface ResponseData {
  // Define your response type
}

Deno.serve(async (req: Request) => {
  try {
    // CORS headers
    if (req.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization",
        },
      });
    }

    // Parse request
    const body: RequestBody = await req.json();

    // Function logic here
    const result: ResponseData = {
      // Your response data
    };

    return new Response(JSON.stringify(result), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  }
});
```

## 🔐 Security Considerations

- Always validate input data
- Use proper CORS headers
- Handle errors gracefully
- Never expose sensitive data
- Use environment variables for secrets

## 📊 Monitoring

- Use MCP connection to check function logs
- Monitor performance and errors
- Set up alerts for critical functions

## 🧪 Testing

- Test functions locally before deployment
- Create test data and scenarios
- Verify CORS and security headers
- Test error handling
