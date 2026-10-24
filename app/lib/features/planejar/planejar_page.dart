import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../data/otp_client.dart' show SemRota;
import '../../domain/models.dart';
import '../../state/planejador.dart';
import '../../widgets/mapa_base.dart';
import '../../widgets/sequencia_rota.dart';

class PlanejarPage extends ConsumerStatefulWidget {
  const PlanejarPage({super.key});

  @override
  ConsumerState<PlanejarPage> createState() => _PlanejarPageState();
}

class _PlanejarPageState extends ConsumerState<PlanejarPage> {
  final _mapa = MapController();
  int _tentativas = 0;

  /// O mapa só tem tamanho quando a tela está visível; se ainda estiver escondida atrás da busca, tenta de novo.
  void _enquadrarQuandoVisivel() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true && _tentativas++ < 8) {
        return _enquadrarQuandoVisivel();
      }
      _tentativas = 0;
      _enquadrar(ref.read(planejadorProvider));
    });
  }

  void _enquadrar(PlanejadorState s) {
    final pts = [
      if (s.origem != null) s.origem!.pos,
      if (s.destino != null) s.destino!.pos,
    ];
    if (pts.isEmpty) return;
    final altura = MediaQuery.sizeOf(context).height;
    if (pts.length == 1) {
      _mapa.move(pts.first, 15);
      return;
    }
    _mapa.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: EdgeInsets.fromLTRB(48, 200, 48, altura * 0.5),
        maxZoom: 15.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(planejadorProvider);
    ref.listen(
      planejadorProvider.select((x) => (x.origem?.pos, x.destino?.pos)),
      (_, _) {
        _enquadrarQuandoVisivel();
      },
    );

    return Scaffold(
      body: Stack(
        children: [
          MapaBase(
            controller: _mapa,
            onTap: (p) => ref.read(planejadorProvider.notifier).tocarNoMapa(p),
            children: [
              MarkerLayer(
                markers: [
                  if (s.origem != null)
                    marcadorPonto(
                      s.origem!.pos,
                      destino: false,
                      context: context,
                    ),
                  if (s.destino != null)
                    marcadorPonto(
                      s.destino!.pos,
                      destino: true,
                      context: context,
                    ),
                ],
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _Cabecalho()),
          if (s.campoMapa == CampoMapa.origem)
            Positioned(
              top: 190,
              left: 0,
              right: 0,
              child: Center(
                child: _Dica(texto: 'Toque no mapa para escolher a origem'),
              ),
            ),
          const _PainelOpcoes(),
        ],
      ),
    );
  }
}

class _Dica extends StatelessWidget {
  const _Dica({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          texto,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: Colors.white),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.3);
  }
}

class _Cabecalho extends ConsumerWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planejadorProvider);
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.margem, 8, Tokens.margem, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: cs.surface,
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(Tokens.raioPainel),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Tokens.azul,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(width: 2, height: 22, color: cs.outline),
                        Icon(Icons.stop_rounded, size: 12, color: cs.onSurface),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        children: [
                          _Campo(
                            rotulo: 'Origem',
                            valor: s.origem?.nome,
                            carregando:
                                s.buscandoLocalizacao && s.origem == null,
                            dica: s.campoMapa == CampoMapa.origem
                                ? 'Toque no mapa'
                                : 'Onde você está?',
                            onTap: () => context.push('/busca/origem'),
                          ),
                          Divider(height: 1, color: cs.outline),
                          _Campo(
                            rotulo: 'Destino',
                            valor: s.destino?.nome,
                            dica: 'Para onde?',
                            destaque: true,
                            onTap: () => context.push('/busca/destino'),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Trocar origem e destino',
                      onPressed: (s.origem != null || s.destino != null)
                          ? ref.read(planejadorProvider.notifier).trocar
                          : null,
                      icon: const Icon(Icons.swap_vert_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _ChipHorario(),
          ],
        ),
      ),
    );
  }
}

