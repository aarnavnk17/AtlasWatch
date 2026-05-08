require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const axios = require('axios');

const app = express();
app.use(cors());
app.use(express.json());

// Proxy Geocoding (Bypasses Emulator DNS issues)
app.get('/geocode', async (req, res) => {
  const { q } = req.query;
  if (!q) return res.status(400).json({ error: 'Query required' });
  try {
    const response = await axios.get(`https://nominatim.openstreetmap.org/search`, {
      params: { q, format: 'json', limit: 1 },
      headers: { 'User-Agent': 'AtlasWatchProxy/1.0' }
    });
    res.json(response.data);
  } catch (err) {
    console.error('Geocode Proxy Error:', err.message);
    res.status(500).json({ error: 'Failed to geocode' });
  }
});

// Request logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Health check
app.get('/', (req, res) => res.send('AtlasWatch Backend Active'));

// MongoDB connection
const MONGO_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/atlaswatch';
mongoose.connect(MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true, family: 4 })
  .then(() => console.log('✅ Connected to MongoDB Atlas'))
  .catch(err => {
    console.error('❌ MongoDB connection error:', err);
    if (err.name === 'MongooseServerSelectionError') {
      console.error('\n🛠️  Troubleshooting Help:');
      console.error('1. Whitelist 0.0.0.0/0 in MongoDB Atlas.');
      console.error('2. Check your .env credentials.');
      console.error('3. Check if your firewall blocks port 27017.');
      console.log('\nTopology details:', JSON.stringify(err.reason, null, 2));
    }
  });

// ============================
// MONGOOSE SCHEMAS & MODELS
// ============================

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

const documentSchema = new mongoose.Schema({
  user_email: { type: String, required: true, index: true },
  originalName: String,
  fileName: String,
  fileType: String,
  fileUrl: String,
  category: { type: String, enum: ['Ticket', 'Hotel', 'Insurance', 'Passport', 'Other'], default: 'Other' },
  uploadDate: { type: Date, default: Date.now }
}, { timestamps: true });

const locationSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  address: String,
  accuracy: Number,
  timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

const geofenceSchema = new mongoose.Schema({
  name: { type: String, required: true },
  type: { type: String, enum: ['safe', 'restricted', 'high-risk'], default: 'restricted' },
  center: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true }
  },
  radius: { type: Number, required: true }, // metres
  created_by: { type: String, default: 'admin' }
}, { timestamps: true });

const sosAlertSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  lat: { type: Number },
  lng: { type: Number },
  trigger: { type: String, enum: ['manual', 'inactivity', 'geofence', 'anomaly'], default: 'manual' },
  status: { type: String, enum: ['active', 'resolved'], default: 'active' },
  notes: { type: String },
  timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

const anomalyLogSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  lat: { type: Number },
  lng: { type: Number },
  risk_level: { type: String, enum: ['low', 'medium', 'high'], default: 'low' },
  anomaly_flag: { type: Boolean, default: false },
  reason: { type: String },
  details: { type: Object },
  timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

// Merged from upstream: CrimeStat schema
const crimeStatSchema = new mongoose.Schema({
  state: { type: String, required: true, index: true },
  city: { type: String, required: true, index: true },
  risk: String,
  score: Number,
  areas: mongoose.Schema.Types.Mixed,
  lastUpdated: { type: Date, default: Date.now }
}, { timestamps: true });

const incidentSchema = new mongoose.Schema({
  location  : { type: String, required: true, index: true },
  latitude  : Number,
  longitude : Number,
  type      : { type: String, enum: ['theft','assault','harassment','fraud','suspicious','other'], default: 'other' },
  severity  : { type: String, enum: ['low','medium','high'], default: 'medium' },
  reportedBy: String,
  description: String,
  createdAt : { type: Date, default: Date.now, index: true }
});

