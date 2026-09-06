import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/semantics.dart';

import '../inputs/haptics.dart';
import '../inputs/surfaces.dart';
import '../inputs/voice.dart';
import '../inputs/voice_vocab.dart';
import '../model/profile.dart';
import '../model/session.dart';
import 'dock.dart';
import 'hold_repeater.dart';

/// Current option (and its group) so a Live overlay can match the phone.
class OptionHighlight {
  const OptionHighlight({
    required this.index,
    required this.value,
    this.phase = 'item',
    this.groupIndexes = const [],
  });

  /// Index into the full [DiscreteTaskView.options] list.
  final int index;
  final String value;

  /// `group` = pass 1 (page/row). `item` = pass 2 (the specific option).
  final String phase;

  /// Indexes in the current group (visible page, or the scan row).
  final List<int> groupIndexes;
}

/// Discrete choice, driven by whichever method the profile selected.
///
/// docs/idea/03-input-calibration.md 3.3: a fallback is not the same widget
/// made worse, it is a different interaction reaching the same outcome --
/// tap for buttons, cycle-and-confirm for the joystick, hover-and-release for
/// the trackpad, auto-scan-and-press for the switch.
class DiscreteTaskView extends StatefulWidget {
  const DiscreteTaskView({
    super.key,
    required this.profile,
    required this.method,
    required this.options,
    required this.onResolve,
    required this.onRaw,
    this.onHighlight,
    this.livePaging = false,
  });

  final CapabilityProfile profile;
  final TouchMethod method;
  final List<String> options;
  final void Function(int index, String value) onResolve;
  final void Function(String raw) onRaw;

  /// Fired when the highlight moves, so a live laptop overlay can follow
  /// without waiting for the act.
  final void Function(OptionHighlight highlight)? onHighlight;

  /// Live RailLink lists (issue #20): cap visible options from the profile
  /// and available height, and auto-advance the page after a full scan/pass.
  /// Offline demo tasks leave this false so their lists stay as they are.
  final bool livePaging;

  @override
  State<DiscreteTaskView> createState() => _DiscreteTaskViewState();
}

class _DiscreteTaskViewState extends State<DiscreteTaskView> {
  int _highlight = 0;
  int _page = 0;
  String? _lastDirection;
  Timer? _scan;
  Timer? _trackpadPageTimer;
  bool _awaitingLeaveLastSlot = false;
  int? _fittedCap;
  late final HoldRepeater _repeater;

  double get _scale => widget.profile.vision.textScale;

  /// Buttons always page. Other methods only page on the Live path.
  bool get _pages =>
      widget.livePaging || widget.method == TouchMethod.buttons;

  int get _profileCap {
    if (widget.options.isEmpty) return 1;
    return widget.profile.visibleOptionCount.clamp(1, widget.options.length);
  }

  int get _perPage {
    if (!_pages) return math.max(1, widget.options.length);
    final fit = _fittedCap;
    if (!widget.livePaging || fit == null) return _profileCap;
    return math.min(_profileCap, fit);
  }

  int get _pageCount {
    if (widget.options.isEmpty) return 1;
    return math.max(1, (widget.options.length / _perPage).ceil());
  }

  int get _pageStart {
    if (!_pages) return 0;
    final page = _page.clamp(0, _pageCount - 1);
    return page * _perPage;
  }

  List<String> get _slice {
    if (!_pages) return widget.options;
    return widget.options.skip(_pageStart).take(_perPage).toList();
  }

