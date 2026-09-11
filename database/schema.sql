-- Nexora initial PostgreSQL schema
-- Designed for Neon Postgres + Drizzle/Better Auth.
-- Enable UUID generation once per database.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE task_status AS ENUM ('planned', 'in_progress', 'completed', 'missed', 'skipped');
CREATE TYPE material_status AS ENUM ('queued', 'processing', 'ready', 'failed');
CREATE TYPE deadline_type AS ENUM ('exam', 'assignment', 'project', 'presentation', 'other');
CREATE TYPE session_status AS ENUM ('active', 'paused', 'completed', 'abandoned');
CREATE TYPE activity_type AS ENUM ('task_completed', 'quiz_completed', 'material_uploaded', 'session_completed', 'deadline_changed', 'plan_recalculated');

-- Better Auth-compatible core tables.
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  image TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user_id_idx ON sessions(user_id);

CREATE TABLE accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  account_id TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  access_token TEXT,
  refresh_token TEXT,
  access_token_expires_at TIMESTAMPTZ,
  refresh_token_expires_at TIMESTAMPTZ,
  scope TEXT,
  password TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider_id, account_id)
);

CREATE TABLE verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,
  value TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE student_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  school TEXT,
  program TEXT,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  preferred_pace TEXT NOT NULL DEFAULT 'balanced',
  daily_minutes INTEGER NOT NULL DEFAULT 90 CHECK (daily_minutes BETWEEN 15 AND 720),
  preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
  onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  color_token TEXT NOT NULL DEFAULT 'cyan',
  target_mastery NUMERIC(5,4) NOT NULL DEFAULT 0.85 CHECK (target_mastery BETWEEN 0 AND 1),
  archived_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX subjects_user_id_idx ON subjects(user_id);

CREATE TABLE topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  parent_topic_id UUID REFERENCES topics(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  estimated_minutes INTEGER NOT NULL DEFAULT 30 CHECK (estimated_minutes > 0),
  mastery_score NUMERIC(5,4) NOT NULL DEFAULT 0 CHECK (mastery_score BETWEEN 0 AND 1),
  confidence_score NUMERIC(5,4) NOT NULL DEFAULT 0 CHECK (confidence_score BETWEEN 0 AND 1),
  last_reviewed_at TIMESTAMPTZ,
  next_review_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX topics_subject_id_idx ON topics(subject_id);
CREATE INDEX topics_review_idx ON topics(next_review_at);

CREATE TABLE topic_prerequisites (
  topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  prerequisite_topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  strength NUMERIC(5,4) NOT NULL DEFAULT 1 CHECK (strength BETWEEN 0 AND 1),
  PRIMARY KEY (topic_id, prerequisite_topic_id),
  CHECK (topic_id <> prerequisite_topic_id)
);

CREATE TABLE goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  target_date DATE,
  target_mastery NUMERIC(5,4) CHECK (target_mastery BETWEEN 0 AND 1),
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE deadlines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  type deadline_type NOT NULL DEFAULT 'other',
  due_at TIMESTAMPTZ NOT NULL,
  importance INTEGER NOT NULL DEFAULT 3 CHECK (importance BETWEEN 1 AND 5),
  notes TEXT,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX deadlines_user_due_idx ON deadlines(user_id, due_at);

CREATE TABLE study_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'Adaptive study plan',
  version INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'active',
  generated_reason TEXT,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX active_plan_per_user_idx ON study_plans(user_id) WHERE status = 'active';

CREATE TABLE study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES study_plans(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  topic_id UUID REFERENCES topics(id) ON DELETE SET NULL,
  deadline_id UUID REFERENCES deadlines(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  session_type TEXT NOT NULL DEFAULT 'study',
  scheduled_start TIMESTAMPTZ NOT NULL,
  scheduled_end TIMESTAMPTZ NOT NULL,
  actual_minutes INTEGER NOT NULL DEFAULT 0 CHECK (actual_minutes >= 0),
  priority INTEGER NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  status task_status NOT NULL DEFAULT 'planned',
  recommendation_reason TEXT,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (scheduled_end > scheduled_start)
);
CREATE INDEX study_sessions_user_schedule_idx ON study_sessions(user_id, scheduled_start);
CREATE INDEX study_sessions_plan_status_idx ON study_sessions(plan_id, status);

CREATE TABLE plan_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_id UUID REFERENCES study_plans(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX plan_events_user_created_idx ON plan_events(user_id, created_at DESC);

CREATE TABLE materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  byte_size BIGINT NOT NULL CHECK (byte_size > 0),
  blob_path TEXT NOT NULL,
  source_url TEXT,
  processing_status material_status NOT NULL DEFAULT 'queued',
  extracted_text TEXT,
  processing_error TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX materials_user_status_idx ON materials(user_id, processing_status);

CREATE TABLE material_topics (
  material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  relevance NUMERIC(5,4) NOT NULL DEFAULT 0 CHECK (relevance BETWEEN 0 AND 1),
  PRIMARY KEY (material_id, topic_id)
);

CREATE TABLE quizzes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
  topic_id UUID REFERENCES topics(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  question_count INTEGER NOT NULL CHECK (question_count > 0),
  difficulty TEXT NOT NULL DEFAULT 'adaptive',
  generated_by TEXT NOT NULL DEFAULT 'ai',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE quiz_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  prompt TEXT NOT NULL,
  options JSONB NOT NULL,
  correct_option TEXT NOT NULL,
  explanation TEXT,
  UNIQUE(quiz_id, position)
);

CREATE TABLE quiz_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id UUID NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score NUMERIC(5,4) NOT NULL CHECK (score BETWEEN 0 AND 1),
  correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
  total_count INTEGER NOT NULL CHECK (total_count > 0),
  answers JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);
CREATE INDEX quiz_attempts_user_idx ON quiz_attempts(user_id, completed_at DESC);

CREATE TABLE tutor_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT,
  context JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tutor_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES tutor_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  model TEXT,
  token_usage JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX tutor_messages_conversation_idx ON tutor_messages(conversation_id, created_at);

CREATE TABLE focus_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  study_session_id UUID REFERENCES study_sessions(id) ON DELETE SET NULL,
  status session_status NOT NULL DEFAULT 'active',
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ,
  focused_seconds INTEGER NOT NULL DEFAULT 0 CHECK (focused_seconds >= 0),
  interruption_count INTEGER NOT NULL DEFAULT 0 CHECK (interruption_count >= 0),
  notes TEXT
);
CREATE INDEX focus_sessions_user_started_idx ON focus_sessions(user_id, started_at DESC);

CREATE TABLE mastery_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL,
  source_id UUID,
  score NUMERIC(5,4) NOT NULL CHECK (score BETWEEN 0 AND 1),
  confidence NUMERIC(5,4) CHECK (confidence BETWEEN 0 AND 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX mastery_events_topic_created_idx ON mastery_events(topic_id, created_at DESC);

CREATE TABLE activity_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type activity_type NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX activity_events_user_created_idx ON activity_events(user_id, created_at DESC);

CREATE TABLE plan_simulations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scenario JSONB NOT NULL,
  result JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Helpful read models can be added later as materialized views. Start with indexed
-- transactional tables and aggregate progress in server-side queries.

-- Example user-scoping policy for application code:
-- SELECT * FROM study_sessions WHERE user_id = $authenticated_user_id;
-- Never trust a user_id supplied by the browser.
