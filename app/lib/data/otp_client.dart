import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../domain/models.dart';
import 'dados_locais.dart';

class SemRota implements Exception {
  const SemRota(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Planejador (OTP) e geocodificador do Bus2, os mesmos usados pelo app SOU. Ver docs/API_MOBILIBUS.md.
class OtpClient {
  OtpClient(this._dados, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Config.otpUri,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
              // Navegadores não deixam trocar o User-Agent.
              headers: kIsWeb ? null : {'User-Agent': Config.userAgent},
            ),
          );

  final Dio _dio;
  final DadosLocais _dados;

  Future<List<Opcao>> planejar({
    required LatLng de,
    required LatLng para,
    DateTime? saida,
  }) async {
    final t = (saida ?? DateTime.now()).toUtc().add(Config.fusoPalmas);
    final r = await _dio.get(
      '/otp/routers/default/plan',
      queryParameters: {
        'fromPlace': '${de.latitude},${de.longitude}',
        'toPlace': '${para.latitude},${para.longitude}',
        'date': DateFormat('MM-dd-yyyy').format(t),
        'time': DateFormat('HH:mm').format(t),
        'mode': 'TRANSIT,WALK',
        'numItineraries': 5,
        'maxWalkDistance': 2000,
      },
    );
    return interpretarPlano(r.data as Map<String, dynamic>, _dados);
  }

  Future<List<Lugar>> buscar(String texto) async {
    final r = await _dio.get(
      '/otp/geocode',
      queryParameters: {'address': texto},
    );
    final lista = (r.data['results'] as List?) ?? const [];
    return [for (final x in lista) _lugar(x as Map<String, dynamic>)];
  }

  /// Nome do ponto marcado no mapa; null se o serviço não souber.
  Future<String?> nomeDoPonto(LatLng p) async {
    try {
      final r = await _dio.get(
        '/otp/geocode/reverse',
        queryParameters: {'lat': p.latitude, 'lon': p.longitude},
      );
      final lista = (r.data['results'] as List?) ?? const [];
      if (lista.isEmpty) return null;
      final x = lista.first as Map<String, dynamic>;
      final rua = x['street'] as String?;
      if (rua != null && (x['number'] as String?) != null) {
        return '$rua, ${x['number']}';
      }
      return _titulo(x['description'] as String? ?? '');
    } on DioException {
      return null;
    }
  }

  static String _titulo(String d) => d.split(',').first.trim();

  Lugar _lugar(Map<String, dynamic> x) {
    final ehParada = x['provider'] == 'GTFS';
    final desc = (x['description'] as String?) ?? '';
    final pos = LatLng(
      (x['lat'] as num).toDouble(),
      (x['lng'] as num).toDouble(),
    );
    if (ehParada) {
      return Lugar(
        nome: _dados.nomeParada(pos, nomeOtp: x['place'] as String?),
        detalhe: 'Parada de ônibus',
        pos: pos,
        ehParada: true,
      );
    }
    final partes = desc.split(',').map((e) => e.trim()).toList();
    final nome = partes.first;
    final resto = partes.skip(1).where((e) => e != 'Palmas').join(', ');
    return Lugar(nome: nome, detalhe: resto.isEmpty ? null : resto, pos: pos);
  }
}

/// Converte a resposta do planejador em opções. Separado do cliente para poder ser testado com uma resposta gravada.
List<Opcao> interpretarPlano(Map<String, dynamic> json, DadosLocais dados) {
  final erro = json['error'];
  if (erro != null) {
    throw SemRota((erro as Map)['msg']?.toString() ?? 'Sem rota');
  }
  final its = (json['plan']?['itineraries'] as List?) ?? const [];
  if (its.isEmpty) {
    throw const SemRota(
      'Nenhum ônibus encontrado para esse trajeto neste horário.',
    );
  }

  DateTime t(num ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true);
  LatLng ponto(Map p) =>
      LatLng((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble());
  String? codigo(Map p) => (p['stopId'] as String?)?.split(':').last;

  return [
    for (final it in its)
      Opcao(
        inicio: t(it['startTime'] as num),
        fim: t(it['endTime'] as num),
        duracao: Duration(seconds: (it['duration'] as num).toInt()),
        trocas: (it['transfers'] as num).toInt(),
        trechos: [
          for (final l in (it['legs'] as List))
            () {
              final de = ponto(l['from'] as Map), para = ponto(l['to'] as Map);
              final onibus = l['mode'] != 'WALK';
              final caminho = [
                for (final c in decodePolyline(
                  l['legGeometry']['points'] as String,
                ))
                  LatLng(c[0].toDouble(), c[1].toDouble()),
              ];
              final linha = l['routeShortName'] as String?;
              final info = linha == null ? null : dados.linhas[linha];
              final seqDe = (l['from'] as Map)['stopSequence'] as num?,
                  seqPara = (l['to'] as Map)['stopSequence'] as num?;
              return Trecho(
                tipo: onibus ? TipoTrecho.onibus : TipoTrecho.andar,
                inicio: t(l['startTime'] as num),
                fim: t(l['endTime'] as num),
                distanciaM: (l['distance'] as num).toDouble(),
                de: de,
                para: para,
                nomeDe: onibus
                    ? dados.nomeParada(
                        de,
                        nomeOtp: (l['from'] as Map)['name'] as String?,
                      )
                    : ((l['from'] as Map)['name'] as String? ?? ''),
                nomePara: onibus
                    ? dados.nomeParada(
                        para,
                        nomeOtp: (l['to'] as Map)['name'] as String?,
                      )
                    : ((l['to'] as Map)['name'] as String? ?? ''),
                caminho: caminho,
                linha: linha,
                destino: l['headsign'] as String?,
                nomeLinha: l['routeLongName'] as String?,
                numParadas: seqDe != null && seqPara != null
                    ? (seqPara - seqDe).toInt()
                    : null,
                aoVivo: l['realTime'] == true,
                codigoDe: codigo(l['from'] as Map),
                codigoPara: codigo(l['to'] as Map),
                cor: info?.cor,
                corTexto: info?.corTexto,
              );
            }(),
        ],
      ),
  ];
}
