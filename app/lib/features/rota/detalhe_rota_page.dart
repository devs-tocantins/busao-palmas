import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/formato.dart';
import '../../core/rotas.dart';
import '../../core/tema.dart';
import '../../domain/models.dart';
import '../../state/planejador.dart';
import '../../widgets/linha_chip.dart';
import '../../widgets/mapa_base.dart';
import '../../widgets/sequencia_rota.dart';

class DetalheRotaPage extends ConsumerStatefulWidget {
  const DetalheRotaPage({super.key});

  @override
  ConsumerState<DetalheRotaPage> createState() => _DetalheRotaPageState();
}

class _DetalheRotaPageState extends ConsumerState<DetalheRotaPage> {
  final _mapa = MapController();

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(planejadorProvider);
    final grupo = s.selecionado;
    if (grupo == null || s.origem == null || s.destino == null) {
      // Abriu direto pela URL, sem rota escolhida.
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final o = grupo.principal;
    final pontos = [for (final t in o.trechos) ...t.caminho];
    final altura = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: Stack(
        children: [
          MapaBase(
            controller: _mapa,
            centro: pontos.first,
            zoom: 14,
            children: [
              PolylineLayer(
                polylines: [
                  for (final t in o.trechos)
                    if (t.tipo == TipoTrecho.andar)
                      Polyline(
                        points: t.caminho,
                        strokeWidth: 5,
                        color: Theme.of(context).colorScheme.onSurface,
                        pattern: StrokePattern.dashed(segments: const [2, 8]),
                        strokeCap: StrokeCap.round,
                      )
                    else
                      Polyline(
                        points: t.caminho,
                        strokeWidth: 7,
                        color: t.cor ?? Tokens.azul,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final t in o.trechos.where(
                    (t) => t.tipo == TipoTrecho.onibus,
                  )) ...[
                    _parada(t.de, t.cor ?? Tokens.azul),
                    _parada(t.para, t.cor ?? Tokens.azul),
                  ],
                  marcadorPonto(
                    s.origem!.pos,
                    destino: false,
                    context: context,
                  ),
                  marcadorPonto(
                    s.destino!.pos,
                    destino: true,
                    context: context,
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                elevation: 4,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Voltar',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
          _Painel(
            grupo: grupo,
            origem: s.origem!,
            destino: s.destino!,
            aoCarregarMapa: () => _enquadrar(pontos, altura),
          ),
        ],
      ),
    );
  }

  bool _enquadrado = false;
  void _enquadrar(List<LatLng> pontos, double altura) {
    if (_enquadrado) return;
    _enquadrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapa.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(pontos),
          padding: EdgeInsets.fromLTRB(40, 80, 40, altura * 0.48),
          maxZoom: 15.5,
        ),
      );
    });
  }

  Marker _parada(LatLng p, Color cor) => Marker(
    point: p,
    width: 18,
    height: 18,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: cor, width: 4),
      ),
    ),
  );
}

class _Painel extends ConsumerWidget {
  const _Painel({
    required this.grupo,
    required this.origem,
    required this.destino,
    required this.aoCarregarMapa,
  });

