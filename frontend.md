# Nexora Frontend Plan

## Current status

The Nexora frontend is currently implemented as a high-fidelity prototype in `app/page.tsx`. It showcases the complete design aesthetic, user flow, and student experience using realistic in-memory state:

- **Mock Student Profile**: Alex Stone (Computer Science major).
- **Navigation & Views**: 5 primary workspace views (*Overview*, *My Study Plan*, *Calendar*, *Progress Analytics*, *Subjects & Topics*) and 5 specialized tool panels (*AI Tutor*, *Quiz Center*, *Upload Materials*, *Study Session*, *Deadlines*), plus *Settings*.
- **Interactive Demonstrations**: Completing daily tasks, streaming mock AI tutor conversations, answering interactive multiple-choice quiz questions, simulating file uploads, toggling focus session timers, running what-if schedule adjustments, and switching between dark and light themes.
- **Styling Architecture**: Custom OKLCH design tokens, responsive CSS grids, and Shadcn UI primitives layered on Tailwind CSS v4 and Base UI.

This document establishes the production frontend architecture, component decomposition, state management model, API client integration, and implementation roadmap to transition Nexora from a monolithic prototype into an enterprise-grade web application.

---

## Recommended stack

- **Framework**: Next.js 16 (App Router) with React 19 and TypeScript 5.7
- **Styling**: Tailwind CSS v4 (`@tailwindcss/postcss`, `tw-animate-css`), custom OKLCH design tokens in `app/globals.css`
- **UI Primitives**: Base UI (`@base-ui/react`), Shadcn UI components (`components/ui/`)
- **Iconography**: Lucide React (`lucide-react`)
- **Visualizations**: Recharts 3.8 (custom styled) + custom responsive SVGs for mastery trajectory curves
- **Client Data Fetching & Sync**: SWR (or TanStack Query) with optimistic updates and cache invalidation
- **AI Streaming**: Vercel AI SDK (`@ai-sdk/react`) for real-time AI Tutor responses (`useChat` / `useCompletion`)
- **File Uploads**: Direct client-to-blob streaming via Vercel Blob client (`@vercel/blob/client`) using short-lived signed URLs from `/api/materials/upload-url`
- **Utility Libraries**: `clsx`, `tailwind-merge`, `class-variance-authority`

---

## Design System & Theme Architecture

Nexora utilizes a dark-first, modern glassmorphic visual language built on the OKLCH color space for high visual fidelity, balanced contrast, and vibrant neon accents.

### Color Palette & Semantic Tokens

| Token | Dark Value | Light Value | Purpose |
| :--- | :--- | :--- | :--- |
| `--background` | `oklch(.13 .025 258)` | `oklch(.97 .012 252)` | App canvas and outer shell |
| `--card` | `oklch(.17 .03 258)` | `oklch(1 0 0)` | Surfaces, modal cards, panels |
| `--primary` | `oklch(.7 .17 274)` | `oklch(.49 .2 271)` | Brand indigo/purple accent, primary buttons, rings |
| `--chart-2` (Accent) | `oklch(.74 .16 195)` | `oklch(.7 .16 195)` | Cyan highlights, recommendation badges, active dots |
| `--chart-3` (Success) | `oklch(.75 .17 145)` | `oklch(.68 .17 145)` | Completed tasks, streak badges, positive trends |
| `--chart-4` (Warning) | `oklch(.8 .16 70)` | `oklch(.78 .15 70)` | High impact/priority alerts, skill gaps |
| `--destructive` | `oklch(.63 .26 29)` | `oklch(.58 .24 27)` | Urgent deadlines, destructive actions |

### Visual Signatures

1. **Glow & Orbit Visuals**: Dual-axis elliptical rings (`.orbit`, `.orbit-two`) around the circular mastery indicator with glowing radial box-shadows.
2. **Tabular Numerals**: All timers, countdowns, and percentage metrics use `font-variant-numeric: tabular-nums` to eliminate layout jitter during live updates.
3. **Live Activity Indicators**: Pulsing dot indicators (`.live-dot`, `.timeline-dot.current`) signifying active recalculations or background processing.
4. **Micro-Transitions**: Subtle 200ms ease transitions on sidebar navigation, quiz selection hover effects, and progress bar fills.

