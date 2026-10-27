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

typedef M = Map<String, dynamic>;

const inCats = ['ভাড়া পেয়েছি', 'অন্যান্য আয়'];
const outCats = [
  'তেল/গ্যাস', 'সার্ভিস', 'মেরামত', 'টায়ার', 'ড্রাইভার বেতন', 'ড্রাইভার অগ্রিম',
  'পার্কিং/টোল', 'কাগজপত্র/ট্যাক্স', 'জরিমানা', 'অন্যান্য খরচ'
];
const svcCats = ['সার্ভিস', 'মেরামত', 'টায়ার'];
const allCars = 'সব গাড়ি';
const noDrv = 'ড্রাইভার নেই';

String fm(num n) => n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
String fd(DateTime d) => '${d.day}/${d.month}/${d.year}';
String mk(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
double n0(dynamic v) => (v as num?)?.toDouble() ?? 0;
double inc(M e) => e['type'] == 'out' ? 0 : n0(e['amt']);
double ex(M e) => e['type'] == 'out' ? n0(e['amt']) : e['type'] == 'trip' ? n0(e['cost']) : 0;
double sIn(Iterable<M> l) => l.fold<double>(0, (s, e) => s + inc(e));
double sEx(Iterable<M> l) => l.fold<double>(0, (s, e) => s + ex(e));
double sDue(Iterable<M> l) => l.fold<double>(0, (s, e) => s + n0(e['due']));
double svcOf(Iterable<M> l) =>
    sEx(l.where((e) => e['type'] == 'out' && svcCats.contains(e['cat'])));
List<M> ofMonth(Iterable<M> l, DateTime m) =>
    l.where((e) => mk(DateTime.parse(e['date'])) == mk(m)).toList();

Widget box(String t, double v, Color c) => Expanded(
      child: Column(children: [
        Text(t, style: const TextStyle(fontSize: 12)),
        Text('৳${fm(v)}',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c)),
      ]),
    );