const User       = mongoose.model('User', userSchema);
const Profile    = mongoose.model('Profile', profileSchema);
const Contact    = mongoose.model('Contact', contactSchema);
const Document   = mongoose.model('Document', documentSchema);
const Location   = mongoose.model('Location', locationSchema);
const Geofence   = mongoose.model('Geofence', geofenceSchema);
const SosAlert   = mongoose.model('SosAlert', sosAlertSchema);
const AnomalyLog = mongoose.model('AnomalyLog', anomalyLogSchema);
const CrimeStat  = mongoose.model('CrimeStat', crimeStatSchema);
const Incident   = mongoose.model('Incident', incidentSchema);

// ============================
// MULTER FILE UPLOAD CONFIG
// ============================
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ storage });
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ============================
// HAVERSINE HELPER
// ============================
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ============================
// AI / ANOMALY DETECTION ENGINE
// FR-3.2.13–15, FR-3.2.10–12
// ============================
async function analyzeRisk(email, lat, lng) {
  const result = {
    risk_level: 'low',
    anomaly_flag: false,
    reason: 'Normal movement detected',
    details: {}
  };

  // Rule 1: Geofence check
  const geofences = await Geofence.find({}).lean();
  for (const fence of geofences) {
    const dist = haversineDistance(lat, lng, fence.center.lat, fence.center.lng);
    if (dist <= fence.radius) {
      result.details.geofence = { name: fence.name, type: fence.type, distanceMeters: Math.round(dist) };
      if (fence.type === 'high-risk') {
        result.risk_level = 'high';
        result.anomaly_flag = true;
        result.reason = `Entered high-risk zone: ${fence.name}`;
        return result;
      }
      if (fence.type === 'restricted') {
        result.risk_level = 'medium';
        result.anomaly_flag = true;
        result.reason = `Entered restricted zone: ${fence.name}`;
      }
    }
  }

  // Rule 2: Inactivity detection (last 10 minutes)
  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
  const recentLocations = await Location.find({
    email,
    timestamp: { $gte: tenMinutesAgo }
  }).sort({ timestamp: 1 }).lean();

  if (recentLocations.length >= 2) {
    const oldest = recentLocations[0];
    const newest = recentLocations[recentLocations.length - 1];
    const totalMovement = haversineDistance(oldest.lat, oldest.lng, newest.lat, newest.lng);
    const elapsedMinutes = (new Date(newest.timestamp) - new Date(oldest.timestamp)) / 60000;

    result.details.movement = {
      totalDistanceMeters: Math.round(totalMovement),
      elapsedMinutes: Math.round(elapsedMinutes)
    };

    if (totalMovement < 30 && elapsedMinutes >= 8) {
      result.anomaly_flag = true;
      result.reason = 'Prolonged inactivity detected (no significant movement in 10 minutes)';
      if (result.risk_level === 'low') result.risk_level = 'medium';
    }

    // Rule 3: Speed spike
    if (recentLocations.length >= 3) {
      let maxSpeed = 0;
      for (let i = 1; i < recentLocations.length; i++) {
        const prev = recentLocations[i - 1];
        const curr = recentLocations[i];
        const d = haversineDistance(prev.lat, prev.lng, curr.lat, curr.lng);
        const t = (new Date(curr.timestamp) - new Date(prev.timestamp)) / 1000;
        if (t > 0) {
          const speedMs = d / t;
          if (speedMs > maxSpeed) maxSpeed = speedMs;
        }
      }
      const speedKph = maxSpeed * 3.6;
      result.details.maxSpeedKph = Math.round(speedKph);
      if (speedKph > 10 && speedKph < 80) {
        result.anomaly_flag = true;
        result.reason = `Unusual movement speed detected (${Math.round(speedKph)} kph)`;
        if (result.risk_level === 'low') result.risk_level = 'medium';
      }
    }
  }

  return result;
}

