-- Versioned local content storage. Ciphertext is bound to org/actor/request.
BEGIN IMMEDIATE;
CREATE TABLE IF NOT EXISTS responses(
 org TEXT NOT NULL, actor TEXT NOT NULL, id TEXT NOT NULL, payload BLOB NOT NULL,
 version INTEGER NOT NULL DEFAULT 1, remembered INTEGER NOT NULL DEFAULT 0,
 archived INTEGER NOT NULL DEFAULT 0, created REAL NOT NULL,
 PRIMARY KEY(org,actor,id), FOREIGN KEY(org,actor,id) REFERENCES runs(org,actor,id),
 CHECK(version>0), CHECK(remembered IN (0,1)), CHECK(archived IN (0,1)));
CREATE TABLE IF NOT EXISTS memory_preferences(
 org TEXT NOT NULL, actor TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 0,
 version INTEGER NOT NULL DEFAULT 1, PRIMARY KEY(org,actor),CHECK(enabled IN (0,1)));
PRAGMA user_version=2;
COMMIT;
