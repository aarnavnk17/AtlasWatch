import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'backend_service.dart';
import 'geofence_service.dart';

class SubScore {
  final String label;
  final String icon;
  final int score;
  final String detail;
  const SubScore({required this.label, required this.icon, required this.score, required this.detail});
}

class DangerAssessment {
  final int score;
  final String severity;
  final String reasoning;
  final bool shouldTriggerSos;
  final List<String> riskFactors;
  final Map<String, dynamic>? breakdown;
  final String? aiSource;
  final String? geofenceZoneName;
  final String? geofenceZoneType;

  const DangerAssessment({
    required this.score, required this.severity, required this.reasoning,
    required this.shouldTriggerSos, required this.riskFactors,
    this.breakdown, this.aiSource, this.geofenceZoneName, this.geofenceZoneType,
  });

  factory DangerAssessment.fromJson(Map<String, dynamic> json) {
    return DangerAssessment(
      score           : (json['score'] as num? ?? 0).toInt().clamp(0, 100),
      severity        : json['severity'] ?? 'safe',
      reasoning       : json['reasoning'] ?? 'Assessment complete.',
      shouldTriggerSos: json['shouldTriggerSos'] ?? false,
      riskFactors     : List<String>.from(json['riskFactors'] ?? []),
      breakdown       : json['breakdown'] as Map<String, dynamic>?,
      aiSource        : json['aiSource'] as String?,
      geofenceZoneName: json['geofenceZoneName'] as String?,
      geofenceZoneType: json['geofenceZoneType'] as String?,
    );
  }

  factory DangerAssessment.fallback() => const DangerAssessment(
    score: 0, severity: 'safe',
    reasoning: 'Risk assessment temporarily unavailable.',
    shouldTriggerSos: false, riskFactors: [], aiSource: 'offline',
  );

  String get aiSourceLabel {
    if (aiSource == null || aiSource == 'rule_engine') return 'Built-in AI';
    if (aiSource == 'offline') return 'Offline';
    return aiSource![0].toUpperCase() + aiSource!.substring(1);
  }

  List<SubScore> get subScores {
    final bd = breakdown;
    if (bd == null) return [];
    return [
      SubScore(label: 'Crime History', icon: '🗂️',
          score: (bd['crimeBase'] as num? ?? 0).toInt().clamp(0, 100),
          detail: 'Historical crime rate for this area'),
      SubScore(label: 'Area Profile', icon: '📍',
          score: (bd['locationProfile'] as num? ?? 0).toInt().clamp(0, 100),
          detail: 'Known risk level of this location type'),
      SubScore(label: 'Time of Day', icon: '🕐',
          score: (bd['temporalRisk'] as num? ?? 0).toInt().clamp(0, 100),
          detail: 'Risk based on current hour & day'),
      SubScore(label: 'Transport Risk', icon: '🚗',
          score: (bd['reportVelocity'] as num? ?? 0).toInt().clamp(0, 100),
          detail: 'Vulnerability based on travel mode'),
      SubScore(label: 'Geofence', icon: '🔺',
          score: (bd['behavioural'] as num? ?? 0).toInt().clamp(0, 100),
          detail: geofenceZoneName != null
              ? 'Zone: $geofenceZoneName ($geofenceZoneType)'
              : 'Movement & zone behaviour'),
    ];
  }
}

class AiDangerService {
  static const int sosTriggerThreshold = 75;

  bool prolongedInactivity = false;
  bool geofenceBreach      = false;

  void setFlag({bool? inactivity, bool? geofence}) {
    if (inactivity != null) prolongedInactivity = inactivity;
    if (geofence   != null) geofenceBreach      = geofence;
  }

