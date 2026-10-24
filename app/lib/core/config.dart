import 'package:latlong2/latlong.dart';

/// Valores fixos de Palmas-TO. Origem: docs/DADOS.md (meta.json) e docs/API_MOBILIBUS.md.
abstract final class Config {
  static const nomeApp = 'Busão Palmas';
  static const cidade = 'Palmas, TO';

  /// OTP (planejador e geocodificador) de Palmas; ambos aceitam chamada do navegador.
  static const otpUri = 'https://otp.mobilibus.com/vJJqIBsca8nqEF';

  /// API de dados da Mobilibus (horários ao vivo). Não libera o navegador (sem CORS): só serve fora da web.
  static const apiUri = 'https://mobilibus.com/api';
  static const projetoId = 635;

  static const centro = LatLng(-10.184, -48.333);
  static const zoomInicial = 13.0;

  /// Palmas está em UTC-3 o ano todo (sem horário de verão).
  static const fusoPalmas = Duration(hours: -3);

  /// Mapa de base minimalista: estilos do OpenFreeMap (gratuito, sem chave, dados do OpenStreetMap).
  /// https://openfreemap.org — considerar apoiar o projeto se o app crescer.
  static const estiloClaro = 'https://tiles.openfreemap.org/styles/positron';
  static const estiloEscuro = 'https://tiles.openfreemap.org/styles/dark';
  static const userAgent = 'br.com.devstocantins.busaopalmas';
  static const atribuicao =
      'OpenFreeMap © OpenMapTiles, dados do OpenStreetMap';
}
