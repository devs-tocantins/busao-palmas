import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../core/config.dart';

/// Camadas do estilo que só poluem o mapa no zoom de rua: nome de toda ruazinha e caminho.
/// As avenidas, a água, os bairros e o aeroporto continuam com nome.
const _camadasRemovidas = {
  'highway-name-minor', // Positron (claro)
  'highway-name-path',
  'highway_name_other', // Dark (escuro)
};

/// Estilo do mapa (claro ou escuro), lido uma vez da rede e simplificado. null se não deu para ler,
/// por exemplo sem internet: o mapa fica em fundo liso e os pinos e rotas continuam aparecendo.
final estiloMapaProvider = FutureProvider.family<vmt.Style?, bool>((
  ref,
  escuro,
) async {
  final uri = escuro ? Config.estiloEscuro : Config.estiloClaro;
  try {
    final base = await vmt.StyleReader(uri: uri).read();
    try {
      final r = await Dio().get<Map<String, dynamic>>(
        uri,
        options: Options(responseType: ResponseType.json),
      );
      final json = r.data!;
      (json['layers'] as List).removeWhere(
        (l) => _camadasRemovidas.contains((l as Map)['id']),
      );
      return vmt.Style(
        name: base.name,
        theme: vtr.ThemeReader().read(json),
        providers: base.providers,
        sprites: base.sprites,
        center: base.center,
        zoom: base.zoom,
      );
    } catch (_) {
      return base; // sem a simplificação, mas com mapa
    }
  } catch (_) {
    return null;
  }
});