  Future<DangerAssessment> assess({
    required String location,
    String? destination,
    double? lat,
    double? lng,
    String? transportMode,          // 'Car', 'Bike', 'Bus', 'Walk', etc.
    List<Map<String,double>>? routeWaypoints, // [{lat, lng}, ...] sampled from route
  }) async {
    // 1. Geofence check
    String? geofenceZoneName;
    String? geofenceZoneType;

    if (lat != null && lng != null) {
      try {
        final zones = await GeofenceService().fetchZones();
        for (final zone in zones) {
          final dist = _haversineMeters(lat, lng, zone.centerLat, zone.centerLng);
          if (dist <= zone.radiusMeters) {
            geofenceZoneName = zone.name;
            geofenceZoneType = zone.type;
            if (zone.type == 'restricted' || zone.type == 'high-risk') {
              setFlag(geofence: true);
            } else if (zone.type == 'safe') {
              setFlag(geofence: false);
            }
            break;
          }
        }
      } catch (e) { debugPrint('[AI] Geofence check error: $e'); }
    }

    // 2. Backend call
    try {
      final params = <String, String>{
        'location': location,
        if (destination != null && destination.isNotEmpty) 'destination': destination,
        if (lat != null) 'lat': lat.toStringAsFixed(5),
        if (lng != null) 'lng': lng.toStringAsFixed(5),
        if (transportMode != null) 'mode': transportMode,
        if (prolongedInactivity) 'prolongedInactivity': 'true',
        if (geofenceBreach)      'geofenceBreach': 'true',
        if (geofenceZoneType != null) 'geofenceZoneType': geofenceZoneType,
        if (geofenceZoneName != null) 'geofenceZoneName': geofenceZoneName,
      };

      final qs = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await BackendService.get('/ai-danger-score?$qs');
      if (response.statusCode != 200) return _localFallback(location: location,
          geofenceZoneName: geofenceZoneName, geofenceZoneType: geofenceZoneType,
          transportMode: transportMode, routeWaypoints: routeWaypoints);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) return _localFallback(location: location,
          geofenceZoneName: geofenceZoneName, geofenceZoneType: geofenceZoneType,
          transportMode: transportMode, routeWaypoints: routeWaypoints);

      final base = DangerAssessment.fromJson(json);
      return DangerAssessment(
        score: base.score, severity: base.severity, reasoning: base.reasoning,
        shouldTriggerSos: base.shouldTriggerSos,
        riskFactors: [
          ...base.riskFactors,
          if (geofenceZoneName != null) 'Geofence: $geofenceZoneName ($geofenceZoneType)',
        ],
        breakdown: base.breakdown, aiSource: base.aiSource,
        geofenceZoneName: geofenceZoneName, geofenceZoneType: geofenceZoneType,
      );
    } catch (e) {
      debugPrint('[AI] Backend error: $e');
      return _localFallback(location: location,
          geofenceZoneName: geofenceZoneName, geofenceZoneType: geofenceZoneType,
          transportMode: transportMode, routeWaypoints: routeWaypoints);
    }
  }

  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(_rad(lat1))*math.cos(_rad(lat2))*math.sin(dLng/2)*math.sin(dLng/2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  // ── Crime data from crime_data.json (raw incident counts) ──
  // Max raw score in dataset ≈ 18320 (New Delhi) — used for normalization.
  static const int _maxRawScore = 18320;

  static const Map<String, int> _crimeRawScores = {
    // Andhra Pradesh
    'visakhapatnam': 2800, 'vizag': 2800,
    'vijayawada': 4500, 'guntur': 4100, 'nellore': 3200, 'kurnool': 4800,
    // Arunachal Pradesh
    'itanagar': 1500, 'tawang': 800, 'pasighat': 1200, 'ziro': 900, 'bomdila': 1000,
    // Assam
    'guwahati': 7500, 'silchar': 4200, 'dibrugarh': 4500, 'jorhat': 4000, 'tezpur': 3200,
    // Bihar
    'patna': 9800, 'gaya': 7500, 'muzaffarpur': 8200, 'bhagalpur': 7800, 'darbhanga': 6500,
    // Chhattisgarh
    'raipur': 5800, 'bhilai': 3500, 'bilaspur': 4200, 'korba': 4000, 'durg': 4100,
    // Goa
    'panaji': 2500, 'margao': 2800, 'vasco': 2700, 'mapusa': 2600, 'ponda': 2200,
    // Gujarat
    'ahmedabad': 15190, 'surat': 16750, 'vadodara': 5200,
    'rajkot': 5500, 'bhavnagar': 3800,
    // Haryana
    'gurugram': 8500, 'gurgaon': 8500, 'faridabad': 8200,
    'panipat': 7800, 'ambala': 5500, 'rohtak': 7400,
    // Himachal Pradesh
    'shimla': 1800, 'manali': 1500, 'dharamshala': 1600, 'solan': 1700, 'mandi': 1900,
    // Jharkhand
    'ranchi': 6200, 'jamshedpur': 5800, 'dhanbad': 7500, 'bokaro': 5100, 'hazaribagh': 4800,
    // Karnataka
    'bengaluru': 5500, 'bangalore': 5500,
    'mysuru': 2500, 'mysore': 2500,
    'hubballi': 4200, 'hubli': 4200,
    'mangaluru': 2800, 'mangalore': 2800,
    'belagavi': 3200, 'belgaum': 3200,
    // Kerala
    'kochi': 16040, 'cochin': 16040,
    'thiruvananthapuram': 4500, 'trivandrum': 4500,
    'kozhikode': 4100, 'calicut': 4100,
    'thrissur': 3200, 'kollam': 3500,
    // Madhya Pradesh
    'indore': 11090, 'bhopal': 8800, 'gwalior': 9200, 'jabalpur': 6800, 'ujjain': 5200,
    // Maharashtra
    'mumbai': 3550, 'bombay': 3550,
    'pune': 3370, 'nagpur': 8920, 'thane': 4500, 'nashik': 3000,
    // Manipur
    'imphal': 8500,
    // Meghalaya
    'shillong': 4200,
    // Mizoram
    'aizawl': 1500,
    // Nagaland
    'kohima': 4500, 'dimapur': 7200,
    // Odisha
    'bhubaneswar': 5200, 'cuttack': 6000, 'rourkela': 4800, 'berhampur': 4500, 'sambalpur': 4200,
    // Punjab
    'ludhiana': 8500, 'amritsar': 8000, 'jalandhar': 7800, 'patiala': 6500, 'bathinda': 6200,
    // Rajasthan
    'jaipur': 10260, 'jodhpur': 6800, 'kota': 6500, 'udaipur': 3800, 'ajmer': 5200,
    // Sikkim
    'gangtok': 1200,
    // Tamil Nadu
    'chennai': 13250, 'madras': 13250,
    'coimbatore': 2000, 'kovai': 2000,
    'madurai': 4800,
    'tiruchirappalli': 2900, 'trichy': 2900,
    'salem': 4100,
    // Telangana
    'hyderabad': 3323, 'warangal': 4800, 'nizamabad': 4500,
    // Tripura
    'agartala': 2200,
    // Uttar Pradesh
    'lucknow': 6000, 'kanpur': 7500, 'ghaziabad': 9000,
    'agra': 6500, 'varanasi': 5800,
    // Uttarakhand
    'dehradun': 4500, 'haridwar': 3800, 'rishikesh': 3200, 'haldwani': 4800,
    // West Bengal
    'kolkata': 839, 'calcutta': 839,
    'howrah': 4500, 'durgapur': 4200, 'asansol': 4800, 'siliguri': 4500,
    // Delhi
    'delhi': 18320, 'new delhi': 18320,
  };

  /// Normalize raw crime count to 0–75 (crime is the base; modifiers push up to ~100).
  /// sqrt scaling so mid-range cities aren't compressed to the bottom.
  int _normalizeCrimeScore(int rawScore) {
    final ratio = rawScore / _maxRawScore;
    return (math.sqrt(ratio) * 65).round().clamp(0, 65);
  }

  /// Look up crime data score for a city name (fuzzy match).
  int? _crimeScoreFor(String loc) {
    // loc may be a full address like "chennai central railway station, tamil nadu, india"
    // Split on commas and try each token so we don't rely on substring matching long strings.
    final tokens = loc.split(',').map((t) => t.trim()).toList();

    // Sort keys longest-first so "new delhi" matches before "delhi"
    final sortedKeys = _crimeRawScores.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in sortedKeys) {
      // Check each comma-token: does this token contain the key or vice versa?
      for (final token in tokens) {
        if (token.contains(key) || key.contains(token) && token.length >= 4) {
          return _normalizeCrimeScore(_crimeRawScores[key]!);
        }
      }
    }
    // Final fallback: check full string (catches single-word inputs like "chennai")
    for (final key in sortedKeys) {
      if (loc.contains(key)) return _normalizeCrimeScore(_crimeRawScores[key]!);
    }
    return null;
  }

  String _riskLabel(int raw) {
    if (raw < 3000)  return 'Low';
    if (raw < 7000)  return 'Medium';
    return 'High';
  }

  DangerAssessment _localFallback({
    required String location,
    String? geofenceZoneName,
    String? geofenceZoneType,
    String? transportMode,
    List<Map<String,double>>? routeWaypoints,
  }) {
    final hour     = DateTime.now().hour;
    final loc      = location.toLowerCase().trim();
    // Extract the actual city name: find which crime DB key matches, use that as display name
    // Fallback: first comma token
    final _sortedKeys = _crimeRawScores.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    String cityName = location.split(',').first.trim();
    for (final key in _sortedKeys) {
      if (loc.contains(key)) {
        cityName = key[0].toUpperCase() + key.substring(1); // capitalize
        break;
      }
    }

    // ── 1. Crime history score from JSON data ──────────────────
    final crimeScore = _crimeScoreFor(loc) ?? 35; // default 35 if city not found

    // Find raw score for reasoning text (same token logic)
    int? rawEntry;
    final sortedKeys = _crimeRawScores.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    outer:
    for (final key in sortedKeys) {
      for (final token in loc.split(',').map((t) => t.trim())) {
        if (token.contains(key) || (key.contains(token) && token.length >= 4)) {
          rawEntry = _crimeRawScores[key];
          break outer;
        }
      }
    }
    if (rawEntry == null) {
      for (final key in sortedKeys) {
        if (loc.contains(key)) { rawEntry = _crimeRawScores[key]; break; }
      }
    }
    final riskLabel = rawEntry != null ? _riskLabel(rawEntry) : 'Unknown';

    // ── 2. Time-of-day risk ────────────────────────────────────
    int timeRisk;
    if (hour >= 23 || hour < 3)       timeRisk = 65;
    else if (hour >= 3 && hour < 6)   timeRisk = 45;
    else if (hour >= 6 && hour < 9)   timeRisk = 20;
    else if (hour >= 9 && hour < 17)  timeRisk = 10;
    else if (hour >= 17 && hour < 20) timeRisk = 18;
    else                               timeRisk = 30;

    // ── 3. Location type modifier ──────────────────────────────
    int locModifier = 0;
    String? locType;
    for (final h in ['station','junction','bazaar','market','bus stand','naka','bus stop']) {
      if (loc.contains(h)) { locModifier = 15; locType = h; break; }
    }
    for (final l in ['mall','hotel','resort','hospital','tech park','it park','airport']) {
      if (loc.contains(l)) { locModifier = -12; locType = l; break; }
    }
    final locationProfile = (crimeScore + locModifier).clamp(0, 100);

    // ── 4. Transport mode risk ─────────────────────────────────
    // Vulnerability: Walk > Bike > Auto > Bus > Car > Train/Metro
    int transportRisk = 0;
    String? modeLabel;
    if (transportMode != null) {
      final m = transportMode.toLowerCase();
      if (m.contains('walk') || m.contains('foot')) {
        transportRisk = 30; modeLabel = 'Walking (highest vulnerability)';
      } else if (m.contains('bike') || m.contains('cycle') || m.contains('bicycle')) {
        transportRisk = 25; modeLabel = 'Cycling (high vulnerability)';
      } else if (m.contains('auto') || m.contains('rickshaw') || m.contains('tuk')) {
        transportRisk = 18; modeLabel = 'Auto/Rickshaw (moderate vulnerability)';
      } else if (m.contains('bus') || m.contains('public')) {
        transportRisk = 15; modeLabel = 'Bus/Public transport (moderate)';
      } else if (m.contains('car') || m.contains('taxi') || m.contains('cab') || m.contains('uber') || m.contains('ola')) {
        transportRisk = 8;  modeLabel = 'Car/Taxi (lower vulnerability)';
      } else if (m.contains('metro') || m.contains('train') || m.contains('rail')) {
        transportRisk = 5;  modeLabel = 'Metro/Train (lowest vulnerability)';
      } else {
        transportRisk = 10; modeLabel = transportMode;
      }
    }

    // ── 5. Route corridor crime scoring ───────────────────────
    // Sample up to 5 waypoints along the route and average their city scores.
    // This makes a Coimbatore→Delhi route score higher than Coimbatore→Chennai.
    int routeScore = crimeScore; // default: just the origin
    final List<String> routeCitiesHit = [];

    if (routeWaypoints != null && routeWaypoints.length >= 2) {
      // Sample ~5 evenly spaced waypoints (skip first — that's origin)
      final step = math.max(1, routeWaypoints.length ~/ 5);
      final samples = <int>[];
      for (int i = step; i < routeWaypoints.length; i += step) {
        final wp = routeWaypoints[i];
        final wLat = wp['lat']!;
        final wLng = wp['lng']!;
        // Find closest city in our dataset by lat/lng
        final cityMatch = _closestCityScore(wLat, wLng);
        if (cityMatch != null) {
          samples.add(cityMatch.score);
          if (cityMatch.name.isNotEmpty) routeCitiesHit.add(cityMatch.name);
        }
      }
      if (samples.isNotEmpty) {
        // Take the max along the route — a journey is only as safe as its most dangerous stretch
        final maxRouteScore = samples.reduce(math.max);
        routeScore = ((crimeScore + maxRouteScore) / 2).round();
      }
    }

    // ── 6. Geofence ───────────────────────────────────────────
    int geofenceRisk = 0;
    if (geofenceZoneType == 'high-risk')  geofenceRisk = 80;
    if (geofenceZoneType == 'restricted') geofenceRisk = 60;

    // ── 7. Final score: crime/route is the BASE (0–75), modifiers push toward 100 ──
    // Crime base is capped at 65 so time-of-day, transport, and geofence
    // always have headroom to push high-risk situations toward 100
    // without low-crime cities being unfairly penalised by a bad time of day.
    final timeMod      = ((timeRisk - 15) * 0.25).round();     // neutral=15; late night adds ~+13
    final transportMod = ((transportRisk - 8) * 0.20).round(); // car=0 baseline; walk adds ~+4
    final locMod       = ((locationProfile - routeScore) * 0.30).round();
    final geoMod       = (geofenceRisk * 0.08).round();
    final score = (routeScore + timeMod + transportMod + locMod + geoMod).clamp(5, 100);

    // ── 6. Reasoning & severity ───────────────────────────────
    final timeDesc = timeRisk <= 10 ? 'daytime hours'
        : timeRisk <= 20 ? 'morning hours'
        : timeRisk <= 30 ? 'evening hours'
        : 'late-night hours';

    String severity; bool sos = false; String reasoning;
    if (score < 40) {
      severity  = 'safe';
      reasoning = '$cityName is a $riskLabel-crime city. '
          'No significant risk detected during $timeDesc.';
    } else if (score < 60) {
      severity  = 'caution';
      reasoning = '$cityName has a $riskLabel crime profile. '
          'Stay alert, especially during $timeDesc.';
    } else if (score < sosTriggerThreshold) {
      severity  = 'danger';
      reasoning = '$cityName has a $riskLabel crime rate. '
          'Avoid isolated areas and stay in well-lit zones.';
    } else {
      severity  = 'critical';
      reasoning = 'Critical danger level in $cityName. Emergency contacts alerted.';
      sos = true;
    }

    return DangerAssessment(
      score: score, severity: severity, reasoning: reasoning,
      shouldTriggerSos: sos,
      riskFactors: [
        if (rawEntry != null) 'Crime data: $rawEntry recorded incidents ($riskLabel risk city)',
        if (modeLabel != null) 'Transport: $modeLabel',
        if (routeCitiesHit.isNotEmpty) 'Route passes through: ${routeCitiesHit.toSet().join(', ')}',
        if (timeRisk >= 45) 'Late-night hours significantly increase risk',
        if (timeRisk >= 30 && timeRisk < 45) 'Evening hours add moderate risk',
        if (locModifier > 0) 'High-footfall area type ($locType) increases risk',
        if (locModifier < 0) 'Low-risk venue type ($locType) reduces risk',
        if (geofenceRisk >= 60) 'Geofence alert: $geofenceZoneName ($geofenceZoneType)',
        if (rawEntry == null) 'City not in crime database — using default baseline',
      ],
      breakdown: {
        'crimeBase'      : routeScore,      // reflects full route, not just origin
        'locationProfile': locationProfile,
        'temporalRisk'   : timeRisk,
        'reportVelocity' : transportRisk,   // reusing this slot for transport
        'behavioural'    : geofenceRisk,
      },
      aiSource: 'offline',
      geofenceZoneName: geofenceZoneName,
      geofenceZoneType: geofenceZoneType,
    );
  }

  // ── City coordinate lookup for route waypoint scoring ──────
  // Coarse lat/lng centroids for major Indian cities
  static const List<Map<String, dynamic>> _cityLatLngs = [
    {'name':'Visakhapatnam','lat':17.6868,'lng':83.2185,'raw':2800},
    {'name':'Vijayawada',   'lat':16.5062,'lng':80.6480,'raw':4500},
    {'name':'Guwahati',     'lat':26.1445,'lng':91.7362,'raw':7500},
    {'name':'Patna',        'lat':25.5941,'lng':85.1376,'raw':9800},
    {'name':'Raipur',       'lat':21.2514,'lng':81.6296,'raw':5800},
    {'name':'Ahmedabad',    'lat':23.0225,'lng':72.5714,'raw':15190},
    {'name':'Surat',        'lat':21.1702,'lng':72.8311,'raw':16750},
    {'name':'Gurugram',     'lat':28.4595,'lng':77.0266,'raw':8500},
    {'name':'Shimla',       'lat':31.1048,'lng':77.1734,'raw':1800},
    {'name':'Ranchi',       'lat':23.3441,'lng':85.3096,'raw':6200},
    {'name':'Bengaluru',    'lat':12.9716,'lng':77.5946,'raw':5500},
    {'name':'Mysuru',       'lat':12.2958,'lng':76.6394,'raw':2500},
    {'name':'Kochi',        'lat':9.9312, 'lng':76.2673,'raw':16040},
    {'name':'Thiruvananthapuram','lat':8.5241,'lng':76.9366,'raw':4500},
    {'name':'Indore',       'lat':22.7196,'lng':75.8577,'raw':11090},
    {'name':'Bhopal',       'lat':23.2599,'lng':77.4126,'raw':8800},
    {'name':'Gwalior',      'lat':26.2183,'lng':78.1828,'raw':9200},
    {'name':'Mumbai',       'lat':19.0760,'lng':72.8777,'raw':3550},
    {'name':'Pune',         'lat':18.5204,'lng':73.8567,'raw':3370},
    {'name':'Nagpur',       'lat':21.1458,'lng':79.0882,'raw':8920},
    {'name':'Imphal',       'lat':24.8170,'lng':93.9368,'raw':8500},
    {'name':'Kohima',       'lat':25.6747,'lng':94.1086,'raw':4500},
    {'name':'Bhubaneswar',  'lat':20.2961,'lng':85.8245,'raw':5200},
    {'name':'Ludhiana',     'lat':30.9010,'lng':75.8573,'raw':8500},
    {'name':'Amritsar',     'lat':31.6340,'lng':74.8723,'raw':8000},
    {'name':'Jaipur',       'lat':26.9124,'lng':75.7873,'raw':10260},
    {'name':'Jodhpur',      'lat':26.2389,'lng':73.0243,'raw':6800},
    {'name':'Gangtok',      'lat':27.3389,'lng':88.6065,'raw':1200},
    {'name':'Chennai',      'lat':13.0827,'lng':80.2707,'raw':13250},
    {'name':'Coimbatore',   'lat':11.0168,'lng':76.9558,'raw':2000},
    {'name':'Madurai',      'lat':9.9252, 'lng':78.1198,'raw':4800},
    {'name':'Tiruchirappalli','lat':10.7905,'lng':78.7047,'raw':2900},
    {'name':'Salem',        'lat':11.6643,'lng':78.1460,'raw':4100},
    {'name':'Hyderabad',    'lat':17.3850,'lng':78.4867,'raw':3323},
    {'name':'Warangal',     'lat':17.9784,'lng':79.5941,'raw':4800},
    {'name':'Agartala',     'lat':23.8315,'lng':91.2868,'raw':2200},
    {'name':'Lucknow',      'lat':26.8467,'lng':80.9462,'raw':6000},
    {'name':'Kanpur',       'lat':26.4499,'lng':80.3319,'raw':7500},
    {'name':'Ghaziabad',    'lat':28.6692,'lng':77.4538,'raw':9000},
    {'name':'Agra',         'lat':27.1767,'lng':78.0081,'raw':6500},
    {'name':'Varanasi',     'lat':25.3176,'lng':82.9739,'raw':5800},
    {'name':'Dehradun',     'lat':30.3165,'lng':78.0322,'raw':4500},
    {'name':'Kolkata',      'lat':22.5726,'lng':88.3639,'raw':839},
    {'name':'Delhi',        'lat':28.6139,'lng':77.2090,'raw':18320},
  ];

  ({int score, String name})? _closestCityScore(double lat, double lng) {
    double minDist = double.infinity;
    Map<String, dynamic>? closest;
    for (final city in _cityLatLngs) {
      final dLat = (city['lat'] as double) - lat;
      final dLng = (city['lng'] as double) - lng;
      final dist = dLat * dLat + dLng * dLng; // no need for actual km, just relative
      if (dist < minDist) { minDist = dist; closest = city; }
    }
    if (closest == null) return null;
    // Only count it if within ~200km (roughly 1.8 degrees²)
    if (minDist > 3.24) return null;
    return (score: _normalizeCrimeScore(closest['raw'] as int), name: closest['name'] as String);
  }

  static String severityFromScore(int score) {
    if (score >= sosTriggerThreshold) return 'critical';
    if (score >= 60) return 'danger';
    if (score >= 40) return 'caution';
    return 'safe';
  }
}