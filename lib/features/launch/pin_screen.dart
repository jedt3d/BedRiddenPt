import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../data/patient_repository.dart';
import '../../data/volunteer_store.dart';
import '../../shared/patient_avatar.dart';
import '../../theme/tokens.dart';

/// PIN entry, every launch (SPEC §7.1, Figma frames 02/04). The PIN is the
/// constant [appPin]; the 6th digit checks it. Right: Home replaces the
/// stack. Wrong: the dots shake and clear. No lockout.
///
/// The top-right ⋮ opens a [CupertinoActionSheet] with Reset sample data
/// (SPEC §6, Figma 05/06). It works before the PIN (accepted risk) and keeps
/// the volunteer's name: [PatientRepository.resetSampleData] only touches
/// the database.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

/// Figma 04: keys are 78 pt circles, the avatar is 72 pt.
const double _keySize = 78;
const double _avatarSize = 72;

/// Figma 04 "Initials avatar" fill: color/accent at 15 %. tokens.json has no
/// opacity for accent yet (asked the hub to add one).
const double _avatarTintOpacity = 0.15;

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  bool get _busy => _shake.isAnimating || _entered.length == appPin.length;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _digit(String d) {
    if (_busy) return;
    setState(() => _entered += d);
    if (_entered.length == appPin.length) _check();
  }

  void _delete() {
    if (_busy || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _check() async {
    if (_entered == appPin) {
      await Routes.replaceAllWith(context, Routes.home);
      return;
    }
    HapticFeedback.heavyImpact();
    await _shake.forward(from: 0);
    if (mounted) setState(() => _entered = '');
  }

  Future<void> _openMenu() async {
    final reset = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        title: const Text('Sample data'),
        message: const Text('Works before you log in. Your name is kept.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(sheet, true),
            child: const Text('Reset sample data'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheet, false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (reset != true || !mounted) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (alert) => CupertinoAlertDialog(
        title: const Text('Reset sample data?'),
        content: const Text(
          'All patients on this phone will be replaced with $sampleSeedCount '
          'random patients from the sample pool. Your name is kept.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(alert, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(alert, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.read(context).patients.resetSampleData();
  }

  @override
  Widget build(BuildContext context) {
    final name = AppScope.of(context).volunteer.name?.trim() ?? '';
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrouped,
      child: SafeArea(
        // Fills the screen; scrolls only if it is shorter than the content.
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(child: _body(name, firstName)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(String name, String firstName) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            key: const ValueKey('pin-more'),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
            onPressed: _openMenu,
            child: const Icon(
              CupertinoIcons.ellipsis_vertical,
              semanticLabel: 'More',
              color: AppColors.accent,
            ),
          ),
        ),
        const Spacer(flex: 2),
        const SizedBox(height: AppSpace.s40),
        _Avatar(initials: initialsOf(name)),
        const SizedBox(height: AppSpace.s12),
        Text(
          firstName.isEmpty ? 'Welcome back' : 'Welcome back, $firstName',
          style: AppText.title2Emphasized.copyWith(
            color: AppColors.labelPrimary,
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Text(
          'Enter your ${appPin.length}-digit PIN',
          style: AppText.subheadline.copyWith(color: AppColors.labelSecondary),
        ),
        const SizedBox(height: AppSpace.s30),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            // Three decaying side-to-side swings.
            offset: Offset(
              AppSpace.s12 *
                  (1 - _shake.value) *
                  math.sin(_shake.value * 6 * math.pi),
              0,
            ),
            child: child,
          ),
          child: _Dots(filled: _entered.length, total: appPin.length),
        ),
        const Spacer(flex: 3),
        const SizedBox(height: AppSpace.s40),
        _Keypad(onDigit: _digit, onDelete: _delete),
        const SizedBox(height: AppSpace.s40),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent.withValues(alpha: _avatarTintOpacity),
      ),
      child: initials.isEmpty
          ? const Icon(
              CupertinoIcons.person_fill,
              size: AppSpace.s40,
              color: AppColors.accent,
            )
          : Text(
              initials,
              style: AppText.initials.copyWith(color: AppColors.accent),
            ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$filled of $total digits entered',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s18),
            Container(
              key: ValueKey('pin-dot-$i'),
              width: AppSpace.s14,
              height: AppSpace.s14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled
                    ? AppColors.labelPrimary
                    : AppColors.transparent,
                border: Border.all(color: AppColors.labelPrimary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onDelete});

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  static const _letters = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
  };

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s24),
          keys[i],
        ],
      ],
    );
    Widget digit(String d) =>
        _Key(digit: d, letters: _letters[d], onTap: () => onDigit(d));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          row([for (final d in r) digit(d)]),
          const SizedBox(height: AppSpace.s16),
        ],
        row([
          const SizedBox.square(dimension: _keySize),
          digit('0'),
          SizedBox.square(
            dimension: _keySize,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onDelete,
              child: Text(
                'Delete',
                style: AppText.body.copyWith(color: AppColors.labelPrimary),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.digit, required this.letters, required this.onTap});

  final String digit;
  final String? letters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: _keySize,
        height: _keySize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.fillKey,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: AppText.keypadDigit.copyWith(
                color: AppColors.labelPrimary,
                height: 1,
              ),
            ),
            if (letters != null)
              Text(
                letters!,
                style: AppText.keyLetters.copyWith(
                  color: AppColors.labelPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
