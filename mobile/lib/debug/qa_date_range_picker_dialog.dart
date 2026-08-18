import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../prefs/app_preferences.dart';
import '../prefs/week_start.dart';
import '../util/week_start_calendar.dart';

/// Prefix for per-day recurrence picker ids (`…-YYYY-MM-DD`, or `…-15` / `…-20`
/// for the 15th and 20th of [rangeFirstDate]'s month).
const kQaRecurrenceDayIdPrefix = 'qa-housing-expense-recurrence-day-';

/// Stable ids for the 15th and 20th of the picker's first month (current month
/// in `showExpenseRecurrenceFlow`). Referenced by `proposal_wizard_expenses`.
const kQaRecurrenceDay15 = 'qa-housing-expense-recurrence-day-15';
const kQaRecurrenceDay20 = 'qa-housing-expense-recurrence-day-20';

const kQaRecurrenceRangeSave = 'qa-housing-expense-recurrence-range-save';

/// Maestro-facing id for a selectable day cell.
///
/// The 15th and 20th of [rangeFirstDate]'s month use stable day-of-month ids so
/// flows do not pin a calendar year. Other days keep an ISO suffix so duplicate
/// day numbers in later months stay unambiguous.
String qaRecurrenceDaySemanticsId(
  DateTime day, {
  required DateTime rangeFirstDate,
}) {
  final d = DateUtils.dateOnly(day);
  final first = DateUtils.dateOnly(rangeFirstDate);
  final inFirstMonth = d.year == first.year && d.month == first.month;
  if (inFirstMonth && d.day == 15) return kQaRecurrenceDay15;
  if (inFirstMonth && d.day == 20) return kQaRecurrenceDay20;
  return '$kQaRecurrenceDayIdPrefix'
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Debug-only range picker with per-day [Semantics] ids for Maestro E2E.
///
/// Production/release builds keep Material [showDateRangePicker].
Future<DateTimeRange?> showQaDateRangePickerDialog({
  required BuildContext context,
  required AppPreferences prefs,
  required DateTime firstDate,
  required DateTime lastDate,
  String? saveText,
}) {
  assert(kDebugMode);
  return showDialog<DateTimeRange>(
    context: context,
    barrierDismissible: false,
    useSafeArea: true,
    builder: (ctx) => weekStartCalendarLocalizations(
      context: ctx,
      prefs: prefs,
      child: _QaDateRangePickerDialog(
        firstDate: DateUtils.dateOnly(firstDate),
        lastDate: DateUtils.dateOnly(lastDate),
        saveText: saveText,
        weekStart: prefs.resolveWeekStart(Localizations.localeOf(ctx)),
      ),
    ),
  );
}

class _QaDateRangePickerDialog extends StatefulWidget {
  const _QaDateRangePickerDialog({
    required this.firstDate,
    required this.lastDate,
    required this.weekStart,
    this.saveText,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final WeekStart weekStart;
  final String? saveText;

  @override
  State<_QaDateRangePickerDialog> createState() => _QaDateRangePickerDialogState();
}

class _QaDateRangePickerDialogState extends State<_QaDateRangePickerDialog> {
  DateTime? _start;
  DateTime? _end;

  bool get _canSave => _start != null && _end != null;

  int get _firstDayOfWeekIndex => firstDayOfWeekIndexFor(widget.weekStart);

  bool _isSelectable(DateTime day) {
    final d = DateUtils.dateOnly(day);
    return !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);
  }

  void _onDayTap(DateTime day) {
    final d = DateUtils.dateOnly(day);
    if (!_isSelectable(d)) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = d;
        _end = null;
        return;
      }
      if (d.isBefore(_start!)) {
        _start = d;
        _end = null;
        return;
      }
      _end = d;
    });
  }

  void _confirmRange() {
    if (!_canSave) return;
    Navigator.pop(
      context,
      DateTimeRange(start: _start!, end: _end!),
    );
  }

  bool _isSameDay(DateTime? a, DateTime b) =>
      a != null && DateUtils.isSameDay(a, b);

  bool _inRange(DateTime day) {
    if (_start == null || _end == null) return false;
    final d = DateUtils.dateOnly(day);
    return !d.isBefore(_start!) && !d.isAfter(_end!);
  }

  Iterable<DateTime> _months() sync* {
    var y = widget.firstDate.year;
    var m = widget.firstDate.month;
    final endY = widget.lastDate.year;
    final endM = widget.lastDate.month;
    while (y < endY || (y == endY && m <= endM)) {
      yield DateTime(y, m);
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
  }

  int _leadingBlankCells(DateTime monthStart) {
    final weekdayFromSunday = monthStart.weekday % 7;
    return (weekdayFromSunday - _firstDayOfWeekIndex + 7) % 7;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final monthTitleFormat = DateFormat.yMMMM(locale.toString());

    final saveLabel = widget.saveText ?? l10n.saveButtonLabel;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      l10n.dateRangePickerHelpText,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: Semantics(
                      identifier: kQaRecurrenceRangeSave,
                      button: true,
                      label: saveLabel,
                      enabled: _canSave,
                      onTap: _canSave ? _confirmRange : null,
                      excludeSemantics: true,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: _canSave ? _confirmRange : null,
                        child: Text(saveLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _start == null
                    ? '${l10n.dateRangeStartLabel} – ${l10n.dateRangeEndLabel}'
                    : _end == null
                        ? '${DateFormat.yMMMd(locale.toString()).format(_start!)} – ${l10n.dateRangeEndLabel}'
                        : '${DateFormat.yMMMd(locale.toString()).format(_start!)} – ${DateFormat.yMMMd(locale.toString()).format(_end!)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final month in _months()) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        monthTitleFormat.format(month),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    _WeekdayHeader(firstDayOfWeekIndex: _firstDayOfWeekIndex),
                    _MonthGrid(
                      month: month,
                      rangeFirstDate: widget.firstDate,
                      leadingBlanks: _leadingBlankCells(month),
                      isSelectable: _isSelectable,
                      isStart: (d) => _isSameDay(_start, d),
                      isEnd: (d) => _isSameDay(_end, d),
                      inRange: _inRange,
                      onDayTap: _onDayTap,
                    ),
                  ],
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

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.firstDayOfWeekIndex});

  final int firstDayOfWeekIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final labels = <String>[];
    for (var i = 0; i < 7; i++) {
      labels.add(l10n.narrowWeekdays[(firstDayOfWeekIndex + i) % 7]);
    }
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.rangeFirstDate,
    required this.leadingBlanks,
    required this.isSelectable,
    required this.isStart,
    required this.isEnd,
    required this.inRange,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime rangeFirstDate;
  final int leadingBlanks;
  final bool Function(DateTime day) isSelectable;
  final bool Function(DateTime day) isStart;
  final bool Function(DateTime day) isEnd;
  final bool Function(DateTime day) inRange;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox(height: 40));
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final selectable = isSelectable(date);
      final selected = isStart(date) || isEnd(date);
      final ranged = inRange(date);
      final scheme = Theme.of(context).colorScheme;
      cells.add(
        Semantics(
          identifier: selectable
              ? qaRecurrenceDaySemanticsId(
                  date,
                  rangeFirstDate: rangeFirstDate,
                )
              : null,
          button: true,
          label: '$day',
          enabled: selectable,
          excludeSemantics: true,
          child: Material(
            color: selected
                ? scheme.primary
                : ranged
                    ? scheme.primaryContainer
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: selectable ? () => onDayTap(date) : null,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: selected
                          ? scheme.onPrimary
                          : selectable
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}
