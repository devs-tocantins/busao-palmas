import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/rotas.dart';
import '../../core/tema.dart';
import '../../domain/models.dart';
import '../../state/parada.dart';
import '../../state/planejador.dart';
import '../../state/salvos.dart';
import '../../widgets/atalhos.dart';
import '../../widgets/linha_chip.dart';

/// Tela de entrada: para onde ir, Casa e Trabalho, paradas perto e recentes.
/// Escolher um destino (aqui ou na busca) leva ao mapa com as rotas.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.read(planejadorProvider.notifier);
    ref.listen(planejadorProvider.select((s) => s.destino), (antes, depois) {
      if (depois == null || depois == antes) return;
      final aqui = GoRouterState.of(context).uri.path == '/';
      if (aqui) context.go('/mapa');
    });
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(saidasProvider);
            await plan.usarMinhaLocalizacao();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              Tokens.margem,
              16,
              Tokens.margem,
              24,
            ),
            children: [
              Text(
                'Para onde você vai?',
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const _CampoBusca(),
              const SizedBox(height: 12),
              AtalhosCasaTrabalho(
                aoEscolher: plan.definirDestino,
                aoDefinir: (a) => context.push(
                  a == Atalho.casa ? '/busca/casa' : '/busca/trabalho',
                ),
              ),
              const SizedBox(height: 24),
              const _Favoritos(),
              const _PertoDeVoce(),
              const SizedBox(height: 16),
              ListaRecentes(max: 4, aoEscolher: plan.definirDestino),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linhas e paradas marcadas com a estrela. Some se não há nenhuma.
class _Favoritos extends ConsumerWidget {
  const _Favoritos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salvos = ref.watch(salvosProvider).value ?? const Salvos();
    if (salvos.linhasFavoritas.isEmpty && salvos.paradasFavoritas.isEmpty) {
      return const SizedBox.shrink();
    }
    final dados = ref.watch(dadosLocaisProvider);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Favoritos',
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (salvos.linhasFavoritas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in salvos.linhasFavoritas)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => context.push('/linha/$n'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LinhaChip.de(dados.linhas[n], n, grande: true),
                      ),
                    ),
                ],
              ),
            ),
          for (final p in salvos.paradasFavoritas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CartaoParada(parada: p),
            ),
        ],
      ),
    );
  }
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Buscar destino',
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => context.push('/busca/destino'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Buscar destino',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// As paradas mais perto de onde a pessoa está, com os próximos ônibus de cada uma.
class _PertoDeVoce extends ConsumerWidget {
  const _PertoDeVoce();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planejadorProvider);
    final dados = ref.watch(dadosLocaisProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final minha = s.minhaPos;

    final Widget corpo;
    if (minha != null) {
      final perto = dados.paradasPerto(minha);
      corpo = perto.isEmpty
          ? _Aviso(
              icone: Icons.location_off_outlined,
              texto: 'Nenhuma parada a menos de 600 m de você.',
            )
          : Column(
              children: [
                for (final p in perto)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CartaoParada(
                      parada: ParadaRef(nome: p.parada.nome, pos: p.parada.pos),
                      metros: p.metros,
                    ),
                  ),
              ],
            );
    } else if (s.buscandoLocalizacao) {
      corpo = const _Aviso(
        icone: Icons.my_location_rounded,
        texto: 'Buscando sua localização…',
      );
    } else {
      corpo = Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Veja os ônibus que passam perto de você.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: ref
                    .read(planejadorProvider.notifier)
                    .usarMinhaLocalizacao,
                icon: const Icon(Icons.my_location_rounded, size: 20),
                label: const Text('Usar minha localização'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perto de você',
          style: t.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        corpo,
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icone, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoParada extends ConsumerWidget {
  const _CartaoParada({required this.parada, this.metros});

  final ParadaRef parada;

  /// Distância até a pessoa; não aparece nos favoritos.
  final double? metros;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dados = ref.watch(dadosLocaisProvider);
    final saidas = ref.watch(saidasProvider(parada));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(caminhoParada(parada.nome, parada.pos)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      parada.nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (metros != null)
                    Text(
                      distanciaTexto(metros!),
                      style: t.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              ...saidas.when(
                loading: () => [
                  Text(
                    'Carregando horários…',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                error: (_, _) => [
                  Text(
                    'Não conseguimos ler os horários agora.',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                data: (lista) => lista.isEmpty
                    ? [
                        Text(
                          'Nenhum ônibus nas próximas horas.',
                          style: t.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ]
                    : [
                        for (final l in lista.take(3))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                LinhaChip.de(dados.linhas[l.linha], l.linha),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.destino ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmall,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  faltaTexto(l.proxima),
                                  style: t.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: l.proxima.aoVivo
                                        ? Tokens.aoVivo
                                        : cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