  final GrupoOpcoes grupo;
  final Lugar origem;
  final Lugar destino;
  final VoidCallback aoCarregarMapa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    aoCarregarMapa();
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final o = grupo.principal;
    final dados = ref.watch(dadosLocaisProvider);
    final outras = grupo.outrasSaidas.take(4).map(horaPalmas).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.42,
      minChildSize: 0.16,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.42, 0.94],
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
            32,
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              children: [
                Text(
                  duracaoTexto(o.duracao),
                  style: t.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'chega às ${horaPalmas(o.fim)}',
                    style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SequenciaRota(grupo: grupo, dados: dados),
            const SizedBox(height: 6),
            Text(
              [
                o.inicio.difference(DateTime.now()).inMinutes < 60
                    ? 'Sai ${horaPalmas(o.inicio)} (${quandoTexto(o.inicio)})'
                    : 'Sai ${horaPalmas(o.inicio)}',
                if (o.trocas > 0)
                  '${o.trocas} ${o.trocas == 1 ? 'troca' : 'trocas'}'
                else
                  'sem troca',
                '${distanciaTexto(o.andarM)} a pé',
              ].join(' · '),
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (outras.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Também sai às ${outras.join(', ')}',
                  style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 20),
            _LinhaDoTempo(
              grupo: grupo,
              origem: origem,
              destino: destino,
              dados: dados,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({
    required this.grupo,
    required this.origem,
    required this.destino,
    required this.dados,
  });

  final GrupoOpcoes grupo;
  final Lugar origem;
  final Lugar destino;
  final dynamic dados;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final o = grupo.principal;
    final blocos = <_Bloco>[];

    blocos.add(
      _Bloco(
        cor: cs.onSurfaceVariant,
        marcador: _Ponto(cor: Tokens.azul, cheio: true),
        hora: horaPalmas(o.inicio),
        titulo: origem.nome,
      ),
    );

    var iBus = 0;
    for (var i = 0; i < o.trechos.length; i++) {
      final t = o.trechos[i];
      if (t.tipo == TipoTrecho.andar) {
        blocos.add(
          _Bloco(
            cor: cs.onSurfaceVariant,
            tracejado: true,
            marcador: Icon(
              Icons.directions_walk_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            titulo:
                'Caminhe ${distanciaTexto(t.distanciaM)} · ${duracaoTexto(t.duracao)}',
            fraco: true,
          ),
        );
        continue;
      }
      final cor = t.cor ?? Tokens.azul;
      final linhas = grupo.linhasDoTrecho(iBus++);
      final outrasLinhas = linhas.where((l) => l != t.linha).toList();

      // Espera no ponto antes de embarcar (se veio de outro trecho).
      final anterior = i > 0 ? o.trechos[i - 1] : null;
      final espera = anterior == null
          ? Duration.zero
          : t.inicio.difference(anterior.fim);
      if (anterior != null &&
          anterior.tipo == TipoTrecho.onibus &&
          espera.inMinutes >= 2) {
        blocos.add(
          _Bloco(
            cor: cs.onSurfaceVariant,
            tracejado: true,
            marcador: Icon(
              Icons.schedule_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            titulo: 'Troca: espere ${duracaoTexto(espera)}',
            fraco: true,
          ),
        );
      }

      blocos.add(
        _Bloco(
          cor: cor,
          marcador: _Ponto(cor: cor),
          hora: horaPalmas(t.inicio),
          titulo: t.nomeDe,
          sub: 'Embarque · ver horários da parada',
          aoTocar: () => context.push(caminhoParada(t.nomeDe, t.de)),
        ),
      );
      blocos.add(
        _Bloco(
          cor: cor,
          marcador: Icon(Icons.directions_bus_rounded, size: 20, color: cor),
          conteudo: _CartaoOnibus(
            trecho: t,
            outrasLinhas: outrasLinhas,
            dados: dados,
          ),
        ),
      );
      blocos.add(
        _Bloco(
          cor: cor,
          marcador: _Ponto(cor: cor),
          hora: horaPalmas(t.fim),
          titulo: t.nomePara,
          sub: 'Desça aqui · ver horários da parada',
          aoTocar: () => context.push(caminhoParada(t.nomePara, t.para)),
          fim: true,
        ),
      );
    }

    blocos.add(
      _Bloco(
        cor: Colors.transparent,
        marcador: Icon(
          Icons.location_on_rounded,
          size: 22,
          color: cs.onSurface,
        ),
        hora: horaPalmas(o.fim),
        titulo: destino.nome,
        ultimo: true,
      ),
    );

    return Column(children: [for (final b in blocos) b]);
  }
}

class _Ponto extends StatelessWidget {
  const _Ponto({required this.cor, this.cheio = false});
  final Color cor;
  final bool cheio;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: cheio ? cor : Theme.of(context).colorScheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: cor, width: 3.5),
    ),
  );
}

class _CartaoOnibus extends StatelessWidget {
  const _CartaoOnibus({
    required this.trecho,
    required this.outrasLinhas,
    required this.dados,
  });

  final Trecho trecho;
  final List<String> outrasLinhas;
  final dynamic dados;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.raioCartao),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LinhaChip(
                numero: trecho.linha ?? '?',
                cor: trecho.cor,
                corTexto: trecho.corTexto,
                grande: true,
              ),
              if (trecho.destino != null)
                Text(
                  '→ ${trecho.destino}',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (trecho.numParadas != null)
                '${trecho.numParadas} ${trecho.numParadas == 1 ? 'parada' : 'paradas'}',
              duracaoTexto(trecho.duracao),
            ].join(' · '),
            style: t.bodyMedium,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                trecho.aoVivo ? Icons.sensors_rounded : Icons.schedule_rounded,
                size: 16,
                color: trecho.aoVivo ? Tokens.aoVivo : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  trecho.aoVivo ? 'Ao vivo' : 'Horário programado',
                  style: t.bodySmall?.copyWith(
                    color: trecho.aoVivo ? Tokens.aoVivo : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (outrasLinhas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Também serve:',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                for (final n in outrasLinhas) LinhaChip.de(dados.linhas[n], n),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma linha da linha do tempo: marcador à esquerda, linha vertical e conteúdo à direita.
class _Bloco extends StatelessWidget {
  const _Bloco({
    required this.cor,
    required this.marcador,
    this.hora,
    this.titulo,
    this.sub,
    this.conteudo,
    this.fraco = false,
    this.tracejado = false,
    this.fim = false,
    this.ultimo = false,
    this.aoTocar,
  });

  final VoidCallback? aoTocar;
  final Color cor;
  final Widget marcador;
  final String? hora;
  final String? titulo;
  final String? sub;
  final Widget? conteudo;
  final bool fraco;
  final bool tracejado;
  final bool fim;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: hora == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      hora!,
                      style: t.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          SizedBox(
            width: 28,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!ultimo)
                  Positioned.fill(
                    top: 12,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: tracejado
                          ? CustomPaint(
                              painter: _Pontilhado(
                                cs.outline.withValues(alpha: 1),
                                cs.onSurfaceVariant,
                              ),
                              size: const Size(3, double.infinity),
                            )
                          : Container(
                              width: 5,
                              decoration: BoxDecoration(
                                color: cor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: marcador,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aoTocar,
              child: Padding(
                padding: EdgeInsets.only(bottom: ultimo ? 0 : 18),
                child:
                    conteudo ??
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo ?? '',
                          style: t.bodyLarge?.copyWith(
                            fontWeight: fraco
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: fraco ? cs.onSurfaceVariant : cs.onSurface,
                          ),
                        ),
                        if (sub != null)
                          Text(
                            sub!,
                            style: t.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pontilhado extends CustomPainter {
  _Pontilhado(this.cor, this.corPonto);
  final Color cor;
  final Color corPonto;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = corPonto
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (double y = 4; y < size.height; y += 9) {
      canvas.drawPoints(PointMode.points, [Offset(size.width / 2, y)], p);
    }
  }

  @override
  bool shouldRepaint(covariant _Pontilhado old) => old.corPonto != corPonto;
}
