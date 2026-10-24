import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../domain/models.dart';
import 'dados_locais.dart';
import 'saidas.dart';

/// Próximas passagens de ônibus numa parada.
///
/// Duas fontes: o planejador (OTP), que dá o horário programado e funciona em todo lugar; e a API da Mobilibus
/// (`departures`), que dá o ônibus ao vivo mas não libera o navegador, então só é usada fora da web.
/// Se uma falhar, a outra ainda responde.
class ParadasRepo {
  ParadasRepo(this._dados, {Dio? otp, Dio? api})
    : _otp = otp ?? _novo('${Config.otpUri}/otp/routers/default'),
      _api = api ?? _novo(Config.apiUri);

  final DadosLocais _dados;
  final Dio _otp;
  final Dio _api;
  final Map<String, String> _idsOtp = {};

  static Dio _novo(String base) => Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: kIsWeb ? null : {'User-Agent': Config.userAgent},
    ),
  );

  Future<List<SaidasLinha>> saidas(ParadaRef parada) async {
    final agora = DateTime.now();
    final resultados = await Future.wait<List<SaidasLinha>?>([
      _viaOtp(
        parada.pos,
        agora,
      ).then<List<SaidasLinha>?>((v) => v).catchError((_) => null),
      kIsWeb
          ? Future.value(const <SaidasLinha>[])
          : _viaApi(
              parada.pos,
              agora,
            ).then<List<SaidasLinha>?>((v) => v).catchError((_) => null),
    ]);
    final otp = resultados[0], api = resultados[1];
    if (otp == null && api == null) {
      throw Exception('Não foi possível ler os horários da parada.');
    }
    return mesclarSaidas(api ?? const [], otp ?? const []);
  }

  /// O OTP identifica a parada por um código próprio; achamos o da parada mais perto do ponto.
  Future<String?> _idOtp(LatLng pos) async {
    final chave =
        '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}';
    final guardado = _idsOtp[chave];
    if (guardado != null) return guardado;
    final r = await _otp.get(
      '/index/stops',
      queryParameters: {
        'lat': pos.latitude,
        'lon': pos.longitude,
        'radius': 40,
      },
    );
    final lista = r.data as List;
    if (lista.isEmpty) return null;
    return _idsOtp[chave] = (lista.first as Map)['id'] as String;
  }

  Future<List<SaidasLinha>> _viaOtp(LatLng pos, DateTime agora) async {
    final id = await _idOtp(pos);
    if (id == null) return const [];
    final r = await _otp.get(
      '/index/stops/$id/stoptimes',
      queryParameters: {'numberOfDepartures': 6},
    );
    return interpretarStoptimes(r.data as List, agora: agora);
  }

  Future<List<SaidasLinha>> _viaApi(LatLng pos, DateTime agora) async {
    final parada = _dados.paradaPerto(pos);
    if (parada == null) return const [];
    final r = await _api.get(
      '/departures',
      queryParameters: {'stop_id': parada.id, 'project_id': Config.projetoId},
    );
    return interpretarDepartures(r.data as Map, agora: agora);
  }
}
