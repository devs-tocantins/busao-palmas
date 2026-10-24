import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/rotas.dart';
import '../core/tema.dart';
import '../state/planejador.dart';

/// Zoom a partir do qual as paradas aparecem. Mais longe seriam 1.210 pontos amontoados.
const zoomParadas = 15.0;

/// As paradas da área visível, como pontos que abrem a tela da parada. Fica dentro do FlutterMap.
class CamadaParadas extends ConsumerWidget {
  const CamadaParadas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = MapCamera.of(context);
    if (camera.zoom < zoomParadas) return const SizedBox.shrink();
    final dados = ref.watch(dadosLocaisProvider);
    final area = camera.visibleBounds;
    final grande = camera.zoom >= 16.5;
    final tamanho = grande ? 28.0 : 18.0;
    final visiveis = [
      for (final p in dados.paradas)
        if (area.contains(p.pos) && !p.nome.startsWith('Parada ')) p,
    ].take(400);
    return MarkerLayer(
      markers: [
        for (final p in visiveis)
          Marker(
            point: p.pos,
            width: tamanho + 16,
            height: tamanho + 16,
            child: Semantics(
              button: true,
              label: 'Parada ${p.nome}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(caminhoParada(p.nome, p.pos)),
                child: Center(
                  child: Container(
                    width: tamanho,
                    height: tamanho,
                    decoration: BoxDecoration(
                      color: Tokens.amarelo,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: grande
                        ? const Icon(
                            Icons.directions_bus_rounded,
                            size: 16,
                            color: Colors.black,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