// POST /analyze
app.post('/analyze', async (req, res) => {
  const { email, lat, lng } = req.body;
  if (!email || lat == null || lng == null)
    return res.status(400).json({ success: false, message: 'email, lat, lng required' });

  try {
    const analysis = await analyzeRisk(email, lat, lng);

    await AnomalyLog.create({
      email, lat, lng,
      risk_level: analysis.risk_level,
      anomaly_flag: analysis.anomaly_flag,
      reason: analysis.reason,
      details: analysis.details
    });

    await User.updateOne({ email }, {
      $set: {
        'lastLocation.riskLevel': analysis.risk_level,
        'lastLocation.anomalyFlag': analysis.anomaly_flag,
        'lastLocation.anomalyReason': analysis.reason,
        'lastLocation.lat': lat,
        'lastLocation.lng': lng,
        'lastLocation.timestamp': new Date()
      }
    });

    return res.json({ success: true, ...analysis });
  } catch (err) {
    console.error('Analyze error:', err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// GEOFENCE ENDPOINTS
// FR-3.2.9, FR-3.2.20
// ============================
app.get('/geofences', async (req, res) => {
  try {
    const fences = await Geofence.find({}).lean();
    return res.json({ success: true, geofences: fences });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.post('/geofences', async (req, res) => {
  const { name, type, center, radius } = req.body;
  if (!name || !center || !center.lat || !center.lng || !radius)
    return res.status(400).json({ success: false, message: 'name, center (lat/lng), and radius required' });
  try {
    const fence = await Geofence.create({ name, type: type || 'restricted', center, radius });
    return res.json({ success: true, geofence: fence });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.put('/geofences/:id', async (req, res) => {
  const { name, type, center, radius } = req.body;
  try {
    const updated = await Geofence.findByIdAndUpdate(
      req.params.id,
      { $set: { name, type, center, radius } },
      { new: true }
    );
    if (!updated) return res.status(404).json({ success: false, message: 'Zone not found' });
    return res.json({ success: true, geofence: updated });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.delete('/geofences/:id', async (req, res) => {
  try {
    await Geofence.deleteOne({ _id: req.params.id });
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// ADMIN ENDPOINTS
// FR-3.2.21
// ============================
app.get('/admin/anomaly-summary', async (req, res) => {
  try {
    const summary = await AnomalyLog.aggregate([
      { $group: {
          _id: '$email',
          totalEvents:  { $sum: 1 },
          anomalyCount: { $sum: { $cond: ['$anomaly_flag', 1, 0] } },
          highRiskCount:{ $sum: { $cond: [{ $eq: ['$risk_level', 'high'] }, 1, 0] } },
          lastEvent:    { $max: '$timestamp' },
          lastReason:   { $last: '$reason' },
          lastRiskLevel:{ $last: '$risk_level' }
      }},
      { $sort: { anomalyCount: -1 } }
    ]);
    return res.json({ success: true, summary });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/anomaly-log', async (req, res) => {
  const { email } = req.query;
  const query = email ? { email } : {};
  try {
    const logs = await AnomalyLog.find(query).sort({ timestamp: -1 }).limit(200).lean();
    return res.json({ success: true, logs });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// SOS ALERT ENDPOINTS
// FR-3.2.16–18
// ============================
app.post('/sos', async (req, res) => {
  const { email, lat, lng, trigger, notes } = req.body;
  if (!email) return res.status(400).json({ success: false, message: 'Email required' });
  try {
    const alert = await SosAlert.create({
      email,
      lat: lat ?? null,
      lng: lng ?? null,
      trigger: trigger || 'manual',
      notes: notes || null
    });
    if (lat != null && lng != null) {
      await User.updateOne({ email }, {
        $set: { lastLocation: { lat, lng, sos: true, timestamp: new Date() } }
      });
    }
    console.log(`🚨 SOS ALERT from ${email} at [${lat}, ${lng}] — trigger: ${trigger || 'manual'}`);
    return res.json({ success: true, alert_id: alert._id });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/sos/alerts', async (req, res) => {
  try {
    const alerts = await SosAlert.find({}).sort({ timestamp: -1 }).limit(100).lean();
    return res.json({ success: true, alerts });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

app.post('/sos/:id/resolve', async (req, res) => {
  try {
    await SosAlert.updateOne({ _id: req.params.id }, { $set: { status: 'resolved' } });
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// CRIME STATS ENDPOINT
// Merged: async handler + CrimeStat model from upstream
// ============================
app.get('/crime-stats', async (req, res) => {
  const { area } = req.query;
  if (!area) return res.json({ score: 0 });

  const searchArea = area.toLowerCase();

  try {
    let stat = await CrimeStat.findOne({ city: { $regex: new RegExp('^' + searchArea + '$', 'i') } }).lean();
    if (!stat)
      stat = await CrimeStat.findOne({ city: { $regex: new RegExp(searchArea, 'i') } }).lean();

    let score = 0;
    let found = false;

    if (stat) {
      score = stat.score;
      found = true;
    } else {
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

    if (!found) {
      let hash = 0;
      for (let i = 0; i < searchArea.length; i++) {
        hash = searchArea.charCodeAt(i) + ((hash << 5) - hash);
      }
      score = Math.abs(hash % 500);
    }

    let finalScore = score > 300 ? Math.floor(score / 20) : score;

    res.json({
      theft:   Math.floor(finalScore / 4),
      assault: Math.floor(finalScore / 4),
      fraud:   Math.floor(finalScore / 4)
    });
  } catch (err) {
    console.error('CrimeStats DB Error:', err);
    res.status(500).json({ success: false, message: 'Database error fetching crime stats' });
  }
});

// ============================
// REGISTER
// ============================
app.post('/register', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ success: false, message: 'Email and password are required', error: 'Email and password are required' });

  const hasUpperCase  = /[A-Z]/.test(password);
  const hasNumber     = /[0-9]/.test(password);
  const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

  if (password.length < 8 || !hasUpperCase || !hasNumber || !hasSpecialChar) {
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
    const msg = err.code === 11000 ? 'Email already registered' : 'Registration failed';
    return res.status(400).json({ success: false, message: msg, error: msg });
  }
});

// ============================
// LOGIN
// ============================
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ success: false, message: 'Email and password are required', error: 'Email and password are required' });

  try {
    const user = await User.findOne({ email }).lean();
    if (user && await bcrypt.compare(password, user.password)) {
      console.log(`User logged in: ${user.email}`);
      return res.json({ success: true, email: user.email });
    }
    return res.status(401).json({ success: false, message: 'Invalid credentials', error: 'Invalid credentials' });
  } catch (err) {
    console.error('Login database error:', err.message);
    return res.status(500).json({ success: false, message: 'Internal server error', error: 'Internal server error' });
  }
});

// ============================
// PROFILE
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

app.post('/profile', async (req, res) => {
  const { email, fullName, phoneNumber, passport, documentType, nationality, bloodGroup, medicalConditions, allergies } = req.body;
  console.log('PROFILE BODY:', req.body);
  try {
    if (passport) {
      const existing = await Profile.findOne({ passport }).lean();
      if (existing && existing.email !== email)
        return res.status(400).json({ success: false, message: 'Passport already registered to another user' });
    }
    await Profile.findOneAndUpdate(
      { email },
      { email, fullName, phoneNumber, passport, documentType, nationality, bloodGroup, medicalConditions, allergies },
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
  if (!email || !name || !phone)
    return res.status(400).json({ success: false, message: 'Missing fields' });
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
    if (/^\d+$/.test(id)) {
      await Contact.deleteOne({ legacy_id: Number(id) });
    } else if (/^[0-9a-fA-F]{24}$/.test(id)) {
      await Contact.deleteOne({ _id: id });
    } else {
      await Contact.deleteOne({ $or: [{ legacy_id: Number(id) }, { _id: id }] });
    }
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// LOCATION ENDPOINTS
// ============================
app.post('/location', async (req, res) => {
  const { email, lat, lng, address, accuracy, timestamp, riskLevel } = req.body;
  if (!email || lat == null || lng == null)
    return res.status(400).json({ success: false, message: 'Missing fields' });
  try {
    const loc = await Location.findOneAndUpdate(
      { email },
      { lat, lng, address, accuracy, timestamp: timestamp ? new Date(timestamp) : new Date() },
      { upsert: true, new: true }
    );
    await User.updateOne({ email }, {
      $set: { lastLocation: { lat, lng, address, accuracy, riskLevel, timestamp: loc.timestamp } }
    });
    return res.json({ success: true, id: loc._id });
  } catch (err) {
    console.error('Location Update Error:', err.message);
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
  if (!email || !req.file)
    return res.status(400).json({ success: false, message: 'Missing file or email' });
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
    const filePath = path.join(__dirname, 'uploads', doc.fileName);
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    await Document.findByIdAndDelete(id);
    res.json({ success: true, message: 'Document deleted' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ============================
// AI DANGER SCORING ENGINE
// ============================
const aiEngine = require('./ai_danger_engine');

app.post('/incident-report', async (req, res) => {
  try {
    const { location, latitude, longitude, type, severity, description, email } = req.body;
    if (!location) return res.status(400).json({ success: false, message: 'location is required' });
    await Incident.create({
      location: location.toLowerCase(), latitude, longitude,
      type: type || 'other', severity: severity || 'medium',
      reportedBy: email || 'anonymous', description
    });
    res.json({ success: true, message: 'Incident reported. Thank you for keeping others safe.' });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Failed to save report' });
  }
});

app.get('/ai-danger-score', async (req, res) => {
  const { location, destination, lat, lng, prolongedInactivity, geofenceBreach, geofenceZoneType, geofenceZoneName } = req.query;
  if (!location) return res.status(400).json({ success: false, message: 'location is required' });

  try {
    const now = new Date();
    const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);

    async function scoreLocation(locName, locLat, locLng) {
      const cityKey = aiEngine.extractCity(locName);
      const cityForQuery = cityKey || locName;

      const reports = await Incident.countDocuments({
        $or: [
          { location: { $regex: new RegExp(cityForQuery.toLowerCase(), 'i') } },
          ...(locLat && locLng ? [{
            latitude:  { $gte: parseFloat(locLat) - 0.05, $lte: parseFloat(locLat) + 0.05 },
            longitude: { $gte: parseFloat(locLng) - 0.05, $lte: parseFloat(locLng) + 0.05 }
          }] : [])
        ],
        createdAt: { $gte: sixHoursAgo }
      });

      let crimeScore = 0;
      if (cityKey) {
        const stat = await CrimeStat.findOne({ city: { $regex: new RegExp('^' + cityKey + '$', 'i') } }).lean();
        if (stat) crimeScore = stat.score;
      }

      let geofenceBoost = 0;
      if (geofenceZoneType === 'high-risk')  geofenceBoost = 80;
      if (geofenceZoneType === 'restricted') geofenceBoost = 55;
      if (geofenceZoneType === 'safe')       geofenceBoost = -20;

      const flags = {
        prolongedInactivity: prolongedInactivity === 'true',
        geofenceBreach:      geofenceBreach === 'true',
        geofenceBoost
      };

      return aiEngine.assess({ crimeRawScore: crimeScore, locationName: locName, reportCount: reports, flags, now });
    }

    const startResult = await scoreLocation(location, lat, lng);
    let finalResult = startResult;

    if (destination && destination.trim()) {
      const destResult = await scoreLocation(destination.trim(), null, null);
      if (destResult.score > startResult.score) {
        finalResult = {
          ...destResult,
          reasoning: `Destination (${destination}): ${destResult.reasoning}`,
          riskFactors: [...startResult.riskFactors.map(f => `Start: ${f}`), ...destResult.riskFactors.map(f => `Dest: ${f}`)]
        };
      } else {
        finalResult = {
          ...startResult,
          reasoning: `Origin (${location}): ${startResult.reasoning}`,
          riskFactors: [...startResult.riskFactors.map(f => `Start: ${f}`), ...destResult.riskFactors.map(f => `Dest: ${f}`)]
        };
      }
    }

    res.json({
      success: true, aiSource: 'rule_engine',
      geofenceZoneName: geofenceZoneName || null,
      geofenceZoneType: geofenceZoneType || null,
      ...finalResult
    });
  } catch (err) {
    console.error('AI Danger Score Error:', err);
    res.status(500).json({ success: false, message: 'AI assessment failed', score: 0, severity: 'safe', shouldTriggerSos: false });
  }
});

app.get('/ai-config', (req, res) => {
  res.json({ success: true, mode: 'rule_engine', provider: 'built-in rule engine' });
});

// ============================
// START SERVER
// ============================
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Backend running on http://0.0.0.0:${PORT}`);
});