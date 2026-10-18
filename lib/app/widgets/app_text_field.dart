import 'package:flutter/material.dart';

/// Outlined text field: label above, helper/error text, password show/hide,
/// autofill hints. Radius 12.
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? autofillHint;
  final int? maxLength;
  final int? maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final bool readOnly;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.autofillHint,
    this.maxLength,
    this.maxLines,
    this.validator,
    this.onChanged,
    this.onTap,
    this.prefixIcon,
    this.suffixWidget,
    this.textInputAction,
    this.onEditingComplete,
    this.readOnly = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final showSuffix = widget.obscureText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: showSuffix ? _obscure : false,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHint != null
              ? [widget.autofillHint!]
              : null,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines ?? 1,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          textInputAction: widget.textInputAction,
          onEditingComplete: widget.onEditingComplete,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
            suffixIcon: showSuffix
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  )
                : widget.suffixWidget,
          ),
        ),
      ],
    );
  }
}
