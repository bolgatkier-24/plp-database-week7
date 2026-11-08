CREATE TABLE students (
  id SERIAL PRIMARY KEY,
  name TEXT,
  email TEXT
);

INSERT INTO students (name, email) VALUES
  ('Ama K.', 'ama@example.com'),
  ('Kwame B.', 'kwame@example.com'),
  ('Abena S.', 'abena@example.com');
