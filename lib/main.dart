// Math Practice (Flutter / Android)
// Addition, Multiplication, Subtraction, Division - paper style worksheets.
//
// * Tap any box -> number pad (bottom sheet).
// * Carry boxes: the pad has a cross button, long-press on the box does the same.
// * Subtraction: tap a top digit -> a light grey "1" (borrow) appears on its left.
//   Writing a carry in the box under the next column removes that light 1.
// * Division: Rough pad (2 digit x 1 digit, not checked). It sits beside the
//   worksheet on wide screens and below it on tall / narrow screens.
// * The worksheet is always scaled to fit the screen (FittedBox) - no scrolling.

import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const MathApp());

// ---------------------------------------------------------------------------
// Constants / helpers
// ---------------------------------------------------------------------------
const Color kInk = Color(0xFF1A237E); // blue "pen" colour
const Color kCross = Color(0xFFD32F2F);
const Color kGood = Color(0xFF2E7D32);
const Color kBad = Color(0xFFC62828);

const double kBox = 52; // answer box
const double kCol = 58; // digit column width
const double kRowH = 60; // row height of a normal row
const double kCarry = 40; // carry box
const double kCardPad = 14;

final Random _rng = Random();

int randInt(int a, int b) => a + _rng.nextInt(b - a + 1); // inclusive

int randomNumber() =>
    _rng.nextDouble() < 0.5 ? randInt(100, 999) : randInt(1000, 9999);

Color soft(int hex, int alpha) => Color((alpha << 24) | (hex & 0x00FFFFFF));

Widget staticText(String t, [double size = 34]) => Text(
      t,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: kInk,
      ),
    );

Map<int, Widget> digitsRow(String s, int Function(int) col) => {
      for (var j = 0; j < s.length; j++) col(s.length - 1 - j): staticText(s[j]),
    };

String totalText(List<BoxModel> totals) {
  // totals are stored ones-first
  if (!totals.any((b) => b.value.isNotEmpty)) return '';
  final s = totals.reversed.map((b) => b.value.isEmpty ? '_' : b.value).join();
  return s.replaceFirst(RegExp(r'^_+'), '');
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------
class BoxModel {
  BoxModel({this.expected = '', this.isCarry = false, this.allowTen = false});

  final String expected;
  final bool isCarry;
  final bool allowTen;

  String value = '';
  bool crossed = false;
  int status = 0; // 0 = none, 1 = ok, 2 = bad

  void reset() {
    value = '';
    crossed = false;
    status = 0;
  }

  void apply(String key) {
    if (key == 'clear') {
      value = '';
      crossed = false;
    } else if (key == 'cross') {
      crossed = !crossed;
    } else {
      value = key;
    }
    status = 0;
  }
}

class TopModel {
  TopModel(this.ch);
  final String ch;
  bool borrowed = false;
}

/// Passed to the problems while they build their widgets.
class BoardCtx {
  BoardCtx({required this.onKey, required this.refresh});
  final void Function(BoxModel, String) onKey;
  final VoidCallback refresh;

  Widget box(BoxModel m, double size) =>
      DigitBox(m: m, size: size, onKey: onKey);
}

abstract class Problem {
  final List<BoxModel> checks = []; // boxes that are checked
  final List<BoxModel> carries = []; // carry boxes (not checked)
  final List<BoxModel> totals = []; // boxes shown in the "Ans:" bar (ones first)
  bool showOk = false;

  bool get hasRough => false;
  Size get naturalSize => const Size(0, 0);

  Widget buildBoard(BoardCtx cx);

  String get answerText => 'Ans: ${totalText(totals)}';

  void onBoxChanged(BoxModel b) {}
  void clearExtra() {}

  /// Boxes for the digits of [text] starting at [startPlace]. Returns place -> box.
  /// extra = one more empty-expected box on the left (hides the digit count).
  Map<int, BoxModel> ansRow(
    String text,
    int startPlace, {
    bool extra = false,
    bool total = false,
  }) {
    final expected = <String>[...text.split('').reversed, if (extra) ''];
    final out = <int, BoxModel>{};
    for (var i = 0; i < expected.length; i++) {
      final b = BoxModel(expected: expected[i]);
      out[startPlace + i] = b;
      checks.add(b);
      if (total) totals.add(b);
    }
    return out;
  }

  bool check() {
    var all = true;
    for (final b in checks) {
      final good = b.value == b.expected;
      b.status = good ? (b.expected.isEmpty ? 0 : 1) : 2;
      all = all && good;
    }
    showOk = all;
    return all;
  }

  void clearAll() {
    for (final b in [...checks, ...carries]) {
      b.reset();
    }
    showOk = false;
    clearExtra();
  }
}

// ---------------------------------------------------------------------------
// Grid helper: rows of fixed-width columns (so everything lines up like paper)
// ---------------------------------------------------------------------------
class Sheet {
  Sheet(this.colW);
  final List<double> colW;
  final List<Widget> _rows = [];

  void row(Map<int, Widget> cells, double h) {
    _rows.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var c = 0; c < colW.length; c++)
            SizedBox(
              width: colW[c],
              height: h,
              child: Center(child: cells[c]),
            ),
        ],
      ),
    );
  }

  /// Horizontal pen line over columns [from]..[to]. bracket = also start the
  /// vertical line of the long-division bracket at column [from].
  void rule(int from, int to, {bool bracket = false}) {
    _rows.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var c = 0; c < colW.length; c++)
            SizedBox(
              width: colW[c],
              height: 11,
              child: (c >= from && c <= to)
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: Container(height: 3, color: kInk),
                          ),
                        ),
                        if (bracket && c == from)
                          Positioned(
                            left: 0,
                            top: 4,
                            bottom: 0,
                            width: 3,
                            child: Container(color: kInk),
                          ),
                      ],
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Widget build() => Column(mainAxisSize: MainAxisSize.min, children: _rows);
}

