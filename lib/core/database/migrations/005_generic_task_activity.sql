ALTER TABLE tasks ADD COLUMN group_name TEXT NOT NULL DEFAULT '';
ALTER TABLE task_occurrences ADD COLUMN amount_minor_units INTEGER;
ALTER TABLE task_occurrences ADD COLUMN currency_code TEXT NOT NULL DEFAULT 'INR';
UPDATE task_occurrences SET amount_minor_units = cost_paise WHERE cost_paise IS NOT NULL;