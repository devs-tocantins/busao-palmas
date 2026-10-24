import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../core/tema.dart';

/// Mapa com os tiles do OpenStreetMap. [children] vão por cima (linhas e marcadores).
class MapaBase extends StatelessWidget {
  const MapaBase({
    super.key,
    required this.controller,
    this.children = const [],
    this.onTap,
    this.centro,
    this.zoom,
  });

  final MapController controller;
  final List<Widget> children;
  final void Function(LatLng)? onTap;
  final LatLng? centro;
  final double? zoom;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: centro ?? Config.centro,
        initialZoom: zoom ?? Config.zoomInicial,
        minZoom: 9,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: onTap == null ? null : (_, p) => onTap!(p),
      ),
      children: [
        TileLayer(
          urlTemplate: Config.tilesUrl,
          userAgentPackageName: Config.userAgent,
        ),
        ...children,
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
