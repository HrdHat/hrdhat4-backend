# FLRA Module Definitions Reference

## Source File

**Location**: `c:\Users\Pawel\HRDhat\HRDhat\HrdHatFLRApdf.html`
**Purpose**: Complete FLRA form structure with exact field definitions for JSONB schema implementation

## Module Structure Analysis

### 1. General Information Module

```typescript
generalInformation: {
  projectName: string;
  taskLocation: string;
  supervisorName: string;
  supervisorContact: string;
  todaysDate: string; // ISO date string
  crewMembers: number;
  todaysTask: string;
  startTime: string; // HH:MM format
  endTime: string; // HH:MM format
}
```

### 2. FLRA Pre-Job Checklist Module

```typescript
preJobChecklist: {
  wellRestedAndFit: boolean;
  trainedAndCompetent: boolean;
  reviewedWorkArea: boolean;
  inspectedTools: boolean;
  requiredPPE: boolean;
  reviewedControlMeasures: boolean;
  equipmentInspectionUpToDate: boolean;
  reviewedEmergencyProcedures: boolean;
  completedFLRA: boolean;
  requiredPermitsInPlace: boolean;
  safetySignageInstalled: boolean;
  communicatedWithCrew: boolean;
  workingAlone: boolean;
  needForSpotters: boolean;
  allRequiredPermits: boolean;
  weatherSuitable: boolean;
  barricadesInstalled: boolean;
  knowFirstAidAttendant: boolean;
  clearAccessToExits: boolean;
  awareOfSiteNotices: boolean;
}
```

### 3. PPE & Platform Inspection Module

```typescript
ppeAndPlatform: {
  ppe: {
    hardhat: boolean;
    safetyVest: boolean;
    safetyGlasses: boolean;
    fallProtection: boolean;
    coveralls: boolean;
    gloves: boolean;
    mask: boolean;
    respirator: boolean;
  }
  platforms: {
    ladder: boolean;
    stepBench: boolean;
    sawhorses: boolean;
    bakerScaffold: boolean;
    scaffold: boolean;
    scissorLift: boolean;
    boomLift: boolean;
    swingStage: boolean;
    hydroLift: boolean;
  }
}
```

### 4. Task, Hazard, Control Module

```typescript
taskHazardControl: {
  entries: Array<{
    task: string;
    hazard: string;
    hazardRisk: number; // 1-10 scale
    control: string;
    controlRisk: number; // 1-10 scale
  }>;
}
```

**Risk Scale Color Mapping:**

- 1-2: Green (#00e676, #66bb6a)
- 3-4: Yellow-Green (#cddc39, #ffeb3b)
- 5-6: Orange (#ffc107, #ff9800)
- 7-8: Red-Orange (#ff5722, #f44336)
- 9-10: Deep Red (#e53935, #b71c1c)

### 5. Signature Module

```typescript
signatures: {
  workers: Array<{
    name: string;
    signature: string; // base64 signature data
  }>;
  supervisor: {
    name: string;
    signature: string; // base64 signature data
  }
}
```

### 6. Photo Module (To Be Defined)

```typescript
photos: {
  entries: Array<{
    description: string;
    imageData: string; // base64 image data or storage URL
    timestamp: string; // ISO timestamp
    location?: string; // GPS coordinates if available
  }>;
}
```

## JSONB Schema Structure

```sql
-- Complete form_data JSONB structure
{
  "modules": {
    "generalInformation": { ... },
    "preJobChecklist": { ... },
    "ppeAndPlatform": { ... },
    "taskHazardControl": { ... },
    "signatures": { ... },
    "photos": { ... }
  },
  "metadata": {
    "version": "1.0",
    "lastModified": "2024-12-XX",
    "completionStatus": "draft|complete",
    "mode": "quickFill|guided"
  }
}
```

## Implementation Notes

### Database Considerations

- Store signatures as base64 strings in JSONB or as separate files in Supabase Storage
- Photo storage: Supabase Storage with URLs in JSONB vs base64 in JSONB
- Risk scale values: Store as integers (1-10), calculate colors in frontend
- Dynamic arrays: Task/Hazard/Control entries and worker signatures

### Validation Rules

- Required fields: All General Information fields
- Risk scale: Must be 1-10 integers
- Signatures: Required for form completion
- Photos: Optional but recommended for hazard documentation

### Frontend Mapping

- HTML form fields map directly to JSONB properties using camelCase
- Checkbox arrays become boolean object properties
- Dynamic tables become arrays of objects
- Canvas signatures become base64 strings

---

**Created**: December 2024
**Last Updated**: December 2024
**Status**: Ready for backend implementation
