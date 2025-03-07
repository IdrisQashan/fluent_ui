import 'package:fluent_ui/fluent_ui.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'pickers.dart';

/// The fields used on date picker.
enum DatePickerField {
  /// The month field
  month,

  /// The day field
  day,

  /// The year field
  year,
}

// There is a known issue with clicking in the popup and select the date.
// The current workaround is very hacky and doesn't work very well with the
// current implementation. TODO: Fix clicking on ListWheelScrollView
// https://github.com/flutter/flutter/issues/38803

/// The date picker gives you a standardized way to let users pick a localized
/// date value using touch, mouse, or keyboard input.
///
/// ![DatePicker Preview](https://docs.microsoft.com/en-us/windows/apps/design/controls/images/controls-datepicker-expand.gif)
///
/// See also:
///
///  * [TimePicker], which gives you a standardized way to let users pick a time
///    value
///  * <https://docs.microsoft.com/en-us/windows/apps/design/controls/date-picker>
class DatePicker extends StatefulWidget {
  /// Creates a date picker.
  const DatePicker({
    Key? key,
    required this.selected,
    this.onChanged,
    this.onCancel,
    this.header,
    this.headerStyle,
    this.showDay = true,
    this.showMonth = true,
    this.showYear = true,
    this.startYear,
    this.endYear,
    this.contentPadding = kPickerContentPadding,
    this.popupHeight = kPickerPopupHeight,
    this.focusNode,
    this.autofocus = false,
    this.locale,
    this.fieldOrder,
  }) : super(key: key);

  /// The current date selected date.
  ///
  /// If null, no date is going to be shown.
  final DateTime? selected;

  /// Whenever the current selected date is changed by the user.
  ///
  /// If null, the picker is considered disabled
  final ValueChanged<DateTime>? onChanged;

  /// Whenever the user cancels the date change.
  final VoidCallback? onCancel;

  /// The content of the header
  final String? header;

  /// The style of the [header]
  final TextStyle? headerStyle;

  /// Whenever to show the month field
  ///
  /// See also:
  ///
  ///  * [showDay]
  ///  * [showYear]
  final bool showMonth;

  /// Whenever to show the day field
  ///
  /// See also:
  ///
  ///  * [showMonth]
  ///  * [showYear]
  final bool showDay;

  /// Whenever to show the year field
  ///
  /// See also:
  ///
  ///  * [showDay]
  ///  * [showMonth]
  final bool showYear;

  /// The year to start counting from.
  ///
  /// If null, defaults to [selected]'s year `- 100`
  final int? startYear;

  /// The year to end the counting.
  ///
  /// If null, defaults to [selected]'s year `+ 25`
  final int? endYear;

  /// The padding of the picker fields. Defaults to [kPickerContentPadding]
  final EdgeInsetsGeometry contentPadding;

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode;

  /// {@macro flutter.widgets.Focus.autofocus}
  final bool autofocus;

  /// The height of the popup.
  ///
  /// Defaults to [kPickerPopupHeight]
  final double popupHeight;

  /// The locale used to format the month name.
  ///
  /// If null, the system locale will be used.
  final Locale? locale;

  /// The order of the fields.
  ///
  /// If null, the order is based on the current locale.
  ///
  /// See also:
  ///  * [getDateOrderFromLocale], which returns the order of the fields based
  ///    on the current locale
  final List<DatePickerField>? fieldOrder;

  @override
  _DatePickerState createState() => _DatePickerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final selected = this.selected ?? DateTime.now();
    properties
      ..add(DiagnosticsProperty('selected', selected,
          ifNull: '${DateTime.now()}'))
      ..add(FlagProperty('showMonth',
          value: showMonth, ifFalse: 'not displaying month'))
      ..add(FlagProperty('showDay',
          value: showDay, ifFalse: 'not displaying day'))
      ..add(FlagProperty('showYear',
          value: showYear, ifFalse: 'not displaying year'))
      ..add(IntProperty('startYear', startYear ?? selected.year - 100))
      ..add(IntProperty('endYear', endYear ?? selected.year + 25))
      ..add(DiagnosticsProperty('contentPadding', contentPadding))
      ..add(ObjectFlagProperty.has('focusNode', focusNode))
      ..add(
          FlagProperty('autofocus', value: autofocus, ifFalse: 'manual focus'))
      ..add(DoubleProperty('popupHeight', popupHeight));
  }
}

class _DatePickerState extends State<DatePicker> {
  late DateTime date;

  FixedExtentScrollController? _monthController;
  FixedExtentScrollController? _dayController;
  FixedExtentScrollController? _yearController;

