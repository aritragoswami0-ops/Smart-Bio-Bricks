import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const SmartBioBricksApp());
}

class SmartBioBricksApp extends StatelessWidget {
  const SmartBioBricksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Bio Bricks',
        theme: ThemeData.dark().copyWith(
          textTheme: GoogleFonts.poppinsTextTheme(),
          scaffoldBackgroundColor: const Color(0xFF001F1F),
          primaryColor: Colors.teal,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  // stored as kg
  final Map<String, double> _values = {
    'Vegetable peels': 8.0,
    'Sawdust': 5.0,
    'Dry leaves': 4.0,
    'Plastic shreds': 2.0,
    'Straws / fibers': 1.0,
    'E-waste': 0.2,
    'Sand': 0.5,
    'Other': 0.3,
  };

  // brick settings
  double brickMass = 2.0; // kg per brick
  double brickVolume = 0.002; // m^3
  double landfillArea = 1000.0; // m^2
  double landfillDepth = 2.0; // m

  // getters
  Map<String, double> get values => Map.from(_values);

  double totalWaste() {
    return _values.values.fold(0.0, (a, b) => a + b);
  }

  int bricksCount() {
    final tw = totalWaste();
    if (brickMass <= 0) return 0;
    return (tw ~/ brickMass).toInt();
  }

  double volumeDiverted() => bricksCount() * brickVolume;

  double areaReduced() {
    if (landfillDepth <= 0) return 0.0;
    return volumeDiverted() / landfillDepth;
  }

  double percentReduced() {
    if (landfillArea <= 0) return 0.0;
    return (areaReduced() / landfillArea) * 100.0;
  }

  // update one waste type
  void updateValue(String key, double newVal) {
    if (!_values.containsKey(key)) return;
    _values[key] = newVal < 0 ? 0.0 : newVal;
    notifyListeners();
  }

  // load JSON object (map of keys to numbers)
  Future<void> loadFromJsonAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    // try to map expected keys and update the ones we support
    // Accept keys in various formats (underscores or spaces)
    for (final k in decoded.keys) {
      final value = decoded[k];
      if (value == null) continue;
      final normalizedKey = k.toString().toLowerCase().replaceAll('_', ' ');
      // try to find a matching key in _values
      for (final label in _values.keys) {
        if (label.toLowerCase().contains(normalizedKey) ||
            normalizedKey.contains(label.toLowerCase().split(' ').first)) {
          // convert to double safely
          final v = (value is num) ? value.toDouble() : double.tryParse(value.toString());
          if (v != null) {
            _values[label] = v;
          }
        }
      }
    }
    notifyListeners();
  }

  // replace all values (useful when loading CSV/JSON externally)
  void setAll(Map<String, double> newValues) {
    for (final k in newValues.keys) {
      if (_values.containsKey(k)) {
        _values[k] = newValues[k]!;
      }
    }
    notifyListeners();
  }

  // utility to return ordered entries for charts
  List<MapEntry<String, double>> orderedEntries() {
    return _values.entries.toList();
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
        backgroundColor: Colors.teal.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Load sample data',
            onPressed: () async {
              await state.loadFromJsonAsset('assets/data/sample_data.json');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample data loaded')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to defaults',
            onPressed: () {
              // reset by reloading the hardcoded defaults:
              state.setAll({
                'Vegetable peels': 8.0,
                'Sawdust': 5.0,
                'Dry leaves': 4.0,
                'Plastic shreds': 2.0,
                'Straws / fibers': 1.0,
                'E-waste': 0.2,
                'Sand': 0.5,
                'Other': 0.3,
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Realtime Analytics'),
              _infoRow('Total available waste (kg)', '${state.totalWaste().toStringAsFixed(2)} kg'),
              _infoRow('Bricks producible (count)', '${state.bricksCount()}'),
              _infoRow('Volume diverted (m³)', '${state.volumeDiverted().toStringAsFixed(4)}'),
              const SizedBox(height: 12),
              _sectionTitle('Composition (tap to edit)'),
              const SizedBox(height: 8),
              _chartAndList(),
              const SizedBox(height: 16),
              _sectionTitle('Landfill reduction'),
              _infoRow('Area reduced (m²)', '${state.areaReduced().toStringAsFixed(3)}'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: LinearProgressIndicator(
                  value: (state.percentReduced() / 100).clamp(0.0, 1.0),
                  minHeight: 12,
                ),
              ),
              Text('${state.percentReduced().toStringAsFixed(2)}% of landfill area reduced', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              _sectionTitle('Brick & Landfill settings'),
              _settingsCard(context),
              const SizedBox(height: 30),
              _sectionTitle('Process steps'),
              _processStep(1, 'Dehumidifying — removes moisture'),
              _processStep(2, 'Grinding — uniform fine mix'),
              _processStep(3, 'Molding — compact shaping'),
              _processStep(4, 'Drying — set and harden bricks'),
              const SizedBox(height: 40),
            ])),
      ),
    );
  }