Widget head(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)));

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<M> items = [];
  List<M> rem = [];
  Map<String, double> drivers = {};
  String car = allCars;
  int tab = 0;
  DateTime month = DateTime.now();
  SharedPreferences? p;

  @override
  void initState() {
    super.initState();
    load();
  }

  List<M> _l(dynamic s) => s == null
      ? []
      : (s as List).map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> load() async {
    p = await SharedPreferences.getInstance();
    try {
      final a = p!.getString('entries'), r = p!.getString('rem'), d = p!.getString('drivers');
      items = _l(a == null ? null : jsonDecode(a));
      rem = _l(r == null ? null : jsonDecode(r));
      if (d != null) {
        drivers = (jsonDecode(d) as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
      }
    } catch (_) {}
    setState(() {});
  }

  void save() {
    p?.setString('entries', jsonEncode(items));
    p?.setString('rem', jsonEncode(rem));
    p?.setString('drivers', jsonEncode(drivers));
    setState(() {});
  }

  void msg(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<bool> ask(String t) async =>
      (await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(title: Text(t), actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('হ্যাঁ')),
        ]),
      )) ==
      true;

  List<String> get cars => {for (final e in items) e['car'] as String}.toList();

  List<M> get shown {
    final l = items.where((e) => car == allCars || e['car'] == car).toList();
    l.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return l;
  }

  // ---------- entry form ----------
  Future<void> addEdit([M? old]) async {
    String t = (old?['type'] ?? 'out') as String;
    final carC = TextEditingController(
        text: old?['car'] ??
            (car != allCars ? car : (cars.isNotEmpty ? cars.first : 'আমার গাড়ি')));
    final amtC = TextEditingController(text: old == null ? '' : fm(n0(old['amt'])));
    final costC = TextEditingController(
        text: old == null || n0(old['cost']) == 0 ? '' : fm(n0(old['cost'])));
    final dueC = TextEditingController(
        text: old == null || n0(old['due']) == 0 ? '' : fm(n0(old['due'])));
    final noteC = TextEditingController(text: old?['note'] ?? '');
    String cat = old?['cat'] ?? outCats.first;
    String drv = old?['driver'] ?? noDrv;
    DateTime d = old == null ? DateTime.now() : DateTime.parse(old['date']);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final cats = t == 'in' ? inCats : outCats;
        if (t != 'trip' && !cats.contains(cat)) cat = cats.first;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'out', label: Text('খরচ')),
                  ButtonSegment(value: 'in', label: Text('আয়')),
                  ButtonSegment(value: 'trip', label: Text('ট্রিপ')),
                ],
                selected: {t},
                onSelectionChanged: (v) => set(() => t = v.first),
              ),
              TextField(
                  controller: carC,
                  decoration: const InputDecoration(labelText: 'গাড়ির নাম/নম্বর')),
              if (t != 'trip')
                DropdownButtonFormField<String>(
                  value: cat,
                  decoration: const InputDecoration(labelText: 'ধরন'),
                  items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => set(() => cat = v!),
                ),
              TextField(
                  controller: amtC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: t == 'trip' ? 'ট্রিপের ভাড়া/আয় (৳)' : 'টাকার পরিমাণ (৳)')),
              if (t == 'trip')
                TextField(
                    controller: costC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'এই ট্রিপের খরচ (তেল/টোল/পার্কিং) (৳)')),
              if (t != 'out')
                TextField(
                    controller: dueC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'বাকি আছে (থাকলে) (৳)')),
              DropdownButtonFormField<String>(
                value: drv,
                decoration: const InputDecoration(labelText: 'ড্রাইভার'),
                items: <String>{noDrv, ...drivers.keys, drv}
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => set(() => drv = v!),
              ),
              TextField(
                  controller: noteC,
                  decoration: const InputDecoration(labelText: 'নোট/রুট (ঐচ্ছিক)')),
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
                    final e = <String, dynamic>{
                      'id': old?['id'] ?? DateTime.now().millisecondsSinceEpoch,
                      'car': carC.text.trim().isEmpty ? 'আমার গাড়ি' : carC.text.trim(),
                      'type': t,
                      'cat': t == 'trip' ? 'ট্রিপ' : cat,
                      'amt': a,
                      'cost': t == 'trip' ? (double.tryParse(costC.text.trim()) ?? 0) : 0,
                      'due': t == 'out' ? 0 : (double.tryParse(dueC.text.trim()) ?? 0),
                      'driver': drv == noDrv ? null : drv,
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

  // ---------- drivers ----------
  Future<void> editDriver([String? old]) async {
    final n = TextEditingController(text: old ?? '');
    final s = TextEditingController(text: old == null ? '' : fm(drivers[old] ?? 0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(old == null ? 'নতুন ড্রাইভার' : 'ড্রাইভার এডিট'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'নাম')),
          TextField(
              controller: s,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'মাসিক বেতন (৳)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(
            onPressed: () {
              final name = n.text.trim();
              if (name.isEmpty) return;
              if (old != null && old != name) {
                drivers.remove(old);
                for (final e in items) {
                  if (e['driver'] == old) e['driver'] = name;
                }
              }
              drivers[name] = double.tryParse(s.text.trim()) ?? 0;
              save();
              Navigator.pop(ctx);
            },
            child: const Text('সংরক্ষণ'),
          ),
        ],
      ),
    );
  }

  Widget drvCard(String n, List<M> m) {
    final mine = m.where((e) => e['driver'] == n).toList();
    final sal = drivers[n] ?? 0;
    final paid = sEx(mine.where((e) => e['cat'] == 'ড্রাইভার বেতন'));
    final adv = sEx(mine.where((e) => e['cat'] == 'ড্রাইভার অগ্রিম'));
    final trips = mine.where((e) => e['type'] == 'trip').toList();
    final bal = sal - paid - adv;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(n, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.edit), onPressed: () => editDriver(n)),
            IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await ask('$n কে তালিকা থেকে মুছবেন? (পুরোনো হিসাব থাকবে)')) {
                    drivers.remove(n);
                    save();
                  }
                }),
          ]),
          Text('মাসিক বেতন: ৳${fm(sal)}'),
          Text('এই মাসে ট্রিপ: ${trips.length} টি  •  ভাড়া আদায়: ৳${fm(sIn(trips))}'),
          Text('বেতন দিয়েছি: ৳${fm(paid)}  •  অগ্রিম: ৳${fm(adv)}'),
          const SizedBox(height: 4),
          Text(bal >= 0 ? 'বাকি বেতন: ৳${fm(bal)}' : 'বেশি দেওয়া হয়েছে: ৳${fm(-bal)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: bal > 0 ? Colors.deepOrange : Colors.teal)),
        ]),
      ),
    );
  }

  Widget drvTab() {
    final m = ofMonth(items, month);
    return ListView(children: [
      monthNav(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: FilledButton.icon(
            onPressed: () => editDriver(),
            icon: const Icon(Icons.person_add),
            label: const Text('ড্রাইভার যোগ করুন')),
      ),
      if (drivers.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Text('ড্রাইভার যোগ করলে তার বেতন, অগ্রিম ও ট্রিপের হিসাব এখানে দেখা যাবে।',
                textAlign: TextAlign.center)),
      for (final n in drivers.keys) drvCard(n, m),
    ]);
  }

  // ---------- reminders ----------
  Future<void> addRem() async {
    final t = TextEditingController();
    DateTime d = DateTime.now().add(const Duration(days: 30));
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('নতুন রিমাইন্ডার'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: t,
                decoration: const InputDecoration(
                    labelText: 'কী? (ফিটনেস, ইনস্যুরেন্স, মবিল চেঞ্জ...)')),
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
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            TextButton(
              onPressed: () {
                if (t.text.trim().isEmpty) return;
                rem.add({
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'title': t.text.trim(),
                  'date': d.toIso8601String()
                });
                save();
                Navigator.pop(ctx);
              },
              child: const Text('সংরক্ষণ'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- common widgets ----------
  Widget monthNav() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => month = DateTime(month.year, month.month - 1))),
        Text(mk(month), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => month = DateTime(month.year, month.month + 1))),
      ]);

  Widget sumCard(String title, List<M> l, {String? extra}) {
    final i = sIn(l), o = sEx(l), pr = i - o;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(height: 6),
          Row(children: [
            box('আয়', i, Colors.green),
            box('খরচ', o, Colors.red),
            box(pr >= 0 ? 'লাভ' : 'লোকসান', pr.abs(), pr >= 0 ? Colors.teal : Colors.deepOrange),
          ]),
          if (extra != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(extra, style: const TextStyle(fontSize: 12))),
        ]),
      ),
    );
  }

  // ---------- tabs ----------
  Widget dash() {
    final l = shown, m = ofMonth(l, month);
    final trips = m.where((e) => e['type'] == 'trip').length;
    final t0 = DateTime.now();
    final today = DateTime(t0.year, t0.month, t0.day);
    final rs = [...rem]..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return ListView(children: [
      monthNav(),
      sumCard('এই মাসের হিসাব', m,
          extra: 'সার্ভিস/মেরামত/টায়ার খরচ: ৳${fm(svcOf(m))}   •   ট্রিপ: $trips টি'),
      sumCard('সর্বমোট (শুরু থেকে এখন পর্যন্ত)', l,
          extra: 'মোট বাকি পাওনা: ৳${fm(sDue(l))}'),
      Row(children: [
        Expanded(child: head('রিমাইন্ডার (কাগজপত্র/সার্ভিস)')),
        TextButton.icon(onPressed: addRem, icon: const Icon(Icons.add), label: const Text('যোগ')),
      ]),
      if (rs.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('ফিটনেস, ট্যাক্স টোকেন, ইনস্যুরেন্স বা সার্ভিসের তারিখ যোগ করে রাখুন।')),
      for (final r in rs)
        Builder(builder: (c) {
          final days = DateTime.parse(r['date']).difference(today).inDays;
          return ListTile(
            leading: Icon(Icons.notifications_active,
                color: days <= 7 ? Colors.red : Colors.teal),
            title: Text(r['title']),
            subtitle: Text(days < 0
                ? 'মেয়াদ শেষ ${-days} দিন আগে (${fd(DateTime.parse(r['date']))})'
                : '$days দিন বাকি (${fd(DateTime.parse(r['date']))})'),
            trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await ask('রিমাইন্ডার মুছবেন?')) {
                    rem.removeWhere((x) => x['id'] == r['id']);
                    save();
                  }
                }),
          );
        }),
      const SizedBox(height: 80),
    ]);
  }

  Widget listTab() {
    final l = shown;
    if (l.isEmpty) {
      return const Center(
          child: Text('এখনও কোনো হিসাব নেই।\nনিচের + বাটনে চাপুন।', textAlign: TextAlign.center));
    }
    return ListView.builder(
      itemCount: l.length,
      itemBuilder: (c, i) {
        final e = l[i];
        final trip = e['type'] == 'trip', isIn = e['type'] == 'in';
        final d = DateTime.parse(e['date']);
        final parts = <String>[
          '${e['car']}',
          fd(d),
          if (e['driver'] != null) 'ড্রাইভার: ${e['driver']}',
          if (trip) 'ভাড়া ৳${fm(n0(e['amt']))} − খরচ ৳${fm(n0(e['cost']))}',
          if (n0(e['due']) > 0) 'বাকি ৳${fm(n0(e['due']))}',
          if ((e['note'] ?? '') != '') '${e['note']}',
        ];
        return ListTile(
          leading: Icon(trip ? Icons.route : (isIn ? Icons.arrow_downward : Icons.arrow_upward),
              color: trip ? Colors.indigo : (isIn ? Colors.green : Colors.red)),
          title: Text(trip
              ? 'ট্রিপ  •  লাভ ৳${fm(n0(e['amt']) - n0(e['cost']))}'
              : '${e['cat']}  •  ৳${fm(n0(e['amt']))}'),
          subtitle: Text(parts.join('  •  ')),
          onTap: () => addEdit(e),
          trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await ask('মুছে ফেলবেন?')) {
                  items.removeWhere((x) => x['id'] == e['id']);
                  save();
                }
              }),
        );
      },
    );
  }

  Widget reportTab() {
    final l = shown;
    final months = <String, List<M>>{};
    for (final e in l) {
      months.putIfAbsent(mk(DateTime.parse(e['date'])), () => []).add(e);
    }
    final keys = months.keys.toList()..sort((a, b) => b.compareTo(a));
    final cats = <String, double>{};
    for (final e in l) {
      if (e['type'] == 'out') {
        cats[e['cat']] = (cats[e['cat']] ?? 0) + n0(e['amt']);
      } else if (e['type'] == 'trip' && n0(e['cost']) > 0) {
        cats['ট্রিপ খরচ'] = (cats['ট্রিপ খরচ'] ?? 0) + n0(e['cost']);
      }
    }
    final cl = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final trips = l.where((e) => e['type'] == 'trip').toList();
    final tp = sIn(trips) - sEx(trips);
    return ListView(children: [
      sumCard('সর্বমোট লাভ/লোকসান', l,
          extra: trips.isEmpty
              ? null
              : 'মোট ট্রিপ ${trips.length} টি  •  প্রতি ট্রিপে গড় লাভ ৳${fm(tp / trips.length)}'),
      head('মাসভিত্তিক হিসাব'),
      for (final k in keys)
        Builder(builder: (c) {
          final mm = months[k]!;
          final pr = sIn(mm) - sEx(mm);
          return ListTile(
            title: Text(k),
            isThreeLine: true,
            subtitle: Text(
                'আয় ৳${fm(sIn(mm))}  •  খরচ ৳${fm(sEx(mm))}\nসার্ভিস/মেরামত/টায়ার ৳${fm(svcOf(mm))}'),
            trailing: Text('${pr >= 0 ? 'লাভ' : 'লোকসান'}\n৳${fm(pr.abs())}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pr >= 0 ? Colors.teal : Colors.deepOrange)),
          );
        }),
      head('কোন খাতে কত খরচ'),
      for (final c in cl)
        ListTile(dense: true, title: Text(c.key), trailing: Text('৳${fm(c.value)}')),
      const SizedBox(height: 40),
    ]);
  }

  // ---------- backup ----------
  Future<void> backup() async {
    await Clipboard.setData(ClipboardData(
        text: jsonEncode({'v': 2, 'entries': items, 'drivers': drivers, 'rem': rem})));
    msg('ব্যাকআপ কপি হয়েছে। WhatsApp/Notes-এ পেস্ট করে রাখুন।');
  }

  Future<void> restore() async {
    final t = (await Clipboard.getData('text/plain'))?.text;
    try {
      final j = jsonDecode(t ?? '');
      if (j is List) {
        items = _l(j);
      } else if (j is Map) {
        items = _l(j['entries']);
        rem = _l(j['rem']);
        drivers = ((j['drivers'] ?? {}) as Map)
            .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
      } else {
        throw 'x';
      }
      save();
      msg('ব্যাকআপ ফেরত আনা হয়েছে');
    } catch (_) {
      msg('কপি করা লেখাটি সঠিক ব্যাকআপ নয়');
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = [allCars, ...cars];
    if (!opts.contains(car)) car = allCars;
    final bodies = [dash(), listTab(), drvTab(), reportTab()];
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
      body: bodies[tab],
      floatingActionButton: tab <= 1
          ? FloatingActionButton(onPressed: () => addEdit(), child: const Icon(Icons.add))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'হোম'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'হিসাব'),
          NavigationDestination(icon: Icon(Icons.person), label: 'ড্রাইভার'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'রিপোর্ট'),
        ],
      ),
    );
  }
}