### Responsive Breakpoints

- **Desktop (`>1100px`)**: Full 248px sidebar, 12-column dashboard grid, multi-column analytics, wide timeline cards.
- **Tablet (`800px – 1100px`)**: Compact 210px sidebar, collapsed secondary descriptions, wrapped recommendation meta.
- **Mobile (`<800px`)**: Hidden static sidebar replaced by topbar hamburger drawer (`Menu`), single-column stacked cards, full-width action buttons, compact calendar day cells.

---

## Route Architecture & Page Structure

Decompose the monolithic `app/page.tsx` into modular Next.js App Router routes with route groups, shared layouts, and dedicated loading/error boundaries:

```text
app/
├── (auth)/
│   ├── layout.tsx                   # Auth shell (minimal brand header)
│   ├── sign-in/page.tsx             # Better Auth sign-in
│   └── sign-up/page.tsx             # Better Auth registration & onboarding
├── (dashboard)/
│   ├── layout.tsx                   # Main app shell (Sidebar, Topbar, ContentWrap)
│   ├── page.tsx                     # Overview / Daily Dashboard
│   ├── study-plan/
│   │   └── page.tsx                 # Full adaptive timeline & What-If simulator
│   ├── calendar/
│   │   └── page.tsx                 # Month/Week study schedule & deadline overlay
│   ├── analytics/
│   │   └── page.tsx                 # Mastery trajectory, deep work ratio, weekly trends
│   ├── subjects/
│   │   ├── page.tsx                 # Curriculum builder, topics, prerequisite graph
│   │   └── [subjectId]/page.tsx     # Deep-dive topic inspector & mastery distribution
│   ├── tutor/
│   │   ├── page.tsx                 # AI Tutor chat workspace
│   │   └── [conversationId]/page.tsx # Persisted conversation thread
│   ├── quizzes/
│   │   ├── page.tsx                 # Quiz center, active recall hub, past attempts
│   │   └── [quizId]/page.tsx        # Active quiz taking & instant review mode
│   ├── materials/
│   │   └── page.tsx                 # Upload dropzone, file library, processing pipeline
│   ├── session/
│   │   └── page.tsx                 # Fullscreen Focus / Pomodoro session & analytics
│   ├── deadlines/
│   │   └── page.tsx                 # Exam countdown, assignment tracker, risk alerts
│   └── settings/
│       └── page.tsx                 # Study preferences, daily pace, account settings
├── api/                             # Route handlers (mapped from backend.md)
├── globals.css                      # Design tokens, keyframes, utility classes
└── layout.tsx                       # Root HTML, font definition, Vercel analytics
```

---

## Component Hierarchy & Directory Structure

To ensure maintainability, code reuse, and testability, components should be organized by domain under `components/`:

