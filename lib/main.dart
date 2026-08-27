import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('bn_BD');
  final storage = LocalStorageService();
  final classes = await storage.loadClasses();
  final notifications = NotificationService();
  await notifications.initialize();
  runApp(AppRoot(
    storage: storage,
    notifications: notifications,
    initialClasses: classes,
  ));
}

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.storage,
    required this.notifications,
    required this.initialClasses,
  });

  final LocalStorageService storage;
  final NotificationService notifications;
  final List<TuitionClass> initialClasses;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final ScheduleController controller;

  @override
  void initState() {
    super.initState();
    controller = ScheduleController(
      storage: widget.storage,
      notifications: widget.notifications,
      classes: widget.initialClasses,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScheduleScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TutorFlow',
        theme: AppTheme.light(),
        home: const MainShell(),
      ),
    );
  }
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      secondary: const Color(0xFF0F9D8A),
      tertiary: const Color(0xFFF2B84B),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      fontFamily: 'sans',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF28324A)),
        bodyMedium: TextStyle(color: Color(0xFF526079)),
        titleLarge: TextStyle(
          color: Color(0xFF222B45),
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: Color(0xFF222B45),
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFFFFFFFF),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEFF3F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(width: 2, color: scheme.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

enum ClassStatus { upcoming, inProgress, completed, cancelled }

enum RecurrenceType { oneTime, weekly }

extension ClassStatusX on ClassStatus {
  String get value => name;

  String get label {
    switch (this) {
      case ClassStatus.upcoming:
        return 'আসন্ন';
      case ClassStatus.inProgress:
        return 'চলমান';
      case ClassStatus.completed:
        return 'সম্পন্ন';
      case ClassStatus.cancelled:
        return 'বাতিল';
    }
  }

  IconData get icon {
    switch (this) {
      case ClassStatus.upcoming:
        return Icons.schedule_rounded;
      case ClassStatus.inProgress:
        return Icons.play_circle_outline_rounded;
      case ClassStatus.completed:
        return Icons.check_circle_rounded;
      case ClassStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Color color(ColorScheme scheme) {
    switch (this) {
      case ClassStatus.upcoming:
        return scheme.primary;
      case ClassStatus.inProgress:
        return scheme.tertiary;
      case ClassStatus.completed:
        return const Color(0xFF16866F);
      case ClassStatus.cancelled:
        return const Color(0xFFD15C62);
    }
  }

  static ClassStatus from(String? value) => ClassStatus.values.firstWhere(
        (item) => item.name == value,
        orElse: () => ClassStatus.upcoming,
      );
}

extension RecurrenceTypeX on RecurrenceType {
  String get value => name;

  String get label =>
      this == RecurrenceType.weekly ? 'সাপ্তাহিক' : 'একবার';

  static RecurrenceType from(String? value) => RecurrenceType.values.firstWhere(
        (item) => item.name == value,
        orElse: () => RecurrenceType.oneTime,
      );
}

class TuitionClass {
  const TuitionClass({
    required this.id,
    required this.batchName,
    required this.subject,
    required this.studentName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.location = '',
    this.notes = '',
    this.homework = '',
    this.colorValue = 0xFF4F46E5,
    this.recurrenceType = RecurrenceType.oneTime,
    this.recurrenceWeekdays = const [],
    this.status = ClassStatus.upcoming,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String batchName;
  final String subject;
  final String studentName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String location;
  final String notes;
  final String homework;
  final int colorValue;
  final RecurrenceType recurrenceType;
  final List<int> recurrenceWeekdays;
  final ClassStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get startsAt => DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );

  DateTime get endsAt => DateTime(
        date.year,
        date.month,
        date.day,
        endTime.hour,
        endTime.minute,
      );

  bool appearsOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final source = DateTime(date.year, date.month, date.day);
    if (recurrenceType == RecurrenceType.oneTime) return target == source;
    return !target.isBefore(source) && recurrenceWeekdays.contains(target.weekday);
  }

  TuitionClass occurrenceFor(DateTime day) => TuitionClass(
        id: '$id-${day.year}-${day.month}-${day.day}',
        batchName: batchName,
        subject: subject,
        studentName: studentName,
        date: day,
        startTime: startTime,
        endTime: endTime,
        location: location,
        notes: notes,
        homework: homework,
        colorValue: colorValue,
        recurrenceType: recurrenceType,
        recurrenceWeekdays: recurrenceWeekdays,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  TuitionClass copyWith({
    ClassStatus? status,
    DateTime? date,
    String? batchName,
    String? subject,
    String? studentName,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? location,
    String? notes,
    String? homework,
    int? colorValue,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceWeekdays,
  }) {
    return TuitionClass(
      id: id,
      batchName: batchName ?? this.batchName,
      subject: subject ?? this.subject,
      studentName: studentName ?? this.studentName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      homework: homework ?? this.homework,
      colorValue: colorValue ?? this.colorValue,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceWeekdays: recurrenceWeekdays ?? this.recurrenceWeekdays,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'batchName': batchName,
        'subject': subject,
        'studentName': studentName,
        'date': date.toIso8601String(),
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
        'location': location,
        'notes': notes,
        'homework': homework,
        'colorValue': colorValue,
        'recurrenceType': recurrenceType.value,
        'recurrenceWeekdays': recurrenceWeekdays,
        'status': status.value,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static TuitionClass? fromJson(Map<String, dynamic> json) {
    try {
      final date = DateTime.parse(json['date'] as String);
      return TuitionClass(
        id: json['id'] as String,
        batchName: json['batchName'] as String,
        subject: json['subject'] as String,
        studentName: json['studentName'] as String,
        date: date,
        startTime: TimeOfDay(
          hour: json['startHour'] as int,
          minute: json['startMinute'] as int,
        ),
        endTime: TimeOfDay(
          hour: json['endHour'] as int,
          minute: json['endMinute'] as int,
        ),
        location: json['location'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        homework: json['homework'] as String? ?? '',
        colorValue: json['colorValue'] as int? ?? 0xFF4F46E5,
        recurrenceType: RecurrenceTypeX.from(json['recurrenceType'] as String?),
        recurrenceWeekdays:
            List<int>.from(json['recurrenceWeekdays'] as List? ?? const []),
        status: ClassStatusX.from(json['status'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

class LocalStorageService {
  static const _classesKey = 'tutorflow_classes';
  static const _firstLaunchKey = 'tutorflow_first_launch';

  Future<List<TuitionClass>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool(_firstLaunchKey) ?? true;
    if (firstLaunch) {
      final sample = _sampleClasses();
      await saveClasses(sample);
      await prefs.setBool(_firstLaunchKey, false);
      return sample;
    }

    try {
      final raw = prefs.getString(_classesKey);
      if (raw == null) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((item) => TuitionClass.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .whereType<TuitionClass>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveClasses(List<TuitionClass> classes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _classesKey,
      jsonEncode(classes.map((item) => item.toJson()).toList()),
    );
  }

  List<TuitionClass> _sampleClasses() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return [
      TuitionClass(
        id: 'sample-1',
        batchName: 'আলফা ব্যাচ',
        subject: 'গণিত',
        studentName: 'রাফি ও মেহেদী',
        date: day,
        startTime: const TimeOfDay(hour: 9, minute: 30),
        endTime: const TimeOfDay(hour: 10, minute: 30),
        location: 'ধানমন্ডি, বাসা ১২',
        notes: 'আগের অধ্যায়টি রিভিশন করাতে হবে',
        homework: 'অনুশীলনী ৩.২',
        colorValue: 0xFF4F46E5,
        createdAt: now,
        updatedAt: now,
      ),
      TuitionClass(
        id: 'sample-2',
        batchName: 'এইচএসসি প্রস্তুতি',
        subject: 'পদার্থবিজ্ঞান',
        studentName: 'সাদিয়া',
        date: day,
        startTime: const TimeOfDay(hour: 17),
        endTime: const TimeOfDay(hour: 18, minute: 30),
        location: 'অনলাইন',
        colorValue: 0xFF0F9D8A,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  Future<void> reschedule(List<TuitionClass> classes) async {
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final item in classes) {
        if (item.status == ClassStatus.cancelled ||
            item.recurrenceType == RecurrenceType.weekly) {
          continue;
        }
        final reminder = item.startsAt.subtract(const Duration(minutes: 15));
        if (reminder.isAfter(now)) {
          await _plugin.zonedSchedule(
            _notificationId(item.id),
            '১৫ মিনিট পর ক্লাস',
            '${item.batchName} • ${item.subject}',
            tz.TZDateTime.from(reminder, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'tutorflow_classes',
                'TutorFlow Classes',
                channelDescription: 'Upcoming class reminders',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (_) {}
  }

  int _notificationId(String value) =>
      value.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff);
}

class ScheduleController extends ChangeNotifier {
  ScheduleController({
    required this.storage,
    required this.notifications,
    required List<TuitionClass> classes,
  }) : _classes = List.of(classes);

  final LocalStorageService storage;
  final NotificationService notifications;
  List<TuitionClass> _classes;

  List<TuitionClass> get classes => List.unmodifiable(_classes);

  List<TuitionClass> classesOn(DateTime day) {
    return _classes
        .where((item) => item.appearsOn(day))
        .map((item) => item.occurrenceFor(day))
        .toList()
      ..sort((a, b) => _minutes(a.startTime).compareTo(_minutes(b.startTime)));
  }

  List<TuitionClass> rawClassesOn(DateTime day) =>
      _classes.where((item) => item.appearsOn(day)).toList();

  Future<void> add(TuitionClass item) async {
    _classes = [..._classes, item];
    await _persist();
  }

  Future<void> update(TuitionClass item) async {
    _classes = _classes.map((old) => old.id == item.id ? item : old).toList();
    await _persist();
  }

  Future<void> remove(String id) async {
    _classes = _classes.where((item) => item.id != id).toList();
    await _persist();
  }

  Future<void> setStatus(String id, ClassStatus status) async {
    final item = _classes.where((entry) => entry.id == id).firstOrNull;
    if (item == null) return;
    await update(item.copyWith(status: status));
  }

  Future<void> _persist() async {
    await storage.saveClasses(_classes);
    await notifications.reschedule(_classes);
    notifyListeners();
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
}

class ScheduleScope extends InheritedNotifier<ScheduleController> {
  const ScheduleScope({
    super.key,
    required ScheduleController controller,
    required super.child,
  }) : super(notifier: controller);

  static ScheduleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScheduleScope>()!.notifier!;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = const [
      HomeScreen(),
      CalendarScreen(),
      InsightsScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: screens[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'ক্যালেন্ডার',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'ইনসাইটস',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ScheduleScope.of(context);
    final today = DateTime.now();
    final classes = controller.classesOn(today);
    final completed =
        classes.where((item) => item.status == ClassStatus.completed).length;
    final upcoming = classes
        .where((item) =>
            item.status == ClassStatus.upcoming ||
            item.status == ClassStatus.inProgress)
        .length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ক্লাস যোগ করুন'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => controller.notifyListeners(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
          children: [
            Text(
              _greeting(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF64708A),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'আজকের ক্লাস',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'bn_BD').format(today),
              style: const TextStyle(
                color: Color(0xFF526079),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    label: 'মোট ক্লাস',
                    value: '${classes.length}',
                    icon: Icons.view_timeline_rounded,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    label: 'সম্পন্ন',
                    value: '$completed',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF16866F),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    label: 'আসন্ন',
                    value: '$upcoming',
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFD5931B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('আজকের সময়সূচি',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${classes.length}টি ক্লাস',
                  style: const TextStyle(
                    color: Color(0xFF64708A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (classes.isEmpty)
              const EmptyState(
                icon: Icons.event_available_rounded,
                title: 'কোনো ক্লাস নেই',
                message: 'আজকের রুটিনে নতুন ক্লাস যোগ করুন।',
              )
            else
              ...classes.asMap().entries.map(
                    (entry) => ScheduleCard(
                      item: entry.value,
                      highlight: _isNext(entry.value, classes),
                      onTap: () => _openForm(
                        context,
                        initial: controller.rawClassesOn(today).firstWhere(
                              (raw) => raw.id == _baseId(entry.value.id),
                            ),
                      ),
                      onComplete: () async {
                        await controller.setStatus(
                          _baseId(entry.value.id),
                          entry.value.status == ClassStatus.completed
                              ? ClassStatus.upcoming
                              : ClassStatus.completed,
                        );
                      },
                      onCancel: () async {
                        await controller.setStatus(
                          _baseId(entry.value.id),
                          entry.value.status == ClassStatus.cancelled
                              ? ClassStatus.upcoming
                              : ClassStatus.cancelled,
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  static bool _isNext(TuitionClass item, List<TuitionClass> classes) {
    final now = DateTime.now();
    return item.status == ClassStatus.upcoming &&
        item.startsAt.isAfter(now) &&
        classes.where((x) => x.status == ClassStatus.upcoming).first.id == item.id;
  }

  static String _baseId(String value) => value.split('-').take(1).join();

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'সুপ্রভাত 👋';
    if (hour < 17) return 'শুভ অপরাহ্ণ 👋';
    return 'শুভ সন্ধ্যা 👋';
  }

  static Future<void> _openForm(
    BuildContext context, {
    TuitionClass? initial,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassFormScreen(initial: initial),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final controller = ScheduleScope.of(context);
    final classes = controller.classesOn(selected);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ClassFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ক্লাস যোগ করুন'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
        children: [
          Text('ক্যালেন্ডার', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text(
            'আপনার ক্লাসগুলো এক নজরে দেখুন',
            style: TextStyle(color: Color(0xFF64708A)),
          ),
          const SizedBox(height: 20),
          CalendarCard(
            month: month,
            selected: selected,
            onPrevious: () => setState(
              () => month = DateTime(month.year, month.month - 1),
            ),
            onNext: () => setState(
              () => month = DateTime(month.year, month.month + 1),
            ),
            hasClasses: (day) => controller.classesOn(day).isNotEmpty,
            onSelected: (day) => setState(() => selected = day),
          ),
          const SizedBox(height: 24),
          Text(
            DateFormat('d MMMM, EEEE', 'bn_BD').format(selected),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (classes.isEmpty)
            const EmptyState(
              icon: Icons.calendar_today_rounded,
              title: 'কোনো ক্লাস নেই',
              message: 'এই দিনে কোনো ক্লাস নির্ধারিত নেই।',
            )
          else
            ...classes.map(
              (item) => ScheduleCard(
                item: item,
                onTap: () {
                  final raw = controller.rawClassesOn(selected).firstWhere(
                        (entry) => entry.id == item.id.split('-').first,
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClassFormScreen(initial: raw),
                    ),
                  );
                },
                onComplete: () => controller.setStatus(
                  item.id.split('-').first,
                  item.status == ClassStatus.completed
                      ? ClassStatus.upcoming
                      : ClassStatus.completed,
                ),
                onCancel: () => controller.setStatus(
                  item.id.split('-').first,
                  item.status == ClassStatus.cancelled
                      ? ClassStatus.upcoming
                      : ClassStatus.cancelled,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ScheduleScope.of(context);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    final all = controller.classes;
    final week = all.where((item) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      return !day.isBefore(
          DateTime(weekStart.year, weekStart.month, weekStart.day));
    }).length;
    final month = all.where((item) {
      return item.date.year == monthStart.year &&
          item.date.month == monthStart.month;
    }).length;
    final completed =
        all.where((item) => item.status == ClassStatus.completed).length;
    final cancelled =
        all.where((item) => item.status == ClassStatus.cancelled).length;

    final weekdayCounts = <int, int>{
      for (var i = 1; i <= 7; i++) i: 0,
    };
    final subjectCounts = <String, int>{};
    for (final item in all) {
      weekdayCounts[item.date.weekday] =
          (weekdayCounts[item.date.weekday] ?? 0) + 1;
      subjectCounts[item.subject] = (subjectCounts[item.subject] ?? 0) + 1;
    }
    final busyDay = weekdayCounts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text('ইনসাইটস', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text(
          'আপনার টিউশন রুটিনের সারাংশ',
          style: TextStyle(color: Color(0xFF64708A)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: InsightMetric(label: 'এই সপ্তাহ', value: '$week')),
            const SizedBox(width: 12),
            Expanded(child: InsightMetric(label: 'এই মাস', value: '$month')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InsightMetric(label: 'সম্পন্ন ক্লাস', value: '$completed'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InsightMetric(label: 'বাতিল ক্লাস', value: '$cancelled'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('সবচেয়ে ব্যস্ত দিন',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '${_weekdayName(busyDay.key)} • ${busyDay.value}টি ক্লাস',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('বিষয় অনুযায়ী ক্লাস',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 18),
                if (subjectCounts.isEmpty)
                  const Text('এখনও কোনো ডেটা নেই।')
                else
                  ...subjectCounts.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: BarRow(
                        label: entry.key,
                        value: entry.value,
                        max: subjectCounts.values.reduce(max),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _weekdayName(int weekday) =>
      DateFormat('EEEE', 'bn_BD').format(DateTime(2024, 1, weekday + 1));
}

class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({super.key, this.initial});

  final TuitionClass? initial;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController batch;
  late final TextEditingController subject;
  late final TextEditingController student;
  late final TextEditingController location;
  late final TextEditingController notes;
  late final TextEditingController homework;
  late DateTime date;
  late TimeOfDay start;
  late TimeOfDay end;
  late RecurrenceType recurrence;
  late List<int> weekdays;
  late int colorValue;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    batch = TextEditingController(text: item?.batchName);
    subject = TextEditingController(text: item?.subject);
    student = TextEditingController(text: item?.studentName);
    location = TextEditingController(text: item?.location);
    notes = TextEditingController(text: item?.notes);
    homework = TextEditingController(text: item?.homework);
    date = item?.date ?? DateTime.now();
    start = item?.startTime ?? const TimeOfDay(hour: 17);
    end = item?.endTime ?? const TimeOfDay(hour: 18);
    recurrence = item?.recurrenceType ?? RecurrenceType.oneTime;
    weekdays = List.of(item?.recurrenceWeekdays ?? const []);
    colorValue = item?.colorValue ?? 0xFF4F46E5;
  }

  @override
  void dispose() {
    batch.dispose();
    subject.dispose();
    student.dispose();
    location.dispose();
    notes.dispose();
    homework.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'ক্লাস সম্পাদনা' : 'নতুন ক্লাস'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: const Text('সংরক্ষণ করুন'),
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('ক্লাসের তথ্য',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _field(batch, 'ব্যাচের নাম', Icons.groups_rounded),
            _field(subject, 'বিষয়', Icons.menu_book_rounded),
            _field(student, 'শিক্ষার্থীর নাম', Icons.person_rounded),
            const SizedBox(height: 8),
            DateTimeTile(
              icon: Icons.event_rounded,
              label: 'তারিখ',
              value: DateFormat('d MMMM yyyy', 'bn_BD').format(date),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: date,
                );
                if (picked != null) setState(() => date = picked);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: DateTimeTile(
                    icon: Icons.login_rounded,
                    label: 'শুরু',
                    value: start.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: start,
                      );
                      if (picked != null) setState(() => start = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateTimeTile(
                    icon: Icons.logout_rounded,
                    label: 'শেষ',
                    value: end.format(context),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: end,
                      );
                      if (picked != null) setState(() => end = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('পুনরাবৃত্তি',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<RecurrenceType>(
              segments: const [
                ButtonSegment(
                  value: RecurrenceType.oneTime,
                  label: Text('একবার'),
                  icon: Icon(Icons.event_rounded),
                ),
                ButtonSegment(
                  value: RecurrenceType.weekly,
                  label: Text('সাপ্তাহিক'),
                  icon: Icon(Icons.repeat_rounded),
                ),
              ],
              selected: {recurrence},
              onSelectionChanged: (value) =>
                  setState(() => recurrence = value.first),
            ),
            if (recurrence == RecurrenceType.weekly) ...[
              const SizedBox(height: 16),
              const Text('যে দিনগুলোতে হবে'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  return FilterChip(
                    label: Text(_weekdayShort(day)),
                    selected: weekdays.contains(day),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          weekdays.add(day);
                        } else {
                          weekdays.remove(day);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
            const SizedBox(height: 24),
            Text('অতিরিক্ত তথ্য',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _field(location, 'লোকেশন', Icons.location_on_rounded, required: false),
            _field(notes, 'নোট', Icons.sticky_note_2_rounded, required: false),
            _field(homework, 'হোমওয়ার্ক', Icons.assignment_rounded,
                required: false),
            const SizedBox(height: 12),
            Text('রঙ নির্বাচন',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                0xFF4F46E5,
                0xFF0F9D8A,
                0xFFF2B84B,
                0xFFD15C62,
                0xFF7C5CBF,
              ].map((value) {
                return InkWell(
                  onTap: () => setState(() => colorValue = value),
                  borderRadius: BorderRadius.circular(24),
                  child: Semantics(
                    label: 'রঙ নির্বাচন',
                    button: true,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(value),
                      child: colorValue == value
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            if (editing)
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('মুছে ফেলুন'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD15C62),
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? 'এই ঘরটি পূরণ করুন' : null
            : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    if (_minutes(end) <= _minutes(start)) {
      _message('শেষ সময় অবশ্যই শুরুর সময়ের পরে হতে হবে');
      return;
    }
    if (recurrence == RecurrenceType.weekly && weekdays.isEmpty) {
      _message('কমপক্ষে একটি দিন নির্বাচন করুন');
      return;
    }

    final controller = ScheduleScope.of(context);
    final overlap = controller.classesOn(date).any((item) {
      final currentId = widget.initial?.id;
      if (item.id.split('-').first == currentId) return false;
      return _minutes(start) < _minutes(item.endTime) &&
          _minutes(end) > _minutes(item.startTime);
    });

    if (overlap && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('সময় মিলে যাচ্ছে'),
          content: const Text('এই সময়ে আরেকটি ক্লাস আছে। তবুও সংরক্ষণ করবেন?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ফিরে যান'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('সংরক্ষণ করুন'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => saving = true);
    final now = DateTime.now();
    final item = TuitionClass(
      id: widget.initial?.id ??
          '${now.microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      batchName: batch.text.trim(),
      subject: subject.text.trim(),
      studentName: student.text.trim(),
      date: DateTime(date.year, date.month, date.day),
      startTime: start,
      endTime: end,
      location: location.text.trim(),
      notes: notes.text.trim(),
      homework: homework.text.trim(),
      colorValue: colorValue,
      recurrenceType: recurrence,
      recurrenceWeekdays: List.of(weekdays),
      status: widget.initial?.status ?? ClassStatus.upcoming,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
    );

    if (widget.initial == null) {
      await controller.add(item);
    } else {
      await controller.update(item);
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.initial == null ? 'ক্লাস যোগ হয়েছে' : 'ক্লাস আপডেট হয়েছে')),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ক্লাস মুছে ফেলবেন?'),
        content: const Text('এই কাজটি ফিরিয়ে আনা যাবে না।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('মুছে ফেলুন'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ScheduleScope.of(context).remove(widget.initial!.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ক্লাস মুছে ফেলা হয়েছে')),
        );
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  String _weekdayShort(int day) =>
      DateFormat('E', 'bn_BD').format(DateTime(2024, 1, day + 1));
}

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({
    super.key,
    required this.item,
    this.highlight = false,
    required this.onTap,
    required this.onComplete,
    required this.onCancel,
  });

  final TuitionClass item;
  final bool highlight;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = item.status.color(scheme);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 92,
                decoration: BoxDecoration(
                  color: Color(item.colorValue),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.batchName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (highlight)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'পরবর্তী',
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${item.subject} • ${item.studentName}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _Meta(
                          icon: Icons.schedule_rounded,
                          text:
                              '${item.startTime.format(context)} - ${item.endTime.format(context)}',
                        ),
                        if (item.location.isNotEmpty)
                          _Meta(
                            icon: Icons.location_on_outlined,
                            text: item.location,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(item.status.icon, size: 16, color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          item.status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.notes.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'নোট',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const Spacer(),
                        PopupMenuButton<String>(
                          tooltip: 'ক্লাসের কাজ',
                          onSelected: (value) {
                            if (value == 'complete') onComplete();
                            if (value == 'cancel') onCancel();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'complete',
                              child: Text(
                                item.status == ClassStatus.completed
                                    ? 'আবার আসন্ন করুন'
                                    : 'সম্পন্ন হিসেবে চিহ্নিত করুন',
                              ),
                            ),
                            PopupMenuItem(
                              value: 'cancel',
                              child: Text(
                                item.status == ClassStatus.cancelled
                                    ? 'ক্লাস পুনরুদ্ধার করুন'
                                    : 'ক্লাস বাতিল করুন',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64708A)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64708A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color.withAlpha(28),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64708A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Icon(icon, size: 46, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64708A)),
            ),
          ],
        ),
      ),
    );
  }
}

class InsightMetric extends StatelessWidget {
  const InsightMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF64708A))),
          ],
        ),
      ),
    );
  }
}

class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : value / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$value', style: const TextStyle(color: Color(0xFF64708A))),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5EAF3),
          ),
        ),
      ],
    );
  }
}

class DateTimeTile extends StatelessWidget {
  const DateTimeTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Color(0xFF64708A), fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarCard extends StatelessWidget {
  const CalendarCard({
    super.key,
    required this.month,
    required this.selected,
    required this.onPrevious,
    required this.onNext,
    required this.hasClasses,
    required this.onSelected,
  });

  final DateTime month;
  final DateTime selected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool Function(DateTime) hasClasses;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'bn_BD').format(month),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                7,
                (index) => SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(
                      DateFormat('E', 'bn_BD').format(
                        DateTime(2024, 1, index + 2),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF64708A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leading + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 48,
              ),
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox();
                final day = index - leading + 1;
                final value = DateTime(month.year, month.month, day);
                final isSelected = value.year == selected.year &&
                    value.month == selected.month &&
                    value.day == selected.day;
                final marked = hasClasses(value);

                return InkWell(
                  onTap: () => onSelected(value),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF28324A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (marked)
                        CircleAvatar(
                          radius: 2.5,
                          backgroundColor:
                              Theme.of(context).colorScheme.tertiary,
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
