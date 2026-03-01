require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());



// MongoDB connection
const MONGO_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/atlaswatch';
mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true })
  .then(() => console.log('Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

// Mongoose models
const userSchema = new mongoose.Schema({
  email: { type: String, unique: true, required: true },
  password: { type: String, required: true },
  profile_completed: { type: Boolean, default: false },
  lastLocation: { type: Object },
  active_journey: { type: Object, default: null }
}, { timestamps: true });

const profileSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  fullName: String,
  phoneNumber: String,
  passport: { type: String, unique: false },
  documentType: String,
  nationality: String,
  bloodGroup: String,
  medicalConditions: String,
  allergies: String
}, { timestamps: true });

const contactSchema = new mongoose.Schema({
  user_email: { type: String, required: true, index: true },
  name: String,
  phone: String,
  relationship: String,
  legacy_id: Number
}, { timestamps: true });

const User = mongoose.model('User', userSchema);
const Profile = mongoose.model('Profile', profileSchema);
const Contact = mongoose.model('Contact', contactSchema);

const documentSchema = new mongoose.Schema({
  user_email: { type: String, required: true, index: true },
  originalName: String,
  fileName: String,
  fileType: String,
  fileUrl: String,
  category: { type: String, enum: ['Ticket', 'Hotel', 'Insurance', 'Passport', 'Other'], default: 'Other' },
  uploadDate: { type: Date, default: Date.now }
}, { timestamps: true });

const Document = mongoose.model('Document', documentSchema);

// Configure Multer for File Uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir);
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const locationSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  accuracy: Number,
  timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

const Location = mongoose.model('Location', locationSchema);

const crimeStatSchema = new mongoose.Schema({
  state: { type: String, required: true, index: true },
  city: { type: String, required: true, index: true },
  risk: String,
  score: Number,
  areas: mongoose.Schema.Types.Mixed,
  lastUpdated: { type: Date, default: Date.now }
}, { timestamps: true });

const CrimeStat = mongoose.model('CrimeStat', crimeStatSchema);

// ============================
// CRIME STATS ENDPOINT (DATABASE-POWERED)
// ============================
app.get('/crime-stats', async (req, res) => {
  const { area } = req.query;
  if (!area) return res.json({ score: 0 });

  const searchArea = area.toLowerCase();

  try {
    // 1. Try to find a direct city match
    let stat = await CrimeStat.findOne({ city: { $regex: new RegExp('^' + searchArea + '$', 'i') } }).lean();

    // 2. If no city match, search for cities that contain the search string
    if (!stat) {
      stat = await CrimeStat.findOne({ city: { $regex: new RegExp(searchArea, 'i') } }).lean();
    }

    // 3. If still no match, search within the 'areas' Map of all cities
    let score = 0;
    let found = false;

    if (stat) {
      score = stat.score;
      found = true;
    } else {
      // Deep search in all cities for a sub-area match
      // Note: This is a bit expensive, but works for the current scale. 
      // In a larger DB, we'd restructure the 'areas' into their own documents.
      const allStats = await CrimeStat.find({}).lean();
      for (const cityStat of allStats) {
        if (cityStat.areas) {
          for (const [subArea, subScore] of Object.entries(cityStat.areas)) {
            if (subArea.toLowerCase() === searchArea || searchArea.includes(subArea.toLowerCase())) {
              score = subScore;
              found = true;
              break;
            }
          }
        }
        if (found) break;
      }
    }

    // Default random-ish score if not found
    if (!found) {
      let hash = 0;
      for (let i = 0; i < searchArea.length; i++) {
        hash = searchArea.charCodeAt(i) + ((hash << 5) - hash);
      }
      score = Math.abs(hash % 500);
    }

    // Normalize Score for frontend (standard 0-300 range)
    let finalScore = score;
    if (score > 300) {
      finalScore = Math.floor(score / 20);
    }

    res.json({
      theft: Math.floor(finalScore / 4),
      assault: Math.floor(finalScore / 4),
      fraud: Math.floor(finalScore / 4)
    });

  } catch (err) {
    console.error('CrimeStats DB Error:', err);
    res.status(500).json({ success: false, message: 'Database error fetching crime stats' });
  }
});