Widget vBar() => Align(
      alignment: Alignment.centerLeft,
      child: Container(width: 3, color: kInk),
    );

// ---------------------------------------------------------------------------
// Number pad (bottom sheet)
// ---------------------------------------------------------------------------
Future<String?> showNumPad(
  BuildContext context, {
  required bool allowCross,
  required bool crossed,
  required bool allowTen,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 420),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      Widget key(String label, String value) => Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                height: 58,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F5FB),
                    foregroundColor: kInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFC5CAE9)),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(value),
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );

      Widget rowOf(List<Widget> kids) => Row(children: kids);

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              rowOf([key('1', '1'), key('2', '2'), key('3', '3')]),
              rowOf([key('4', '4'), key('5', '5'), key('6', '6')]),
              rowOf([key('7', '7'), key('8', '8'), key('9', '9')]),
              rowOf([
                key('⌫', 'clear'),
                key('0', '0'),
                if (allowCross)
                  key(crossed ? '↺' : '✕', 'cross')
                else
                  const Expanded(child: SizedBox()),
              ]),
              if (allowTen) rowOf([key('10', '10')]),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------
class DigitBox extends StatelessWidget {
  const DigitBox({
    super.key,
    required this.m,
    required this.size,
    required this.onKey,
  });

  final BoxModel m;
  final double size;
  final void Function(BoxModel, String) onKey;

  @override
  Widget build(BuildContext context) {
    final border = m.status == 1 ? kGood : (m.status == 2 ? kBad : kInk);
    final bg = m.status == 1
        ? const Color(0xFFE8F5E9)
        : (m.status == 2 ? const Color(0xFFFFEBEE) : Colors.white);
    final fg = m.crossed ? const Color(0xFF9E9E9E) : kInk;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final k = await showNumPad(
          context,
          allowCross: m.isCarry,
          crossed: m.crossed,
          allowTen: m.allowTen,
        );
        if (k != null) onKey(m, k);
      },
      onLongPress: m.isCarry ? () => onKey(m, 'cross') : null,
      child: CustomPaint(
        foregroundPainter: m.crossed ? _CrossPainter() : null,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            m.value,
            style: TextStyle(
              fontSize: size >= 44 ? size * 0.56 : size * 0.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = kCross
      ..strokeWidth = max(2.0, s.width * 0.06)
      ..strokeCap = StrokeCap.round;
    final m = max(3.0, s.width * 0.1);
    canvas.drawLine(Offset(m, m), Offset(s.width - m, s.height - m), p);
    canvas.drawLine(Offset(s.width - m, m), Offset(m, s.height - m), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Top-row digit of a subtraction: tap -> light grey "1" shows on its left.
Widget topDigit(TopModel m, BoardCtx cx) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        m.borrowed = !m.borrowed;
        cx.refresh();
      },
      child: SizedBox(
        width: 54,
        height: 54,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (m.borrowed)
                Transform.translate(
                  offset: const Offset(0, -8),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB0B0B0),
                    ),
                  ),
                ),
              staticText(m.ch),
            ],
          ),
        ),
      ),
    );

