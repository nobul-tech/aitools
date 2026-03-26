# Credits Tracking Tool -- Design for Multi-Provider Upgrade

**Date**: 2026-03-25
**Author**: S3-Credits (delegated)
**Purpose**: Design a credits tracking tool that improves on nobul-aws-credits,
expanding from AWS-only to all cloud/SaaS startup credit programs. Serves
Stage 2 (EXTEND) of the SaaS Contingency Lifecycle (RFC 0023).

---

## Current State: nobul-aws-credits

### What It Is

A Next.js 15 mobile-first web app at credits.nobul.tech. Built 2026-03-07
in a single session. Deployed on Vercel with Upstash Redis backend.

### What It Does Well

- Mobile-first task tracker with Nobul brand design system
- Shared state between Jose (phone UI) and Claude Code (API)
- Activity log tracking status changes and notes by author
- Phase-based playbook structure with collapsible cards
- Bearer token auth for API access (UI is open, API is gated)
- Optimistic UI updates with async persistence

### What It Does NOT Do

- **Single provider only**: Hardcoded for AWS Activate 6-phase playbook
- **No multi-program view**: Cannot track Auth0, Okta, Datadog, Cloudflare,
  DigitalOcean, or any other program
- **No expiry tracking**: No runway countdown, no decision gate timing
- **No eligibility status**: No field for "eligible/applied/denied/active/lost"
- **No credits amount or value**: Just task checkboxes, no dollar amounts
- **No cross-program dashboard**: Cannot see total credits across all providers
- **No urgency signals**: No visual indication of which programs need action NOW
- **Vercel-hosted**: Itself needs migration per RFC 0023 P0

### Architecture

```
Next.js 15 (App Router, TypeScript)
  |-- Upstash Redis (KV_REST_API_URL, KV_REST_API_TOKEN)
  |     |-- credits:playbook (JSON blob -- full playbook state)
  |     |-- credits:activity (Redis list -- capped at 200 entries)
  |-- Vercel hosting
  |-- Bearer token auth (API_KEY env var)
  |-- Tailwind CSS with Nobul brand tokens
```

### Data Model

```typescript
// Current -- AWS-specific, task-oriented
interface Playbook { phases: Phase[]; updatedAt: string; }
interface Phase { id: string; title: string; subtitle: string; order: number; tasks: Task[]; }
interface Task {
  id: string; title: string; description: string;
  status: "not_started" | "in_progress" | "done" | "blocked";
  notes: Note[]; completedAt: string | null; updatedAt: string;
}
```

---

## Proposed Design: credits.nobul.tech v2

### Principles

1. **Programs are the primary entity, not tasks.** The current app tracks
   tasks within one program. The new app tracks programs, each with their
   own lifecycle stage and tasks.
2. **Dashboard first.** The landing view shows all programs with status,
   credits amount, runway remaining, and urgency.
3. **Decision gates are first-class.** When credits expire, the decision
   gate fires. The tool tracks gate timing proactively.
4. **Keep what works.** The mobile-first Nobul design system, the shared
   Jose/Claude state model, the activity log, the API surface -- all stay.
5. **Same stack.** Next.js 15, Upstash Redis, TypeScript, Tailwind.
   Migration to new hosting (Cloudflare/Fly.io per RFC 0023) is a
   separate workstream.

### Data Model v2

