import '../models/models.dart';

/// Estado temporário do fluxo de agendamento.
///
/// Percorre as telas Serviços → Barbeiro → Horário → Confirmação → Pagamento
/// sem precisar passar argumentos por todas as rotas.
class BookingFlow {
  BookingFlow._();

  static Servico? servicoSelecionado;
  static Barbeiro? barbeiroSelecionado;
  static DateTime? dataSelecionada;
  static String? horaSelecionada;
  static int? agendamentoCriadoId;

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

  static void limpar() {
    servicoSelecionado = null;
    barbeiroSelecionado = null;
    dataSelecionada = null;
    horaSelecionada = null;
    agendamentoCriadoId = null;
  }
}
