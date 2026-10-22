import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Outlined text field with theme-aware colors, labels, helper/error text,
/// password visibility, and autofill support.
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
  final String? suffixText;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final bool readOnly;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

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
    this.suffixText,
    this.textInputAction,
    this.onEditingComplete,
    this.readOnly = false,
    this.focusNode,
    this.inputFormatters,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showSuffix = widget.obscureText;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: showSuffix ? _obscure : false,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
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
      style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurface),
      cursorColor: colors.primary,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        errorText: widget.errorText,
        filled: true,
        fillColor: colors.surface,
        labelStyle: TextStyle(color: colors.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colors.onSurfaceVariant),
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        helperStyle: TextStyle(color: colors.onSurfaceVariant),
        errorStyle: TextStyle(color: colors.error),
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: colors.onSurfaceVariant)
            : null,
        suffixText: widget.suffixText,
        suffixStyle: TextStyle(color: colors.onSurfaceVariant),
        suffixIcon: showSuffix
            ? IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: colors.onSurfaceVariant,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffixWidget,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
      ),
    );
  }
}
