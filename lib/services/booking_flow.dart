import '../models/models.dart';

/// Mantém o estado temporário durante o fluxo de criação de agendamento.
/// Resetado após confirmar/cancelar.
class BookingFlow {
  static Servico? servicoSelecionado;
  static Barbeiro? barbeiroSelecionado;
  static DateTime? dataSelecionada;
  static String? horarioSelecionado;
  static int? agendamentoCriadoId;

  static void limpar() {
    servicoSelecionado = null;
    barbeiroSelecionado = null;
    dataSelecionada = null;
    horarioSelecionado = null;
    agendamentoCriadoId = null;
  }
}
