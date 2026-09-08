import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A single calendar event tied to a specific date.
class CalendarEvent {
  final String id;
  final DateTime date;
  final String title;

  CalendarEvent({required this.id, required this.date, required this.title});

  factory CalendarEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['date'] as Timestamp;
    return CalendarEvent(
      id: doc.id,
      date: ts.toDate(),
      title: data['title'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'title': title,
        'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      };
}

/// Holds all state for the Calendar screen.
class CalendarController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String uid;

  CalendarController({required this.uid});

  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get focusedMonth => _focusedMonth;

  /// e.g. "July 2026" — shown in the CalendarMonthHeader.
  String get focusedMonthLabel => DateFormat('MMMM yyyy').format(_focusedMonth);

  /// The day currently tapped in the grid, if any.
  DateTime? selectedDay;

  List<CalendarEvent> _events = [];
  bool isLoading = false;
  bool isSaving = false;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// All events for the currently focused month, sorted by date.
  List<CalendarEvent> get monthEvents {
    return _events
        .where((e) =>
            e.date.year == _focusedMonth.year &&
            e.date.month == _focusedMonth.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// What the screen's "Events" list actually shows: if a day is
  /// selected, just that day's events; otherwise every event in the
  /// focused month.
  List<CalendarEvent> get eventsForMonth {
    if (selectedDay != null) return eventsForDay(selectedDay!);
    return monthEvents;
  }

  /// Returns all events on a specific day (for dot indicators).
  List<CalendarEvent> eventsForDay(DateTime day) {
    return _events.where((e) => _isSameDay(e.date, day)).toList();
  }

  bool hasEventsOnDay(DateTime day) => eventsForDay(day).isNotEmpty;

  /// Normalized (y/m/d only) set of days within the focused month
  /// that have at least one event — used by CalendarGrid to draw
  /// dot indicators.
  Set<DateTime> get daysWithEvents {
    return monthEvents
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
  }

  Future<void> _fetchEvents() async {
    try {
      final snap = await _firestore
          .collection('calendar_events')
          .where('uid', isEqualTo: uid)
          .get();
      _events = snap.docs.map(CalendarEvent.fromFirestore).toList();
    } catch (e) {
      debugPrint('CalendarController: failed to load events: $e');
    }
  }

  Future<void> loadEvents() async {
    isLoading = true;
    notifyListeners();
    await _fetchEvents();
    isLoading = false;
    notifyListeners();
  }

  void previousMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    selectedDay = null;
    notifyListeners();
  }

  void nextMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    selectedDay = null;
    notifyListeners();
  }

  /// Tapping a day selects it; tapping the same day again clears the
  /// selection (back to showing the whole month's events).
  void selectDay(DateTime day) {
    selectedDay = (selectedDay != null && _isSameDay(selectedDay!, day))
        ? null
        : day;
    notifyListeners();
  }

  /// Adds a new event to Firestore and refreshes (without flipping
  /// the full-screen [isLoading] flag, since this runs while the
  /// "Add Event" sheet is still open).
  Future<void> addEvent(DateTime date, String title) async {
    if (title.trim().isEmpty) return;

    isSaving = true;
    notifyListeners();

    try {
      final event = CalendarEvent(id: '', date: date, title: title.trim());
      await _firestore.collection('calendar_events').add(event.toMap());
      await _fetchEvents();
    } catch (e) {
      debugPrint('CalendarController: failed to add event: $e');
    }

    isSaving = false;
    notifyListeners();
  }

  /// Deletes an event and refreshes.
  Future<void> deleteEvent(CalendarEvent event) async {
    try {
      await _firestore.collection('calendar_events').doc(event.id).delete();
      await _fetchEvents();
      notifyListeners();
    } catch (e) {
      debugPrint('CalendarController: failed to delete event: $e');
    }
  }
}
