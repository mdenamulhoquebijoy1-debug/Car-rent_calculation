import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'গাড়ির হিসাব',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF00695C),
            foregroundColor: Colors.white,
          ),
        ),
        home: const Home(),
      );
}

typedef M = Map<String, dynamic>;

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
double inc(M e) => e['type'] == 'out' || e['type'] == 'self' ? 0 : n0(e['amt']);
double ex(M e) => e['type'] == 'out' ? n0(e['amt']) : (e['type'] == 'trip' || e['type'] == 'self') ? n0(e['cost']) : 0;
double sIn(Iterable<M> l) => l.fold<double>(0, (s, e) => s + inc(e));
double sEx(Iterable<M> l) => l.fold<double>(0, (s, e) => s + ex(e));
double sDue(Iterable<M> l) => l.fold<double>(0, (s, e) => s + n0(e['due']));
double svcOf(Iterable<M> l) => sEx(l.where((e) => e['type'] == 'out' && svcCats.contains(e['cat'])));
List<M> ofMonth(Iterable<M> l, DateTime m) => l.where((e) => mk(DateTime.parse(e['date'])) == mk(m)).toList();

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
    checkUpdate();
  }

  Future<void> checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final res = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/mdenamulhoquebijoy1-debug/Car-rent_calculation/main/version.json'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final latest = data['version'] as String;
        if (_isNewer(latest, info.version)) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('নতুন আপডেট আছে'),
              content: Text(data['message'] ?? 'আপডেট ডাউনলোড করুন'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('পরে')),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    _downloadAndInstall(data['apk_url']);
                  },
                  child: const Text('ডাউনলোড'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.parse).toList();
    final c = current.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if ((l.length > i ? l[i] : 0) > (c.length > i ? c[i] : 0)) return true;
      if ((l.length > i ? l[i] : 0) < (c.length > i ? c[i] : 0)) return false;
    }
    return false;
  }

  Future<void> _downloadAndInstall(String url) async {
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/update.apk');
    final res = await http.get(Uri.parse(url));
    await file.writeAsBytes(res.bodyBytes);
    await OpenFile.open(file.path);
  }

  List<M> _l(dynamic s) => s == null ? [] : (s as List).map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> load() async {
    p = await SharedPreferences.getInstance();
    try {
      final a = p!.getString('entries'), r = p!.getString('rem'), d = p!.getString('drivers');
      items = _l(a == null ? null : jsonDecode(a));
      rem = _l(r == null ? null : jsonDecode(r));
      if (d != null) drivers = (jsonDecode(d) as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
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
      )) == true;

  List<String> get cars => {for (final e in items) e['car'] as String}.toList();

  List<M> get shown {
    final l = items.where((e) => car == allCars || e['car'] == car).toList();
    l.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return l;
  }

  Future<void> addEdit([M? old]) async {
    final result = await Navigator.push<M>(
      context,
      MaterialPageRoute(builder: (_) => AddEditPage(old: old, cars: cars, currentCar: car, drivers: drivers.keys.toList())),
    );
    if (result != null) {
      if (old != null) items.removeWhere((x) => x['id'] == old['id']);
      items.add(result);
      save();
    }
  }

  Future<void> editDriver([String? old]) async {
    final n = TextEditingController(text: old ?? '');
    final s = TextEditingController(text: old == null ? '' : fm(drivers[old] ?? 0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(old == null ? 'নতুন ড্রাইভার' : 'ড্রাইভার এডিট'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: n, decoration: const InputDecoration(labelText: 'নাম')),
          TextField(controller: s, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'মাসিক বেতন (৳)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(
            onPressed: () {
              final name = n.text.trim();
              if (name.isEmpty) return;
              if (old != null && old != name) {
                drivers.remove(old);
                for (final e in items) if (e['driver'] == old) e['driver'] = name;
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

  Widget monthNav() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left), style: IconButton.styleFrom(backgroundColor: Colors.teal.shade50)),
          const SizedBox(width: 16),
          Text('${_monthName(month.month)} ${month.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right), style: IconButton.styleFrom(backgroundColor: Colors.teal.shade50)),
        ]),
      );

  String _monthName(int m) => ['', 'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'][m];

  Widget sumCard(String title, double value, Color color, IconData icon) => Expanded(
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: color.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 13)),
              Text('৳${fm(value)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ]),
          ),
        ),
      );

  Future<void> addRem() async {
    final t = TextEditingController();
    DateTime d = DateTime.now().add(const Duration(days: 30));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
            title: const Text('রিমাইন্ডার যোগ'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: t, decoration: const InputDecoration(labelText: 'কীসের রিমাইন্ডার?')),
              ListTile(title: Text('তারিখ: ${fd(d)}'), trailing: const Icon(Icons.calendar_today), onTap: () async {
                final x = await showDatePicker(context: ctx, initialDate: d, firstDate: DateTime.now(), lastDate: DateTime(2100));
                if (x != null) set(() => d = x);
              }),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('যোগ')),
            ],
          )),
    );
    if (ok == true && t.text.trim().isNotEmpty) {
      rem.add({'id': DateTime.now().millisecondsSinceEpoch, 'title': t.text.trim(), 'date': d.toIso8601String()});
      save();
    }
  }

  Widget dash() {
    final m = ofMonth(shown, month);
    final i = sIn(m), o = sEx(m), pr = i - o;
    final today = DateTime.now();
    final rs = [...rem]..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return ListView(padding: const EdgeInsets.all(12), children: [
      monthNav(),
      Row(children: [
        sumCard('আয়', i, Colors.green, Icons.account_balance_wallet),
        const SizedBox(width: 8),
        sumCard('খরচ', o, Colors.red, Icons.receipt_long),
        const SizedBox(width: 8),
        sumCard(pr >= 0 ? 'লাভ' : 'লোকসান', pr.abs(), pr >= 0 ? Colors.teal : Colors.deepOrange, Icons.trending_up),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        const Expanded(child: Text('সাম্প্রতিক রিমাইন্ডার', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        TextButton(onPressed: addRem, child: const Text('যোগ')),
      ]),
      for (final r in rs.take(5))
        Builder(builder: (_) {
          final days = DateTime.parse(r['date']).difference(today).inDays;
          final expired = days < 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: expired ? Colors.red.shade50 : Colors.teal.shade50, child: Icon(Icons.notifications, color: expired ? Colors.red : Colors.teal)),
              title: Text(r['title']),
              subtitle: Text(expired ? 'মেয়াদ শেষ' : fd(DateTime.parse(r['date']))),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: expired ? Colors.orange.shade100 : Colors.green.shade100, borderRadius: BorderRadius.circular(20)),
                child: Text(expired ? 'বাকি' : 'সম্পন্ন', style: TextStyle(color: expired ? Colors.orange.shade800 : Colors.green.shade800, fontSize: 12)),
              ),
            ),
          );
        }),
      const SizedBox(height: 80),
    ]);
  }

  Widget listTab() {
    final l = shown;
    if (l.isEmpty) return const Center(child: Text('এখনও কোনো হিসাব নেই।\n+ বাটনে চাপুন।', textAlign: TextAlign.center));
    return ListView.builder(
      itemCount: l.length,
      itemBuilder: (c, i) {
        final e = l[i];
        final trip = e['type'] == 'trip';
        final self = e['type'] == 'self';
        final profit = trip ? (n0(e['amt']) - n0(e['cost'])) : 0.0;
        return ListTile(
          leading: Icon(trip ? Icons.route : (self ? Icons.directions_car : Icons.arrow_upward), color: trip ? Colors.indigo : (self ? Colors.orange : Colors.red)),
          title: Text(trip ? 'ট্রিপ  •  লাভ ৳${fm(profit)}' : self ? 'নিজে ব্যবহার  •  খরচ ৳${fm(n0(e['cost']))}' : '${e['cat']}  •  ৳${fm(n0(e['amt']))}'),
          subtitle: Text('${e['car']}  •  ${fd(DateTime.parse(e['date']))}'),
          onTap: () => addEdit(e),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
            if (await ask('মুছে ফেলবেন?')) { items.removeWhere((x) => x['id'] == e['id']); save(); }
          }),
        );
      },
    );
  }

  Widget drvTab() {
    final m = ofMonth(items, month);
    return ListView(children: [
      monthNav(),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: FilledButton.icon(onPressed: () => editDriver(), icon: const Icon(Icons.person_add), label: const Text('ড্রাইভার যোগ করুন'))),
      if (drivers.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('ড্রাইভার যোগ করুন')),
      for (final n in drivers.keys)
        Card(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(n, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.edit), onPressed: () => editDriver(n)),
              ]),
              Text('মাসিক বেতন: ৳${fm(drivers[n] ?? 0)}'),
              Text('এই মাসে ট্রিপ/ব্যবহার: ${m.where((e) => e['driver'] == n).length} টি'),
              Text('ট্রিপ থেকে দিয়েছি: ৳${fm(m.where((e) => e['driver'] == n).fold(0.0, (s, e) => s + n0(e['driver_pay'])))}'),
            ]),
          ),
        ),
      const SizedBox(height: 80),
    ]);
  }

  Widget reportTab() => const Center(child: Text('রিপোর্ট (আগের কোড ব্যবহার করো)'));

  Future<void> backup() async {
    await Clipboard.setData(ClipboardData(text: jsonEncode({'v': 4, 'entries': items, 'drivers': drivers, 'rem': rem})));
    msg('ব্যাকআপ কপি হয়েছে');
  }

  Future<void> restore() async {
    final t = (await Clipboard.getData('text/plain'))?.text;
    try {
      final j = jsonDecode(t ?? '');
      if (j is Map) {
        items = _l(j['entries']);
        rem = _l(j['rem']);
        drivers = ((j['drivers'] ?? {}) as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
      }
      save();
      msg('ব্যাকআপ ফেরত আনা হয়েছে');
    } catch (_) { msg('সঠিক ব্যাকআপ নয়'); }
  }

  @override
  Widget build(BuildContext context) {
    final opts = [allCars, ...cars];
    if (!opts.contains(car)) car = allCars;
    return Scaffold(
      appBar: AppBar(
        title: const Text('গাড়ির হিসাব'),
        actions: [
          DropdownButton<String>(value: car, underline: const SizedBox(), dropdownColor: Colors.teal.shade700, style: const TextStyle(color: Colors.white), items: opts.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => car = v!)),
          PopupMenuButton<String>(onSelected: (v) => v == 'b' ? backup() : restore(), itemBuilder: (c) => const [
            PopupMenuItem(value: 'b', child: Text('ব্যাকআপ কপি করুন')),
            PopupMenuItem(value: 'r', child: Text('ব্যাকআপ পেস্ট করে ফেরত আনুন')),
          ]),
        ],
      ),
      body: [dash(), listTab(), drvTab(), reportTab()][tab],
      floatingActionButton: tab <= 1 ? FloatingActionButton(onPressed: () => addEdit(), child: const Icon(Icons.add)) : null,
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'হোম'),
        NavigationDestination(icon: Icon(Icons.list_alt), label: 'হিসাব'),
        NavigationDestination(icon: Icon(Icons.person), label: 'ড্রাইভার'),
        NavigationDestination(icon: Icon(Icons.bar_chart), label: 'রিপোর্ট'),
      ]),
    );
  }
}

