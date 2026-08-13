import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'neu_surface.dart';
import 'neu_tokens.dart';

/// Campo de texto do design system: cavidade (inset) com rótulo em cima.
/// Rótulo SEMPRE visível (não some ao digitar — usuário pouco digital).
///
/// Com [obscureText] o campo ganha SOZINHO o botão de mostrar/ocultar senha (o
/// "olhinho"), e por isso é `Stateful`: a revelação é estado da própria caixa,
/// não do formulário em volta.
///
/// Antes cada tela resolvia isso por conta própria via [suffix] — e só algumas
/// resolviam. Login, cadastro e aceite de convite não tinham botão nenhum: quem
/// errava a senha não tinha como conferir o que digitou, e num teclado de celular
/// isso é a diferença entre entrar e ficar de fora. As duas telas que tinham
/// ainda usavam ícones TROCADOS entre si (uma mostrava o olho aberto para
/// "revelar", a outra para "ocultar"). Regra que vale agora, uma vez só, aqui:
/// **o ícone mostra o que o toque vai FAZER** — olho aberto = vai revelar.
class NeuTextField extends StatefulWidget {
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
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  /// Foco externo — permite a uma tela mandar o cursor para este campo (ex.: o
  /// atalho de despesa fixa sem valor fechado).
  final FocusNode? focusNode;
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
  State<NeuTextField> createState() => _NeuTextFieldState();
}

class _NeuTextFieldState extends State<NeuTextField> {
  /// Senha à mostra? Começa sempre oculta — revelar é escolha de cada vez, e
  /// lembrar a escolha deixaria a senha aberta na frente de quem passar depois.
  bool _revelada = false;

  /// O campo cuida do próprio olhinho quando é senha E a tela não mandou um
  /// [NeuTextField.suffix] próprio — respeitar o suffix do chamador evita dois
  /// ícones empilhados em quem já tinha resolvido à mão.
  bool get _mostraOlhinho => widget.obscureText && widget.suffix == null;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final ocultar = widget.obscureText && !_revelada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              color: neu.inkMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        NeuSurface(
          elevation: NeuElevation.inset,
          radius: NeuTokens.rField,
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: ocultar,
            keyboardType: widget.keyboardType,
            autofillHints: widget.autofillHints,
            validator: widget.validator,
            onFieldSubmitted: widget.onFieldSubmitted,
            onChanged: widget.onChanged,
            enabled: widget.enabled,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            // Enter avança para o próximo campo (pedido do balcão: preencher o
            // formulário sem tirar a mão do teclado). Declarar a ação BASTA: o
            // próprio `EditableText` chama `nextFocus()` ao receber `next` —
            // adicionar um `onFieldSubmitted` que também avança faria o foco
            // pular DOIS campos. No celular, ainda troca a tecla "concluído"
            // pela seta de avançar. Só em campo de uma linha: num campo de
            // várias, Enter tem de continuar quebrando linha.
            textInputAction: widget.textInputAction ??
                (widget.maxLines == 1 ? TextInputAction.next : null),
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            textCapitalization: widget.textCapitalization,
            autofocus: widget.autofocus,
            style: TextStyle(color: neu.ink, fontSize: 15),
            decoration: InputDecoration(
              counterText: '', // esconde o contador; o cap de maxLength continua
              hintText: widget.hint,
              hintStyle: TextStyle(color: neu.inkFaint),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, size: 20, color: neu.inkMuted)
                  : null,
              suffixIcon: _mostraOlhinho
                  ? _Olhinho(
                      revelada: _revelada,
                      onPressed: () =>
                          setState(() => _revelada = !_revelada),
                    )
                  : widget.suffix,
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
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                color: neu.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              widget.helper!,
              style: TextStyle(color: neu.inkFaint, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

/// O botão de mostrar/ocultar senha.
///
/// `IconButton` de verdade (e não um `GestureDetector` com ícone) por causa do
/// alvo de toque: ele já garante os 48dp mínimos, que é o que faz o olhinho ser
/// acertável no polegar, num celular, sem esbarrar no campo de texto. O tooltip
/// também vira rótulo de acessibilidade para leitor de tela.
class _Olhinho extends StatelessWidget {
  const _Olhinho({required this.revelada, required this.onPressed});

  final bool revelada;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    return IconButton(
      // O ícone anuncia a AÇÃO, não o estado: olho aberto = "vai mostrar".
      icon: Icon(
        revelada ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: neu.inkMuted,
      ),
      tooltip: revelada ? 'Ocultar senha' : 'Mostrar senha',
      onPressed: onPressed,
      // Sem isso o IconButton reserva a área de um botão de AppBar e empurra o
      // texto da senha para longe da borda no celular.
      visualDensity: VisualDensity.compact,
      splashRadius: 22,
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
