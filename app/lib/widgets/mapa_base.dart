import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;

import '../core/config.dart';
import '../core/tema.dart';
import '../state/mapa.dart';

/// Mapa de base minimalista (OpenFreeMap). [children] vão por cima (linhas e marcadores).
class MapaBase extends ConsumerWidget {
  const MapaBase({
    super.key,
    required this.controller,
    this.children = const [],
    this.onTap,
    this.centro,
    this.zoom,
    this.interativo = true,
    this.ajuste,
    this.botoes = false,
    this.aoLocalizar,
  });

  final MapController controller;
  final List<Widget> children;
  final void Function(LatLng)? onTap;
  final LatLng? centro;
  final double? zoom;

  /// false: mapa só para olhar (dentro de uma lista que rola).
  final bool interativo;

  /// Enquadramento inicial (por exemplo, o percurso inteiro de uma linha). Vale sobre [centro] e [zoom].
  final CameraFit? ajuste;

  /// Mostra + e − (e "minha localização", se [aoLocalizar] vier). Para quem usa mouse: não há como dar pinça.
  final VoidCallback? aoLocalizar;
  final bool botoes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final estilo = ref.watch(estiloMapaProvider(escuro)).value;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: centro ?? Config.centro,
        initialZoom: zoom ?? Config.zoomInicial,
        initialCameraFit: ajuste,
        minZoom: 9,
        maxZoom: 19,
        backgroundColor: escuro
            ? const Color(0xFF111111)
            : const Color(0xFFF1F1EF),
        interactionOptions: InteractionOptions(
          flags: interativo
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (_, p) => onTap!(p),
      ),
      children: [
        if (estilo != null)
          vmt.VectorTileLayer(
            theme: estilo.theme,
            sprites: estilo.sprites,
            tileProviders: estilo.providers,
          ),
        ...children,
        if (botoes) _Botoes(controller: controller, aoLocalizar: aoLocalizar),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution(Config.atribuicao)],
        ),
      ],
    );
  }
}

/// Pino de destino ou círculo de origem.
Marker marcadorPonto(
  LatLng p, {
  required bool destino,
  required BuildContext context,
}) {
  final cs = Theme.of(context).colorScheme;
  return Marker(
    point: p,
    width: 44,
    height: 44,
    alignment: destino ? Alignment.topCenter : Alignment.center,
    child: destino
        ? Icon(
            Icons.location_on_rounded,
            size: 44,
            color: cs.onSurface,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black38)],
          )
        : Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Tokens.azul,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(blurRadius: 6, color: Colors.black38),
              ],
            ),
          ),
  );
}

/// Botões de zoom (+ e −) e de "minha localização" no canto do mapa.
class _Botoes extends StatelessWidget {
  const _Botoes({required this.controller, this.aoLocalizar});

  final MapController controller;
  final VoidCallback? aoLocalizar;

  void _zoom(double delta) {
    final c = controller.camera;
    controller.move(c.center, (c.zoom + delta).clamp(9, 19));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget botao(IconData i, String dica, VoidCallback f) => Tooltip(
      message: dica,
      child: Material(
        color: cs.surface,
        elevation: 3,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(i),
          onPressed: f,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
      ),
    );
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (aoLocalizar != null) ...[
              botao(
                Icons.my_location_rounded,
                'Minha localização',
                aoLocalizar!,
              ),
              const SizedBox(height: 12),
            ],
            botao(Icons.add_rounded, 'Aproximar', () => _zoom(1)),
            const SizedBox(height: 8),
            botao(Icons.remove_rounded, 'Afastar', () => _zoom(-1)),
          ],
        ),
      ),
    );
  }
}
