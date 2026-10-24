import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../core/formato.dart';
import '../core/tema.dart';
import '../data/frota_repo.dart';
import '../state/frota.dart';
import '../state/parada.dart';
import '../state/planejador.dart';
import 'linha_chip.dart';

/// Ônibus rodando no mapa, como miniaturas vistas de cima que giram para onde vão e deslizam entre as atualizações.
/// Fica dentro do FlutterMap. Só consulta a API enquanto a tela está à vista.
class CamadaOnibus extends ConsumerStatefulWidget {
  const CamadaOnibus({super.key, this.linhas, this.destaque = const {}});

  /// Só estas linhas. null = todas.
  final Set<String>? linhas;

  /// Números de ônibus (`vehicleId`) a realçar, como o que a pessoa vai pegar.
  final Set<String> destaque;

  @override
  ConsumerState<CamadaOnibus> createState() => _CamadaOnibusState();
}

class _CamadaOnibusState extends ConsumerState<CamadaOnibus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  final Map<String, Onibus> _de = {};
  Map<String, Onibus> _para = {};

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Nova leitura: cada ônibus parte de onde está na tela agora e vai até a posição nova.
  void _novaLeitura(List<Onibus> lista) {
    final t = Curves.easeInOut.transform(_anim.value);
    final agora = <String, Onibus>{
      for (final o in _para.values) o.id: _interpolar(_de[o.id] ?? o, o, t),
    };
    _de
      ..clear()
      ..addAll(agora);
    _para = {for (final o in lista) o.id: o};
    _anim.forward(from: 0);
  }

  static Onibus _interpolar(Onibus a, Onibus b, double t) {
    var dr = (b.rumo - a.rumo + 540) % 360 - 180; // menor giro
    // Meia-volta: provavelmente fim de linha, não gira.
    if (dr.abs() > 170) dr = 0;
    return Onibus(
      id: b.id,
      linha: b.linha,
      sentido: b.sentido,
      pos: LatLng(
        a.pos.latitude + (b.pos.latitude - a.pos.latitude) * t,
        a.pos.longitude + (b.pos.longitude - a.pos.longitude) * t,
      ),
      rumo: (a.rumo + dr * t) % 360,
      atrasoSeg: b.atrasoSeg,
      hora: b.hora,
    );
  }

  @override
  Widget build(BuildContext context) {
    final aVista = TickerMode.valuesOf(context).enabled;
    final mostrar = ref.watch(mostrarOnibusProvider);
    if (!aVista || !mostrar) return const SizedBox.shrink();
    ref.listen(frotaProvider, (_, novo) {
      final v = novo.value;
      if (v != null) _novaLeitura(v);
    });
    // Primeira vez: o dado já pode ter chegado antes de esta camada existir.
    final atual = ref.watch(frotaProvider).value;
    if (atual != null && _para.isEmpty && atual.isNotEmpty) {
      _de.clear();
      _para = {for (final o in atual) o.id: o};
    }
    final camera = MapCamera.of(context);
    final dados = ref.watch(dadosLocaisProvider);
    final escala = camera.zoom < 13 ? 0.75 : (camera.zoom < 15 ? 1.0 : 1.3);
    final rotulo = camera.zoom >= 14.5;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_anim.value);
        final visiveis = [
          for (final o in _para.values)
            if (widget.linhas == null || widget.linhas!.contains(o.linha))
              _interpolar(_de[o.id] ?? o, o, t),
        ];
        return MarkerLayer(
          markers: [
            for (final o in visiveis)
              Marker(
                point: o.pos,
                width: 56 * escala,
                height: 64 * escala,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => mostrarOnibus(context, ref, _para[o.id] ?? o),
                  child: Semantics(
                    button: true,
                    label: 'Ônibus da linha ${o.linha}',
                    excludeSemantics: true,
                    child: _IconeOnibus(
                      cor: dados.linhas[o.linha]?.cor ?? Tokens.azul,
                      corTexto: dados.linhas[o.linha]?.corTexto ?? Colors.white,
                      numero: o.linha,
                      rumo: o.rumo,
                      escala: escala,
                      rotulo: rotulo,
                      destaque: widget.destaque.contains(o.id),
                      apagado: _para[o.id]?.desatualizado() ?? false,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Folha com o que se sabe do ônibus: linha, sentido, atraso e há quanto tempo veio o último sinal.
void mostrarOnibus(BuildContext context, WidgetRef ref, Onibus o) {
  final dados = ref.read(dadosLocaisProvider);
  final linhas = ref.read(dadosLinhasProvider).value;
  final destino = linhas?.porNumero[o.linha]?.sentidos
      .where((s) => s.id == o.sentido)
      .firstOrNull
      ?.destino;
  final atraso = o.atrasoSeg;
  final situacao = atraso.abs() < 90
      ? 'No horário'
      : atraso > 0
      ? 'Atrasado ${duracaoTexto(Duration(seconds: atraso))}'
      : 'Adiantado ${duracaoTexto(Duration(seconds: -atraso))}';
  final ha = DateTime.now().difference(o.hora);
  final sinal = ha.inSeconds < 60
      ? 'Sinal há ${ha.inSeconds.clamp(0, 59)} s'
      : 'Sinal há ${ha.inMinutes} min';
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      final t = Theme.of(c).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.margem,
            0,
            Tokens.margem,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LinhaChip.de(dados.linhas[o.linha], o.linha, grande: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destino == null ? 'Ônibus ${o.id}' : 'Sentido $destino',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                situacao,
                style: t.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: atraso > 120 ? Tokens.atraso : Tokens.aoVivo,
                ),
              ),
              Text(
                '$sinal · ônibus ${o.id}',
                style: t.bodySmall?.copyWith(
                  color: Theme.of(c).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(c);
                  context.push('/linha/${o.linha}');
                },
                child: Text('Ver a linha ${o.linha}'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _IconeOnibus extends StatelessWidget {
  const _IconeOnibus({
    required this.cor,
    required this.corTexto,
    required this.numero,
    required this.rumo,
    required this.escala,
    required this.rotulo,
    required this.destaque,
    required this.apagado,
  });

  final Color cor;
  final Color corTexto;
  final String numero;
  final double rumo;
  final double escala;
  final bool rotulo;
  final bool destaque;
  final bool apagado;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: apagado ? 0.45 : 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (destaque)
            Container(
              width: 46 * escala,
              height: 46 * escala,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Tokens.amarelo.withValues(alpha: 0.45),
                border: Border.all(color: Tokens.amarelo, width: 2),
              ),
            ),
          Transform.rotate(
            angle: rumo * math.pi / 180,
            child: CustomPaint(
              size: Size(15 * escala, 34 * escala),
              painter: _PintorOnibus(cor),
            ),
          ),
          if (rotulo)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  numero,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: corTexto,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ônibus visto de cima, apontando para cima (norte); quem usa gira pelo rumo.
class _PintorOnibus extends CustomPainter {
  _PintorOnibus(this.cor);
  final Color cor;

  @override
  void paint(Canvas canvas, Size s) {
    final corpo = RRect.fromRectAndRadius(
      Offset.zero & s,
      Radius.circular(s.width * 0.32),
    );
    canvas.drawShadow(ui.Path()..addRRect(corpo), Colors.black, 3, true);
    canvas.drawRRect(corpo, Paint()..color = cor);
    canvas.drawRRect(
      corpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white,
    );
    // Para-brisa (frente, em cima), teto e vidro de trás.
    final vidro = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * 0.16,
          s.height * 0.06,
          s.width * 0.68,
          s.height * 0.17,
        ),
        Radius.circular(s.width * 0.2),
      ),
      vidro,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * 0.22,
          s.height * 0.3,
          s.width * 0.56,
          s.height * 0.46,
        ),
        Radius.circular(s.width * 0.14),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * 0.2,
          s.height * 0.84,
          s.width * 0.6,
          s.height * 0.08,
        ),
        Radius.circular(s.width * 0.1),
      ),
      vidro,
    );
  }

  @override
  bool shouldRepaint(_PintorOnibus old) => old.cor != cor;
}