  int get startYear =>
      ((widget.startYear ?? DateTime.now().year) - 100).toInt();
  int get endYear => ((widget.endYear ?? DateTime.now().year) + 25).toInt();

  int get currentYear {
    return List.generate(endYear - startYear, (index) {
      return startYear + index;
    }).firstWhere((v) => v == date.year, orElse: () => 0);
  }

  @override
  void initState() {
    super.initState();
    date = widget.selected ?? DateTime.now();
    initControllers();
  }

  void initControllers() {
    if (widget.selected == null && mounted) {
      setState(() => date = DateTime.now());
    }
    _monthController = FixedExtentScrollController(
      initialItem: date.month - 1,
    );
    _dayController = FixedExtentScrollController(
      initialItem: date.day - 1,
    );

    _yearController = FixedExtentScrollController(
      initialItem: currentYear - startYear - 1,
    );
  }

  @override
  void dispose() {
    _monthController?.dispose();
    _dayController?.dispose();
    _yearController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != date) {
      date = widget.selected ?? DateTime.now();
      _monthController?.jumpToItem(date.month - 1);
      _dayController?.jumpToItem(date.day - 1);
      _yearController?.jumpToItem(currentYear - startYear - 1);
    }
  }

  void handleDateChanged(DateTime newDate) {
    if (mounted) setState(() => date = newDate);
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasFluentLocalizations(context));
    assert(debugCheckHasFluentTheme(context));
    final theme = FluentTheme.of(context);
    final localizations = FluentLocalizations.of(context);

    final locale = widget.locale ?? Localizations.maybeLocaleOf(context);

    final fieldOrder = widget.fieldOrder ?? getDateOrderFromLocale(locale);
    assert(fieldOrder.isNotEmpty);
    assert(
      fieldOrder.where((f) => f == DatePickerField.month).length == 1,
      'There can be only one month field',
    );
    assert(
      fieldOrder.where((f) => f == DatePickerField.day).length == 1,
      'There can be only one day field',
    );
    assert(
      fieldOrder.where((f) => f == DatePickerField.year).length == 1,
      'There can be only one year field',
    );

    Widget picker = Picker(
      pickerContent: (context) {
        return _DatePickerContentPopUp(
          date: date,
          dayController: _dayController!,
          endYear: endYear,
          monthController: _monthController!,
          onCancel: () => widget.onCancel?.call(),
          onChanged: (date) => widget.onChanged?.call(date),
          showDay: widget.showDay,
          showMonth: widget.showMonth,
          showYear: widget.showYear,
          startYear: startYear,
          yearController: _yearController!,
          locale: widget.locale,
          fieldOrder: fieldOrder,
        );
      },
      pickerHeight: widget.popupHeight,
      child: (context, open) => HoverButton(
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        onPressed: () async {
          _monthController?.dispose();
          _monthController = null;
          _dayController?.dispose();
          _dayController = null;
          _yearController?.dispose();
          _yearController = null;
          initControllers();
          await open();
        },
        builder: (context, states) {
          if (states.isDisabled) states = <ButtonStates>{};
          const divider = Divider(
            direction: Axis.vertical,
            style: DividerThemeData(
              verticalMargin: EdgeInsets.zero,
              horizontalMargin: EdgeInsets.zero,
            ),
          );

          final monthWidgets = [
            Expanded(
              flex: 2,
              child: Padding(
                padding: widget.contentPadding,
                child: Text(
                  widget.selected == null
                      ? localizations.month
                      : DateFormat(DateFormat.STANDALONE_MONTH, '$locale')
                          .format(widget.selected!)
                          .uppercaseFirst(),
                  locale: locale,
                ),
              ),
            )
          ];

          final dayWidget = [
            Expanded(
              child: Padding(
                padding: widget.contentPadding,
                child: Text(
                  widget.selected == null
                      ? localizations.day
                      : DateFormat.d().format(DateTime(
                          0,
                          0,
                          widget.selected!.day,
                        )),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ];

          final yearWidgets = [
            Expanded(
              child: Padding(
                padding: widget.contentPadding,
                child: Text(
                  widget.selected == null
                      ? localizations.year
                      : DateFormat.y().format(DateTime(
                          widget.selected!.year,
                        )),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ];

          final fields = <DatePickerField, List<Widget>>{
            if (widget.showYear) DatePickerField.year: yearWidgets,
            if (widget.showMonth) DatePickerField.month: monthWidgets,
            if (widget.showDay) DatePickerField.day: dayWidget,
          };

          final fieldMap = fieldOrder.map((e) => fields[e]);

          return FocusBorder(
            focused: states.isFocused,
            child: AnimatedContainer(
              duration: theme.fastAnimationDuration,
              curve: theme.animationCurve,
              height: kPickerHeight,
              decoration: kPickerDecorationBuilder(context, states),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: widget.selected == null
                      ? theme.resources.textFillColorSecondary
                      : null,
                ),
                maxLines: 1,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ...fieldMap.elementAt(0) ?? [],
                  if (fieldMap.elementAt(1) != null) ...[
                    if (fieldMap.elementAt(0) != null) divider,
                    ...fieldMap.elementAt(1)!,
                  ],
                  if (fieldMap.elementAt(2) != null) ...[
                    divider,
                    ...fieldMap.elementAt(2)!,
                  ],
                ]),
              ),
            ),
          );
        },
      ),
    );
    if (widget.header != null) {
      return InfoLabel(
        label: widget.header!,
        labelStyle: widget.headerStyle,
        child: picker,
      );
    }
    return picker;
  }
}

