-- Local execution metadata only; no business content or credentials.
CREATE TABLE IF NOT EXISTS runs(
 org TEXT NOT NULL, actor TEXT NOT NULL, id TEXT NOT NULL,
 fingerprint TEXT, owner TEXT NOT NULL, state TEXT NOT NULL
 CHECK(state IN ('pending','running','succeeded','failed','cancelled','uncertain')),
 day TEXT NOT NULL, charged INTEGER NOT NULL CHECK(charged IN (0,1)),
 dispatched INTEGER NOT NULL DEFAULT 0 CHECK(dispatched IN (0,1)),
 held INTEGER NOT NULL CHECK(held IN (0,1)), deadline REAL NOT NULL,
 created REAL NOT NULL, updated REAL NOT NULL,
 PRIMARY KEY(org,actor,id));
CREATE INDEX IF NOT EXISTS runs_budget ON runs(org,day,charged);
CREATE TABLE IF NOT EXISTS events(
 n INTEGER PRIMARY KEY, org TEXT NOT NULL, actor TEXT NOT NULL, id TEXT NOT NULL,
 state TEXT NOT NULL, at REAL NOT NULL);
PRAGMA user_version=1;
