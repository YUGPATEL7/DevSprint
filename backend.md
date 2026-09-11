# Nexora Backend Plan

## Current status

The current Nexora experience is a frontend prototype using realistic in-memory student data. Actions such as completing tasks, sending tutor messages, answering quizzes, uploading material, starting sessions, and toggling theme are client-side demonstrations.

This document defines the production backend contract and persistence model for replacing those placeholders.

## Recommended stack

- Next.js 16 App Router route handlers and Server Actions
- Neon Postgres for relational data
- Drizzle ORM for typed queries and migrations
- Better Auth for email/password authentication and sessions
- Vercel AI Gateway with the AI SDK for tutor responses, quiz generation, material extraction, and recommendations
- Vercel Blob for uploaded PDFs, DOCX files, and source materials
- Background jobs or Workflow SDK for document processing, spaced-repetition scheduling, and adaptive-plan recalculation

## API surface

### Authentication

Use Better Auth for:

- `POST /api/auth/sign-up`
- `POST /api/auth/sign-in`
- `POST /api/auth/sign-out`
- `GET /api/auth/session`

All user-owned queries must be scoped to the authenticated session user ID.

### Dashboard

- `GET /api/dashboard` — summary metrics, active tasks, recommendations, gaps, deadlines, and recent activity.
- `GET /api/progress?range=12w` — mastery and study-time series.
- `GET /api/recommendations/current` — highest-impact next study action.

### Study planning

- `GET /api/study-plans/current`
- `POST /api/study-plans/recalculate` — reschedule after missed work, changed availability, new material, or an exam-date change.
- `PATCH /api/study-sessions/:id` — complete, skip, pause, or reschedule a session.
- `POST /api/simulations` — run a what-if scenario without mutating the real plan.

### Curriculum and subjects

- `GET /api/subjects`
- `POST /api/subjects`
- `GET /api/topics/:id`
- `PATCH /api/topics/:id`
- `GET /api/topics/:id/prerequisites`

### Tutor and quizzes

- `POST /api/tutor/messages` — stream a context-aware response using the student’s subjects, plan, mastery, and recent activity.
- `GET /api/tutor/conversations`
- `POST /api/quizzes/generate`
- `POST /api/quizzes/:id/attempts`
- `GET /api/quizzes/:id/results`

### Materials

- `POST /api/materials/upload-url` — return a protected Blob upload URL.
- `POST /api/materials` — create a material record after upload.
- `GET /api/materials`
- `GET /api/materials/:id`
- `POST /api/materials/:id/process` — enqueue extraction and concept mapping.

### Focus sessions

- `POST /api/focus-sessions`
- `PATCH /api/focus-sessions/:id`
- `GET /api/focus-sessions/analytics`

### Deadlines and settings

- `GET /api/deadlines`
- `POST /api/deadlines`
- `PATCH /api/deadlines/:id`
- `GET /api/settings`
- `PATCH /api/settings`

## Adaptive planning rules

1. Each topic has a mastery score between 0 and 1.
2. A completed quiz updates mastery using weighted recent evidence rather than replacing the score outright.
3. Weak topics, prerequisite relationships, exam proximity, estimated effort, and student availability determine priority.
4. Missed sessions are marked as missed and trigger a recalculation event; the system should not silently overwrite history.
5. Recalculation preserves fixed deadlines and completed sessions, then moves flexible sessions into available study windows.
6. Spaced repetition creates review sessions after successful recall at increasing intervals.
7. Exam Rescue Mode prioritizes prerequisite blockers, high-value topics, and short retrieval sessions while warning when the available time is insufficient.
8. What-if simulations use a transaction or isolated calculation and never modify the active plan.

## Security and operational requirements

- Validate request bodies with Zod or an equivalent schema.
- Use parameterized Drizzle queries; never interpolate user input into SQL.
- Scope every user-owned table query by `user_id`.
- Keep AI calls on the server and redact unnecessary personal data from prompts.
- Store uploads privately and use short-lived signed URLs.
- Rate-limit tutor, quiz-generation, upload, and authentication endpoints.
- Add audit events for plan changes, deadline changes, and material processing.
- Use idempotency keys for upload completion and repeated plan recalculation requests.
- Return consistent error payloads: `{ error: { code, message, requestId } }`.

## Background processing

Recommended asynchronous jobs:

- Material text extraction and concept classification
- Prerequisite graph updates
- Plan recalculation after an event
- Daily spaced-repetition review generation
- Deadline-risk evaluation
- Weekly progress summaries

The UI should optimistically update only reversible interactions. Server-confirmed state should be fetched or invalidated after mutations.

## Suggested route structure

```text
app/
  api/
    auth/[...all]/route.ts
    dashboard/route.ts
    study-plans/current/route.ts
    study-plans/recalculate/route.ts
    tutor/messages/route.ts
    quizzes/generate/route.ts
    materials/upload-url/route.ts
    materials/[id]/process/route.ts
    focus-sessions/route.ts
    deadlines/route.ts
    settings/route.ts
lib/
  auth.ts
  db.ts
  validations.ts
  planner/
  ai/
  storage/
```

## Frontend migration notes

Replace the prototype state in `app/page.tsx` with server-backed hooks or Server Component data:

- `tasks` → `study_sessions`
- `messages` → `tutor_messages`
- `uploaded` → `materials.processing_status`
- quiz score state → `quiz_attempts`
- timer state → `focus_sessions`
- progress bars and charts → aggregated progress endpoints

Use SWR for client-side synchronization after mutations and show pending/error states for every asynchronous action.

## Environment variables

```text
DATABASE_URL
BETTER_AUTH_SECRET
BLOB_READ_WRITE_TOKEN
AI_GATEWAY_API_KEY
```

The AI Gateway and Blob variables should be supplied by their respective Vercel integrations rather than committed to source control.

## Implementation order

1. Provision database and authentication.
2. Add schema migrations and typed database access.
3. Replace dashboard hardcoded data with authenticated queries.
4. Add study-plan mutations and recalculation workflow.
5. Add materials and background processing.
6. Add tutor and quiz endpoints.
7. Add analytics aggregation, risk alerts, and spaced repetition.
8. Add rate limits, audit events, tests, and observability.

See `database/schema.sql` for the initial relational schema.
