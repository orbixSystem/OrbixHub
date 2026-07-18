import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'neu_surface.dart';
import 'neu_tokens.dart';

/// Campo de texto do design system: cavidade (inset) com rótulo em cima.
/// Rótulo SEMPRE visível (não some ao digitar — usuário pouco digital).
class NeuTextField extends StatelessWidget {
  const NeuTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final int maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  /// Limite de caracteres (cap rígido na digitação). O contador é escondido
  /// para preservar o visual do campo; o limite continua valendo.
  final int? maxLength;

  /// Capitalização automática do teclado (nomes → words; texto livre → sentences).
  final TextCapitalization textCapitalization;

  /// Foca o campo automaticamente ao abrir (ex.: 1º campo de um modal).
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            validator: validator,
            onFieldSubmitted: onFieldSubmitted,
            onChanged: onChanged,
            enabled: enabled,
            maxLines: maxLines,
            minLines: minLines,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            textCapitalization: textCapitalization,
            autofocus: autofocus,
            style: TextStyle(color: neu.ink, fontSize: 15),
            decoration: InputDecoration(
              counterText: '', // esconde o contador; o cap de maxLength continua
              hintText: hint,
              hintStyle: TextStyle(color: neu.inkFaint),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 20, color: neu.inkMuted)
                  : null,
              suffixIcon: suffix,
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              // Erros de validator (Form.validate) aparecem abaixo do campo.
              errorStyle: TextStyle(
                color: neu.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              errorText!,
              style: TextStyle(
                color: neu.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              helper!,
              style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

/// Barra de busca pill (cavada), com debounce por conta do chamador.
class NeuSearchBar extends StatelessWidget {
  const NeuSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return NeuSurface(
      elevation: NeuElevation.inset,
      radius: 999,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search_rounded, size: 20, color: neu.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: neu.ink, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: neu.inkFaint),
                border: InputBorder.none,
                // Sem fill próprio: o fundo é o NeuSurface (inset) do tema.
                // Sem isto, herda o filled:true global (fillColor fixo) e pinta
                // um retângulo que não combina com a paleta.
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)]
          else const SizedBox(width: 16),
        ],
      ),
    );
  }
}
