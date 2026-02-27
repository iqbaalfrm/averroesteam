import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ShalatNotificationService {
  ShalatNotificationService._();

  static final ShalatNotificationService instance = ShalatNotificationService._();

  static const List<String> _prayerOrder = <String>[
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  static const Map<String, String> _prayerLabels = <String, String>{
    'Fajr': 'Subuh',
    'Dhuhr': 'Dzuhur',
    'Asr': 'Ashar',
    'Maghrib': 'Maghrib',
    'Isha': 'Isya',
  };

  static const List<int> _reminderMinutes = <int>[15, 5];
  static const int _baseId = 41000;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> schedulePrayerReminders({
    required String city,
    required String timezoneName,
    required Map<String, dynamic> timings,
  }) async {
    await initialize();

    final cityKey = city.toLowerCase();
    final cityIndex = cityKey == 'jakarta' ? 1 : 2;
    final location = tz.getLocation(timezoneName);
    final now = tz.TZDateTime.now(location);

    for (var prayerIndex = 0; prayerIndex < _prayerOrder.length; prayerIndex++) {
      final prayerKey = _prayerOrder[prayerIndex];
      final rawValue = (timings[prayerKey] ?? '').toString().split(' ').first.trim();
      final parsed = _parseHourMinute(rawValue);
      if (parsed == null) {
        continue;
      }

      final prayerAt = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        parsed.$1,
        parsed.$2,
      );

      for (var reminderIndex = 0; reminderIndex < _reminderMinutes.length; reminderIndex++) {
        final minutesBefore = _reminderMinutes[reminderIndex];
        final remindAt = prayerAt.subtract(Duration(minutes: minutesBefore));
        final id = _notificationId(cityIndex, prayerIndex, reminderIndex);

        await _plugin.cancel(id);
        if (!remindAt.isAfter(now)) {
          continue;
        }

        final prayerLabel = _prayerLabels[prayerKey] ?? prayerKey;
        await _plugin.zonedSchedule(
          id,
          'Pengingat Shalat $city',
          '$minutesBefore menit lagi waktu $prayerLabel (${_formatHm(parsed.$1, parsed.$2)})',
          remindAt,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'shalat_reminder',
              'Pengingat Shalat',
              channelDescription: 'Notifikasi pengingat jadwal shalat',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  Future<void> scheduleFromAladhanRaw({
    required String city,
    required String timezoneName,
    required dynamic raw,
  }) async {
    final data = raw is Map ? raw['data'] : null;
    final timings = data is Map ? data['timings'] : null;
    if (timings is! Map) {
      return;
    }
    await schedulePrayerReminders(
      city: city,
      timezoneName: timezoneName,
      timings: timings.cast<String, dynamic>(),
    );
  }

  static int _notificationId(int cityIndex, int prayerIndex, int reminderIndex) {
    return _baseId + (cityIndex * 100) + (prayerIndex * 10) + reminderIndex;
  }

  static (int, int)? _parseHourMinute(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  static String _formatHm(int h, int m) {
    final hs = h.toString().padLeft(2, '0');
    final ms = m.toString().padLeft(2, '0');
    return '$hs:$ms';
  }

  Future<void> debugPrintPending() async {
    if (!kDebugMode) return;
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('Pending shalat notifications: ${pending.length}');
  }
}