  Widget _chartAndList() {
    return Consumer<AppState>(builder: (context, state, _) {
      final entries = state.orderedEntries();
      final total = state.totalWaste();
      // prepare pie sections (limit to top 6 to avoid clutter)
      final colors = [
        Colors.greenAccent,
        Colors.orangeAccent,
        Colors.blueAccent,
        Colors.pinkAccent,
        Colors.yellowAccent,
        Colors.cyanAccent,
        Colors.limeAccent,
      ];

      final nonZero = entries.where((e) => e.value > 0).toList();
      final sections = <PieChartSectionData>[];
      for (var i = 0; i < nonZero.length; i++) {
        final e = nonZero[i];
        final value = e.value;
        final percent = total > 0 ? (value / total) * 100 : 0.0;
        sections.add(PieChartSectionData(
          color: colors[i % colors.length],
          value: value,
          title: '${percent.toStringAsFixed(0)}%',
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
          radius: 50,
        ));
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 26,
                ),
                swapAnimationDuration: const Duration(milliseconds: 300),
              ),
            ),
            const SizedBox(height: 8),
            // editable list
            Column(
              children: entries.map((e) {
                return _editableValueRow(e.key, e.value);
              }).toList(),
            )
          ],
        ),
      );
    });
  }

  Widget _editableValueRow(String label, double value) {
    return Consumer<AppState>(builder: (context, state, _) {
      final controller = TextEditingController(text: value.toString());
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (s) {
                  final v = double.tryParse(s.trim());
                  if (v != null) {
                    state.updateValue(label, v);
                  } else {
                    // ignore invalid input
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid number')));
                  }
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _settingsCard(BuildContext context) {
    final state = context.read<AppState>();
    final brickMassController = TextEditingController(text: state.brickMass.toString());
    final brickVolController = TextEditingController(text: state.brickVolume.toString());
    final areaController = TextEditingController(text: state.landfillArea.toString());
    final depthController = TextEditingController(text: state.landfillDepth.toString());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Row(children: [
          Expanded(child: _smallField('Brick mass (kg)', brickMassController, (v) {
            final d = double.tryParse(v);
            if (d != null) state.brickMass = d;
            state.notifyListeners();
          })),
          const SizedBox(width: 8),
          Expanded(child: _smallField('Brick volume (m³)', brickVolController, (v) {
            final d = double.tryParse(v);
            if (d != null) state.brickVolume = d;
            state.notifyListeners();
          })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _smallField('Landfill area (m²)', areaController, (v) {
            final d = double.tryParse(v);
            if (d != null) state.landfillArea = d;
            state.notifyListeners();
          })),
          const SizedBox(width: 8),
          Expanded(child: _smallField('Landfill depth (m)', depthController, (v) {
            final d = double.tryParse(v);
            if (d != null) state.landfillDepth = d;
            state.notifyListeners();
          })),
        ]),
      ]),
    );
  }

  Widget _smallField(String label, TextEditingController controller, void Function(String) onSubmitted) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
        style: const TextStyle(color: Colors.white),
        onSubmitted: onSubmitted,
      ),
    ]);
  }

  Widget _infoRow(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _processStep(int n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        CircleAvatar(radius: 14, backgroundColor: Colors.tealAccent, child: Text('$n', style: const TextStyle(color: Colors.black))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
      ]),
    );
  }
}
