import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Antecedência do lembrete do horário (regra de negócio 20): sobra 1 hora
/// para cancelar ou reagendar sem multa.
const Duration antecedenciaDoLembrete = Duration(hours: 2);

/// Notificação que avisa o cliente do próprio horário.
class Lembrete {
  /// O id do agendamento: cada agendamento tem no máximo um lembrete.
  final int id;
  final DateTime quando;
  final String titulo;
  final String texto;

  const Lembrete({
    required this.id,
    required this.quando,
    required this.titulo,
    required this.texto,
  });
}

/// Os lembretes dos [agendamentos] que ainda valem em [agora]: um por
/// agendamento em aberto, [antecedenciaDoLembrete] antes do horário. Quem
/// agenda em cima da hora, com esse momento já passado, fica sem lembrete.
List<Lembrete> lembretesDe(List<Agendamento> agendamentos, DateTime agora) {
  String hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
  return [
    for (final a in agendamentos)
      if (a.emAberto &&
          a.id != null &&
          a.data.subtract(antecedenciaDoLembrete).isAfter(agora))
        Lembrete(
          id: a.id!,
          quando: a.data.subtract(antecedenciaDoLembrete),
          titulo: 'Seu horário é às ${hora(a.data)}',
          texto:
              '${a.servico?.nome ?? 'Atendimento'} com '
              '${a.barbeiro?.nome ?? 'a barbearia'}. Se não puder ir, cancele '
              'ou reagende até as '
              '${hora(a.data.subtract(const Duration(hours: 1)))}, sem multa.',
        ),
  ];
}

/// Onde os lembretes ficam agendados. Hoje é o próprio aparelho
/// ([LembretesLocais]); os testes usam [LembretesEmMemoria].
abstract class Lembretes {
  /// Troca os lembretes agendados por [lembretes].
  Future<void> substituir(List<Lembrete> lembretes);

  /// Apaga todos os lembretes do aparelho.
  Future<void> apagarTodos();

  /// Pede a permissão de notificação (Android 13 ou mais novo) uma vez só,
  /// no primeiro agendamento feito no aparelho.
  Future<void> pedirPermissao();
}

/// Lembretes como notificações locais, agendadas no próprio celular pelo
/// `flutter_local_notifications`, sem servidor. O alarme é exato: um alarme
/// inexato pode chegar até 1 hora depois, que é o limite para cancelar sem
/// multa. Se o aparelho não permitir alarme exato, fica o inexato.
///
/// Uma falha aqui nunca impede o agendamento: ela só vai para o log.
class LembretesLocais implements Lembretes {
  LembretesLocais._();

  static final LembretesLocais instance = LembretesLocais._();

  static const String _chavePermissaoPedida = 'lembretes_permissao_pedida';

  /// Ícone pequeno das notificações: a tesoura, um recurso do Android
  /// (`android/app/src/main/res/drawable/ic_notificacao.xml`). O ícone do app
  /// não serve: o Android desenha o ícone pequeno numa cor só.
  static const String icone = 'ic_notificacao';

  /// Cor com que o Android pinta o ícone pequeno: o amarelo do app.
  static const cor = AppColors.amarelo;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _iniciado = false;

  static const NotificationDetails _detalhes = NotificationDetails(
    android: AndroidNotificationDetails(
      'lembretes',
      'Lembretes de horário',
      channelDescription: 'Aviso 2 horas antes do atendimento',
      importance: Importance.high,
      priority: Priority.high,
      icon: icone,
      color: cor,
    ),
  );

  /// Prepara as notificações; chamado na abertura do app.
  Future<void> iniciar() async {
    if (_iniciado) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(icone),
        ),
      );
      _iniciado = true;
    } catch (erro) {
      developer.log('Lembretes indisponíveis', name: 'sysbarber', error: erro);
    }
  }

  @override
  Future<void> substituir(List<Lembrete> lembretes) async {
    await iniciar();
    try {
      await _plugin.cancelAll();
      final exato =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.canScheduleExactNotifications() ??
          false;
      for (final l in lembretes) {
        await _plugin.zonedSchedule(
          id: l.id,
          // Um instante só, sem repetição: o fuso de referência não importa.
          scheduledDate: tz.TZDateTime.from(l.quando.toUtc(), tz.UTC),
          notificationDetails: _detalhes,
          androidScheduleMode: exato
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          title: l.titulo,
          body: l.texto,
        );
      }
    } catch (erro) {
      developer.log(
        'Falha ao agendar os lembretes',
        name: 'sysbarber',
        error: erro,
      );
    }
  }

  @override
  Future<void> apagarTodos() async {
    await iniciar();
    try {
      await _plugin.cancelAll();
    } catch (erro) {
      developer.log(
        'Falha ao apagar os lembretes',
        name: 'sysbarber',
        error: erro,
      );
    }
  }

  @override
  Future<void> pedirPermissao() async {
    await iniciar();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_chavePermissaoPedida) ?? false) return;
      await prefs.setBool(_chavePermissaoPedida, true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (erro) {
      developer.log(
        'Falha ao pedir a permissão de notificação',
        name: 'sysbarber',
        error: erro,
      );
    }
  }
}

/// Lembretes guardados numa lista, para os testes conferirem o que seria
/// agendado no aparelho.
@visibleForTesting
class LembretesEmMemoria implements Lembretes {
  List<Lembrete> agendados = [];
  int pedidosDePermissao = 0;

  @override
  Future<void> substituir(List<Lembrete> lembretes) async =>
      agendados = List.of(lembretes);

  @override
  Future<void> apagarTodos() async => agendados = [];

  @override
  Future<void> pedirPermissao() async => pedidosDePermissao++;
}
