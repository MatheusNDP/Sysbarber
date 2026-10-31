import '../models/models.dart';

/// Estado temporário do fluxo de agendamento.
///
/// Percorre as telas Serviços → Barbeiro → Horário → Confirmação → Pagamento
/// sem precisar passar argumentos por todas as rotas. Num reagendamento, o
/// caminho é só Barbeiro → Horário ([reagendando]); ao repetir o último
/// serviço, começa no Horário ([repetir]).
class BookingFlow {
  BookingFlow._();

  static Servico? servicoSelecionado;
  static Barbeiro? barbeiroSelecionado;
  static DateTime? dataSelecionada;
  static String? horaSelecionada;

  /// Agendamento que o cliente está reagendando (regra de negócio 19). Com
  /// ele, o horário escolhido troca o do agendamento em vez de virar uma
  /// reserva nova.
  static Agendamento? reagendando;

  /// Data e hora combinadas, prontas para persistir no banco.
  static DateTime? get dataHoraCompleta {
    final data = dataSelecionada;
    final hora = horaSelecionada;
    if (data == null || hora == null) return null;
    final partes = hora.split(':');
    return DateTime(
      data.year,
      data.month,
      data.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );
  }

  /// Começa um agendamento novo a partir do serviço escolhido. Profissional
  /// e horário de um fluxo anterior não podem vazar para este.
  static void iniciar(Servico servico) {
    limpar();
    servicoSelecionado = servico;
  }

  /// Começa um agendamento novo igual ao atendimento [a], o "Repetir" do
  /// último serviço (regra de negócio 21): o serviço e o barbeiro vêm
  /// escolhidos. Se o barbeiro ficou indisponível, a escolha do profissional
  /// não o deixa selecionado.
  static void repetir(Agendamento a) {
    limpar();
    servicoSelecionado = a.servico;
    barbeiroSelecionado = a.barbeiro;
  }

  /// Começa a reagendar [a]: o serviço é o mesmo, e o barbeiro atual vem
  /// escolhido.
  static void iniciarReagendamento(Agendamento a) {
    limpar();
    reagendando = a;
    servicoSelecionado = a.servico;
    barbeiroSelecionado = a.barbeiro;
  }

  static void limpar() {
    reagendando = null;
    servicoSelecionado = null;
    barbeiroSelecionado = null;
    dataSelecionada = null;
    horaSelecionada = null;
  }
}
