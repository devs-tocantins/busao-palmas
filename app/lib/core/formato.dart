import 'package:intl/intl.dart';

import 'config.dart';

final _hora = DateFormat('HH:mm');

/// Converte um instante para o relógio de Palmas e formata como "HH:mm".
String horaPalmas(DateTime t) => _hora.format(t.toUtc().add(Config.fusoPalmas));

/// "7 min", "1 h 8 min".
String duracaoTexto(Duration d) {
  final min = d.inMinutes < 1 ? 1 : d.inMinutes;
  if (min < 60) return '$min min';
  final h = min ~/ 60, m = min % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "630 m", "1,2 km".
String distanciaTexto(double metros) {
  if (metros < 1000) return '${(metros / 10).round() * 10} m';
  return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// "em 3 min", "agora", "às 08:25".
String quandoTexto(DateTime saida, {DateTime? agora}) {
  final dif = saida.difference(agora ?? DateTime.now()).inMinutes;
  if (dif < 1) return 'agora';
  if (dif < 60) return 'em $dif min';
  return 'às ${horaPalmas(saida)}';
}
