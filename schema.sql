-- Schema for canvas_mcp

CREATE TABLE IF NOT EXISTS users (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  email           TEXT        NOT NULL UNIQUE,
  canvas_token    TEXT,
  canvas_user_id  BIGINT,
  inserted_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Migration: add canvas_user_id to existing databases
-- ALTER TABLE users ADD COLUMN IF NOT EXISTS canvas_user_id BIGINT;

CREATE TABLE IF NOT EXISTS admins (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  granted_by  UUID        REFERENCES users(id) ON DELETE SET NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS audit_log (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        REFERENCES users(id) ON DELETE SET NULL,
  event       TEXT        NOT NULL,
  remote_ip   TEXT,
  data        JSONB,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS canvas_courses (
  id             BIGINT      PRIMARY KEY,
  term_id        BIGINT,
  term_name      TEXT,
  canvas_object  JSONB       NOT NULL,
  fetched_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS canvas_enrollments (
  id               BIGINT      PRIMARY KEY,
  course_id        BIGINT      NOT NULL REFERENCES canvas_courses(id) ON DELETE CASCADE,
  user_id          BIGINT      NOT NULL,
  enrollment_state TEXT,
  canvas_object    JSONB       NOT NULL,
  fetched_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS canvas_enrollments_course_id_idx       ON canvas_enrollments(course_id);
CREATE INDEX IF NOT EXISTS canvas_enrollments_user_id_idx         ON canvas_enrollments(user_id);
CREATE INDEX IF NOT EXISTS canvas_enrollments_enrollment_state_idx ON canvas_enrollments(enrollment_state);

CREATE TABLE IF NOT EXISTS canvas_assignments (
  id            BIGINT      PRIMARY KEY,
  course_id     BIGINT      NOT NULL REFERENCES canvas_courses(id) ON DELETE CASCADE,
  canvas_object JSONB       NOT NULL,
  fetched_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS canvas_assignments_course_id_idx ON canvas_assignments(course_id);

CREATE TABLE IF NOT EXISTS canvas_submissions (
  id             BIGINT      PRIMARY KEY,
  assignment_id  BIGINT      NOT NULL REFERENCES canvas_assignments(id) ON DELETE CASCADE,
  user_id        BIGINT      NOT NULL,
  workflow_state TEXT        NOT NULL,
  canvas_object  JSONB       NOT NULL,
  fetched_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS canvas_submissions_assignment_id_idx ON canvas_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS canvas_submissions_user_id_idx       ON canvas_submissions(user_id);

CREATE TABLE IF NOT EXISTS canvas_rubrics (
  id              BIGINT      PRIMARY KEY,
  course_id       BIGINT      NOT NULL REFERENCES canvas_courses(id) ON DELETE CASCADE,
  assignment_id   BIGINT      REFERENCES canvas_assignments(id) ON DELETE SET NULL,
  canvas_object   JSONB       NOT NULL,
  fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS canvas_rubrics_course_id_idx    ON canvas_rubrics(course_id);
CREATE INDEX IF NOT EXISTS canvas_rubrics_assignment_id_idx ON canvas_rubrics(assignment_id);

CREATE TABLE IF NOT EXISTS canvas_users (
  id             BIGINT      PRIMARY KEY,
  login_id       TEXT,
  canvas_object  JSONB       NOT NULL,
  fetched_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS canvas_users_login_id_idx ON canvas_users(login_id);
