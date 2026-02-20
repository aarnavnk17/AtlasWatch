const sqlite3 = require('sqlite3').verbose();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const MONGO_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/atlaswatch';

// Mongoose models
const userSchema = new mongoose.Schema({
  email: { type: String, unique: true, required: true },
  password: String,
  profile_completed: { type: Boolean, default: false }
}, { timestamps: true });

const profileSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  passport: String,
  document_type: String,
  nationality: String
}, { timestamps: true });

const contactSchema = new mongoose.Schema({
  user_email: { type: String, required: true, index: true },
  name: String,
  phone: String,
  relationship: String
}, { timestamps: true });

async function run() {
  console.log('Connecting to MongoDB...', MONGO_URI);
  await mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true });
  const User = mongoose.model('User', userSchema);
  const Profile = mongoose.model('Profile', profileSchema);
  const Contact = mongoose.model('Contact', contactSchema);

  const db = new sqlite3.Database('./atlaswatch.db', sqlite3.OPEN_READONLY, (err) => {
    if (err) return console.error('Failed to open sqlite DB:', err.message);
  });

  // Helpers to run queries returning promises
  const all = (sql, params=[]) => new Promise((res, rej) => db.all(sql, params, (e, rows) => e ? rej(e) : res(rows)));
  const get = (sql, params=[]) => new Promise((res, rej) => db.get(sql, params, (e, row) => e ? rej(e) : res(row)));

  try {
    // Migrate users
    const users = await all('SELECT * FROM users');
    console.log(`Found ${users.length} users in sqlite`);

    for (const u of users) {
      // Map possible column name variations
      const email = u.email || u.username || null;
        const password = u.password || null;
      const profile_completed = (u.profile_completed === 1) || (u.profile_completed === true) || false;
      if (!email) continue;

        // Avoid double-hashing if password already looks like a bcrypt hash
        let hashed = password;
        if (password && !password.startsWith('$2')) {
          hashed = bcrypt.hashSync(password, 10);
        }

        await User.updateOne({ email }, { $set: { email, password: hashed, profile_completed } }, { upsert: true });
    }

    // Migrate profiles
    const profiles = await all('SELECT * FROM profiles');
    console.log(`Found ${profiles.length} profiles in sqlite`);

    for (const p of profiles) {
      const email = p.email || null;
      if (!email) continue;
      // Normalize field names used in different files
      const passport = p.passport || p.passport_number || null;
      const document_type = p.documentType || p.document_type || null;
      const nationality = p.nationality || null;

      await Profile.updateOne({ email }, { $set: { email, passport, document_type, nationality } }, { upsert: true });
    }

    // Migrate contacts
    const contacts = await all('SELECT * FROM contacts');
    console.log(`Found ${contacts.length} contacts in sqlite`);

    for (const c of contacts) {
      const user_email = c.user_email || c.email || null;
      if (!user_email) continue;
      const name = c.name || null;
      const phone = c.phone || null;
      const relationship = c.relationship || null;

      await Contact.create({ user_email, name, phone, relationship });
    }

    console.log('Migration complete. Verify data in MongoDB.');
  } catch (err) {
    console.error('Migration error:', err);
  } finally {
    db.close();
    await mongoose.disconnect();
    process.exit(0);
  }
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
