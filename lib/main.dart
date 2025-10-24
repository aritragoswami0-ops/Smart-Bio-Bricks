
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const SmartBioBricksApp());
}

class SmartBioBricksApp extends StatelessWidget {
  const SmartBioBricksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState()..load(),
      child: MaterialApp(
        title: 'Smart Bio Bricks',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          textTheme: GoogleFonts.openSansTextTheme(ThemeData.dark().textTheme),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  final Map<String, double> _values = {
    'Vegetable peels': 10.0,
    'Sawdust': 5.0,
    'Dry leaves': 4.0,
    'Plastic (shreds)': 2.0,
    'Straws / fibers': 1.0,
    'E-waste': 0.2,
    'Sand': 0.5,
    'Other': 0.3,
  };

  // Brick settings
  double brickMass = 2.0; // kg
  double brickVolume = 0.002; // m^3

  // landfill settings
  double landfillArea = 1000.0; // m^2
  double landfillDepth = 2.0; // m

  Map<String, double> get values => Map.unmodifiable(_values);

  void updateValue(String key, double val) {
    _values[key] = val < 0 ? 0 : val;
    notifyListeners();
    _save();
  }

  double get totalAvailableWaste {
    return _values.values.fold(0.0, (a, b) => a + b);
  }

  int get bricksProducible {
    final bricks = totalAvailableWaste / brickMass;
    return bricks.floor();
  }

  double get totalDivertedMass {
    // assume all but small losses get diverted
    return bricksProducible * brickMass;
  }

  double get volumeDiverted {
    return bricksProducible * brickVolume;
  }

  double get areaReduced {
    if (landfillDepth <= 0) return 0.0;
    return volumeDiverted / landfillDepth;
  }

  double percentLandfillReduced() {
    if (landfillArea <= 0) return 0.0;
    final p = areaReduced / landfillArea * 100.0;
    return p.clamp(0.0, 100.0);
  }

  // persistence
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in _values.entries) {
      await prefs.setDouble('v:${e.key}', e.value);
    }
    await prefs.setDouble('brickMass', brickMass);
    await prefs.setDouble('brickVolume', brickVolume);
    await prefs.setDouble('landfillArea', landfillArea);
    await prefs.setDouble('landfillDepth', landfillDepth);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _values.keys.toList()) {
      final v = prefs.getDouble('v:$key');
      if (v != null) _values[key] = v;
    }
    brickMass = prefs.getDouble('brickMass') ?? brickMass;
    brickVolume = prefs.getDouble('brickVolume') ?? brickVolume;
    landfillArea = prefs.getDouble('landfillArea') ?? landfillArea;
    landfillDepth = prefs.getDouble('landfillDepth') ?? landfillDepth;
    notifyListeners();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Bio Bricks'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restore_outlined),
            onPressed: () => _confirmReset(context),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _summaryCard(context, state),
            const SizedBox(height: 12),
            _compositionCard(context, state),
            const SizedBox(height: 12),
            _landfillCard(context, state),
            const SizedBox(height: 12),
            _processSteps(),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, AppState s) {
    final total = s.totalAvailableWaste;
    final bricks = s.bricksProducible;
    final diverted = s.totalDivertedMass;
    final areaReduced = s.areaReduced;
    final percent = s.percentLandfillReduced();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Real-time Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Total available waste (kg)', style: TextStyle(color: Colors.white70))),
            Text('${total.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Bricks producible (count)', style: TextStyle(color: Colors.white70))),
            Text('$bricks', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Total diverted mass (kg)', style: TextStyle(color: Colors.white70))),
            Text('${diverted.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Area reduced: ${areaReduced.toStringAsFixed(3)} m²')),
            const SizedBox(width: 8),
            Text('${percent.toStringAsFixed(2)} %'),
          ]),
        ]),
      ),
    );
  }

  Widget _compositionCard(BuildContext context, AppState s) {
    final entries = s.values.entries.toList();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Composition per brick (editable)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...entries.map((e) => _valueRow(context, e.key, e.value)).toList(),
          const SizedBox(height: 12),
          _chartCard(s),
        ]),
      ),
    );
  }

  Widget _valueRow(BuildContext context, String label, double value) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: 'Decrease',
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => state.updateValue(label, _round(value - _step(value))),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: TextEditingController(text: value.toStringAsFixed(_decimals(value))),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(isDense: true, filled: true, fillColor: Colors.white12),
            onSubmitted: (txt) {
              final v = double.tryParse(txt.replaceAll(',', '.')) ?? value;
              state.updateValue(label, _round(v));
            },
            onEditingComplete: () {
              // ensure value is saved
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => state.updateValue(label, _round(value + _step(value)))),
      ]),
    );
  }

  int _decimals(double v) => v % 1 == 0 ? 0 : 3;
  double _step(double v) => v < 1 ? 0.1 : (v < 10 ? 0.5 : 1.0);
  double _round(double v) => (v * 1000).round() / 1000.0;

  Widget _chartCard(AppState s) {
    final entries = s.values.entries.where((e) => e.value > 0).toList();
    final total = s.totalAvailableWaste;
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final percent = total > 0 ? (e.value / total) * 100.0 : 0.0;
      sections.add(PieChartSectionData(
        value: e.value,
        title: '${percent.toStringAsFixed(1)}%',
        radius: 48,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    if (sections.isEmpty) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('No data to chart'));
    }

    return SizedBox(
      height: 180,
      child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 28, sectionsSpace: 2)),
    );
  }

  Widget _landfillCard(BuildContext context, AppState s) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Landfill & conversion settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _settingRow(context, 'Brick mass (kg)', s.brickMass, (v) {
            s.brickMass = v > 0 ? v : s.brickMass;
            s.notifyListeners();
            s._save();
          }),
          const SizedBox(height: 8),
          _settingRow(context, 'Brick volume (m³)', s.brickVolume, (v) {
            s.brickVolume = v > 0 ? v : s.brickVolume;
            s.notifyListeners();
            s._save();
          }),
          const SizedBox(height: 8),
          _settingRow(context, 'Landfill area (m²)', s.landfillArea, (v) {
            s.landfillArea = v > 0 ? v : s.landfillArea;
            s.notifyListeners();
            s._save();
          }),
          const SizedBox(height: 8),
          _settingRow(context, 'Average landfill depth (m)', s.landfillDepth, (v) {
            s.landfillDepth = v > 0 ? v : s.landfillDepth;
            s.notifyListeners();
            s._save();
          }),
        ]),
      ),
    );
  }

  Widget _settingRow(BuildContext context, String label, double value, void Function(double) onChanged) {
    return Row(children: [
      Expanded(child: Text(label)),
      SizedBox(
        width: 110,
        child: TextField(
          controller: TextEditingController(text: value.toStringAsFixed(3)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(isDense: true, filled: true, fillColor: Colors.white12),
          onSubmitted: (txt) {
            final v = double.tryParse(txt.replaceAll(',', '.')) ?? value;
            onChanged(_round(v));
          },
        ),
      ),
    ]);
  }

  Widget _processSteps() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('Process steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('1. Dehumidifying — hot air removes moisture to prevent microbial growth.'),
          Text('2. Grinding — crushing and size reduction to form a uniform mix.'),
          Text('3. Molding — mixing with binders and compacting into molds.'),
          Text('4. Drying — controlled drying to set the bricks.'),
        ]),
      ),
    );
  }

  double _round(double v) => (v * 1000).round() / 1000.0;

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset values'),
        content: const Text('Reset all values to defaults?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final state = context.read<AppState>();
              state._values.clear();
              state._values.addAll({
                'Vegetable peels': 10.0,
                'Sawdust': 5.0,
                'Dry leaves': 4.0,
                'Plastic (shreds)': 2.0,
                'Straws / fibers': 1.0,
                'E-waste': 0.2,
                'Sand': 0.5,
                'Other': 0.3,
              });
              state.brickMass = 2.0;
              state.brickVolume = 0.002;
              state.landfillArea = 1000.0;
              state.landfillDepth = 2.0;
              state.notifyListeners();
              state._save();
              Navigator.of(context).pop();
            },
            child: const Text('Reset'),
          )
        ],
      ),
    );
  }
}