Widget okBadge() => Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kInk, width: 3),
      ),
      child: const Text(
        'OK',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: kInk,
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Addition (3 rows of 3-4 digits)
// ---------------------------------------------------------------------------
class AdditionProblem extends Problem {
  AdditionProblem() {
    nums = List<int>.generate(3, (_) => randomNumber());
    st = '${nums.reduce((a, b) => a + b)}';
    L = st.length;
    for (var p = 1; p < L; p++) {
      final b = BoxModel(isCarry: true);
      carry[p] = b;
      carries.add(b);
    }
    ans = ansRow(st, 0, total: true);
  }

  late final List<int> nums;
  late final String st;
  late final int L;
  late final Map<int, BoxModel> ans;
  final Map<int, BoxModel> carry = {};

  @override
  Widget buildBoard(BoardCtx cx) {
    final sh = Sheet(<double>[42, ...List<double>.filled(L, kCol)]);
    int col(int p) => L - p;

    sh.row({
      for (final e in carry.entries) col(e.key): cx.box(e.value, kCarry),
    }, 48);
    for (var i = 0; i < 3; i++) {
      sh.row({
        if (i == 2) 0: staticText('+', 30),
        ...digitsRow('${nums[i]}', col),
      }, kRowH);
    }
    sh.rule(0, L);
    sh.row({
      for (final e in ans.entries) col(e.key): cx.box(e.value, kBox),
    }, kRowH);
    return sh.build();
  }
}

// ---------------------------------------------------------------------------
// Multiplication (4-5 digit x 2 digit)
// ---------------------------------------------------------------------------
class MultiplicationProblem extends Problem {
  MultiplicationProblem() {
    final nd = randInt(4, 5);
    final digits = <int>[
      randInt(1, 9),
      for (var i = 0; i < nd - 1; i++) randInt(0, 9),
    ];
    final a = int.parse(digits.join());
    final t = randInt(2, 9); // tens digit of the multiplier
    final o = randInt(2, 9); // ones digit of the multiplier
    final b = t * 10 + o;

    sa = '$a';
    sb = '$b';
    final s1 = '${a * o}';
    final s2 = '${a * t}';
    final st = '${a * b}';
    L = st.length + 1; // +1 column for the extra box on the left

    for (var p = 1; p < nd; p++) {
      final c1 = BoxModel(isCarry: true);
      final c2 = BoxModel(isCarry: true);
      carry1[p] = c1;
      carry2[p] = c2;
      carries.addAll([c1, c2]);
    }
    row1 = ansRow(s1, 0, extra: true); // a x ones digit
    row2 = ansRow(s2, 1, extra: true); // a x tens digit (shifted)
    row3 = ansRow(st, 0, extra: true, total: true);
  }

  late final String sa, sb;
  late final int L;
  late final Map<int, BoxModel> row1, row2, row3;
  final Map<int, BoxModel> carry1 = {};
  final Map<int, BoxModel> carry2 = {};

  @override
  Widget buildBoard(BoardCtx cx) {
    final sh = Sheet(<double>[42, ...List<double>.filled(L, kCol)]);
    int col(int p) => L - p;
    Map<int, Widget> boxes(Map<int, BoxModel> m, double size) => {
          for (final e in m.entries) col(e.key): cx.box(e.value, size),
        };

    sh.row(boxes(carry1, kCarry), 48);
    sh.row(boxes(carry2, kCarry), 48);
    sh.row(digitsRow(sa, col), kRowH);
    sh.row({0: staticText('×', 30), ...digitsRow(sb, col)}, kRowH);
    sh.rule(0, L);
    sh.row(boxes(row1, kBox), kRowH);
    sh.row({col(0): staticText('×', 26), ...boxes(row2, kBox)}, kRowH);
    sh.rule(0, L);
    sh.row(boxes(row3, kBox), kRowH);
    return sh.build();
  }
}

// ---------------------------------------------------------------------------
// Subtraction (2 rows of 3-4 digits)
// ---------------------------------------------------------------------------
class SubtractionProblem extends Problem {
  SubtractionProblem() {
    var x = randomNumber();
    var y = randomNumber();
    while (x == y) {
      y = randomNumber();
    }
    if (x < y) {
      final tmp = x;
      x = y;
      y = tmp;
    }
    sa = '$x';
    sb = '$y';
    sr = '${x - y}';
    L = sa.length;
    for (var p = 0; p < L; p++) {
      tops[p] = TopModel(sa[L - 1 - p]);
      final c = BoxModel(isCarry: true, allowTen: true);
      carry[p] = c;
      carries.add(c);
      carryPlace[c] = p;
    }
    ans = ansRow(sr, 0, total: true);
  }

  late final String sa, sb, sr;
  late final int L;
  late final Map<int, BoxModel> ans;
  final Map<int, TopModel> tops = {};
  final Map<int, BoxModel> carry = {};
  final Map<BoxModel, int> carryPlace = {};

  @override
  void onBoxChanged(BoxModel b) {
    // a value in the carry box of place p uses up the borrowed 1 at place p-1
    final p = carryPlace[b];
    if (p != null && b.value.isNotEmpty) {
      tops[p - 1]?.borrowed = false;
    }
  }

  @override
  void clearExtra() {
    for (final t in tops.values) {
      t.borrowed = false;
    }
  }

  @override
  Widget buildBoard(BoardCtx cx) {
    final sh = Sheet(<double>[42, ...List<double>.filled(L, kCol)]);
    int col(int p) => L - p;

    sh.row({
      for (var p = 0; p < L; p++) col(p): topDigit(tops[p]!, cx),
    }, kRowH);
    sh.row({0: staticText('−', 30), ...digitsRow(sb, col)}, kRowH);
    sh.row({
      for (var p = 0; p < L; p++) col(p): cx.box(carry[p]!, kCarry),
    }, 48);
    sh.rule(0, L);
    sh.row({
      for (final e in ans.entries) col(e.key): cx.box(e.value, kBox),
    }, kRowH);
    return sh.build();
  }
}

// ---------------------------------------------------------------------------
// Division (4 digit / 2 digit -> 3 digit quotient + remainder)
// ---------------------------------------------------------------------------
class _Step {
  _Step(this.boxes, this.minus, this.ruleBefore);
  final List<BoxModel> boxes;
  final bool minus;
  final bool ruleBefore;
}

class DivisionProblem extends Problem {
  DivisionProblem() {
    d = randInt(11, 50);
    final qMax = (9999 - (d - 1)) ~/ d;
    var q = randInt(111, qMax);
    while ('$q'.contains('0')) {
      q = randInt(111, qMax);
    }
    final r = randInt(0, d - 1);
    final n = q * d + r; // 4 digit dividend
    digs = '$n';

    // long division, step by step
    final p1 = int.parse(digs.substring(0, 2));
    final prod1 = (p1 ~/ d) * d;
    final p2 = (p1 - prod1) * 10 + int.parse(digs[2]);
    final prod2 = (p2 ~/ d) * d;
    final p3 = (p2 - prod2) * 10 + int.parse(digs[3]);
    final prod3 = (p3 ~/ d) * d;
    final rem = p3 - prod3;

    final qs = '$q';
    for (var i = 0; i < 3; i++) {
      final b = BoxModel(expected: qs[i]);
      qBoxes.add(b);
      checks.add(b);
    }

    _Step mk(String text, int endJ, {required bool minus, required bool rule}) {
      final startJ = endJ - text.length + 1;
      final boxes = <BoxModel>[];
      for (var j = 0; j < 4; j++) {
        final inside = j >= startJ && j <= endJ;
        final b = BoxModel(expected: inside ? text[j - startJ] : '');
        boxes.add(b);
        checks.add(b);
      }
      return _Step(boxes, minus, rule);
    }

    steps.addAll([
      mk('$prod1', 1, minus: true, rule: false), // divisor x 1st quotient digit
      mk('$p2', 2, minus: false, rule: true), // remainder + next digit
      mk('$prod2', 2, minus: true, rule: false),
      mk('$p3', 3, minus: false, rule: true),
      mk('$prod3', 3, minus: true, rule: false),
      mk('$rem', 3, minus: false, rule: true), // final remainder
    ]);
  }

  late final int d;
  late final String digs;
  final List<BoxModel> qBoxes = [];
  final List<_Step> steps = [];

  @override
  bool get hasRough => true;

  // approximate natural size of the board, used to choose the rough pad position
  @override
  Size get naturalSize => const Size(274, 428);

  List<BoxModel> get remBoxes => steps.last.boxes;

  @override
  String get answerText {
    final q = qBoxes.map((b) => b.value.isEmpty ? '_' : b.value).join();
    final r = remBoxes.map((b) => b.value).join();
    return 'Quotient: $q    Remainder: ${r.isEmpty ? '_' : r}';
  }

  @override
  Widget buildBoard(BoardCtx cx) {
    const double db = 46; // compact box size
    const double rowH = 48;
    final sh = Sheet(<double>[62, 12, 50, 50, 50, 50]);
    int c(int j) => 2 + j; // grid column of dividend digit j (0..3)

    // quotient boxes above the last three dividend digits
    sh.row({
      for (var i = 0; i < 3; i++) c(i + 1): cx.box(qBoxes[i], db),
    }, rowH);

    // bracket, divisor, dividend
    sh.rule(1, 5, bracket: true);
    sh.row({
      0: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: staticText('$d', 30),
        ),
      ),
      1: vBar(),
      for (var j = 0; j < 4; j++) c(j): staticText(digs[j], 30),
    }, rowH);

    for (final s in steps) {
      if (s.ruleBefore) sh.rule(2, 5);
      sh.row({
        if (s.minus)
          0: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: staticText('−', 28),
            ),
          ),
        for (var j = 0; j < 4; j++) c(j): cx.box(s.boxes[j], db),
      }, rowH);
    }
    return sh.build();
  }
}