```typescript
// ---- Program (the new primary entity) ----
interface Program {
  id: string;                    // e.g. "cloudflare-startup"
  provider: string;              // e.g. "Cloudflare"
  programName: string;           // e.g. "Startup Program (BOOTSTRAPPED)"
  category: ProgramCategory;     // cloud | saas | database | email | observability | hosting | identity
  creditsAmount: number | null;  // dollar value, null if unknown
  creditsUnit: string;           // "USD" | "months" | "seats" etc.

  // Lifecycle
  status: ProgramStatus;
  appliedDate: string | null;    // ISO date
  approvedDate: string | null;
  activatedDate: string | null;
  expiryDate: string | null;     // when credits expire

  // Eligibility
  eligibility: EligibilityStatus;
  eligibilityNotes: string;      // "Requires VC" | "BOOTSTRAPPED code" etc.
  vcRequired: boolean;

  // Decision gate (RFC 0023 Stage 5)
  decisionGateDate: string | null;  // when to evaluate switch-or-pay
  contingencyReady: boolean;        // is the replacement ready?
  contingencyRfc: string | null;    // "RFC 0022" etc.

  // Playbook (optional -- per-program task tracking)
  phases: Phase[];

  // Meta
  url: string | null;            // application URL
  notes: Note[];
  updatedAt: string;
  createdAt: string;
}

type ProgramCategory =
  | "cloud" | "hosting" | "database" | "email"
  | "observability" | "identity" | "saas" | "other";

type ProgramStatus =
  | "not_explored"    // haven't looked at it yet
  | "researching"     // gathering info
  | "eligible"        // confirmed eligible, not yet applied
  | "applied"         // application submitted
  | "approved"        // approved, credits not yet active
  | "active"          // credits are live and being used
  | "expiring"        // <90 days until expiry
  | "expired"         // credits expired
  | "denied"          // application denied
  | "lost";           // eligibility lost (signed up retail, etc.)

type EligibilityStatus =
  | "eligible"        // confirmed can apply
  | "likely"          // probably eligible, needs verification
  | "unclear"         // research needed
  | "ineligible"      // confirmed cannot apply
  | "lost";           // was eligible, no longer

// ---- Phase and Task (retained from v1) ----
interface Phase {
  id: string;
  title: string;
  subtitle: string;
  order: number;
  tasks: Task[];
}

interface Task {
  id: string;
  title: string;
  description: string;
  status: "not_started" | "in_progress" | "done" | "blocked";
  notes: Note[];
  completedAt: string | null;
  updatedAt: string;
}

// ---- Supporting types ----
interface Note {
  text: string;
  author: "jose" | "claude";
  timestamp: string;
}

interface ActivityEntry {
  id: string;
  action: "status_change" | "note_added" | "program_added" | "program_updated";
  programId: string;
  programName: string;
  taskId: string | null;        // null for program-level actions
  taskTitle: string | null;
  author: "jose" | "claude";
  detail: string;
  timestamp: string;
}

// ---- Dashboard aggregation ----
interface Dashboard {
  totalCreditsActive: number;
  totalCreditsPotential: number;
  programsByStatus: Record<ProgramStatus, number>;
  urgentActions: UrgentAction[];
  updatedAt: string;
}

interface UrgentAction {
  programId: string;
  programName: string;
  action: string;               // "Apply now" | "Expiring in 30 days" | "Decision gate approaching"
  urgency: "critical" | "high" | "medium" | "low";
  dueDate: string | null;
}
```

### Redis Key Structure

```
credits:programs            -- Hash: programId -> Program JSON
credits:programs:order      -- List: ordered programIds for display
credits:activity            -- List: ActivityEntry (LPUSH, capped at 500)
credits:dashboard           -- String: Dashboard JSON (computed on write)
```

Migrated from single `credits:playbook` blob to hash-per-program for
independent updates. The dashboard is a computed cache, rebuilt on any
program mutation.