// ============================
// CREATE TABLES
// ============================
// No SQL table creation needed; Mongoose will manage collections.

// ============================
// REGISTER
// ============================
app.post('/register', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ success: false, message: 'Email and password are required', error: 'Email and password are required' });
  }

  // Password Complexity Validation
  const minLength = 8;
  const hasUpperCase = /[A-Z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

  if (password.length < minLength || !hasUpperCase || !hasNumber || !hasSpecialChar) {
    return res.status(400).json({
      success: false,
      message: 'Password must be at least 8 characters long and contain at least one uppercase letter, one number, and one special character.',
      error: 'Invalid password format'
    });
  }

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ email, password: hashedPassword });
    await user.save();
    console.log(`User registered: ${email}`);
    return res.json({ success: true });
  } catch (err) {
    console.error('Registration error:', err.message);
    let msg = 'Registration failed';
    if (err.code === 11000) {
      msg = 'Email already registered';
    }
    return res.status(400).json({ success: false, message: msg, error: msg });
  }
});

// ============================
// LOGIN (Supports Email or Username)
// ============================
app.post('/login', async (req, res) => {
  const { email, password } = req.body; // email is required

  if (!email || !password) {
    return res.status(400).json({ success: false, message: 'Email and password are required', error: 'Email and password are required' });
  }

  try {
    const user = await User.findOne({ email }).lean();
    if (user) {
      const isMatch = await bcrypt.compare(password, user.password);
      if (isMatch) {
        console.log(`User logged in: ${user.email}`);
        return res.json({ success: true, email: user.email });
      }
    }
    return res.status(401).json({ success: false, message: 'Invalid credentials', error: 'Invalid credentials' });
  } catch (err) {
    console.error('Login database error:', err.message);
    return res.status(500).json({ success: false, message: 'Internal server error', error: 'Internal server error' });
  }
});