// ---------------------------------------------------------------------------
// Rough pad (Division only) - free 2 digit x 1 digit multiplication, not checked
// ---------------------------------------------------------------------------
const Size kRoughSize = Size(190, 320); // approximate natural size

class RoughModel {
  final BoxModel carry = BoxModel(isCarry: true);
  final List<BoxModel> mcand = [BoxModel(), BoxModel()]; // tens, ones
  final BoxModel mult = BoxModel();
  final List<BoxModel> prod = [BoxModel(), BoxModel(), BoxModel()];

  void clear() {
    for (final b in [carry, ...mcand, mult, ...prod]) {
      b.reset();
    }
  }
}

class RoughPad extends StatelessWidget {
  const RoughPad({
    super.key,
    required this.model,
    required this.accent,
    required this.cx,
    required this.onClear,
  });

  final RoughModel model;
  final int accent;
  final BoardCtx cx;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const double bs = 40;
    final sh = Sheet(<double>[28, 44, 44, 44]);
    sh.row({2: cx.box(model.carry, 30)}, 38);
    sh.row({2: cx.box(model.mcand[0], bs), 3: cx.box(model.mcand[1], bs)}, 48);
    sh.row({0: staticText('×', 26), 3: cx.box(model.mult, bs)}, 48);
    sh.rule(0, 3);
    sh.row({
      1: cx.box(model.prod[0], bs),
      2: cx.box(model.prod[1], bs),
      3: cx.box(model.prod[2], bs),
    }, 48);

