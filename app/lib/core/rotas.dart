import 'package:latlong2/latlong.dart';

/// Endereço da tela de uma parada. Leva o ponto e o nome na própria URL, então o link também funciona na web.
String caminhoParada(String nome, LatLng pos) =>
    '/parada?lat=${pos.latitude}&lng=${pos.longitude}&nome=${Uri.encodeQueryComponent(nome)}';
