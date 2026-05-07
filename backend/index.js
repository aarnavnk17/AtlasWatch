const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const crimeData = require('./data/crime_data.json');

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
  passport: { type: String, unique: false },
  documentType: String,
  nationality: String
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

const locationSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  accuracy: Number,
  timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

const Location = mongoose.model('Location', locationSchema);

// ============================
// CRIME STATS ENDPOINT
// ============================
// Frontend RiskService thresholds: score < 100 → Low, < 200 → Medium, ≥ 200 → High.
// CrimeService computes: score = theft + (assault * 2) + fraud.
// Raw JSON scores are in the thousands, so we scale them down to the 0–300 range
// by dividing by 20, keeping proportional differences between cities intact.
app.get('/crime-stats', (req, res) => {
  const { area } = req.query;
  if (!area) return res.json({ theft: 0, assault: 0, fraud: 0 });

  const searchArea = area.toLowerCase();
  let rawScore = 0;
  let found = false;

  for (const state in crimeData) {
    const cities = crimeData[state];
    for (const city in cities) {
      if (city.toLowerCase() === searchArea || searchArea.includes(city.toLowerCase())) {
        rawScore = cities[city].score;
        found = true;
        break;
      }
      const subAreas = cities[city].areas;
      if (subAreas) {
        for (const sub in subAreas) {
          if (sub.toLowerCase() === searchArea || searchArea.includes(sub.toLowerCase())) {
            rawScore = subAreas[sub];
            found = true;
            break;
          }
        }
      }
      if (found) break;
    }
    if (found) break;
  }

  // Deterministic fallback for unknown places (0–300 range)
  if (!found) {
    let hash = 0;
    for (let i = 0; i < searchArea.length; i++) {
      hash = searchArea.charCodeAt(i) + ((hash << 5) - hash);
    }
    rawScore = Math.abs(hash % 6000); // will be scaled below
  }

  // Scale large raw scores into the 0–300 range expected by RiskService
  const finalScore = rawScore > 300 ? Math.floor(rawScore / 20) : rawScore;
  const third = Math.floor(finalScore / 3);

  res.json({ theft: third, assault: third, fraud: third });
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

  try {
    const user = new User({ email, password });
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
    if (user && user.password === password) {
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
// GET PROFILE
// ============================
app.get('/profile', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: 'Email required' });

  try {
    const row = await Profile.findOne({ email }).lean();
    if (row) return res.json({ success: true, profile: { passport: row.passport, documentType: row.documentType, nationality: row.nationality } });
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
  const { email, passport, documentType, nationality } = req.body;
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
      { email, passport, documentType, nationality },
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
// GEOFENCE ZONES (DYNAMIC)
// Auto-generated from crime_data.json scores.
// Thresholds: score < 3000 → safe | 3000–5999 → restricted | ≥ 6000 → high-risk
// Radius scales with risk: safe 4km | restricted 5km | high-risk 6km
// ============================

// City coordinates mirror of lib/data/city_coordinates.dart
const CITY_COORDS = {
  'Visakhapatnam': { lat: 17.6868, lng: 83.2185 },
  'Vijayawada': { lat: 16.5062, lng: 80.6480 },
  'Guntur': { lat: 16.3067, lng: 80.4365 },
  'Nellore': { lat: 14.4426, lng: 79.9865 },
  'Kurnool': { lat: 15.8281, lng: 78.0373 },
  'Itanagar': { lat: 27.0844, lng: 93.6053 },
  'Tawang': { lat: 27.5861, lng: 91.8594 },
  'Pasighat': { lat: 28.0665, lng: 95.3275 },
  'Ziro': { lat: 27.5946, lng: 93.8443 },
  'Bomdila': { lat: 27.2645, lng: 92.4159 },
  'Guwahati': { lat: 26.1158, lng: 91.7086 },
  'Silchar': { lat: 24.8170, lng: 92.8023 },
  'Dibrugarh': { lat: 27.4728, lng: 94.9120 },
  'Jorhat': { lat: 26.7509, lng: 94.2037 },
  'Tezpur': { lat: 26.6528, lng: 92.7926 },
  'Patna': { lat: 25.5941, lng: 85.1376 },
  'Gaya': { lat: 24.7914, lng: 85.0002 },
  'Muzaffarpur': { lat: 26.1197, lng: 85.3910 },
  'Bhagalpur': { lat: 25.2425, lng: 87.0118 },
  'Darbhanga': { lat: 26.1118, lng: 85.8960 },
  'Raipur': { lat: 21.2514, lng: 81.6296 },
  'Bhilai': { lat: 21.1938, lng: 81.3509 },
  'Bilaspur': { lat: 22.0797, lng: 82.1409 },
  'Korba': { lat: 22.3569, lng: 82.6807 },
  'Durg': { lat: 21.1904, lng: 81.2849 },
  'Panaji': { lat: 15.4909, lng: 73.8278 },
  'Margao': { lat: 15.2832, lng: 73.9862 },
  'Vasco da Gama': { lat: 15.3991, lng: 73.8125 },
  'Mapusa': { lat: 15.5945, lng: 73.8166 },
  'Ponda': { lat: 15.4026, lng: 74.0182 },
  'Ahmedabad': { lat: 23.0225, lng: 72.5714 },
  'Surat': { lat: 21.1702, lng: 72.8311 },
  'Vadodara': { lat: 22.3072, lng: 73.1812 },
  'Rajkot': { lat: 22.3039, lng: 70.8022 },
  'Bhavnagar': { lat: 21.7645, lng: 72.1519 },
  'Gurugram': { lat: 28.4595, lng: 77.0266 },
  'Faridabad': { lat: 28.4089, lng: 77.3178 },
  'Panipat': { lat: 29.3909, lng: 76.9635 },
  'Ambala': { lat: 30.3782, lng: 76.7767 },
  'Rohtak': { lat: 28.8955, lng: 76.6066 },
  'Shimla': { lat: 31.1048, lng: 77.1734 },
  'Manali': { lat: 32.2396, lng: 77.1887 },
  'Dharamshala': { lat: 32.2190, lng: 76.3239 },
  'Solan': { lat: 30.9084, lng: 77.0999 },
  'Mandi': { lat: 31.5892, lng: 76.9182 },
  'Ranchi': { lat: 23.3441, lng: 85.3096 },
  'Jamshedpur': { lat: 22.8046, lng: 86.2029 },
  'Dhanbad': { lat: 23.7957, lng: 86.4304 },
  'Bokaro': { lat: 23.6693, lng: 86.1511 },
  'Hazaribagh': { lat: 23.9962, lng: 85.3629 },
  'Bengaluru': { lat: 12.9716, lng: 77.5946 },
  'Mysuru': { lat: 12.2958, lng: 76.6394 },
  'Hubballi': { lat: 15.3647, lng: 75.1240 },
  'Mangaluru': { lat: 12.9141, lng: 74.8560 },
  'Belagavi': { lat: 15.8497, lng: 74.4977 },
  'Kochi': { lat: 9.9312, lng: 76.2673 },
  'Thiruvananthapuram': { lat: 8.5241, lng: 76.9366 },
  'Kozhikode': { lat: 11.2588, lng: 75.7804 },
  'Thrissur': { lat: 10.5276, lng: 76.2144 },
  'Kollam': { lat: 8.8932, lng: 76.6141 },
  'Indore': { lat: 22.7196, lng: 75.8577 },
  'Bhopal': { lat: 23.2599, lng: 77.4126 },
  'Gwalior': { lat: 26.2183, lng: 78.1828 },
  'Jabalpur': { lat: 23.1815, lng: 79.9864 },
  'Ujjain': { lat: 23.1765, lng: 75.7885 },
  'Mumbai': { lat: 19.0760, lng: 72.8777 },
  'Pune': { lat: 18.5204, lng: 73.8567 },
  'Nagpur': { lat: 21.1458, lng: 79.0882 },
  'Thane': { lat: 19.2183, lng: 72.9781 },
  'Nashik': { lat: 19.9975, lng: 73.7898 },
  'Imphal': { lat: 24.8170, lng: 93.9368 },
  'Churachandpur': { lat: 24.3364, lng: 93.6707 },
  'Thoubal': { lat: 24.6401, lng: 93.9933 },
  'Kakching': { lat: 24.4984, lng: 93.9678 },
  'Ukhrul': { lat: 25.1111, lng: 94.3582 },
  'Shillong': { lat: 25.5788, lng: 91.8933 },
  'Tura': { lat: 25.5141, lng: 90.2030 },
  'Jowai': { lat: 25.4526, lng: 92.2030 },
  'Nongpoh': { lat: 25.9080, lng: 91.8688 },
  'Williamnagar': { lat: 25.4983, lng: 90.6276 },
  'Aizawl': { lat: 23.7271, lng: 92.7176 },
  'Lunglei': { lat: 22.8844, lng: 92.7302 },
  'Champhai': { lat: 23.4759, lng: 93.3293 },
  'Kolasib': { lat: 24.2186, lng: 92.6841 },
  'Serchhip': { lat: 23.2872, lng: 92.8390 },
  'Kohima': { lat: 25.6751, lng: 94.1086 },
  'Dimapur': { lat: 25.8629, lng: 93.7538 },
  'Mokokchung': { lat: 26.3236, lng: 94.5126 },
  'Tuensang': { lat: 26.2796, lng: 94.8214 },
  'Wokha': { lat: 26.1030, lng: 94.2690 },
  'Bhubaneswar': { lat: 20.2961, lng: 85.8245 },
  'Cuttack': { lat: 20.4625, lng: 85.8828 },
  'Rourkela': { lat: 22.2604, lng: 84.8536 },
  'Berhampur': { lat: 19.3149, lng: 84.7941 },
  'Sambalpur': { lat: 21.4669, lng: 83.9812 },
  'Ludhiana': { lat: 30.9010, lng: 75.8573 },
  'Amritsar': { lat: 31.6340, lng: 74.8723 },
  'Jalandhar': { lat: 31.3260, lng: 75.5762 },
  'Patiala': { lat: 30.3398, lng: 76.3869 },
  'Bathinda': { lat: 30.2110, lng: 74.9455 },
  'Jaipur': { lat: 26.9124, lng: 75.7873 },
  'Jodhpur': { lat: 26.2389, lng: 73.0243 },
  'Kota': { lat: 25.2138, lng: 75.8648 },
  'Udaipur (RJ)': { lat: 24.5854, lng: 73.7125 },
  'Ajmer': { lat: 26.4499, lng: 74.6399 },
  'Gangtok': { lat: 27.3389, lng: 88.6065 },
  'Namchi': { lat: 27.1668, lng: 88.3610 },
  'Geyzing': { lat: 27.3005, lng: 88.2435 },
  'Mangan': { lat: 27.5029, lng: 88.5309 },
  'Rangpo': { lat: 27.1751, lng: 88.5298 },
  'Chennai': { lat: 13.0827, lng: 80.2707 },
  'Coimbatore': { lat: 11.0168, lng: 76.9558 },
  'Madurai': { lat: 9.9252, lng: 78.1198 },
  'Tiruchirappalli': { lat: 10.7905, lng: 78.7047 },
  'Salem': { lat: 11.6643, lng: 78.1460 },
  'Hyderabad': { lat: 17.3850, lng: 78.4867 },
  'Warangal': { lat: 17.9689, lng: 79.5941 },
  'Nizamabad': { lat: 18.6725, lng: 78.0941 },
  'Karimnagar': { lat: 18.4386, lng: 79.1288 },
  'Khammam': { lat: 17.2473, lng: 80.1514 },
  'Agartala': { lat: 23.8315, lng: 91.2868 },
  'Dharmanagar': { lat: 24.3794, lng: 92.1691 },
  'Udaipur (TR)': { lat: 23.5350, lng: 91.4883 },
  'Kailashahar': { lat: 24.3263, lng: 92.0164 },
  'Belonia': { lat: 23.2505, lng: 91.4552 },
  'Lucknow': { lat: 26.8467, lng: 80.9462 },
  'Kanpur': { lat: 26.4499, lng: 80.3319 },
  'Ghaziabad': { lat: 28.6692, lng: 77.4538 },
  'Agra': { lat: 27.1767, lng: 78.0081 },
  'Varanasi': { lat: 25.3176, lng: 82.9739 },
  'Dehradun': { lat: 30.3165, lng: 78.0322 },
  'Haridwar': { lat: 29.9457, lng: 78.1642 },
  'Rishikesh': { lat: 30.0869, lng: 78.2676 },
  'Haldwani': { lat: 29.2190, lng: 79.5126 },
  'Roorkee': { lat: 29.8543, lng: 77.8880 },
  'Kolkata': { lat: 22.5726, lng: 88.3639 },
  'Howrah': { lat: 22.5958, lng: 88.2636 },
  'Durgapur': { lat: 23.5204, lng: 87.3119 },
  'Asansol': { lat: 23.6739, lng: 86.9524 },
  'Siliguri': { lat: 26.7271, lng: 88.3953 },
  'New Delhi': { lat: 28.6139, lng: 77.2090 },
  'Delhi': { lat: 28.7041, lng: 77.1025 },
};

/**
 * Build geofence zones dynamically from crime_data.json.
 *
 * Classification thresholds (score = raw city score):
 *   score < 3000       → type: 'safe'       radius: 4000 m
 *   3000 ≤ score < 6000 → type: 'restricted'  radius: 5000 m
 *   score ≥ 6000       → type: 'high-risk'   radius: 6000 m
 *
 * Only cities that appear in CITY_COORDS get a zone (guarantees valid coords).
 */
function buildGeofenceZones(crimeData) {
  const zones = [];
  let idx = 0;

  for (const state of Object.keys(crimeData)) {
    const cities = crimeData[state];
    for (const city of Object.keys(cities)) {
      const score = cities[city].score || 0;
      const coords = CITY_COORDS[city];
      if (!coords) continue; // no coords → skip

      let type, radius;
      if (score >= 6000) {
        type = 'high-risk';
        radius = 6000;
      } else if (score >= 3000) {
        type = 'restricted';
        radius = 5000;
      } else {
        type = 'safe';
        radius = 4000;
      }

      zones.push({
        id: `zone-${idx++}`,
        name: city,
        state,
        type,
        score,
        lat: coords.lat,
        lng: coords.lng,
        radius,
      });
    }
  }

  return zones;
}

// Build once at startup — O(n) over 142 cities, negligible cost
const GEOFENCE_ZONES = buildGeofenceZones(crimeData);
console.log(`[GeofenceService] ${GEOFENCE_ZONES.length} zones loaded from crime data.`);

app.get('/geofences', (req, res) => {
  // Optional: filter by type query param, e.g. /geofences?type=high-risk
  const { type } = req.query;
  const zones = type
    ? GEOFENCE_ZONES.filter(z => z.type === type)
    : GEOFENCE_ZONES;
  res.json({ success: true, count: zones.length, zones });
});

// ============================
// RULE-BASED ANALYZE ENDPOINT
// ============================
app.post('/analyze', async (req, res) => {
  const { email, lat, lng } = req.body;
  if (!email || lat == null || lng == null) {
    return res.status(400).json({ success: false, message: 'Missing fields' });
  }

  try {
    const recent = await Location.find({ email }).sort({ timestamp: -1 }).limit(5).lean();

    let anomalyFlag = false;
    let anomalyReason = null;

    if (recent.length >= 2) {
      const prev = recent[0];
      const dt = (Date.now() - new Date(prev.timestamp).getTime()) / 1000;
      if (dt > 0) {
        const dLat = (lat - prev.lat) * Math.PI / 180;
        const dLng = (lng - prev.lng) * Math.PI / 180;
        const a = Math.sin(dLat/2)**2 + Math.cos(prev.lat*Math.PI/180)*Math.cos(lat*Math.PI/180)*Math.sin(dLng/2)**2;
        const distMeters = 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        const speedKmh = (distMeters / dt) * 3.6;
        if (speedKmh > 200) { anomalyFlag = true; anomalyReason = `Unusual speed: ${Math.round(speedKmh)} km/h`; }
      }
    }

    if (!anomalyFlag && recent.length >= 4) {
      const spread = recent.slice(0, 4).map(p => {
        const dLat = (lat - p.lat) * Math.PI / 180;
        const dLng = (lng - p.lng) * Math.PI / 180;
        const a = Math.sin(dLat/2)**2 + Math.cos(p.lat*Math.PI/180)*Math.cos(lat*Math.PI/180)*Math.sin(dLng/2)**2;
        return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
      });
      const timeSpanMs = recent.length >= 4 ? Date.now() - new Date(recent[3].timestamp).getTime() : 0;
      if (Math.max(...spread) < 30 && timeSpanMs > 300000) { anomalyFlag = true; anomalyReason = 'No movement for 5+ minutes'; }
    }

    const geofenceHit = GEOFENCE_ZONES.find(z => {
      const dLat = (lat - z.lat) * Math.PI / 180;
      const dLng = (lng - z.lng) * Math.PI / 180;
      const a = Math.sin(dLat/2)**2 + Math.cos(z.lat*Math.PI/180)*Math.cos(lat*Math.PI/180)*Math.sin(dLng/2)**2;
      return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)) <= z.radius && z.type !== 'safe';
    });

    return res.json({ success: true, anomalyFlag: anomalyFlag || !!geofenceHit, anomalyReason, geofenceZone: geofenceHit || null });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});
// ============================
// ADMIN ENDPOINT
// ============================
app.get('/admin/users', async (req, res) => {
  try {
    const users = await User.find({}).lean();

    // Attach profile info
    const fullUsers = await Promise.all(users.map(async (u) => {
      const profile = await Profile.findOne({ email: u.email }).lean();
      return {
        email: u.email,
        profileComplete: u.profile_completed,
        profile: profile ? { passport: profile.passport, documentType: profile.documentType, nationality: profile.nationality } : null,
        lastLocation: u.lastLocation || null,
        activeJourney: u.active_journey || null
      };
    }));

    return res.json({ success: true, users: fullUsers });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
});

const PORT = process.env.PORT || 3000;
if (process.env.NODE_ENV !== 'production') {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Backend running on http://0.0.0.0:${PORT}`);
  });
}

// Export for Vercel serverless hosting
module.exports = app;