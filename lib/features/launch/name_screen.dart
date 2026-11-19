import 'package:flutter/cupertino.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../theme/tokens.dart';

/// "Your name", first launch only (SPEC §7.1, Figma frame 01). The name is
/// required; it is saved with [VolunteerStore.setName] and used as
/// `registered_by`. Then the PIN screen ([Routes.pin]) replaces this one.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _name = TextEditingController();
  bool _saving = false;

  bool get _canContinue => _name.text.trim().isNotEmpty && !_saving;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_canContinue) return;
    setState(() => _saving = true);
    await AppScope.read(context).volunteer.setName(_name.text);
    if (!mounted) return;
    await Routes.replaceAllWith(context, Routes.pin);
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppText.footnote.copyWith(
      color: AppColors.labelSecondary,
    );
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrouped,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s50,
            AppSpace.s16,
            AppSpace.s16,
          ),
          children: [
            Text(
              'Welcome, volunteer',
              style: AppText.largeTitle.copyWith(color: AppColors.labelPrimary),
            ),
            const SizedBox(height: AppSpace.s6),
            Text(
              'This phone belongs to one volunteer. Enter your name once; '
              'you won’t be asked again.',
              style: AppText.subheadline.copyWith(
                color: AppColors.labelSecondary,
              ),
            ),
            const SizedBox(height: AppSpace.s24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              child: Text('VOLUNTEER', style: secondary),
            ),
            const SizedBox(height: AppSpace.s6),
            _nameRow(),
            const SizedBox(height: AppSpace.s6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              child: Text(
                'Required. Saved as “registered by” on each patient you add.',
                style: secondary,
              ),
            ),
            const SizedBox(height: AppSpace.s24),
            SizedBox(
              height: AppSpace.s50,
              child: CupertinoButton.filled(
                padding: EdgeInsets.zero,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.button),
                ),
                onPressed: _canContinue ? _continue : null,
                child: Text(
                  'Continue',
                  style: AppText.headline.copyWith(
                    color: AppColors.labelInverse,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s24),
            Text(
              'Next: enter the PIN. Every launch asks for it.',
              style: secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameRow() {
    return Container(
      height: AppSpace.s30 + AppSpace.s14,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.person,
            size: AppSpace.s20,
            color: AppColors.iconSecondary,
          ),
          const SizedBox(width: AppSpace.s12),
          Text(
            'Name',
            style: AppText.body.copyWith(color: AppColors.labelPrimary),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: CupertinoTextField.borderless(
              controller: _name,
              autofocus: true,
              placeholder: 'Your full name',
              textAlign: TextAlign.end,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              padding: EdgeInsets.zero,
              style: AppText.body.copyWith(color: AppColors.labelPrimary),
              placeholderStyle: AppText.body.copyWith(
                color: AppColors.labelTertiary,
              ),
              onSubmitted: (_) => _continue(),
            ),
          ),
        ],
      ),
    );
  }
}