class AddEditPage extends StatefulWidget {
  final M? old;
  final List<String> cars;
  final String currentCar;
  final List<String> drivers;
  const AddEditPage({super.key, this.old, required this.cars, required this.currentCar, required this.drivers});
  @override
  State<AddEditPage> createState() => _AddEditPageState();
}

class _AddEditPageState extends State<AddEditPage> {
  late String t;
  late TextEditingController carC, amtC, costC, noteC, driverPayC;
  late String cat, drv;
  late DateTime d;

  @override
  void initState() {
    super.initState();
    final old = widget.old;
    t = (old?['type'] ?? 'out') as String;
    if (t == 'in') t = 'out';
    carC = TextEditingController(text: old?['car'] ?? (widget.currentCar != allCars ? widget.currentCar : (widget.cars.isNotEmpty ? widget.cars.first : 'আমার গাড়ি')));
    amtC = TextEditingController(text: old == null ? '' : fm(n0(old['amt'])));
    costC = TextEditingController(text: old == null || n0(old['cost']) == 0 ? '' : fm(n0(old['cost'])));
    noteC = TextEditingController(text: old?['note'] ?? '');
    driverPayC = TextEditingController(text: old == null || n0(old['driver_pay']) == 0 ? '' : fm(n0(old['driver_pay'])));
    cat = old?['cat'] ?? outCats.first;
    drv = old?['driver'] ?? noDrv;
    d = old == null ? DateTime.now() : DateTime.parse(old['date']);
  }

