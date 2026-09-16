/// ===============================================================
/// DATAS PARA A TELA
/// ===============================================================
///
/// Cada tela formatava data à mão com `padLeft`, e o resultado era sempre o
/// mesmo `dd/MM` seco: sem hora, sem "hoje", sem localidade. Quem olha uma
/// entrega quer saber se foi agora ou semana passada — "hoje, 14:32" responde
/// isso; "15/09" obriga a conferir o calendário.
library;

import 'package:intl/intl.dart';

final DateFormat _hora = DateFormat('HH:mm', 'pt_BR');
final DateFormat _diaMes = DateFormat('dd/MM', 'pt_BR');
final DateFormat _diaMesAno = DateFormat('dd/MM/yyyy', 'pt_BR');

/// "hoje, 14:32" · "ontem, 09:05" · "12/09, 18:40" · "12/09/2025".
///
/// O ano só aparece quando a data cai em outro ano: dentro do ano corrente ele
/// é ruído em tela pequena.
String descreverData(DateTime data) {
  final agora = DateTime.now();
  final dia = DateTime(data.year, data.month, data.day);
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final diferenca = hoje.difference(dia).inDays;

  if (diferenca == 0) return 'hoje, ${_hora.format(data)}';
  if (diferenca == 1) return 'ontem, ${_hora.format(data)}';
  if (data.year != agora.year) return _diaMesAno.format(data);
  return '${_diaMes.format(data)}, ${_hora.format(data)}';
}

/// Só a data, para linhas onde a hora não acrescenta (extrato, avaliações).
String formatarData(DateTime data) => _diaMesAno.format(data);

/// Só a hora — prazos dentro do mesmo dia.
String formatarHora(DateTime data) => _hora.format(data);