```text
components/
├── layout/
│   ├── app-shell.tsx                # Context provider for theme, active session, mobile nav
│   ├── sidebar.tsx                  # Brand mark, mini profile, workspace & tool nav links
│   ├── topbar.tsx                   # Breadcrumbs, global search bar, notifications, user menu
│   └── mobile-nav.tsx               # Drawer navigation for mobile screens
│
├── dashboard/
│   ├── hero-mastery-card.tsx        # Dual-orbit mastery ring, progress %, weekly delta
│   ├── stat-grid.tsx                # Mastery score, streak, focus time, exam countdown
│   ├── recommendation-card.tsx      # "What should I study now?" 25-min micro-lesson prompt
│   ├── today-timeline.tsx           # Chronological study sessions with complete/skip actions
│   ├── progress-snapshot-chart.tsx  # 12-week bar chart of mastery points
│   ├── skill-gap-card.tsx           # Weak topics list with progress bars and score indicators
│   ├── upcoming-deadlines-card.tsx  # Prioritized exam/assignment cards with urgency flags
│   └── tutor-banner-card.tsx        # AI Tutor quick-launcher banner
│
├── study-plan/
│   ├── timeline-item.tsx            # Single study session row (active, planned, completed)
│   ├── what-if-simulator.tsx        # Sliders for missed days/new assignments & live recalculate
│   ├── plan-recalculate-dialog.tsx  # Confirmation modal with summary of rescheduled blocks
│   └── session-card.tsx             # Detailed study session card with prerequisite tags
│
├── tutor/
│   ├── tutor-chat-window.tsx        # Chat header, message feed, and auto-scroll manager
│   ├── tutor-message.tsx            # Formatted message bubble (Markdown, code syntax, citations)
│   ├── tutor-composer.tsx           # Auto-resizing textarea with keyboard shortcuts (Enter to send)
│   └── tutor-context-badge.tsx      # Subject/topic context pill (e.g. "Physics 201 context")
│
├── quiz/
│   ├── quiz-runner.tsx              # Multi-step quiz state machine
│   ├── question-card.tsx            # Question prompt with single-select multiple choice
│   ├── answer-option.tsx            # A/B/C/D option button with correct/incorrect visual feedback
│   ├── quiz-explanation.tsx         # AI-generated concept explanation after answering
│   └── mastery-snapshot-card.tsx    # Live mastery gauge, accuracy %, and completed question count
│
├── materials/
│   ├── upload-dropzone.tsx          # Drag-and-drop file target with size validation & progress
│   ├── analysis-pipeline.tsx        # 3-step pipeline tracker (Uploaded → Extracted → Planned)
│   └── material-list.tsx            # Uploaded file cards with processing badge & extracted count
│
├── session/
│   ├── focus-timer.tsx              # Large 72px tabular timer with circle progress ring
│   ├── timer-controls.tsx           # Start, pause, resume, finish, and abandon buttons
│   ├── session-stat-panel.tsx       # Average focus, deep work ratio, optimal study time
│   └── distraction-modal.tsx        # Log interruption reason when pausing
│
├── analytics/
│   ├── trajectory-chart.tsx         # SVG bezier curve showing current vs projected mastery
│   ├── prediction-card.tsx          # Projected exam readiness percentage with risk badge
│   └── subject-breakdown-chart.tsx  # Multi-subject comparative radar or bar visualization
│
├── calendar/
│   ├── calendar-grid.tsx            # 7-column monthly/weekly grid
│   ├── calendar-day-cell.tsx        # Day cell with session dots and deadline indicators
│   └── day-schedule-popover.tsx     # Flyout listing all sessions planned for the selected date
│
└── ui/                              # Base UI / Shadcn primitives
    ├── avatar.tsx
    ├── badge.tsx
    ├── button.tsx
    ├── card.tsx
    ├── chart.tsx
    ├── dialog.tsx
    ├── dropdown-menu.tsx
    ├── input.tsx
    ├── progress.tsx
    ├── separator.tsx
    ├── sheet.tsx
    ├── tabs.tsx
    └── textarea.tsx
```

---

## State Management & Client Data Synchronization

Nexora separates UI state, URL state, and remote server state clearly:

```
┌─────────────────────────────────────────────────────────────┐
│                       Client State                          │
├──────────────────────┬──────────────────────┬───────────────┤
│    Local UI State    │      URL State       │  Server State │
│  (Theme, Form Input, │ (Active Tab, Filter, │  (SWR Hooks & │
│   Live Timer Ticks)  │   Selected Subject)  │ AI Streaming) │
└──────────────────────┴──────────────────────┴───────────────┘
```

### 1. Remote Server State via SWR

SWR handles caching, revalidation on focus, and optimistic updates:

```typescript
// Example custom hooks pattern
export function useDashboard() {
  const { data, error, isLoading, mutate } = useSWR<DashboardResponse>(
    '/api/dashboard',
    fetcher,
    { revalidateOnFocus: true, keepPreviousData: true }
  )
  return { dashboard: data, isLoading, isError: error, refresh: mutate }
}

export function useStudyPlan() {
  const { data, error, isLoading, mutate } = useSWR<StudyPlanResponse>(
    '/api/study-plans/current',
    fetcher
  )

  const completeSession = async (sessionId: string) => {
    // Optimistic UI update: instantly mark session completed in cache
    await mutate(
      async (current) => {
        if (!current) return current
        await api.patch(`/api/study-sessions/${sessionId}`, { status: 'completed' })
        return {
          ...current,
          sessions: current.sessions.map((s) =>
            s.id === sessionId ? { ...s, status: 'completed', completedAt: new Date().toISOString() } : s
          ),
        }
      },
      {
        optimisticData: (current) => (!current ? current : {
          ...current,
          sessions: current.sessions.map((s) =>
            s.id === sessionId ? { ...s, status: 'completed' } : s
          ),
        }),
        rollbackOnError: true,
        revalidate: true,
      }
    )
  }

  return { plan: data, isLoading, isError: error, completeSession }
}
```