  @override
  void initState() {
    super.initState();
    _repeater = HoldRepeater(_stepFromDirection);
    if (widget.method == TouchMethod.switchScan) _startScan();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitHighlight());
  }

  @override
  void didUpdateWidget(DiscreteTaskView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameOptions(oldWidget.options, widget.options)) {
      _page = 0;
      _highlight = 0;
      _scanRow = 0;
      _scanCol = 0;
      _fittedCap = null;
      if (widget.method == TouchMethod.switchScan) _startScan();
    } else if (oldWidget.method != widget.method) {
      _scan?.cancel();
      if (widget.method == TouchMethod.switchScan) _startScan();
    }
  }

  bool _sameOptions(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _emitHighlight({String? phase}) {
    final cb = widget.onHighlight;
    if (cb == null || widget.options.isEmpty) return;
    final i = _highlight.clamp(0, widget.options.length - 1);
    cb(OptionHighlight(
      index: i,
      value: widget.options[i],
      phase: phase ?? _highlightPhase,
      groupIndexes: _groupIndexes,
    ));
  }

  /// Offline switch pass 1 highlights a row; Live paging treats the
  /// visible page as the group and the current option as the item.
  String get _highlightPhase {
    if (widget.method == TouchMethod.switchScan &&
        !widget.livePaging &&
        _scanPhase == 0) {
      return 'group';
    }
    return 'item';
  }

  List<int> get _groupIndexes {
    if (widget.method == TouchMethod.switchScan &&
        !widget.livePaging &&
        _scanPhase == 0) {
      final cols = _scanCols;
      final start = _scanRow * cols;
      return [
        for (var c = 0; c < cols; c++)
          if (start + c < widget.options.length) start + c,
      ];
    }
    if (_pages) {
      return [for (var i = 0; i < _slice.length; i++) _pageStart + i];
    }
    return [for (var i = 0; i < widget.options.length; i++) i];
  }

  @override
  void dispose() {
    _scan?.cancel();
    _trackpadPageTimer?.cancel();
    _repeater.stop();
    super.dispose();
  }

  // --- paging ----------------------------------------------------------

  void _goToPage(int page, {int highlightInPage = 0}) {
    if (widget.options.isEmpty) return;
    final pages = _pageCount;
    final next = ((page % pages) + pages) % pages;
    setState(() {
      _page = next;
      final len = math.max(1, _slice.length);
      final local = highlightInPage.clamp(0, len - 1);
      _highlight = _pageStart + local;
      if (widget.livePaging) {
        _scanRow = local;
        _scanCol = 0;
        _scanPhase = 1;
      }
    });
    _announce(widget.options[_highlight.clamp(0, widget.options.length - 1)]);
    _emitHighlight();
    widget.onRaw('page ${_page + 1}/$pages');
  }

  Widget _fitContent(
      Widget Function(int perPage, int start, List<String> slice) builder) {
    if (!widget.livePaging) {
      return builder(_perPage, _pageStart, _slice);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final h =
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
      final fitted = widget.profile.visibleCountForHeight(h);
      final changed = _fittedCap != fitted;
      _fittedCap = fitted;
      if (changed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
      final per = math.min(_profileCap, fitted);
      final pages = math.max(1, (widget.options.length / per).ceil());
      final page = _page.clamp(0, pages - 1);
      final start = page * per;
      final slice = widget.options.skip(start).take(per).toList();
      return builder(per, start, slice);
    });
  }

  // --- switch scanning -------------------------------------------------

  /// Dwell time is stretched for an unsteady user: the whole risk of scanning
  /// is pressing one item late, so steadiness buys speed rather than being
  /// fixed for everyone.
  Duration get _dwell => widget.profile.scanDwell;

  /// Row-then-column scanning, the same shape [PointingTaskView] already uses
  /// for its switch fallback -- for a floor-case user, scanning every option
  /// one at a time doesn't scale (6 plans = up to 6 dwells); a grid needs at
  /// most rows+cols (2 rows x 3 cols = at most 5). Degenerates to a single
  /// column pass automatically when there's only one row's worth of options.
  ///
  /// Live paging already caps the page, so it scans the current page as a
  /// single column and auto-advances when that pass wraps.
  int get _scanCols => widget.livePaging
      ? 1
      : math.max(1, math.sqrt(widget.options.length).ceil());
  int get _scanRows => widget.livePaging
      ? math.max(1, _slice.length)
      : (widget.options.length / _scanCols).ceil();

  int _scanPhase = 0; // 0 = scanning rows, 1 = scanning the chosen row's columns
  int _scanRow = 0;
  int _scanCol = 0;

  void _tickScan() {
    if (!mounted) return;
    Haptics.navigate();
    if (widget.livePaging) {
      _tickLiveScan();
      return;
    }
    setState(() {
      if (_scanPhase == 0) {
        _scanRow = (_scanRow + 1) % _scanRows;
        _highlight = _scanRow * _scanCols;
      } else {
        _scanCol = (_scanCol + 1) % _scanCols;
        final idx = _scanRow * _scanCols + _scanCol;
        if (idx < widget.options.length) _highlight = idx;
      }
    });
    final raw = _scanPhase == 0 ? 'scan row $_scanRow' : 'scan col $_scanCol';
    widget.onRaw(raw);
    final idx = _scanRow * _scanCols + _scanCol;
    if (_scanPhase == 1 && idx < widget.options.length) {
      _announce(widget.options[idx]);
    } else if (_scanPhase == 0 && _highlight < widget.options.length) {
      _announce(widget.options[_highlight]);
    }
    _emitHighlight();
  }

  void _tickLiveScan() {
    final n = _slice.length;
    if (n == 0) return;
    var row = _scanRow + 1;
    var page = _page;
    if (row >= n) {
      page = (_page + 1) % _pageCount;
      row = 0;
    }
    setState(() {
      _page = page;
      _scanRow = row;
      _scanCol = 0;
      _scanPhase = 1;
      _highlight = _pageStart + row;
    });
    final label = _slice.isEmpty
        ? ''
        : _slice[row.clamp(0, _slice.length - 1)];
    widget.onRaw('page ${_page + 1}/$_pageCount scan $label');
    if (label.isNotEmpty) _announce(label);
    _emitHighlight();
  }

  void _startScan() {
    _scan?.cancel();
    if (widget.livePaging) {
      _scanPhase = 1;
      _scanRow = 0;
      _scanCol = 0;
    } else {
      _scanPhase = _scanRows > 1 ? 0 : 1;
      _scanRow = 0;
      _scanCol = 0;
    }
    _scan = Timer.periodic(_dwell, (_) => _tickScan());
  }

  /// The switch's one press: picks the row on the first press (if there is
  /// more than one), then the cell within that row on the second. The same
  /// running timer just switches what it increments -- no restart needed.
  /// Live paging is already a short column, so one press selects.
  void _switchPress() {
    if (widget.livePaging) {
      final index = _pageStart + _scanRow;
      if (index < widget.options.length) {
        _resolve(index);
      } else {
        _startScan();
      }
      return;
    }
    if (_scanPhase == 0) {
      setState(() => _scanPhase = 1);
      _emitHighlight();
      return;
    }
    final index = _scanRow * _scanCols + _scanCol;
    if (index < widget.options.length) {
      _resolve(index);
    } else {
      // Grid isn't fully filled (e.g. 4 options in a 2x3 grid) and landed on
      // an empty cell -- restart rather than silently doing nothing.
      _startScan();
    }
  }

  // --- joystick --------------------------------------------------------

  void _announce(String option) {
    if (!mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      '$option, selected',
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  Map<String, String> get _vocabMap => VocabMapping.mapWords(
        vocabulary: widget.profile.vocabulary,
        options: _pages ? _slice : widget.options,
      );

  void _applyVocab(String action) {
    if (action == VocabMapping.next) {
      _lastDirection = 'down';
      _stepFromDirection();
    } else if (action == VocabMapping.previous) {
      _lastDirection = 'up';
      _stepFromDirection();
    } else if (action == VocabMapping.select) {
      _resolve(_highlight);
    } else {
      final opts = _pages ? _slice : widget.options;
      final i = opts.indexOf(action);
      if (i >= 0) _resolve(_pageStart + i);
    }
  }

  void _stepBy(int delta) {
    if (widget.options.isEmpty) return;
    if (widget.livePaging && _pages) {
      final local = _highlight - _pageStart;
      final nextLocal = local + delta;
      if (nextLocal >= _slice.length) {
        _goToPage(_page + 1, highlightInPage: 0);
        return;
      }
      if (nextLocal < 0) {
        final prev = (_page - 1 + _pageCount) % _pageCount;
        final start = prev * _perPage;
        final len = math.min(_perPage, widget.options.length - start);
        _goToPage(prev, highlightInPage: math.max(0, len - 1));
        return;
      }
      setState(() => _highlight = _pageStart + nextLocal);
    } else {
      setState(() {
        _highlight = (_highlight + delta + widget.options.length) %
            widget.options.length;
      });
    }
    _announce(widget.options[_highlight]);
    _emitHighlight();
  }

  void _stepFromDirection() {
    final dir = _lastDirection;
    if (dir == null) return;
    Haptics.navigate();
    final delta = (dir == 'up' || dir == 'left') ? -1 : 1;
    _stepBy(delta);
    widget.onRaw('$dir -> ${widget.options[_highlight]}');
  }

  void _onVector(Offset v) {
    final dir = cardinalOf(v, deadZone: 0.45);
    if (dir == _lastDirection) return;
    _lastDirection = dir;
    if (dir == null) {
      _repeater.stop();
    } else {
      _repeater.start();
    }
  }

  // --- resolution ------------------------------------------------------

  void _resolve(int index) {
    Haptics.confirm();
    _scan?.cancel();
    _trackpadPageTimer?.cancel();
    _repeater.stop();
    widget.onResolve(index, widget.options[index]);
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.method) {
      TouchMethod.buttons => _buttons(),
      TouchMethod.joystick => _joystick(),
      TouchMethod.trackpad => _trackpad(),
      TouchMethod.switchScan => _switch(),
    };
  }

  /// Ideal pattern: direct tap. Only [CapabilityProfile.visibleOptionCount]
  /// options are on screen at once -- 2.4's rule that lower precision means
  /// lower interface resolution, not smaller buttons.
  Widget _buttons() {
    return InputOverlay(
      profile: widget.profile,
      content: _fitContent((per, start, slice) {
        return OptionList(
          options: slice,
          highlight: -1,
          textScale: _scale,
          minTargetSize: widget.profile.minTargetSize,
          onTap: (i) {
            setState(() => _highlight = start + i);
            _emitHighlight();
            _resolve(start + i);
          },
        );
      }),
      dock: _vocabDock(
        extra: _pageCount <= 1
            ? null
            : Row(
                children: [
                  Expanded(
                    child: CalibratedButton(
                      label: 'More options',
                      subtitle: 'page ${_page + 1} of $_pageCount',
                      minSize: widget.profile.minTargetSize,
                      textScale: _scale,
                      onPressed: () =>
                          _goToPage(_page + 1, highlightInPage: 0),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget? _vocabDock({Widget? extra}) {
    if (!widget.profile.usesWordVocab) return extra;
    final map = _vocabMap;
    final hint = map.entries.map((e) => '${e.key} → ${e.value}').join(' · ');
    final mic = HoldToSpeak(
      label: hint.isEmpty ? 'Hold to speak a word' : hint,
      height: 88,
      onUtterance: (sounds, heldMs) async {
        final r = await SimulatedSpeechSource(
          phrases: widget.profile.vocabulary,
        ).capture(
          heldMs: heldMs,
          soundCount: sounds,
          clarity: SpeechClarity.partial,
        );
        final action = VocabMapping.resolve(r.transcript, map);
        if (action != null) {
          _applyVocab(action);
        } else {
          widget.onRaw('vocab missed: ${r.transcript}');
        }
      },
    );
    if (extra == null) return mic;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [mic, const SizedBox(height: 8), extra],
    );
  }

  int _localHighlight(int start, List<String> slice) {
    if (slice.isEmpty) return -1;
    final local = _highlight - start;
    if (local < 0 || local >= slice.length) return 0;
    return local;
  }

  /// Fallback pattern: cycle the highlight, press the stick to confirm --
  /// a game menu, which is a pattern most people already know.
  Widget _joystick() => InputOverlay(
        profile: widget.profile,
        content: _fitContent((per, start, slice) {
          return OptionList(
            options: slice,
            highlight: _localHighlight(start, slice),
            textScale: _scale,
            minTargetSize: widget.profile.minTargetSize,
            compact: !widget.livePaging,
          );
        }),
        overlay: JoystickPad(
          size: 170,
          label: 'SELECT',
          onVector: _onVector,
          onPress: () => _resolve(_highlight),
          onRelease: () {
            _lastDirection = null;
            _repeater.stop();
          },
        ),
      );

  /// Fallback pattern: drag to hover, release to select. Position on the pad
  /// maps to position in the list, so the whole list is one gesture away.
  Widget _trackpad() => InputOverlay(
        profile: widget.profile,
        content: _fitContent((per, start, slice) {
          return OptionList(
            options: slice,
            highlight: _localHighlight(start, slice),
            textScale: _scale,
            minTargetSize: widget.profile.minTargetSize,
            compact: !widget.livePaging,
          );
        }),
        dock: SizedBox(
          height: 190,
          child: TrackpadSurface(
            hint: 'drag up and down, let go to choose',
            axisLock: Axis.vertical,
            // A tap moves the highlight without committing, so a stray tap is
            // never a wrong selection.
            onTapAt: (n) => _hover(n.dy),
            onStart: (n) => _hover(n.dy),
            onMove: (n, _) => _hover(n.dy),
            onEnd: (_) => _resolve(_highlight),
          ),
        ),
      );

  void _hover(double y) {
    final n = _slice.length;
    if (n == 0) return;
    final local = (y * n).floor().clamp(0, n - 1);
    final i = _pageStart + local;
    if (i != _highlight) {
      setState(() => _highlight = i);
      _announce(widget.options[i]);
      _emitHighlight();
      widget.onRaw('hover -> ${widget.options[i]}');
    }
    if (widget.livePaging && _pageCount > 1) {
      if (local == n - 1 && !_awaitingLeaveLastSlot) {
        _armTrackpadPage();
      } else {
        _trackpadPageTimer?.cancel();
        _trackpadPageTimer = null;
        if (local < n - 1) _awaitingLeaveLastSlot = false;
      }
    }
  }

  void _armTrackpadPage() {
    if (_trackpadPageTimer != null) return;
    _trackpadPageTimer = Timer(_dwell, () {
      if (!mounted) return;
      _trackpadPageTimer = null;
      _awaitingLeaveLastSlot = true;
      _goToPage(_page + 1, highlightInPage: 0);
    });
  }

  /// Floor case (3.5): row-then-column auto-scan, one press advances the
  /// phase or selects. Live paging scans the current page as a column.
  Widget _switch() => InputOverlay(
        profile: widget.profile,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: _fitContent((per, start, slice) => _scanGrid(slice)),
        ),
        dock: SwitchTrigger(
          label: 'PRESS TO SELECT',
          onPress: _switchPress,
        ),
      );

  Widget _scanGrid(List<String> options) {
    final scheme = Theme.of(context).colorScheme;
    final cols = widget.livePaging
        ? 1
        : math.max(1, math.sqrt(widget.options.length).ceil());
    final rows = (options.length / cols).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var c = 0; c < cols; c++)
                  Expanded(child: _scanCell(scheme, r, c, cols, options)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _scanCell(
    ColorScheme scheme,
    int row,
    int col,
    int cols,
    List<String> options,
  ) {
    final index = row * cols + col;
    final has = index < options.length;
    final rowActive = row == _scanRow;
    final cellActive = _scanPhase == 1 && rowActive && col == _scanCol;
    final rowOnlyActive = _scanPhase == 0 && rowActive;
    final minH = widget.livePaging ? widget.profile.minTargetSize : 56.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        constraints: BoxConstraints(minHeight: minH),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: !has
              ? Colors.transparent
              : cellActive
                  ? scheme.primary
                  : rowOnlyActive
                      ? scheme.primaryContainer.withValues(alpha: 0.55)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: has
              ? Border.all(
                  color: cellActive || rowOnlyActive
                      ? scheme.primary
                      : scheme.outlineVariant,
                  width: cellActive ? 3 : 1,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: has
            ? Semantics(
                button: true,
                selected: cellActive,
                label: options[index],
                child: Text(
                  options[index],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14 * _scale,
                    fontWeight: cellActive ? FontWeight.w800 : FontWeight.w600,
                    color: cellActive ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
