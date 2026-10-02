import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'profile_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final ProfileController controller;
  final ValueChanged<int> onNavTap;
  const EditProfileScreen({
    super.key,
    required this.controller,
    required this.onNavTap,
  });
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.controller.profile?.fullName,
  );
  late final _email = TextEditingController(
    text: widget.controller.profile?.email,
  );
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (!await widget.controller.saveProfile(_name.text, _email.text) ||
        !mounted) {
      return;
    }
    final pending = widget.controller.profile?.pendingEmail;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pending != null && pending.isNotEmpty
              ? 'Name saved. Check your email to confirm the new address.'
              : 'Profile updated.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => ProfilePage(
      title: 'Edit profile',
      gap: 32,
      onBack: () => Navigator.pop(context),
      onNavTap: widget.onNavTap,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keep your details up to date',
              style: profileText(20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              'Update your profile details.',
              style: profileText(14, color: AppColors.greyText),
            ),
            const SizedBox(height: 16),
            ProfileField(
              label: 'Full name',
              hint: 'Enter your full name',
              controller: _name,
              enabled: !widget.controller.busy,
              capitalization: TextCapitalization.words,
              validator: (value) => ProfileService.validateName(value ?? ''),
            ),
            const SizedBox(height: 16),
            ProfileField(
              label: 'Email address',
              hint: 'Enter your email',
              controller: _email,
              enabled: !widget.controller.busy,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => ProfileService.validateEmail(value ?? ''),
            ),
            const SizedBox(height: 16),
            if (widget.controller.error != null) ...[
              ProfileError(widget.controller.error!),
              const SizedBox(height: 16),
            ],
            ProfileButton(
              text: widget.controller.busy ? 'Saving...' : 'Save changes',
              onPressed: widget.controller.busy ? null : _save,
            ),
            const SizedBox(height: 16),
            ProfileButton(
              text: 'Cancel',
              background: Colors.white,
              foreground: AppColors.primary,
              onPressed: widget.controller.busy
                  ? null
                  : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
