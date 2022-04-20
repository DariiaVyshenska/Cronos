CREATE TABLE lists(
id serial PRIMARY KEY,
name text UNIQUE NOT NULL
);

CREATE TABLE todos(
  id serial PRIMARY KEY,
  name text NOT NULL,
  list_id INT NOT NULL REFERENCES lists(id),
  completed boolean NOT NULL DEFAULT false
);
