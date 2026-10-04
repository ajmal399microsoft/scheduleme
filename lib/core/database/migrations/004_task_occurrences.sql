CREATE TABLE task_occurrences (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL,
  scheduled_at INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('planned', 'completed', 'missed')),
  completed_at INTEGER,
  cost_paise INTEGER CHECK (cost_paise IS NULL OR cost_paise >= 0),
  note TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
);

CREATE INDEX idx_task_occurrences_task_date ON task_occurrences (task_id, scheduled_at DESC);