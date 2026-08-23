import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../di.dart';

/// Fone de suporte da barra superior: leva ao Suporte da Orbix e mostra em
/// vermelho quantas respostas ainda não foram lidas.
///
/// Mora no chrome global, ao lado do sino, e não numa tela: quem precisa de
/// ajuda precisa dela ONDE tropeçou — obrigar a passar por Configurações era
/// pedir para procurar socorro no lugar errado.
class SupportButton extends ConsumerWidget {
  const SupportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final naoLidas = ref.watch(supportUnreadProvider).asData?.value ?? 0;
    final tem = naoLidas > 0;
    final router = ref.read(routerProvider);
    // Já estando no Suporte, o ícone perde a graça de "ir para" — vira só
    // destaque de onde você está.
    final aqui =
        router.routerDelegate.currentConfiguration.uri.path == '/suporte';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const Key('suporte-topo'),
          tooltip: 'Suporte Orbix',
          icon: Icon(
            Icons.support_agent_rounded,
            color: tem || aqui ? AppColors.brand : null,
          ),
          onPressed: () => router.go('/suporte'),
        ),
        if (tem)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  naoLidas > 99 ? '99+' : '$naoLidas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
