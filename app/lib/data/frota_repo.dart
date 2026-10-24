import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';

/// Uma viagem do snapshot: de qual linha e sentido ela é. O `/vehicles` da API é por viagem.
class ViagemRef {
  const ViagemRef({
    required this.tripId,
    required this.linha,
    required this.sentido,
  });

  final String tripId;
  final String linha;
  final int sentido;
}

/// Um ônibus rodando agora.
class Onibus {
  const Onibus({
    required this.id,
    required this.linha,
    required this.sentido,
    required this.pos,
    required this.rumo,
    required this.atrasoSeg,
    required this.hora,
  });

  final String id;
  final String linha;
  final int sentido;
  final LatLng pos;

  /// Graus a partir do norte, no sentido horário (0 = norte, 90 = leste).
  final double rumo;

  /// Positivo: atrasado. Negativo: adiantado.
  final int atrasoSeg;

  /// Instante (UTC) da última posição de GPS.
  final DateTime hora;

  /// Sem sinal novo há tanto tempo que a posição pode estar errada.
  bool desatualizado([DateTime? agora]) =>
      (agora ?? DateTime.now()).difference(hora) > const Duration(minutes: 3);
}

/// Posição de todos os ônibus de Palmas.
///
/// A API só devolve os ônibus de uma viagem por vez (`/vehicles?trip_id=`), então perguntamos pelas 106 viagens
/// do snapshot de uma vez (medido em 2026-10-24: 106 respostas em 1,6 s, a resposta fica 15 s no cache da CDN).
/// Não libera o navegador (sem CORS): só funciona no app.
class FrotaRepo {
  FrotaRepo(this._viagens, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Config.apiUri,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': Config.userAgent},
            ),
          );

  final List<ViagemRef> _viagens;
  final Dio _dio;

  /// Se [linhas] vier, só pergunta pelas viagens dessas linhas.
  Future<List<Onibus>> carregar({Set<String>? linhas, DateTime? agora}) async {
    final alvo = [
      for (final v in _viagens)
        if (linhas == null || linhas.contains(v.linha)) v,
    ];
    var falhas = 0;
    final respostas = <(ViagemRef, List)>[];
    // Em lotes, para não abrir 106 conexões ao mesmo tempo.
    for (var i = 0; i < alvo.length; i += 30) {
      final lote = alvo.skip(i).take(30);
      final r = await Future.wait([
        for (final v in lote)
          _dio
              .get<List>('/vehicles', queryParameters: {'trip_id': v.tripId})
              .then<List?>((x) => x.data ?? const [])
              .catchError((_) {
                falhas++;
                return null;
              }),
      ]);
      var k = 0;
      for (final v in lote) {
        final x = r[k++];
        if (x != null) respostas.add((v, x));
      }
    }
    if (alvo.isNotEmpty && respostas.isEmpty && falhas > 0) {
      throw Exception('Não foi possível ler a posição dos ônibus.');
    }
    return interpretarVeiculos(respostas, agora: agora);
  }
}

/// Junta as respostas de `/vehicles` de várias viagens. Um ônibus que aparece em mais de uma fica com a posição mais nova.
List<Onibus> interpretarVeiculos(
  Iterable<(ViagemRef, List)> respostas, {
  DateTime? agora,
}) {
  final agr = agora ?? DateTime.now();
  final palmas = agr.toUtc().add(Config.fusoPalmas);
  final meiaNoite = DateTime.utc(palmas.year, palmas.month, palmas.day);
  final porId = <String, Onibus>{};
  for (final (viagem, lista) in respostas) {
    for (final x in lista) {
      if (x is! Map) continue;
      final lat = (x['lat'] as num?)?.toDouble();
      final lng = (x['lng'] as num?)?.toDouble();
      final id = x['vehicleId']?.toString();
      if (lat == null || lng == null || id == null) continue;
      final p = ((x['positionTime'] as String?) ?? '').split(':');
      if (p.length < 2) continue;
      var parede = meiaNoite.add(
        Duration(
          hours: int.tryParse(p[0]) ?? 0,
          minutes: int.tryParse(p[1]) ?? 0,
          seconds: p.length > 2 ? int.tryParse(p[2]) ?? 0 : 0,
        ),
      );
      var hora = parede.subtract(Config.fusoPalmas);
      // Uma posição "do futuro" é da véspera (virada da meia-noite).
      if (hora.isAfter(agr.toUtc().add(const Duration(minutes: 2)))) {
        hora = hora.subtract(const Duration(days: 1));
      }
      final o = Onibus(
        id: id,
        linha: viagem.linha,
        sentido: viagem.sentido,
        pos: LatLng(lat, lng),
        rumo: ((x['heading'] as num?)?.toDouble() ?? 0) % 360,
        atrasoSeg: (x['delay'] as num?)?.toInt() ?? 0,
        hora: hora,
      );
      final antigo = porId[id];
      if (antigo == null || o.hora.isAfter(antigo.hora)) porId[id] = o;
    }
  }
  return porId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}