    final a = Color(accent);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: soft(accent, 160), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rough',
            style: TextStyle(
              color: a,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: a,
            ),
          ),
          const Text(
            '2 digit × 1 digit',
            style: TextStyle(color: Color(0xFF777777), fontSize: 12),
          ),
          const SizedBox(height: 6),
          sh.build(),
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: a,
                side: BorderSide(color: a, width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 32),
              ),
              onPressed: onClear,
              child: const Text('Clear rough',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App / screens
// ---------------------------------------------------------------------------
class OpSpec {
  OpSpec({
    required this.id,
    required this.sign,
    required this.title,
    required this.desc,
    required this.accent,
    required this.create,
  });
  final String id, sign, title, desc;
  final int accent;
  final Problem Function() create;
}

final List<OpSpec> kOps = [
  OpSpec(
    id: 'add',
    sign: '+',
    title: 'Addition',
    desc: '3 numbers, 3-4 digits each',
    accent: 0xFF2A9D8F,
    create: () => AdditionProblem(),
  ),
  OpSpec(
    id: 'mul',
    sign: '×',
    title: 'Multiplication',
    desc: '4-5 digits × 2 digits',
    accent: 0xFFF08C00,
    create: () => MultiplicationProblem(),
  ),
  OpSpec(
    id: 'sub',
    sign: '−',
    title: 'Subtraction',
    desc: '2 numbers, 3-4 digits each',
    accent: 0xFFE05260,
    create: () => SubtractionProblem(),
  ),
  OpSpec(
    id: 'div',
    sign: '÷',
    title: 'Division',
    desc: '4 digits ÷ 2 digits, with a rough pad',
    accent: 0xFF7C4DFF,
    create: () => DivisionProblem(),
  ),
];

// unfinished problems survive going back to the home page
final Map<String, Problem> _savedProblems = {};
final Map<String, RoughModel> _savedRough = {};

class MathApp extends StatelessWidget {
  const MathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Practice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kInk,
      ),
      home: const HomeScreen(),
    );
  }
}

