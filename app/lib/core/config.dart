import 'package:latlong2/latlong.dart';

/// Valores fixos de Palmas-TO. Origem: docs/DADOS.md (meta.json) e docs/API_MOBILIBUS.md.
abstract final class Config {
  static const nomeApp = 'Busão Palmas';
  static const cidade = 'Palmas, TO';

  /// OTP (planejador e geocodificador) de Palmas; ambos aceitam chamada do navegador.
  static const otpUri = 'https://otp.mobilibus.com/vJJqIBsca8nqEF';

  static const centro = LatLng(-10.184, -48.333);
  static const zoomInicial = 13.0;

  /// Palmas está em UTC-3 o ano todo (sem horário de verão).
  static const fusoPalmas = Duration(hours: -3);

  static const tilesUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'br.com.devstocantins.busaopalmas';
  static const atribuicao = '© colaboradores do OpenStreetMap';
}
