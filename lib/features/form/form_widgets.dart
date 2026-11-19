// Building blocks of the Add / Edit form (Figma frames 19–25).

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';

/// Width of the icon + label column, so values line up (Figma: x 200).
const _labelColumn = 168.0;

/// Height of the relationship / subdistrict picker sheet (Figma frame 21).
const _pickerHeight = 260.0;

/// Row height of a picker wheel.
const _pickerItemExtent = 36.0;

/// One field: icon, label, then [child] in the value column.
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.below,
    this.error,
  });

  final IconData icon;
  final String label;
  final Widget child;

  /// Shown under the row, e.g. the care-need chips.
  final Widget? below;

  /// A validation message shown in red under the row (Figma frame 22).
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s11,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: _labelColumn,
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: AppSpace.s20,
                      color: AppColors.iconSecondary,
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Text(
                        label,
                        style: AppText.body.copyWith(
                          color: AppColors.labelPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
          ?below,
          if (error != null) FieldError(text: error!),
        ],
      ),
    );
  }
}

/// "(!) A patient with this national ID already exists." (Figma frame 22).
class FieldError extends StatelessWidget {
  const FieldError({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: AppSpace.s16,
            color: AppColors.actionDestructive,
          ),
          const SizedBox(width: AppSpace.s6),
          Expanded(
            child: Text(
              text,
              style: AppText.footnote.copyWith(
                color: AppColors.actionDestructive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A borderless text field for the value column.
class FieldText extends StatelessWidget {
  const FieldText({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.color = AppColors.labelPrimary,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField.borderless(
      controller: controller,
      placeholder: placeholder,
      placeholderStyle: AppText.body.copyWith(color: AppColors.labelQuaternary),
      style: AppText.body.copyWith(color: color),
      padding: EdgeInsets.zero,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: 1,
      maxLines: maxLines,
    );
  }
}

/// Reformats the text with [format] and puts the cursor at the end.
class ReformatInput extends TextInputFormatter {
  ReformatInput(this.format);

  final String Function(String) format;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// A value that opens a picker: the text (or a grey placeholder) and ⌃⌄.
class PickerValue extends StatelessWidget {
  const PickerValue({
    super.key,
    required this.text,
    required this.onTap,
    this.placeholder = 'Choose',
  });

  final String? text;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text ?? placeholder,
              style: AppText.body.copyWith(
                color: text == null
                    ? AppColors.labelQuaternary
                    : AppColors.labelPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          const Icon(
            CupertinoIcons.chevron_up_chevron_down,
            size: AppSpace.s16,
            color: AppColors.iconSecondary,
          ),
        ],
      ),
    );
  }
}

/// A bottom sheet with a title, Done and a wheel of [options] (Figma frame
/// 21). Returns the option shown when Done is tapped, or null when dismissed.
Future<T?> showChoicePicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) label,
  T? selected,
}) {
  var index = selected == null ? 0 : options.indexOf(selected);
  if (index < 0) index = 0;
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) => Container(
      height: _pickerHeight,
      color: AppColors.bgSurface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              color: AppColors.bgChrome,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.headline.copyWith(
                        color: AppColors.labelPrimary,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(options[index]),
                    child: Text(
                      'Done',
                      style: AppText.headline.copyWith(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: _pickerItemExtent,
                scrollController: FixedExtentScrollController(
                  initialItem: index,
                ),
                onSelectedItemChanged: (i) => index = i,
                children: [
                  for (final o in options)
                    Center(
                      child: Text(
                        label(o),
                        style: AppText.pickerRow.copyWith(
                          color: AppColors.labelPrimary,
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
}

/// The ADL score − / + stepper.
class AdlStepper extends StatelessWidget {
  const AdlStepper({super.key, required this.onMinus, required this.onPlus});

  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    Widget button(String symbol, VoidCallback? onPressed) => CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s14),
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Text(
        symbol,
        style: AppText.stepperSymbol.copyWith(
          color: onPressed == null
              ? AppColors.labelQuaternary
              : AppColors.labelPrimary,
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.fillTertiary.withValues(
          alpha: AppColors.fillTertiaryOpacity,
        ),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('−', onMinus),
          Container(
            width: AppSpace.s1,
            height: AppSpace.s18,
            color: AppColors.separatorDefault.withValues(
              alpha: AppColors.separatorDefaultOpacity,
            ),
          ),
          button('+', onPlus),
        ],
      ),
    );
  }
}

/// A care-need chip: filled blue with a check when selected.
class NeedChip extends StatelessWidget {
  const NeedChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.labelInverse : AppColors.labelPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : AppColors.fillTertiary.withValues(
                    alpha: AppColors.fillTertiaryOpacity,
                  ),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s10,
              vertical: AppSpace.s5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(CupertinoIcons.checkmark, size: AppSpace.s14, color: fg),
                  const SizedBox(width: AppSpace.s4),
                ],
                Text(label, style: AppText.chipLabel.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opacity of the accent fill behind [FormBanner] (Figma node 10:556 binds
/// `color/accent` at 0.1; design/tokens.json has no token for it yet).
const _bannerTintOpacity = 0.1;

/// The tinted note at the top of Add (Figma frames 19, 23).
class FormBanner extends StatelessWidget {
  const FormBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        left: AppSpace.s16,
        top: AppSpace.s16,
        right: AppSpace.s16,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s10,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: _bannerTintOpacity),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppText.footnote.copyWith(color: AppColors.labelInfo),
            ),
          ),
        ],
      ),
    );
  }
}
