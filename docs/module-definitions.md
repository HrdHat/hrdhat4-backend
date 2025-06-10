# FLRA Module Definitions Reference

**Status**: Implementation Ready  
**Last Updated**: January 6, 2025  
**Source**: FlraFormPlan.Md  
**Purpose**: Simple field definitions for all FLRA form modules

---

## Module Structure

### 1. General Information Module

```typescript
generalInformation: {
  projectName: string; // Project Name
  taskLocation: string; // Task Location
  supervisorName: string; // Supervisor's Name
  supervisorContact: string; // Supervisor's Contact #
  todaysDate: string; // Today's Date (YYYY-MM-DD)
  crewMembers: string; // # of Crew Members
  todaysTask: string; // Today's Task
  startTime: string; // Start Time (HH:mm)
  endTime: string; // End Time (HH:mm)
}
```

### 2. FLRA Pre-Job Checklist Module

```typescript
preJobChecklist: {
  wellRested: boolean; // Are you well-rested and fit for duty?
  trainedCompetent: boolean; // Are you trained and competent for your tasks today?
  areaReviewed: boolean; // Have you reviewed the work area for hazards?
  toolsInspected: boolean; // Have you inspected your tools and equipment?
  ppeRequired: boolean; // Do you have the required PPE for today?
  controlMeasuresReviewed: boolean; // Have you reviewed the control measures needed today?
  equipmentInspectionUpToDate: boolean; // Is your equipment inspection up-to-date?
  emergencyProceduresReviewed: boolean; // Have you reviewed your emergency procedures?
  flraCompleted: boolean; // Have you completed your FLRA / hazard assessment?
  permitsInPlace: boolean; // Are all required permits in place (if applicable)?
  signageInstalled: boolean; // Has all safety signage been installed and checked?
  crewCommunication: boolean; // Have you communicated with your crew about today's plan?
  workingAlone: boolean; // Are you working alone today?
  specialControlsNeeded: boolean; // Is there a need for spotters, barricades, or other special controls?
  allPermitsForTasks: boolean; // Do you have all required permits for today's tasks?
  weatherSuitable: boolean; // Is the weather or environmental condition suitable for work?
  barricadesSignageInstalled: boolean; // Have all necessary barricades, signage, and barriers been installed and are in good condition?
  knowFirstAidAttendant: boolean; // Do you know who the designated first aid attendant is today?
  emergencyAccess: boolean; // Do you have clear access to emergency exits and muster points?
  siteNotices: boolean; // Are you aware of any specific site notices or bulletins today?
}
```

### 3. PPE & Platform Inspection Module

```typescript
ppeAndPlatform: {
  // Personal Protective Equipment
  hardhat: boolean; // Hardhat
  safetyVest: boolean; // Safety Vest
  safetyGlasses: boolean; // Safety Glasses
  fallProtection: boolean; // Fall Protection
  coveralls: boolean; // Coveralls
  gloves: boolean; // Gloves
  mask: boolean; // Mask
  respirator: boolean; // Respirator

  // Equipment Platforms
  ladder: boolean; // Ladder
  stepBench: boolean; // Step Bench / Work Bench
  sawhorses: boolean; // Sawhorses
  bakerScaffold: boolean; // Baker Scaffold
  scaffold: boolean; // Scaffold
  scissorLift: boolean; // Scissor Lift
  boomLift: boolean; // Boom Lift
  swingStage: boolean; // Swing Stage
  hydroLift: boolean; // Hydro Lift
}
```

### 4. Task, Hazard, Control Module

```typescript
taskHazardControl: {
  entries: Array<{
    task: string; // Task description
    hazard: string; // Hazard identification
    hazardRisk: number; // Risk level before controls (1-10)
    control: string; // Control measure description
    controlRisk: number; // Risk level after controls (1-10)
  }>;
}
```

**Risk Scale**: 1-10 integers

- 1-2: Low Risk (Green)
- 3-4: Low-Medium Risk (Yellow-Green)
- 5-6: Medium Risk (Orange)
- 7-8: High Risk (Red-Orange)
- 9-10: Critical Risk (Deep Red)

### 5. Photos Module

```typescript
photos: Array<string>; // Array of form_photos.id references (UUIDs)
```

**Storage**: Separate `form_photos` table with Supabase Storage references  
**Constraints**: Max 5 photos per form, 5MB per photo

### 6. Signatures Module

```typescript
signatures: Array<string>; // Array of form_signatures.id references (UUIDs)
```

**Storage**: Separate `form_signatures` table with Supabase Storage references  
**Constraints**: Max 100KB per signature, unlimited signatures per form  
**Roles**: Flexible signer roles (worker, supervisor, foreman, safety_officer, management, etc.)

---

## Complete Form Structure

```typescript
interface FLRAFormData {
  modules: {
    generalInformation: GeneralInformationModule;
    preJobChecklist: PreJobChecklistModule;
    ppeAndPlatform: PPEAndPlatformModule;
    taskHazardControl: TaskHazardControlModule;
    photos: Array<string>;
    signatures: Array<string>;
  };
}
```

---

## Field Counts

- **General Information**: 9 fields
- **Pre-Job Checklist**: 20 boolean fields
- **PPE & Platform**: 17 boolean fields (8 PPE + 9 Platform)
- **Task/Hazard/Control**: Dynamic array (unlimited entries)
- **Photos**: Max 5 references
- **Signatures**: Unlimited references

---

**Total Static Fields**: 46 fields + dynamic arrays