### 2. AI Tutor Streaming via Vercel AI SDK

The AI Tutor integrates with the streaming route `/api/tutor/messages`:

```typescript
import { useChat } from '@ai-sdk/react'

export function useTutorChat(subjectId?: string) {
  const { messages, input, handleInputChange, handleSubmit, isLoading } = useChat({
    api: '/api/tutor/messages',
    body: { subjectId },
    initialMessages: [
      {
        id: 'welcome',
        role: 'assistant',
        content: 'Hey Alex. I noticed you have a gap in thermodynamics. Want a 5-minute refresher before your physics block?',
      },
    ],
  })
  return { messages, input, handleInputChange, handleSubmit, isLoading }
}
```

### 3. Focus Timer Management

- Timer ticks run client-side using `requestAnimationFrame` or `setInterval` with timestamps (`Date.now() - startTime`) to avoid background tab throttling.
- Session lifecycle (`active`, `paused`, `completed`) synchronizes with `POST /api/focus-sessions` and `PATCH /api/focus-sessions/:id`.
- If the student navigates between views, the timer persists globally via a lightweight React Context or Zustand store, displaying a floating mini-timer bar in the layout.

---

## API Surface Mapping

Every user interaction in the frontend maps directly to the backend contracts specified in `backend.md`:

| Frontend View / Component | Trigger / User Action | Backend Endpoint | Method |
| :--- | :--- | :--- | :--- |
| `TodayTimeline` | Click checkmark to complete session | `/api/study-sessions/:id` | `PATCH` |
| `HeroMasteryCard` | Dashboard mount / interval refresh | `/api/dashboard` | `GET` |
| `ProgressSnapshotChart` | Range selector change (12w / 6m) | `/api/progress?range=12w` | `GET` |
| `RecommendationCard` | "Start now" button | `/api/focus-sessions` | `POST` |
| `WhatIfSimulator` | "Recalculate plan" button | `/api/study-plans/recalculate` | `POST` |
| `WhatIfSimulator` | Slider adjustments | `/api/simulations` | `POST` |
| `TutorComposer` | Send message (Enter key / click) | `/api/tutor/messages` | `POST` (stream) |
| `QuizRunner` | Open quiz modal or page | `/api/quizzes/generate` | `POST` |
| `AnswerOption` | Submit answer selection | `/api/quizzes/:id/attempts` | `POST` |
| `UploadDropzone` | Drop file or select via file picker | `/api/materials/upload-url` | `POST` |
| `AnalysisPipeline` | Poll extraction progress | `/api/materials/:id` | `GET` |
| `FocusTimer` | Start / Pause / End session | `/api/focus-sessions/:id` | `PATCH` |
| `UpcomingDeadlinesCard` | Create or update deadline | `/api/deadlines` | `POST` / `PATCH` |
| `Settings` | Save pace, minutes, notification prefs | `/api/settings` | `PATCH` |

---

## TypeScript Client Data Contracts

These types match the PostgreSQL schema (`database/schema.sql`) and backend API payloads:

```typescript
export type TaskStatus = 'planned' | 'in_progress' | 'completed' | 'missed' | 'skipped'
export type MaterialStatus = 'queued' | 'processing' | 'ready' | 'failed'
export type DeadlineType = 'exam' | 'assignment' | 'project' | 'presentation' | 'other'
export type SessionStatus = 'active' | 'paused' | 'completed' | 'abandoned'

export interface UserProfile {
  id: string
  name: string
  email: string
  school?: string
  program?: string
  dailyMinutes: number
  preferredPace: 'light' | 'balanced' | 'focused' | 'intense'
}

export interface Subject {
  id: string
  name: string
  code?: string
  colorToken: string
  targetMastery: number
}

export interface Topic {
  id: string
  subjectId: string
  name: string
  description?: string
  estimatedMinutes: number
  masteryScore: number      // 0.0 to 1.0
  confidenceScore: number   // 0.0 to 1.0
  nextReviewAt?: string
}

export interface StudySession {
  id: string
  planId: string
  topicId?: string
  deadlineId?: string
  title: string
  sessionType: 'study' | 'review' | 'quiz' | 'rescue'
  scheduledStart: string
  scheduledEnd: string
  actualMinutes: number
  priority: number          // 1 to 5
  status: TaskStatus
  recommendationReason?: string
  completedAt?: string
}

export interface DashboardData {
  student: UserProfile
  overallMastery: number
  weeklyDelta: number
  streakDays: number
  focusMinutesThisWeek: number
  examCountdownDays: number
  nextExamName: string
  recommendation: {
    title: string
    subject: string
    minutes: number
    masteryGain: number
    topicId: string
  }
  tasks: StudySession[]
  chartData: { label: string; value: number; selected?: boolean }[]
  skillGaps: { title: string; subject: string; score: number }[]
  deadlines: { id: string; date: string; title: string; subject: string; urgent: boolean }[]
}
```

---

## Accessibility & Usability (a11y)

1. **Keyboard Navigation**:
   - Every interactive element (timeline checkmarks, quiz choices, calendar day cells, tabs) must have visible focus rings (`focus-visible:ring-2 focus-visible:ring-primary`).
   - Quiz options support arrow keys (`ArrowUp`/`ArrowDown`) and number keys (`1`-`4` or `A`-`D`) for rapid selection.
2. **Screen Reader Support**:
   - `aria-live="polite"` on streaming tutor output and timer status updates.
   - Distinct `aria-label`s on icon-only buttons (e.g., `aria-label="Complete Vectors & planes"`).
   - Clear semantic heading structure (`<h1>` per page, nested `<h2>` and `<h3>`).
3. **Color Contrast & Dark/Light Modes**:
   - All text complies with WCAG AA minimum 4.5:1 contrast ratio against `--background` and `--card`.
   - Theme toggle uses CSS custom properties with smooth transitions; prevents layout flashes on reload via `next-themes` script.

---

## Performance & Optimization Strategy

- **React Server Components (RSC)**: Layout shell, initial dashboard shell, static marketing cards, and meta tags are rendered on the server to minimize client JavaScript bundle size.
- **Code Splitting & Lazy Loading**: Heavy charting libraries (Recharts) and PDF previewers are dynamically imported via `next/dynamic` with skeleton fallbacks.
- **Optimistic UI**: Reversible actions (completing a study session, adding a quick deadline) update the DOM immediately without waiting for server round-trips.
- **Image & Icon Optimization**: Icons imported selectively from `lucide-react`; SVG icons embedded inline or pre-bundled.

---

## Frontend Migration Roadmap

```
Phase 1: Architecture & Shell Decoupling
  ├── 1.1 Set up App Router route groups: (auth) and (dashboard)
  ├── 1.2 Extract Sidebar, Topbar, and MobileNav into components/layout/
  └── 1.3 Implement theme provider and auth session wrapper

Phase 2: Component Decomposition
  ├── 2.1 Extract Dashboard cards into modular components under components/dashboard/
  ├── 2.2 Break out TodayTimeline and SessionRow with optimistic completion
  └── 2.3 Build reusable chart wrappers for Recharts and SVG trajectory

Phase 3: SWR Data Layer & Backend Connection
  ├── 3.1 Implement API client (fetch wrapper with error typing and auth headers)
  ├── 3.2 Create SWR hooks (useDashboard, useStudyPlan, useDeadlines)
  └── 3.3 Replace hardcoded mock state in Dashboard with live server queries

Phase 4: Specialized Feature Modules
  ├── 4.1 AI Tutor: Integrate Vercel AI SDK useChat with streaming UI
  ├── 4.2 Quiz Center: Build multi-question interactive engine & score persistence
  ├── 4.3 Upload Pipeline: Add drag-and-drop file upload with Vercel Blob client
  └── 4.4 Focus Session: Implement global persistent timer & analytics logging

Phase 5: Polish, What-If Simulator & a11y
  ├── 5.1 Interactive What-If recalculation slider connected to /api/simulations
  ├── 5.2 Comprehensive keyboard navigation and screen reader audits
  └── 5.3 Mobile drawer responsiveness and touch gesture verification
```
