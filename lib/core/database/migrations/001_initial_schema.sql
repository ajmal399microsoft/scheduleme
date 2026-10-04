CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  notes TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  recurrence_frequency TEXT NOT NULL,
  recurrence_interval INTEGER NOT NULL,
  recurrence_weekdays TEXT NOT NULL,
  attachment_path TEXT,
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1))
);

CREATE TABLE completions (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  completed_at INTEGER NOT NULL,
  FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
);

CREATE INDEX idx_tasks_active_created_at ON tasks (is_archived, created_at);
CREATE INDEX idx_completions_task_completed_at ON completions (task_id, completed_at DESC);