### API v2

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/programs` | All programs with dashboard summary |
| `GET` | `/api/programs/[id]` | Single program with phases/tasks |
| `POST` | `/api/programs` | Add new program |
| `PATCH` | `/api/programs/[id]` | Update program fields |
| `DELETE` | `/api/programs/[id]` | Remove program |
| `PATCH` | `/api/programs/[id]/tasks/[taskId]` | Update task (status, notes) |
| `GET` | `/api/activity` | Activity log |
| `GET` | `/api/dashboard` | Dashboard aggregation |
| `POST` | `/api/seed` | Seed with known programs (dev) |
| `POST` | `/api/migrate` | Migrate v1 playbook to v2 (one-time) |

**Backward compatibility**: The v1 `/api/playbook` and `/api/tasks/[taskId]`
endpoints continue to work, reading from the "aws-activate" program in the
new structure. Existing Claude Code rules that use v1 API keep working.

### UI v2

**Dashboard view (new landing page)**:
- Total credits bar: active credits / potential credits
- Program cards in priority order, each showing:
  - Provider logo + program name
  - Credits amount (or "Unknown")
  - Status badge (color-coded)
  - Runway remaining (days) or "Apply now"
  - Urgency indicator
- Tap program card -> program detail view

**Program detail view (enhanced v1)**:
- Program metadata (provider, credits, dates, eligibility)
- Phase cards with tasks (same as v1 but scoped to one program)
- Decision gate section (if applicable)
- Notes and activity (scoped to this program)

**Urgency sidebar/banner**:
- Programs needing immediate action
- Approaching expiry dates
- Decision gates within 90 days

### Seed Data

The initial seed includes all programs from the inventory research:

```typescript
const SEED_PROGRAMS: Program[] = [
  // Active
  { id: "auth0-startups", provider: "Auth0", programName: "Auth0 for Startups",
    category: "identity", creditsAmount: null, creditsUnit: "months",
    status: "active", eligibility: "eligible", vcRequired: false, ... },
  { id: "okta-startups", provider: "Okta", programName: "Okta for Startups",
    category: "identity", creditsAmount: null, creditsUnit: "months",
    status: "active", eligibility: "eligible", vcRequired: false, ... },
  { id: "datadog-startup", provider: "Datadog", programName: "Datadog Startup Program",
    category: "observability", creditsAmount: 100000, creditsUnit: "USD",
    status: "active", eligibility: "eligible", vcRequired: false, ... },

  // Pursuing
  { id: "aws-activate-founders", provider: "AWS", programName: "AWS Activate Founders",
    category: "cloud", creditsAmount: 1000, creditsUnit: "USD",
    status: "researching", eligibility: "eligible", vcRequired: false,
    phases: [/* migrate existing 6-phase playbook here */], ... },
  { id: "cloudflare-bootstrapped", provider: "Cloudflare",
    programName: "Startup Program (BOOTSTRAPPED)",
    category: "hosting", creditsAmount: 5000, creditsUnit: "USD",
    status: "eligible", eligibility: "eligible", vcRequired: false, ... },

  // To investigate
  { id: "gcp-startups", provider: "Google Cloud",
    programName: "Google for Startups Cloud Program",
    category: "cloud", creditsAmount: 200000, creditsUnit: "USD",
    status: "researching", eligibility: "likely", vcRequired: false,
    eligibilityNotes: "Assumed lost but research shows existing customers CAN apply. VERIFY.", ... },
  { id: "digitalocean-hatch", provider: "DigitalOcean", programName: "Hatch",
    category: "cloud", creditsAmount: 100000, creditsUnit: "USD",
    status: "not_explored", eligibility: "likely", vcRequired: false, ... },
  { id: "microsoft-founders-hub", provider: "Microsoft",
    programName: "Founders Hub",
    category: "cloud", creditsAmount: 25000, creditsUnit: "USD",
    status: "not_explored", eligibility: "likely", vcRequired: false,
    eligibilityNotes: "Requires NEW Azure account. Bootstrapped tier: $1K-$25K.", ... },

  // Denied
  { id: "vercel-startup", provider: "Vercel", programName: "Vercel Startup Program",
    category: "hosting", creditsAmount: null, creditsUnit: "USD",
    status: "denied", eligibility: "ineligible", vcRequired: true,
    eligibilityNotes: "Requires VC affiliation", ... },

  // Lost
  { id: "azure-startups", provider: "Microsoft", programName: "Azure for Startups",
    category: "cloud", creditsAmount: 150000, creditsUnit: "USD",
    status: "lost", eligibility: "lost", vcRequired: false,
    eligibilityNotes: "Signed up retail. Program requires new customers only.", ... },

  // ... all 16 programs from inventory
];
```

### Migration Path

1. **v1 -> v2 data migration**: One-time `/api/migrate` endpoint reads
   `credits:playbook` (v1), creates a "aws-activate" program in v2
   structure, preserving all task statuses and notes.
2. **v1 API compatibility**: v1 endpoints proxy to the "aws-activate"
   program. Existing `.claude/rules/tracker-api.md` continues to work.
3. **Hosting migration**: Separate workstream. App currently on Vercel.
   When Cloudflare/Fly.io is ready (RFC 0023 P0), migrate there.

### Implementation Chunks

**Chunk 1: Data model + API (no UI changes)**
- Add Program type and CRUD API endpoints
- Seed with all known programs
- Migration endpoint for v1 data
- Backward-compatible v1 API
- Test via curl

**Chunk 2: Dashboard UI**
- New landing page with program cards
- Status badges, credits amounts, runway counters
- Urgency indicators
- Tap-through to program detail

**Chunk 3: Program detail view**
- Enhanced phase/task view scoped to one program
- Program metadata editing
- Decision gate section

**Chunk 4: Computed dashboard + urgency engine**
- Dashboard cache rebuilt on mutations
- Urgency calculations (expiry, gate timing)
- Notification-ready (future: push to phone)

---

## Operational Learning

### From the existing app session (2026-03-07)

The app was built in a single session from a detailed plan. Key decisions:
- Upstash Redis was chosen because qr-contact already used it (shared instance)
- Nobul brand design system was extracted from vcard.nobul.tech CSS
- API was designed for Claude Code interaction (Bearer auth, PATCH for status)
- The 6-phase playbook was hardcoded from aws-credits-playbook.md

### From RFC 0023

- credits.nobul.tech is referenced as the "meta-tool for tracking credit acquisition"
- RFC explicitly states it "should expand to track ALL startup credit programs"
- The credits preservation constraint is the highest-priority rule
- Every SaaS dependency follows the 6-stage contingency lifecycle

### From the inventory research

- The assumption that GCP eligibility is lost needs immediate verification
- Cloudflare BOOTSTRAPPED is the highest-ROI immediate action ($5K, self-serve)
- Microsoft Founders Hub offers $1K-$25K for bootstrapped with no VC
- DigitalOcean Hatch offers up to $100K (bootstrapped eligible at lower tiers)
- Total addressable credits range: $7K (self-serve minimum) to $307K+ (if GCP not lost)