// ============================
// GET PROFILE
// ============================
app.get('/profile', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: 'Email required' });

  try {
    const row = await Profile.findOne({ email }).lean();
    if (row) {
      return res.json({
        success: true,
        profile: {
          fullName: row.fullName,
          phoneNumber: row.phoneNumber,
          passport: row.passport,
          documentType: row.documentType,
          nationality: row.nationality,
          bloodGroup: row.bloodGroup,
          medicalConditions: row.medicalConditions,
          allergies: row.allergies
        }
      });
    }
    return res.json({ success: false, profile: null });
  } catch (err) {
    console.error('Profile GET error:', err.message);
    return res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ============================
// SAVE / UPDATE PROFILE
// ============================
app.post('/profile', async (req, res) => {
  const {
    email,
    fullName,
    phoneNumber,
    passport,
    documentType,
    nationality,
    bloodGroup,
    medicalConditions,
    allergies
  } = req.body;
  console.log('PROFILE BODY:', req.body);

  try {
    if (passport) {
      const existing = await Profile.findOne({ passport }).lean();
      if (existing && existing.email !== email) {
        return res.status(400).json({ success: false, message: 'Passport already registered to another user' });
      }
    }

    await Profile.findOneAndUpdate(
      { email },
      {
        email,
        fullName,
        phoneNumber,
        passport,
        documentType,
        nationality,
        bloodGroup,
        medicalConditions,
        allergies
      },
      { upsert: true }
    );

    return res.json({ success: true });
  } catch (err) {
    console.log('PROFILE SAVE ERROR:', err.message);
    return res.status(500).json({ success: false, message: 'Database error' });
  }
});

// ============================
// EMERGENCY CONTACTS
// ============================

app.get('/contacts', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: 'Email required' });

  try {
    const rows = await Contact.find({ user_email: email }).lean();
    return res.json({ success: true, contacts: rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.post('/contacts', async (req, res) => {
  const { email, name, phone, relationship } = req.body;
  if (!email || !name || !phone) return res.status(400).json({ success: false, message: 'Missing fields' });

  try {
    const c = await Contact.create({ user_email: email, name, phone, relationship });
    return res.json({ success: true, id: c._id });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.post('/contacts/:id', async (req, res) => {
  const { id } = req.params;
  const { name, phone, relationship } = req.body;

  try {
    const updateData = {};
    if (name) updateData.name = name;
    if (phone) updateData.phone = phone;
    if (relationship !== undefined) updateData.relationship = relationship;

    if (/^\d+$/.test(id)) {
      await Contact.updateOne({ legacy_id: Number(id) }, { $set: updateData });
    } else if (/^[0-9a-fA-F]{24}$/.test(id)) {
      await Contact.updateOne({ _id: id }, { $set: updateData });
    } else {
      await Contact.updateOne({ $or: [{ legacy_id: Number(id) }, { _id: id }] }, { $set: updateData });
    }

    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.delete('/contacts/:id', async (req, res) => {
  const { id } = req.params;

  try {
    // If id looks like a number, try legacy_id; else try ObjectId
    if (/^\d+$/.test(id)) {
      await Contact.deleteOne({ legacy_id: Number(id) });
    } else if (/^[0-9a-fA-F]{24}$/.test(id)) {
      await Contact.deleteOne({ _id: id });
    } else {
      // Fallback: try both
      await Contact.deleteOne({ $or: [{ legacy_id: Number(id) }, { _id: id }] });
    }
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// LOCATION ENDPOINTS
// Devices should POST their coords periodically. Example body:
// { email, lat, lng, accuracy, timestamp }
// ============================
app.post('/location', async (req, res) => {
  const { email, lat, lng, accuracy, timestamp, riskLevel } = req.body;
  if (!email || lat == null || lng == null) return res.status(400).json({ success: false, message: 'Missing fields' });

  try {
    const loc = await Location.create({ email, lat, lng, accuracy, timestamp: timestamp ? new Date(timestamp) : undefined });
    // Keep last location and explicitly store riskLevel on user document
    await User.updateOne({ email }, { $set: { lastLocation: { lat, lng, accuracy, riskLevel, timestamp: loc.timestamp } } });
    return res.json({ success: true, id: loc._id });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/location/latest', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: 'Email required' });

  try {
    const loc = await Location.findOne({ email }).sort({ timestamp: -1 }).lean();
    if (!loc) return res.json({ success: false, location: null });
    return res.json({ success: true, location: loc });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// JOURNEY TRACKING
// ============================
app.post('/journey', async (req, res) => {
  const { email, startLocation, endLocation, mode, reference, riskLevel } = req.body;
  if (!email) return res.status(400).json({ success: false, message: 'Email required' });

  try {
    const journey = { startLocation, endLocation, mode, reference, riskLevel, startTime: new Date() };
    await User.updateOne({ email }, { $set: { active_journey: journey } });
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.delete('/journey', async (req, res) => {
  const userEmail = req.body.email || req.query.email;
  if (!userEmail) return res.status(400).json({ success: false, message: 'Email required' });

  try {
    await User.updateOne({ email: userEmail }, { $set: { active_journey: null } });
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});
// ============================
// DOCUMENT VAULT
// ============================

app.post('/documents/upload', upload.single('file'), async (req, res) => {
  const { email, category } = req.body;
  if (!email || !req.file) return res.status(400).json({ success: false, message: 'Missing file or email' });

  try {
    const doc = await Document.create({
      user_email: email,
      originalName: req.file.originalname,
      fileName: req.file.filename,
      fileType: req.file.mimetype,
      fileUrl: `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`,
      category: category || 'Other'
    });
    res.json({ success: true, document: doc });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/documents', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: 'Email required' });

  try {
    const docs = await Document.find({ user_email: email }).sort({ createdAt: -1 }).lean();
    res.json({ success: true, documents: docs });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.delete('/documents/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const doc = await Document.findById(id);
    if (!doc) return res.status(404).json({ success: false, message: 'Document not found' });

    // Delete physically
    const filePath = path.join(__dirname, 'uploads', doc.fileName);
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    await Document.findByIdAndDelete(id);
    res.json({ success: true, message: 'Document deleted' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Backend running on http://0.0.0.0:${PORT}`);
});