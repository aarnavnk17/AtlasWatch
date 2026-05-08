'use strict';

const SOS_THRESHOLD    = 75;
const DANGER_THRESHOLD = 60;
const CAUTION_THRESHOLD = 40;

const WEIGHTS = { crimeBase:0.35, locationProfile:0.20, temporalRisk:0.15, reportVelocity:0.20, behavioural:0.10 };

const HIGH_RISK_AREAS = ['dharavi','kurla','govandi','mankhurd','seelampur','sangam vihar','uttam nagar','gajuwaka','jagadamba','benz circle','patamata','saidapet','vyasarpadi','kolathur','turbhe','vashi naka','asilmetta','maharanipeta','brodiepet','arundelpet'];
const MEDIUM_RISK_AREAS = ['airport','railway station','bus stand','bus depot','market','bazaar','junction','flyover'];
const LOW_RISK_AREAS = ['resort','hotel','mall','it park','tech park','university','hospital','embassy'];

const MAX_RAW_CRIME = 18320; // Delhi — highest in dataset

// Crime raw scores from crime_data.json — same dataset as Dart client
const CITY_CRIME_RAW = {
  'visakhapatnam':2800,'vijayawada':4500,'guntur':4100,'nellore':3200,'kurnool':4800,
  'itanagar':1500,'tawang':800,'pasighat':1200,'ziro':900,'bomdila':1000,
  'guwahati':7500,'silchar':4200,'dibrugarh':4500,'jorhat':4000,'tezpur':3200,
  'patna':9800,'gaya':7500,'muzaffarpur':8200,'bhagalpur':7800,'darbhanga':6500,
  'raipur':5800,'bhilai':3500,'bilaspur':4200,'korba':4000,'durg':4100,
  'panaji':2500,'margao':2800,'vasco':2700,'mapusa':2600,'ponda':2200,
  'ahmedabad':15190,'surat':16750,'vadodara':5200,'rajkot':5500,'bhavnagar':3800,
  'gurugram':8500,'gurgaon':8500,'faridabad':8200,'panipat':7800,'ambala':5500,'rohtak':7400,
  'shimla':1800,'manali':1500,'dharamshala':1600,'solan':1700,'mandi':1900,
  'ranchi':6200,'jamshedpur':5800,'dhanbad':7500,'bokaro':5100,'hazaribagh':4800,
  'bengaluru':5500,'bangalore':5500,'mysuru':2500,'mysore':2500,
  'hubballi':4200,'hubli':4200,'mangaluru':2800,'mangalore':2800,'belagavi':3200,'belgaum':3200,
  'kochi':16040,'cochin':16040,'thiruvananthapuram':4500,'trivandrum':4500,
  'kozhikode':4100,'calicut':4100,'thrissur':3200,'kollam':3500,
  'indore':11090,'bhopal':8800,'gwalior':9200,'jabalpur':6800,'ujjain':5200,
  'mumbai':3550,'bombay':3550,'pune':3370,'nagpur':8920,'thane':4500,'nashik':3000,
  'imphal':8500,'shillong':4200,'aizawl':1500,'kohima':4500,'dimapur':7200,
  'bhubaneswar':5200,'cuttack':6000,'rourkela':4800,'berhampur':4500,'sambalpur':4200,
  'ludhiana':8500,'amritsar':8000,'jalandhar':7800,'patiala':6500,'bathinda':6200,
  'jaipur':10260,'jodhpur':6800,'kota':6500,'udaipur':3800,'ajmer':5200,
  'gangtok':1200,
  'chennai':13250,'madras':13250,'coimbatore':2000,'kovai':2000,
  'madurai':4800,'tiruchirappalli':2900,'trichy':2900,'salem':4100,
  'hyderabad':3323,'warangal':4800,'nizamabad':4500,
  'agartala':2200,
  'lucknow':6000,'kanpur':7500,'ghaziabad':9000,'agra':6500,'varanasi':5800,
  'dehradun':4500,'haridwar':3800,'rishikesh':3200,'haldwani':4800,
  'kolkata':839,'calcutta':839,'howrah':4500,'durgapur':4200,'asansol':4800,'siliguri':4500,
  'delhi':18320,'new delhi':18320,
};

// Extract city from full address (e.g. "New Delhi Railway Station, Delhi, India" -> "new delhi")
function extractCity(locationName) {
  const loc = locationName.toLowerCase();
  const tokens = loc.split(',').map(t => t.trim());
  // Sort keys longest-first to prefer "new delhi" over "delhi"
  const sortedKeys = Object.keys(CITY_CRIME_RAW).sort((a, b) => b.length - a.length);
  for (const key of sortedKeys) {
    for (const token of tokens) {
      if (token.includes(key)) return key;
    }
  }
  // fallback: full string scan
  for (const key of sortedKeys) {
    if (loc.includes(key)) return key;
  }
  return null;
}

// Same sqrt+65 normalization as Dart client
function normaliseCrimeBase(rawScore) {
  if (!rawScore || rawScore <= 0) return 0;
  return Math.min(65, Math.round(Math.sqrt(rawScore / MAX_RAW_CRIME) * 65));
}

// Look up crime score by city extracted from full address
function crimeScoreForLocation(locationName) {
  const city = extractCity(locationName);
  if (!city) return 0;
  const raw = CITY_CRIME_RAW[city] || 0;
  return normaliseCrimeBase(raw);
}

