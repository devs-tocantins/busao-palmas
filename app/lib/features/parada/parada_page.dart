import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../domain/models.dart';
import '../../state/parada.dart';
import '../../state/planejador.dart';
import '../../widgets/linha_chip.dart';

/// Quando passa o ônibus numa parada: próximas passagens por linha, ao vivo quando há GPS.
class ParadaPage extends ConsumerStatefulWidget {
  const ParadaPage({super.key, required this.parada});

  final ParadaRef parada;

  @override
  ConsumerState<ParadaPage> createState() => _ParadaPageState();
}

class _ParadaPageState extends ConsumerState<ParadaPage> {
  Timer? _timer;
  DateTime _atualizadoEm = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Atualização sugerida pela própria Mobilibus: a cada 20 s (project-details: realtimeUpdateFreqSec).
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _atualizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _atualizar() {
    if (!mounted) return;
    ref.invalidate(saidasProvider(widget.parada));
    setState(() => _atualizadoEm = DateTime.now());
  }

  void _comoChegar() {
    final p = widget.parada;
    ref
        .read(planejadorProvider.notifier)
        .definirDestino(Lugar(nome: p.nome, pos: p.pos, ehParada: true));
    context.go('/mapa');
  }

  @override
  Widget build(BuildContext context) {
    final saidas = ref.watch(saidasProvider(widget.parada));
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Parada')),
      body: RefreshIndicator(
        onRefresh: () async {
          _atualizar();
          await ref
              .read(saidasProvider(widget.parada).future)
              .catchError((_) => <SaidasLinha>[]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Tokens.margem,
            4,
            Tokens.margem,
            32,
          ),
          children: [
            Text(
              widget.parada.nome,
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Atualizado às ${horaPalmas(_atualizadoEm)}',
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _comoChegar,
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: const Text('Como chegar aqui'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...saidas.when(
              loading: () => [for (var i = 0; i < 3; i++) const _Esqueleto()],
              error: (e, _) => [
                _Mensagem(
                  titulo: 'Não conseguimos atualizar agora',
                  texto: 'Verifique a internet. Puxe para baixo para tentar de novo.',
                  icone: Icons.cloud_off_rounded,
                ),
              ],
              data: (lista) => lista.isEmpty
                  ? [
                      const _Mensagem(
                        titulo: 'Nenhum ônibus nas próximas horas',
                        texto: 'Esta parada não tem passagens programadas agora. Tente de novo mais tarde.',
                        icone: Icons.directions_bus_outlined,
                      ),
                    ]
                  : [
                      for (final s in lista)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CartaoLinha(saidas: s),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoLinha extends ConsumerWidget {
  const _CartaoLinha({required this.saidas});

  final SaidasLinha saidas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dados = ref.watch(dadosLocaisProvider);
    final c = saidas.proxima;
    final depois = saidas.chegadas
        .skip(1)
        .take(3)
        .map((x) => horaPalmas(x.horario))
        .toList();
    final atrasado = c.aoVivo && (c.atrasoSeg ?? 0) >= 120;

    return Semantics(
      label:
          'Linha ${saidas.linha}${saidas.destino == null ? '' : ' sentido ${saidas.destino}'}. '
          '${faltaTexto(c)}${c.aoVivo ? ', ao vivo' : ', horário programado'}.',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinhaChip.de(
                    dados.linhas[saidas.linha],
                    saidas.linha,
                    grande: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      saidas.destino ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        faltaTexto(c),
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: c.aoVivo ? Tokens.aoVivo : cs.onSurface,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            c.aoVivo
                                ? Icons.sensors_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: c.aoVivo
                                ? Tokens.aoVivo
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            c.aoVivo ? 'Ao vivo' : 'Programado',
                            style: t.labelSmall?.copyWith(
                              color: c.aoVivo
                                  ? Tokens.aoVivo
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (atrasado)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Atrasado ${duracaoTexto(Duration(seconds: c.atrasoSeg!))}',
                    style: t.bodySmall?.copyWith(
                      color: Tokens.atraso,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (depois.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Depois: ${depois.join(' · ')}',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) => Container(
    height: 84,
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(Tokens.raioCartao),
    ),
  );
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({
    required this.titulo,
    required this.texto,
    required this.icone,
  });

  final String titulo;
  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icone, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
