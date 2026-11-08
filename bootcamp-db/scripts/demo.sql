-- ============================================================
-- Demo Script – Bootcamp Database Assignment
-- ============================================================

-- 1. Current students
SELECT * FROM students ORDER BY id;

-- 2. Make changes that the audit trigger will capture
UPDATE students SET name = 'Kofi M.' WHERE id = 1;
DELETE FROM students WHERE id = 3;

-- 3. Inspect the audit trail
SELECT
  id,
  tbl,
  op,
  old_row->>'name' AS was,
  new_row->>'name' AS now,
  changed_by,
  at
FROM audit_log
ORDER BY at DESC;

-- 4. Full JSON rows (for deeper inspection)
SELECT id, op, old_row, new_row FROM audit_log ORDER BY id;

-- 5. Category hierarchy via recursive CTE
WITH RECURSIVE tree AS (
  SELECT id, name, parent_id, 0 AS depth
  FROM categories
  WHERE parent_id IS NULL

  UNION ALL

  SELECT c.id, c.name, c.parent_id, t.depth + 1
  FROM categories c
  JOIN tree t ON c.parent_id = t.id
)
SELECT repeat('  ', depth) || name AS tree
FROM tree
ORDER BY depth, name;

-- 6. Verify roles and privileges
\du
SELECT grantee, privilege_type, table_name
FROM information_schema.role_table_grants
WHERE grantee IN ('app_read', 'app_write', 'api')
ORDER BY grantee, table_name;
