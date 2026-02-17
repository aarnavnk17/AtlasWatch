const sqlite3 = require('sqlite3').verbose();

const db = new sqlite3.Database('./atlaswatch.db');

db.serialize(() => {
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE,
      password TEXT,
      profile_completed INTEGER DEFAULT 0
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT,
      passport TEXT,
      document_type TEXT,
      nationality TEXT
    )
  `);
});

module.exports = db;