  @override
  void dispose() {
    carC.dispose(); amtC.dispose(); costC.dispose(); noteC.dispose(); driverPayC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.old == null ? 'নতুন হিসাব যোগ করুন' : 'হিসাব এডিট')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'trip', label: Text('ট্রিপ'), icon: Icon(Icons.route)),
              ButtonSegment(value: 'self', label: Text('নিজে ব্যবহার'), icon: Icon(Icons.directions_car)),
              ButtonSegment(value: 'out', label: Text('খরচ'), icon: Icon(Icons.arrow_upward)),
            ],
            selected: {t},
            onSelectionChanged: (v) => setState(() => t = v.first),
          ),
          const SizedBox(height: 20),
          TextField(controller: carC, decoration: const InputDecoration(labelText: 'গাড়ির নাম/নম্বর', border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_car))),
          const SizedBox(height: 12),
          TextField(controller: amtC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t == 'trip' ? 'ট্রিপের ভাড়া (৳)' : 'পরিমাণ (৳)', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.attach_money))),
          const SizedBox(height: 12),
          if (t == 'trip' || t == 'self') ...[
            TextField(controller: costC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'খরচ (তেল/টোল ইত্যাদি) (৳)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt))),
            const SizedBox(height: 12),
            TextField(controller: driverPayC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'ড্রাইভারকে দিয়েছি (৳)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
          ],
          if (t == 'out')
            DropdownButtonFormField<String>(value: cat, decoration: const InputDecoration(labelText: 'খরচের ধরন', border: OutlineInputBorder()), items: outCats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => cat = v!)),
          if (t == 'out') const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: drv, decoration: const InputDecoration(labelText: 'ড্রাইভার', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)), items: <String>{noDrv, ...widget.drivers, drv}.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => drv = v!)),
          const SizedBox(height: 12),
          TextField(controller: noteC, decoration: const InputDecoration(labelText: 'নোট (ঐচ্ছিক)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.note))),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero, title: Text('তারিখ: ${fd(d)}'), trailing: const Icon(Icons.calendar_today), onTap: () async {
            final x = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (x != null) setState(() => d = x);
          }),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(
            onPressed: () {
              final a = double.tryParse(amtC.text.trim());
              if (a == null || a <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক পরিমাণ দিন'))); return; }
              final e = <String, dynamic>{
                'id': widget.old?['id'] ?? DateTime.now().millisecondsSinceEpoch,
                'car': carC.text.trim().isEmpty ? 'আমার গাড়ি' : carC.text.trim(),
                'type': t,
                'cat': t == 'trip' ? 'ট্রিপ' : (t == 'self' ? 'নিজে ব্যবহার' : cat),
                'amt': a,
                'cost': (t == 'trip' || t == 'self') ? (double.tryParse(costC.text.trim()) ?? 0) : 0,
                'driver': drv == noDrv ? null : drv,
                'driver_pay': (t == 'trip' || t == 'self') ? (double.tryParse(driverPayC.text.trim()) ?? 0) : 0,
                'note': noteC.text.trim(),
                'date': d.toIso8601String(),
              };
              Navigator.pop(context, e);
            },
            icon: const Icon(Icons.save),
            label: const Text('সংরক্ষণ করুন'),
          )),
        ]),
      ),
    );
  }
}
