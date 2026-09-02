import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finora/core/theme/app_spacing.dart';

/// Text field used across all auth screens. When [isPassword] is true it
/// renders a show/hide toggle and starts obscured.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.prefixIcon,
    this.enabled = true,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final IconData? prefixIcon;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
          AppSpacing.vXs,
          TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            obscureText: _obscure,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onFieldSubmitted,
            onChanged: widget.onChanged,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: widget.keyboardType == TextInputType.emailAddress
                ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
                : null,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon:
                  widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : null,
            ),
          ),
        ],
      );
}