class PaperBackground extends StatelessWidget {
  const PaperBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3F6FF), Color(0xFFFFF7EC)],
        ),
      ),
      child: child,
    );
  }
}

// ---- Home ------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              const double cw = 240, ch = 220, gap = 16, side = 16;
              final n = kOps.length;

              // choose 4 / 2 / 1 columns - whichever gives the biggest cards
              var bestCols = 2;
              var bestU = 0.0;
              for (final cols in const [4, 2, 1]) {
                final rows = (n + cols - 1) ~/ cols;
                final uw =
                    (c.maxWidth - 2 * side - gap * (cols - 1)) / (cols * cw);
                final uh = (c.maxHeight - 150 - gap * (rows - 1)) / (rows * ch);
                final u = min(uw, uh);
                if (u > bestU * 1.001) {
                  bestU = u;
                  bestCols = cols;
                }
              }
              final u = bestU.clamp(0.4, 1.3).toDouble();
              final ts = u.clamp(0.6, 1.0).toDouble();

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Math Practice',
                          style: TextStyle(
                            color: kInk,
                            fontSize: 44 * ts,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Pick an operation and solve it on a paper-style worksheet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF6B7280),
                              fontSize: 16 * ts,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: bestCols * cw * u + (bestCols - 1) * gap + 2,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final spec in kOps)
                                SizedBox(
                                  width: cw * u,
                                  height: ch * u,
                                  child: FittedBox(
                                    child: SizedBox(
                                      width: cw,
                                      height: ch,
                                      child: HomeCard(
                                        spec: spec,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                ProblemScreen(spec: spec),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.spec, required this.onTap});
  final OpSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE1E5F3), width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: soft(spec.accent, 40),
        highlightColor: soft(spec.accent, 22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(spec.accent),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  spec.sign,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                spec.title,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spec.desc,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Practice page -----------------------------------------------------------
ButtonStyle _outlined(Color a) => OutlinedButton.styleFrom(
      foregroundColor: a,
      backgroundColor: Colors.white,
      side: BorderSide(color: a, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );

ButtonStyle _filled(Color a) => FilledButton.styleFrom(
      backgroundColor: a,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    );

class ProblemScreen extends StatefulWidget {
  const ProblemScreen({super.key, required this.spec});
  final OpSpec spec;

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen> {
  late Problem problem;
  late RoughModel rough;
  String statusText = '';
  bool? statusGood;

  @override
  void initState() {
    super.initState();
    final id = widget.spec.id;
    problem = _savedProblems[id] ?? widget.spec.create();
    _savedProblems[id] = problem;
    rough = _savedRough[id] ?? RoughModel();
    _savedRough[id] = rough;
  }

  void _newProblem() {
    setState(() {
      problem = widget.spec.create();
      _savedProblems[widget.spec.id] = problem;
      statusText = '';
      statusGood = null;
    });
  }

  void _onKey(BoxModel m, String key) {
    setState(() {
      m.apply(key);
      problem.showOk = false;
      statusText = '';
      statusGood = null;
      problem.onBoxChanged(m);
    });
  }

  void _check() {
    setState(() {
      final ok = problem.check();
      statusGood = ok;
      statusText = ok
          ? 'Perfect! Shob thik ache ✔'
          : 'Kichu box bhul ba khali — lal box gulo abar dekho.';
    });
  }

  void _clearAll() {
    setState(() {
      problem.clearAll();
      statusText = '';
      statusGood = null;
    });
  }

  /// Rough pad beside the worksheet or below it - whichever gives bigger boxes.
  bool _preferHorizontal(Size avail, Size board, Size roughSize) {
    const pad = kCardPad * 2;
    const gap = 16.0;
    final hw = board.width + gap + roughSize.width + pad;
    final hh = max(board.height, roughSize.height) + pad;
    final vw = max(board.width, roughSize.width) + pad;
    final vh = board.height + gap + roughSize.height + pad;
    final sh = min(avail.width / hw, avail.height / hh);
    final sv = min(avail.width / vw, avail.height / vh);
    return sh >= sv;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final accent = Color(spec.accent);

    final cx = BoardCtx(onKey: _onKey, refresh: () => setState(() {}));
    final roughCx = BoardCtx(
      onKey: (m, k) => setState(() => m.apply(k)),
      refresh: () => setState(() {}),
    );

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Column(
              children: [
                // header
                Row(
                  children: [
                    OutlinedButton(
                      style: _outlined(accent),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('←  Home',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        '${spec.sign}  ${spec.title}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // worksheet - always scaled to fit
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final board = problem.buildBoard(cx);
                      Widget content = board;
                      if (problem.hasRough) {
                        final horizontal = _preferHorizontal(
                          Size(c.maxWidth, c.maxHeight),
                          problem.naturalSize,
                          kRoughSize,
                        );
                        final pad = RoughPad(
                          model: rough,
                          accent: spec.accent,
                          cx: roughCx,
                          onClear: () => setState(rough.clear),
                        );
                        content = Flex(
                          direction: horizontal ? Axis.horizontal : Axis.vertical,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: horizontal
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.center,
                          children: [
                            board,
                            SizedBox(
                              width: horizontal ? 16 : 0,
                              height: horizontal ? 0 : 16,
                            ),
                            pad,
                          ],
                        );
                      }
                      final card = Container(
                        padding: const EdgeInsets.all(kCardPad),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: const Color(0xFFDFE3F3), width: 2),
                        ),
                        child: content,
                      );
                      return Center(
                        child: FittedBox(fit: BoxFit.contain, child: card),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // answer bar
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: soft(spec.accent, 34),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      problem.answerText,
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // status line (+ OK badge)
                SizedBox(
                  height: 46,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (problem.showOk) ...[
                        okBadge(),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          statusText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: statusGood == null
                                ? const Color(0xFF555555)
                                : (statusGood! ? kGood : kBad),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: _outlined(accent),
                        onPressed: _clearAll,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Clear all',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        style: _filled(accent),
                        onPressed: _check,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Check  ✔',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: _outlined(accent),
                        onPressed: _newProblem,
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('New problem',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