class _DatePickerContentPopUp extends StatefulWidget {
  const _DatePickerContentPopUp({
    Key? key,
    required this.showMonth,
    required this.showDay,
    required this.showYear,
    required this.date,
    required this.onChanged,
    required this.onCancel,
    required this.monthController,
    required this.dayController,
    required this.yearController,
    required this.startYear,
    required this.endYear,
    required this.locale,
    required this.fieldOrder,
  }) : super(key: key);

  final bool showMonth;
  final bool showDay;
  final bool showYear;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onCancel;
  final FixedExtentScrollController monthController;
  final FixedExtentScrollController dayController;
  final FixedExtentScrollController yearController;
  final int startYear;
  final int endYear;
  final Locale? locale;
  final List<DatePickerField> fieldOrder;

  @override
  __DatePickerContentPopUpState createState() =>
      __DatePickerContentPopUpState();
}

class __DatePickerContentPopUpState extends State<_DatePickerContentPopUp> {
  int _getDaysInMonth([int? month, int? year]) {
    year ??= DateTime.now().year;
    month ??= DateTime.now().month;
    return DateTimeRange(
      start: DateTime(year, month),
      end: DateTime(year, month + 1),
    ).duration.inDays;
  }

  late DateTime localDate = widget.date;

  void handleDateChanged(DateTime time) {
    if (localDate == time) {
      return;
    }
    setState(() {
      localDate = time;
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasFluentTheme(context));
    const divider = Divider(
      direction: Axis.vertical,
      style: DividerThemeData(
        verticalMargin: EdgeInsets.zero,
        horizontalMargin: EdgeInsets.zero,
      ),
    );

    final locale = widget.locale ?? Localizations.maybeLocaleOf(context);

    final monthWidget = [
      Expanded(
        flex: 2,
        child: () {
          final formatter = DateFormat.MMMM(locale.toString());
          // MONTH
          return PickerNavigatorIndicator(
            onBackward: () {
              widget.monthController.navigateSides(
                context,
                false,
                12,
              );
            },
            onForward: () {
              widget.monthController.navigateSides(
                context,
                true,
                12,
              );
            },
            child: ListWheelScrollView.useDelegate(
              controller: widget.monthController,
              itemExtent: kOneLineTileHeight,
              diameterRatio: kPickerDiameterRatio,
              physics: const FixedExtentScrollPhysics(),
              childDelegate: ListWheelChildLoopingListDelegate(
                children: List.generate(12, (month) {
                  month++;
                  final text =
                      formatter.format(DateTime(1, month)).uppercaseFirst();
                  return ListTile(
                    title: Text(
                      text,
                      style: kPickerPopupTextStyle(
                        context,
                        month == localDate.month,
                      ),
                      locale: locale,
                    ),
                  );
                }),
              ),
              onSelectedItemChanged: (index) {
                final month = index + 1;
                final daysInMonth = _getDaysInMonth(month, localDate.year);
                int day = localDate.day;
                if (day > daysInMonth) day = daysInMonth;
                handleDateChanged(DateTime(
                  localDate.year,
                  month,
                  day,
                  localDate.hour,
                  localDate.minute,
                  localDate.second,
                  localDate.millisecond,
                  localDate.microsecond,
                ));
              },
            ),
          );
        }(),
      ),
    ];

    final dayWidget = [
      Expanded(
        child: () {
          // DAY
          final daysInMonth = _getDaysInMonth(localDate.month, localDate.year);
          final formatter = DateFormat.d(locale.toString());
          return PickerNavigatorIndicator(
            onBackward: () {
              widget.dayController.navigateSides(
                context,
                false,
                daysInMonth,
              );
            },
            onForward: () {
              widget.dayController.navigateSides(
                context,
                true,
                daysInMonth,
              );
            },
            child: ListWheelScrollView.useDelegate(
              controller: widget.dayController,
              itemExtent: kOneLineTileHeight,
              diameterRatio: kPickerDiameterRatio,
              physics: const FixedExtentScrollPhysics(),
              childDelegate: ListWheelChildLoopingListDelegate(
                children: List<Widget>.generate(
                  daysInMonth,
                  (day) {
                    day++;
                    return ListTile(
                      title: Center(
                        child: Text(
                          formatter.format(DateTime(0, 0, day)),
                          style: kPickerPopupTextStyle(
                            context,
                            day == localDate.day,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              onSelectedItemChanged: (index) {
                handleDateChanged(DateTime(
                  localDate.year,
                  localDate.month,
                  index + 1,
                  localDate.hour,
                  localDate.minute,
                  localDate.second,
                  localDate.millisecond,
                  localDate.microsecond,
                ));
              },
            ),
          );
        }(),
      ),
    ];

    final yearWidget = [
      Expanded(
        child: () {
          final years = widget.endYear - widget.startYear;
          final formatter = DateFormat.y(locale.toString());
          // YEAR
          return PickerNavigatorIndicator(
            onBackward: () {
              widget.yearController.navigateSides(
                context,
                false,
                years,
              );
            },
            onForward: () {
              widget.yearController.navigateSides(
                context,
                true,
                years,
              );
            },
            child: ListWheelScrollView(
              controller: widget.yearController,
              itemExtent: kOneLineTileHeight,
              diameterRatio: kPickerDiameterRatio,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                handleDateChanged(DateTime(
                  widget.startYear + index + 1,
                  localDate.month,
                  localDate.day,
                  localDate.hour,
                  localDate.minute,
                  localDate.second,
                  localDate.millisecond,
                  localDate.microsecond,
                ));
              },
              children: List.generate(years, (index) {
                // index++;
                final realYear = widget.startYear + index + 1;
                return ListTile(
                  title: Center(
                    child: Text(
                      formatter.format(DateTime(realYear)),
                      style: kPickerPopupTextStyle(
                        context,
                        realYear == localDate.year,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }(),
      ),
    ];

    final fields = <DatePickerField, List<Widget>>{
      if (widget.showYear) DatePickerField.year: yearWidget,
      if (widget.showMonth) DatePickerField.month: monthWidget,
      if (widget.showDay) DatePickerField.day: dayWidget,
    };

    final fieldMap = widget.fieldOrder.map((e) => fields[e]);

    return Column(children: [
      Expanded(
        child: Stack(children: [
          PickerHighlightTile(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            ...fieldMap.elementAt(0) ?? [],
            if (fieldMap.elementAt(1) != null) ...[
              divider,
              ...fieldMap.elementAt(1)!,
            ],
            if (fieldMap.elementAt(2) != null) ...[
              divider,
              ...fieldMap.elementAt(2)!,
            ],
          ]),
        ]),
      ),
      const Divider(
        style: DividerThemeData(
          verticalMargin: EdgeInsets.zero,
          horizontalMargin: EdgeInsets.zero,
        ),
      ),
      YesNoPickerControl(
        onChanged: () {
          widget.onChanged(localDate);
          Navigator.pop(context);
        },
        onCancel: () {
          widget.onCancel();
          Navigator.pop(context);
        },
      ),
    ]);
  }
}

/// Get the date order based on the current locale.
///
///
/// ![](https://upload.wikimedia.org/wikipedia/commons/thumb/9/97/Date_format_by_country_NEW.svg/700px-Date_format_by_country_NEW.svg.png)
///
/// DMY is mostly used around the globe, so that's the returned
///
/// See also:
///
///  * <https://en.wikipedia.org/wiki/Date_format_by_country>
List<DatePickerField> getDateOrderFromLocale(Locale? locale) {
  final dmy = [
    DatePickerField.day,
    DatePickerField.month,
    DatePickerField.year,
  ];
  final ymd = [
    DatePickerField.year,
    DatePickerField.month,
    DatePickerField.day,
  ];
  final mdy = [
    DatePickerField.month,
    DatePickerField.day,
    DatePickerField.year,
  ];

  if (locale?.countryCode?.toLowerCase() == 'us') return mdy;

  final lang = locale?.languageCode;

  if (['zh', 'ko', 'jp'].contains(lang)) return ymd;

  return dmy;
}
