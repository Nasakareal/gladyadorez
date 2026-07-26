import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_client.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _granate = Color(0xFF7A0019);
  static const _dorado = Color(0xFFF2C14E);

  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _format = CalendarFormat.month;

  final Map<DateTime, List<_Actividad>> _events = {};
  bool _loading = false;
  String? _error;

  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _fetchRange(_visibleRange(_focusedDay, _format));
  }

  // normaliza a fecha (sin hora)
  DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

  // rango visible según formato (agregamos twoWeeks)
  ({DateTime start, DateTime end}) _visibleRange(
    DateTime focus,
    CalendarFormat fmt,
  ) {
    if (fmt == CalendarFormat.week) {
      final weekStart = _d(focus.subtract(Duration(days: (focus.weekday % 7))));
      final weekEnd = _d(weekStart.add(const Duration(days: 6)));
      return (start: weekStart, end: weekEnd);
    }
    if (fmt == CalendarFormat.twoWeeks) {
      final start = _d(focus.subtract(Duration(days: (focus.weekday % 7))));
      final end = _d(start.add(const Duration(days: 13)));
      return (start: start, end: end);
    }
    // month
    final first = DateTime(focus.year, focus.month, 1);
    final last = DateTime(focus.year, focus.month + 1, 0);
    return (
      start: first.subtract(const Duration(days: 2)),
      end: last.add(const Duration(days: 2)),
    );
  }

  Future<void> _fetchRange(({DateTime start, DateTime end}) range) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final token = await _storage.read(key: 'token');

      // Si tu backend espera UTC, descomenta .toUtc():
      final startIso = /* range.start.toUtc().toIso8601String() */ range.start
          .toIso8601String();
      final endIso = /* range.end.toUtc().toIso8601String()   */ range.end
          .toIso8601String();

      final res = await api.dio.get(
        '/v1/actividades/feed',
        queryParameters: {'start': startIso, 'end': endIso},
        options: token != null
            ? Options(headers: {'Authorization': 'Bearer $token'})
            : null,
      );

      // Acepta tanto List como Map{data: List}
      final raw = res.data;
      final List data = raw is List
          ? raw
          : (raw is Map && raw['data'] is List)
          ? raw['data'] as List
          : const [];

      _events.clear();
      for (final row in data.cast<Map>()) {
        final start = DateTime.tryParse('${row['start'] ?? ''}');
        if (start == null) continue;
        final ev = _Actividad(
          id: (row['id'] ?? 0) is int
              ? row['id'] as int
              : int.tryParse('${row['id'] ?? 0}') ?? 0,
          title: row['title']?.toString() ?? 'Sin título',
          start: start,
          end: DateTime.tryParse('${row['end'] ?? ''}'),
          allDay: (row['allDay'] ?? false) == true,
          colorHex: row['color']?.toString(),
          // API feed no siempre manda 'estado', pero si viene lo usamos
          estado: row['estado']?.toString(),
        );
        final key = _d(start);
        (_events[key] ??= []).add(ev);
      }

      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar las actividades: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Actividad> _getEventsForDay(DateTime day) =>
      _events[_d(day)] ?? const [];

  @override
  Widget build(BuildContext context) {
    final tt = GoogleFonts.montserratTextTheme(Theme.of(context).textTheme);

    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: _granate),
              const SizedBox(width: 8),
              Text(
                'Calendario de actividades',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              PopupMenuButton<CalendarFormat>(
                initialValue: _format,
                onSelected: (f) {
                  setState(() => _format = f);
                  _fetchRange(_visibleRange(_focusedDay, _format));
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: CalendarFormat.month,
                    child: Text('Mes'),
                  ),
                  PopupMenuItem(
                    value: CalendarFormat.twoWeeks,
                    child: Text('2 semanas'),
                  ),
                  PopupMenuItem(
                    value: CalendarFormat.week,
                    child: Text('Semana'),
                  ),
                ],
                child: Row(
                  children: [
                    Text(
                      _format == CalendarFormat.month
                          ? 'Mes'
                          : _format == CalendarFormat.twoWeeks
                          ? '2 semanas'
                          : 'Semana',
                      style: tt.bodyMedium,
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Calendario (con FIX al assert de BoxDecoration)
        Container(
          color: Colors.white,
          child: TableCalendar<_Actividad>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            eventLoader: _getEventsForDay,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w800,
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left_rounded,
                color: _granate,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right_rounded,
                color: _granate,
              ),
            ),
            calendarStyle: CalendarStyle(
              // 👇 FIX: si usas borderRadius, forzar shape rectangular
              todayDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(color: _dorado, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              selectedDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                color: _granate,
                borderRadius: BorderRadius.circular(8),
              ),
              markerDecoration: const BoxDecoration(
                color: _granate,
                shape: BoxShape
                    .circle, // marcador sí puede ser círculo (sin borderRadius)
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: tt.bodySmall!.copyWith(fontWeight: FontWeight.w700),
              weekendStyle: tt.bodySmall!.copyWith(fontWeight: FontWeight.w700),
            ),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _fetchRange(_visibleRange(_focusedDay, _format));
            },
          ),
        ),

        if (_loading) const LinearProgressIndicator(minHeight: 2),

        if (_error != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFEBEE),
            padding: const EdgeInsets.all(8),
            child: Text(
              _error!,
              style: tt.bodySmall?.copyWith(color: const Color(0xFFC62828)),
            ),
          ),

        // Lista de eventos del día seleccionado
        Expanded(
          child: Container(
            color: const Color(0xFFF7F7F9),
            child: _dayEventsList(tt, _selectedDay ?? DateTime.now()),
          ),
        ),
      ],
    );
  }

  Widget _dayEventsList(TextTheme tt, DateTime day) {
    final items = _getEventsForDay(day);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Sin actividades para esta fecha',
          style: tt.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = items[i];
        final color = _parseColor(a.colorHex) ?? _estadoColorFallback(a);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: ListTile(
            title: Text(
              a.title,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _subtitle(a),
              style: tt.bodySmall?.copyWith(color: Colors.black54),
            ),
            leading: Icon(Icons.event, color: color),
          ),
        );
      },
    );
  }

  String _subtitle(_Actividad a) {
    final start = _fmtDT(a.start);
    final end = a.end != null ? ' - ${_fmtDT(a.end!)}' : '';
    return a.allDay ? '$start (todo el día)' : '$start$end';
  }

  String _fmtDT(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$da $hh:$mm';
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    return Color(int.parse(h, radix: 16));
  }

  Color _estadoColorFallback(_Actividad a) {
    switch (a.estado) {
      case 'programada':
        return const Color(0xFF1976D2);
      case 'cancelada':
        return const Color(0xFFD32F2F);
      case 'realizada':
        return const Color(0xFF388E3C);
      default:
        return const Color(0xFF616161);
    }
  }
}

class _Actividad {
  final int id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final String? colorHex;
  final String? estado;

  _Actividad({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.colorHex,
    this.estado,
  });
}
