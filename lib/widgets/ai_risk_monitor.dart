import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/ai_danger_service.dart';
import '../services/backend_service.dart';

class AiRiskMonitor extends StatefulWidget {
  final String location;
  final double? latitude;
  final double? longitude;
  final void Function(int score, String reason)? onAutoSosTrigger;
  final void Function(int score, String severity, String reason)? onRiskAssessed;
  final Duration pollInterval;

  const AiRiskMonitor({
    super.key, required this.location, this.latitude, this.longitude,
    this.onAutoSosTrigger, this.onRiskAssessed, this.pollInterval = const Duration(seconds: 60),
  });

  @override
  State<AiRiskMonitor> createState() => AiRiskMonitorState();
}

class AiRiskMonitorState extends State<AiRiskMonitor>
    with TickerProviderStateMixin {
  DangerAssessment? _assessment;
  bool _loading   = true;
  bool _expanded  = false;
  bool _sosFired  = false;
  bool _reporting = false;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _expandCtrl;
  late Animation<double>   _expandAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _expandCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
    _assess();
    _timer = Timer.periodic(widget.pollInterval, (_) => _assess());
  }

  @override
  void dispose() { _timer?.cancel(); _pulseCtrl.dispose(); _expandCtrl.dispose(); super.dispose(); }

  Future<void> refresh() async {
    setState(() => _loading = true);
    await _assess();
  }

  Future<void> _assess() async {
    if (!mounted) return;
    final result = await AiDangerService().assess(
      location: widget.location, lat: widget.latitude, lng: widget.longitude,
    );
    if (!mounted) return;
    setState(() { _assessment = result; _loading = false; });
    widget.onRiskAssessed?.call(result.score, result.severity, result.reasoning);
    
    if (result.shouldTriggerSos && !_sosFired) {
      _sosFired = true;
      widget.onAutoSosTrigger?.call(result.score, result.reasoning);
    }
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    _expanded ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  Future<void> _submitReport(String type) async {
    setState(() => _reporting = true);
    try {
      await BackendService.post('/incident-report',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'location': widget.location, 'latitude': widget.latitude,
          'longitude': widget.longitude, 'type': type, 'severity': 'medium'}),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✅ Incident reported — re-assessing...'),
        backgroundColor: Colors.green.shade800, duration: const Duration(seconds: 2),
      ));
      setState(() { _loading = true; _reporting = false; });
      _assess();
    } catch (e) {
      setState(() => _reporting = false);
    }
  }

  Color _colorFor(int s) {
    if (s < 40) return const Color(0xFF22C55E);
    if (s < 60) return const Color(0xFFF59E0B);
    if (s < 75) return const Color(0xFFEF4444);
    return const Color(0xFFDC2626);
  }

  Color get _mainColor => _colorFor(_assessment?.score ?? 0);

  Color get _bgColor {
    final s = _assessment?.score ?? 0;
    if (s < 40) return const Color(0xFF041A0D);
    if (s < 60) return const Color(0xFF1A1000);
    return const Color(0xFF1A0404);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Row(children: [
        SizedBox(height: 18, width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade400)),
        const SizedBox(width: 14),
        const Text('AI assessing danger level...', style: TextStyle(color: Colors.white38, fontSize: 13)),
      ]),
    );

    final a = _assessment!;
    final isCritical = a.score >= 75;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(scale: isCritical ? _pulseAnim.value : 1.0, child: child),
      child: GestureDetector(
        onTap: _toggleExpand,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: _bgColor, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _mainColor.withOpacity(0.45), width: 1.5),
            boxShadow: isCritical ? [BoxShadow(color: _mainColor.withOpacity(0.3), blurRadius: 28, spreadRadius: 2)] : [],
          ),
          child: Column(children: [
            // ── Main visible card ─────────────────────────────
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _mainColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      isCritical ? Icons.gpp_bad_rounded
                          : (a.score >= 60 ? Icons.warning_rounded : Icons.verified_user_rounded),
                      color: _mainColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI DANGER SCORE', style: TextStyle(color: _mainColor, fontSize: 11,
                        fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    if (a.aiSource != null)
                      Text('powered by ${a.aiSourceLabel}',
                          style: const TextStyle(color: Colors.white24, fontSize: 9)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: a.score.toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOut,
                      builder: (_, val, __) => Text(val.toInt().toString(),
                          style: TextStyle(color: _mainColor, fontSize: 42,
                              fontWeight: FontWeight.w900, height: 1)),
                    ),
                    Text('/100', style: TextStyle(color: _mainColor.withOpacity(0.5),
                        fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.expand_more_rounded, color: Colors.white38, size: 22),
                  ),
                ]),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: a.score / 100),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: val, minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(_mainColor)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: _mainColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _mainColor.withOpacity(0.35))),
                    child: Text(a.severity.toUpperCase(),
                        style: TextStyle(color: _mainColor, fontSize: 10,
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(a.reasoning,
                      style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45))),
                ]),
                if (a.geofenceZoneName != null) ...[
                  const SizedBox(height: 10),
                  _buildGeofencePill(a),
                ],
                if (isCritical) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.45))),
                    child: const Row(children: [
                      Icon(Icons.emergency_rounded, color: Colors.red, size: 15),
                      SizedBox(width: 8),
                      Expanded(child: Text('AUTO-SOS TRIGGERED — Alerting emergency contacts',
                          style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_expanded ? 'Tap to collapse' : 'Tap for breakdown',
                      style: const TextStyle(color: Colors.white24, fontSize: 10)),
                  GestureDetector(
                    onTap: () { setState(() => _loading = true); _assess(); },
                    child: const Row(children: [
                      Icon(Icons.refresh_rounded, size: 13, color: Colors.white24),
                      SizedBox(width: 3),
                      Text('Refresh', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    ]),
                  ),
                ]),
              ]),
            ),
            // ── Expanded breakdown ────────────────────────────
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(children: [
                Divider(color: _mainColor.withOpacity(0.15), height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SCORE BREAKDOWN', style: TextStyle(color: _mainColor.withOpacity(0.7),
                        fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 14),
                    ...a.subScores.map(_buildSubRow),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withOpacity(0.06), height: 1),
                    const SizedBox(height: 14),
                    Text('REPORT AN INCIDENT', style: TextStyle(color: Colors.orange.withOpacity(0.8),
                        fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    _buildReportPanel(),
                    const SizedBox(height: 16),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSubRow(SubScore sub) {
    final color = _colorFor(sub.score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        SizedBox(width: 28, child: Text(sub.icon, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sub.label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(sub.detail, style: const TextStyle(color: Colors.white30, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 10),
        SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${sub.score}', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: sub.score / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(value: val, minHeight: 5,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color)),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _buildGeofencePill(DangerAssessment a) {
    Color zoneColor; IconData zoneIcon;
    switch (a.geofenceZoneType) {
      case 'high-risk':  zoneColor = Colors.red;    zoneIcon = Icons.gpp_bad_outlined; break;
      case 'restricted': zoneColor = Colors.orange; zoneIcon = Icons.do_not_disturb_on_outlined; break;
      default:           zoneColor = Colors.green;  zoneIcon = Icons.verified_user_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: zoneColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: zoneColor.withOpacity(0.35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(zoneIcon, color: zoneColor, size: 14),
        const SizedBox(width: 6),
        Text('Geofence: ${a.geofenceZoneName} · ${a.geofenceZoneType}',
            style: TextStyle(color: zoneColor, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildReportPanel() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        ('theft',      Icons.shopping_bag_outlined,   'Theft'),
        ('assault',    Icons.sports_kabaddi_outlined, 'Assault'),
        ('harassment', Icons.person_off_outlined,     'Harassment'),
        ('suspicious', Icons.visibility_outlined,     'Suspicious'),
      ].map((t) => GestureDetector(
        onTap: _reporting ? null : () => _submitReport(t.$1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(t.$2, size: 13, color: Colors.orange.shade300),
            const SizedBox(width: 6),
            Text(t.$3, style: TextStyle(color: Colors.orange.shade300,
                fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      )).toList(),
    );
  }
}