/// "Sair agora" / "Sair às 08:00": define a hora de saída usada no planejamento.
class _ChipHorario extends ConsumerWidget {
  const _ChipHorario();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saida = ref.watch(planejadorProvider.select((s) => s.saida));
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 4,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          final n = ref.read(planejadorProvider.notifier);
          final agora = TimeOfDay.fromDateTime(
            DateTime.now().toUtc().add(Config.fusoPalmas),
          );
          final h = await showTimePicker(
            context: context,
            initialTime: saida == null
                ? agora
                : TimeOfDay.fromDateTime(saida.add(Config.fusoPalmas)),
            helpText: 'Sair às',
            cancelText: 'Sair agora',
            confirmText: 'Pronto',
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          );
          // "Sair agora" fecha o seletor sem escolher hora.
          h == null ? n.definirSaida(null) : n.definirSaida(h.hour, h.minute);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 18),
                const SizedBox(width: 8),
                Text(
                  saida == null ? 'Sair agora' : 'Sair às ${horaPalmas(saida)}',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.rotulo,
    required this.dica,
    required this.onTap,
    this.valor,
    this.destaque = false,
    this.carregando = false,
  });

  final String rotulo;
  final String dica;
  final String? valor;
  final bool destaque;
  final bool carregando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final vazio = valor == null;
    return Semantics(
      button: true,
      label: '$rotulo: ${valor ?? dica}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              carregando ? 'Buscando sua localização…' : (valor ?? dica),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodyLarge?.copyWith(
                color: vazio ? cs.onSurfaceVariant : cs.onSurface,
                fontWeight: destaque && !vazio
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PainelOpcoes extends ConsumerWidget {
  const _PainelOpcoes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(planejadorProvider);
    final cs = Theme.of(context).colorScheme;
    final temResultado =
        s.grupos is AsyncData && (s.grupos.value?.isNotEmpty ?? false);
    final tamanho = s.destino == null ? 0.2 : (temResultado ? 0.44 : 0.3);

    return DraggableScrollableSheet(
      key: ValueKey(tamanho),
      initialChildSize: tamanho,
      minChildSize: 0.14,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: [tamanho, 0.92],
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Tokens.raioPainel),
          ),
          boxShadow: const [BoxShadow(blurRadius: 14, color: Colors.black26)],
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            Tokens.margem,
            8,
            Tokens.margem,
            24,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ..._conteudo(context, ref, s),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(
    BuildContext context,
    WidgetRef ref,
    PlanejadorState s,
  ) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (s.destino == null) {
      return [
        Text(
          'Para onde você quer ir?',
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Busque um lugar ou toque no mapa.',
          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ];
    }
    if (s.origem == null) {
      return [
        Text(
          'Falta a origem',
          style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Permita a localização ou escolha de onde você sai.',
          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () =>
                  ref.read(planejadorProvider.notifier).usarMinhaLocalizacao(),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Usar minha localização'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => context.push('/busca/origem'),
              child: const Text('Escolher'),
            ),
          ],
        ),
      ];
    }
    return s.grupos.when(
      loading: () => [for (var i = 0; i < 3; i++) const _CartaoEsqueleto()],
      error: (e, _) => [
        Icon(
          Icons.directions_bus_outlined,
          size: 40,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          e is SemRota
              ? 'Não achamos ônibus para esse trajeto'
              : 'Não conseguimos atualizar agora',
          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          e is SemRota
              ? 'Tente outro destino ou outro horário.'
              : 'Verifique a internet e tente de novo.',
          style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
      data: (grupos) => [
        for (var i = 0; i < grupos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CartaoRota(grupo: grupos[i], melhor: i == 0)
                .animate()
                .fadeIn(delay: (60 * i).ms, duration: 250.ms)
                .slideY(begin: 0.08),
          ),
      ],
    );
  }
}

class _CartaoEsqueleto extends StatelessWidget {
  const _CartaoEsqueleto();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Tokens.raioCartao),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: cs.outline);
  }
}

class _CartaoRota extends ConsumerWidget {
  const _CartaoRota({required this.grupo, required this.melhor});

  final GrupoOpcoes grupo;
  final bool melhor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final o = grupo.principal;
    final dados = ref.watch(dadosLocaisProvider);
    final outras = grupo.outrasSaidas.take(3).map(horaPalmas).toList();
    final emBreve = o.inicio.difference(DateTime.now()).inMinutes < 60;
    final saida = emBreve
        ? 'Sai ${horaPalmas(o.inicio)} (${quandoTexto(o.inicio)})'
        : 'Sai ${horaPalmas(o.inicio)}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.raioCartao),
        onTap: () {
          ref.read(planejadorProvider.notifier).selecionar(grupo);
          context.push('/rota');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      duracaoTexto(o.duracao),
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${horaPalmas(o.inicio)} → ${horaPalmas(o.fim)}',
                    style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SequenciaRota(grupo: grupo, dados: dados),
              const SizedBox(height: 10),
              Text(
                [
                  saida,
                  if (o.trocas > 0)
                    '${o.trocas} ${o.trocas == 1 ? 'troca' : 'trocas'}'
                  else
                    'sem troca',
                ].join(' · '),
                style: t.bodyMedium,
              ),
              if (outras.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Também às ${outras.join(', ')}',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              if (melhor)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.amarelo,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Chega primeiro',
                      style: t.labelSmall?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