function locationProfileScore(locationName) {
  const loc = locationName.toLowerCase();
  for (const a of HIGH_RISK_AREAS)   if (loc.includes(a)) return 80;
  for (const a of MEDIUM_RISK_AREAS) if (loc.includes(a)) return 55;
  for (const a of LOW_RISK_AREAS)    if (loc.includes(a)) return 15;
  return 40;
}

function temporalRiskScore(hour, dayOfWeek) {
  let s;
  if (hour >= 23 || hour < 3)      s = 90;
  else if (hour >= 3 && hour < 6)  s = 70;
  else if (hour >= 6 && hour < 9)  s = 35;
  else if (hour >= 9 && hour < 17) s = 20;
  else if (hour >= 17 && hour < 20)s = 30;
  else                              s = 55;
  const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
  if (isWeekend && (hour >= 22 || hour < 4)) s = Math.min(100, s + 10);
  return s;
}

function reportVelocityScore(reportCount) {
  if (reportCount <= 0) return 0;
  return Math.min(100, Math.round(30 * Math.log(reportCount + 1)));
}

function behaviouralScore(flags = {}) {
  let score = 0;
  if (flags.prolongedInactivity) score += 35;
  if (flags.geofenceBreach)      score += 50;
  if (flags.geofenceBoost)       score += flags.geofenceBoost;
  return Math.max(0, Math.min(100, score));
}

function severityLabel(score) {
  if (score >= SOS_THRESHOLD)    return 'critical';
  if (score >= DANGER_THRESHOLD) return 'danger';
  if (score >= CAUTION_THRESHOLD)return 'caution';
  return 'safe';
}

function buildExplanation(score, bd, reportCount, locationName, hour) {
  const city = extractCity(locationName);
  const displayName = city ? (city.charAt(0).toUpperCase() + city.slice(1)) : locationName.split(',')[0].trim();
  const factors = [];
  if (bd.crimeBase >= 50)       factors.push(`High historical crime rate in ${displayName}`);
  else if (bd.crimeBase >= 30)  factors.push(`Moderate crime data for ${displayName}`);
  else if (bd.crimeBase > 0)    factors.push(`Low crime baseline for ${displayName}`);
  if (bd.locationProfile >= 70) factors.push('Known high-risk neighbourhood or area');
  else if (bd.locationProfile >= 50) factors.push('Public transit or market area (pick-pocket risk)');
  if (bd.temporalRisk >= 70)    factors.push(`High-risk time of night (${hour}:00)`);
  if (reportCount > 0)          factors.push(`${reportCount} recent incident report${reportCount>1?'s':''} nearby`);
  if (bd.behavioural >= 30)     factors.push('Unusual movement or geofence breach detected');

  const severity = severityLabel(score);
  let reasoning;
  switch (severity) {
    case 'critical': reasoning = `Critical danger detected near ${displayName}. Immediate action recommended.`; break;
    case 'danger':   reasoning = `Significant risk factors present near ${displayName}. Stay vigilant.`; break;
    case 'caution':  reasoning = `Elevated risk in ${displayName}. Exercise extra caution.`; break;
    default:         reasoning = `${displayName} appears relatively safe. Maintain normal awareness.`;
  }
  return { reasoning, factors };
}

function assess(input) {
  const { crimeRawScore=0, locationName='Unknown', reportCount=0, flags={}, now=new Date() } = input;
  const hour = now.getHours(), dayOfWeek = now.getDay();

  // Always derive crime base from our city dataset using the location name.
  // crimeRawScore from MongoDB CrimeStat is used as a boost if available,
  // but city dataset is the reliable primary source.
  const datasetScore = crimeScoreForLocation(locationName);
  const mongoScore   = normaliseCrimeBase(crimeRawScore);
  const l1 = datasetScore > 0 ? datasetScore : mongoScore; // prefer dataset
  const l2 = locationProfileScore(locationName);
  const l3 = temporalRiskScore(hour, dayOfWeek);
  const l4 = reportVelocityScore(reportCount);
  const l5 = behaviouralScore(flags);

  // Use additive modifier approach: crime is base (0-65), modifiers push toward 100
  const timeMod      = Math.round((l3 - 15) * 0.25);   // neutral=15, late night adds ~+13
  const reportMod    = Math.round(l4 * 0.20);           // report velocity adds up to +20
  const behaviourMod = Math.round(l5 * 0.08);
  const locMod       = l2 >= 70 ? 12 : l2 >= 50 ? 6 : l2 <= 20 ? -5 : 0; // location type nudge
  const final_score  = Math.min(100, Math.max(5, l1 + timeMod + reportMod + behaviourMod + locMod));
  const severity = severityLabel(final_score);
  const { reasoning, factors } = buildExplanation(final_score, {crimeBase:l1,locationProfile:l2,temporalRisk:l3,reportVelocity:l4,behavioural:l5}, reportCount, locationName, hour);

  return {
    score: final_score, severity, reasoning,
    shouldTriggerSos: final_score >= SOS_THRESHOLD,
    riskFactors: factors,
    breakdown: { crimeBase:l1, locationProfile:l2, temporalRisk:l3, reportVelocity:l4, behavioural:l5 },
    meta: { reportCount, hour, dayOfWeek, location:locationName, computedAt:now.toISOString() },
  };
}

module.exports = { assess, extractCity, SOS_THRESHOLD, DANGER_THRESHOLD, CAUTION_THRESHOLD };