import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'গাড়ির হিসাব',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const Home(),
      );
}

const inCats = ['ভাড়া পেয়েছি', 'অন্যান্য আয়'];
const outCats = [
  'তেল/গ্যাস', 'মেরামত', 'সার্ভিস', 'টায়ার', 'ড্রাইভার বেতন',
  'পার্কিং/টোল', 'কাগজপত্র/ট্যাক্স', 'জরিমানা', 'অন্যান্য খরচ'
];
const allCars = 'সব গাড়ি';

String fm(num n) => n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
String fd(DateTime d) => '${d.day}/${d.month}/${d.year}';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> items = [];
  String car = allCars;
  int tab = 0;
  SharedPreferences? p;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    p = await SharedPreferences.getInstance();
    final s = p!.getString('entries');
    if (s != null) {
      items = (jsonDecode(s) as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    setState(() {});
  }

  void save() {
    p?.setString('entries', jsonEncode(items));
    setState(() {});
  }

  List<String> get cars => {for (final e in items) e['car'] as String}.toList();

  List<Map<String, dynamic>> get shown {
    final l = items.where((e) => car == allCars || e['car'] == car).toList();
    l.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return l;
  }

  double sum(List<Map<String, dynamic>> l, String type) => l
      .where((e) => e['type'] == type)
      .fold(0.0, (s, e) => s + (e['amt'] as num));

  Future<void> addEdit([Map<String, dynamic>? old]) async {
    bool isIn = old?['type'] == 'in';
    final carC = TextEditingController(
        text: old?['car'] ??
            (car != allCars ? car : (cars.isNotEmpty ? cars.first : 'আমার গাড়ি')));
    final amtC = TextEditingController(text: old == null ? '' : fm(old['amt']));
    final noteC = TextEditingController(text: old?['note'] ?? '');
    String cat = old?['cat'] ?? outCats.first;
    DateTime d = old == null ? DateTime.now() : DateTime.parse(old['date']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final cats = isIn ? inCats : outCats;
        if (!cats.contains(cat)) cat = cats.first;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('খরচ')),
                  ButtonSegment(value: true, label: Text('আয়')),
                ],
                selected: {isIn},
                onSelectionChanged: (v) => set(() => isIn = v.first),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: carC,
                  decoration: const InputDecoration(labelText: 'গাড়ির নাম/নম্বর')),
              DropdownButtonFormField<String>(
                value: cat,
                decoration: const InputDecoration(labelText: 'ধরন'),
                items: cats
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => set(() => cat = v!),
              ),
              TextField(
                  controller: amtC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'টাকার পরিমাণ')),
              TextField(
                  controller: noteC,
                  decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('তারিখ: ${fd(d)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final x = await showDatePicker(
                      context: ctx,
                      initialDate: d,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (x != null) set(() => d = x);
                },
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final a = double.tryParse(amtC.text.trim());
                    if (a == null || a <= 0) return;
                    final e = {
                      'id': old?['id'] ?? DateTime.now().millisecondsSinceEpoch,
                      'car': carC.text.trim().isEmpty ? 'আমার গাড়ি' : carC.text.trim(),
                      'type': isIn ? 'in' : 'out',
                      'cat': cat,
                      'amt': a,
                      'note': noteC.text.trim(),
                      'date': d.toIso8601String(),
                    };
                    if (old != null) items.removeWhere((x) => x['id'] == old['id']);
                    items.add(e);
                    save();
                    Navigator.pop(ctx);
                  },
                  child: const Text('সংরক্ষণ করুন'),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> del(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('মুছে ফেলবেন?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('হ্যাঁ')),
        ],
      ),
    );
    if (ok == true) {
      items.removeWhere((x) => x['id'] == e['id']);
      save();
    }
  }

  Future<void> backup() async {
    await Clipboard.setData(ClipboardData(text: jsonEncode(items)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ব্যাকআপ কপি হয়েছে। কোথাও (যেমন WhatsApp/Notes) পেস্ট করে রাখুন।')));
    }
  }

  Future<void> restore() async {
    final t = (await Clipboard.getData('text/plain'))?.text;
    try {
      final l = (jsonDecode(t ?? '') as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      items = l;
      save();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ব্যাকআপ ফেরত আনা হয়েছে')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('কপি করা লেখাটি সঠিক ব্যাকআপ নয়')));
      }
    }
  }

  Widget summary(List<Map<String, dynamic>> l) {
    final i = sum(l, 'in'), o = sum(l, 'out'), pr = i - o;
    Widget box(String t, double v, Color c) => Expanded(
          child: Column(children: [
            Text(t),
            Text('৳${fm(v)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
          ]),
        );
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          box('আয়', i, Colors.green),
          box('খরচ', o, Colors.red),
          box(pr >= 0 ? 'লাভ' : 'লোকসান', pr.abs(), pr >= 0 ? Colors.teal : Colors.deepOrange),
        ]),
      ),
    );
  }

  Widget listTab() {
    final l = shown;
    return Column(children: [
      summary(l),
      Expanded(
        child: l.isEmpty
            ? const Center(child: Text('এখনও কোনো হিসাব নেই।\nনিচের + বাটনে চাপুন।', textAlign: TextAlign.center))
            : ListView.builder(
                itemCount: l.length,
                itemBuilder: (c, i) {
                  final e = l[i];
                  final inc = e['type'] == 'in';
                  final d = DateTime.parse(e['date']);
                  return ListTile(
                    leading: Icon(inc ? Icons.arrow_downward : Icons.arrow_upward,
                        color: inc ? Colors.green : Colors.red),
                    title: Text('${e['cat']}  •  ৳${fm(e['amt'])}'),
                    subtitle: Text(
                        '${e['car']}  •  ${fd(d)}${(e['note'] as String).isEmpty ? '' : '\n${e['note']}'}'),
                    isThreeLine: (e['note'] as String).isNotEmpty,
                    onTap: () => addEdit(e),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline), onPressed: () => del(e)),
                  );
                }),
      ),
    ]);
  }

  Widget reportTab() {
    final l = shown;
    final months = <String, List<Map<String, dynamic>>>{};
    for (final e in l) {
      final d = DateTime.parse(e['date']);
      months.putIfAbsent('${d.year}-${d.month.toString().padLeft(2, '0')}', () => []).add(e);
    }
    final keys = months.keys.toList()..sort((a, b) => b.compareTo(a));
    final cats = <String, double>{};
    for (final e in l.where((e) => e['type'] == 'out')) {
      cats[e['cat']] = (cats[e['cat']] ?? 0) + (e['amt'] as num);
    }
    final catList = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ListView(children: [
      summary(l),
      const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('মাসভিত্তিক', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final k in keys)
        ListTile(
          title: Text(k),
          subtitle: Text(
              'আয় ৳${fm(sum(months[k]!, 'in'))}  •  খরচ ৳${fm(sum(months[k]!, 'out'))}'),
          trailing: Text('৳${fm(sum(months[k]!, 'in') - sum(months[k]!, 'out'))}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('কোন খাতে কত খরচ', style: TextStyle(fontWeight: FontWeight.bold))),
      for (final c in catList)
        ListTile(dense: true, title: Text(c.key), trailing: Text('৳${fm(c.value)}')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final opts = [allCars, ...cars];
    if (!opts.contains(car)) car = allCars;
    return Scaffold(
      appBar: AppBar(
        title: const Text('গাড়ির হিসাব'),
        actions: [
          DropdownButton<String>(
            value: car,
            underline: const SizedBox(),
            items: opts.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => car = v!),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'b' ? backup() : restore(),
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'b', child: Text('ব্যাকআপ কপি করুন')),
              PopupMenuItem(value: 'r', child: Text('ব্যাকআপ পেস্ট করে ফেরত আনুন')),
            ],
          ),
        ],
      ),
      body: tab == 0 ? listTab() : reportTab(),
      floatingActionButton:
          FloatingActionButton(onPressed: () => addEdit(), child: const Icon(Icons.add)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'হিসাব'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'রিপোর্ট'),
        ],
      ),
    );
  }
}
