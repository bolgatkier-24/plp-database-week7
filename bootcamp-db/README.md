# Bootcamp Database Assignment – Audit Log, Hierarchical Data, Migrations & Security

This repository contains a complete, working solution for the PostgreSQL advanced topics assignment:

1. **Reusable Audit Log** – JSONB-based trigger that records INSERT / UPDATE / DELETE
2. **Watch the Audit Log Work** – demonstration of changes and the resulting trail
3. **Category Tree** – self-referencing table + recursive CTE
4. **Versioned Migrations with Flyway** – ordered migration files applied cleanly
5. **Least-Privilege Security** – `app_read` / `app_write` roles + application user

---

## Project Structure

```
bootcamp-db/
├── migrations/
│   ├── V1__core_tables.sql      # students table + seed data
│   ├── V2__audit_log.sql        # audit_log table, function & trigger
│   └── V3__categories.sql       # categories table + seed data
├── outputs/                     # Captured results for submission
│   ├── flyway_info.txt
│   ├── audit_log_full.txt
│   ├── category_tree.txt
│   ├── tables.txt
│   ├── functions.txt
│   ├── roles.txt
│   └── permissions.txt
├── scripts/
│   └── demo.sql                 # All demonstration queries
└── README.md
```

---

## How the Solution Was Built

### Step 1 – Audit Log

```sql
CREATE TABLE audit_log (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tbl TEXT,
  op TEXT,
  old_row JSONB,
  new_row JSONB,
  changed_by TEXT DEFAULT current_user,
  at TIMESTAMPTZ DEFAULT now()
);

CREATE FUNCTION audit() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log(tbl, op, old_row, new_row)
  VALUES (
    TG_TABLE_NAME,
    TG_OP,
    to_jsonb(OLD),
    to_jsonb(NEW)
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit
AFTER INSERT OR UPDATE OR DELETE
ON students
FOR EACH ROW
EXECUTE FUNCTION audit();
```

### Step 2 – Demonstration

```sql
UPDATE students SET name = 'Kofi M.' WHERE id = 1;
DELETE FROM students WHERE id = 3;

SELECT
  tbl,
  op,
  old_row->>'name' AS was,
  new_row->>'name' AS now,
  at
FROM audit_log
ORDER BY at DESC;
```

**Result:**

| tbl      | op     | was      | now     | at                          |
|----------|--------|----------|---------|-----------------------------|
| students | UPDATE | Ama K.   | Kofi M. | 2026-11-08 07:06:48.112501+00 |
| students | DELETE | Abena S. |         | 2026-11-08 07:06:48.112501+00 |

### Step 3 – Category Tree (Recursive CTE)

```sql
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
```

**Result:**

```
 Electronics
   Computers
   Phones
     Laptops
```

### Step 4 – Flyway Migrations

Migrations were applied with:

```bash
flyway -url=jdbc:postgresql://localhost:5432/bootcamp \
       -user=postgres -password=postgres \
       -locations=filesystem:./migrations \
       migrate

flyway ... info
```

**Flyway Status (v3):**

| Version | Description   | State   |
|---------|---------------|---------|
| 1       | core tables   | Success |
| 2       | audit log     | Success |
| 3       | categories    | Success |

### Step 5 – Least-Privilege Security

```sql
CREATE ROLE app_read;
CREATE ROLE app_write;

GRANT CONNECT ON DATABASE bootcamp TO app_read, app_write;
GRANT USAGE ON SCHEMA public TO app_read, app_write;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_read;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_write;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_read;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_write;

CREATE USER api LOGIN PASSWORD 'strong-secret' IN ROLE app_write;
```

- `app_read`  → SELECT only  
- `app_write` → full DML  
- `api` user inherits write privileges (suitable for an application connection)

---

## Reproducing Locally

1. Install PostgreSQL 16+ and Flyway.
2. Create the database:
   ```bash
   createdb bootcamp
   ```
3. Run migrations:
   ```bash
   flyway -url=jdbc:postgresql://localhost:5432/bootcamp \
          -user=postgres -password=<your-password> \
          -locations=filesystem:./migrations \
          migrate
   ```
4. Execute the demo queries in `scripts/demo.sql`.

---

## Notes for Submission

- All SQL is production-style and uses modern PostgreSQL features (`GENERATED ALWAYS AS IDENTITY`, `JSONB`, `EXECUTE FUNCTION`).
- Migrations are cleanly ordered and idempotent when applied to an empty database.
- The audit trigger is reusable – attach it to any table with the same pattern.
- Security follows the principle of least privilege.

Prepared and verified on PostgreSQL 16.15 with Flyway 10.20.1.
