# Edge Functions

This directory contains Edge Functions for the HrdHat backend, deployed to Supabase.

## 📁 Directory Structure

```
edge-functions/
├── README.md              # This file
├── [function-name]/       # Individual function directories
│   ├── index.ts          # Main function code
│   ├── types.ts          # TypeScript types
│   └── utils.ts          # Helper functions
└── shared/               # Shared utilities across functions
    ├── types.ts          # Common types
    └── utils.ts          # Common utilities
```

## 🚀 Edge Functions for HrdHat

### Planned Functions

1. **PDF Generator**

   - Generate professional PDF forms from FLRA data
   - Input: Form instance JSON
   - Output: PDF buffer/URL

2. **Form Validator**

   - Validate form data before submission
   - Input: Form data JSON
   - Output: Validation results

3. **Photo Processor**

   - Process uploaded photos (resize, compress)
   - Input: Image file
   - Output: Processed image

4. **Email Sender**
   - Send form submission notifications
   - Input: Email data
   - Output: Send status

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
