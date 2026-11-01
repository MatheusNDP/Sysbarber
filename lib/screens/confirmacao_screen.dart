import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Revisão final antes de gravar o agendamento (`/confirmacao`).
class ConfirmacaoScreen extends StatefulWidget {
  const ConfirmacaoScreen({super.key});

  @override
  State<ConfirmacaoScreen> createState() => _ConfirmacaoScreenState();
}

class _ConfirmacaoScreenState extends State<ConfirmacaoScreen> {
  bool _verificando = false;

  /// Nada é gravado aqui: o agendamento só nasce junto com o pagamento, na
  /// próxima tela. Esta checagem apenas avisa cedo se o horário foi ocupado
  /// (ou o profissional ficou indisponível) com a tela aberta.
  Future<void> _continuar() async {
    final usuario = AuthService.instance.usuarioAtual;
    final servico = BookingFlow.servicoSelecionado;
    final barbeiro = BookingFlow.barbeiroSelecionado;
    final dataHora = BookingFlow.dataHoraCompleta;

    if (usuario?.id == null ||
        servico?.id == null ||
        barbeiro?.id == null ||
        dataHora == null) {
      mostrarErro(context, 'Dados do agendamento incompletos');
      return;
    }

    setState(() => _verificando = true);

    try {
      final impedimento = await DatabaseService.instance.verificarReserva(
        idBarbeiro: barbeiro!.id!,
        dataHora: dataHora,
        idServico: servico!.id,
        idCliente: usuario!.id,
      );
      if (!mounted) return;
      setState(() => _verificando = false);

      if (impedimento != null) {
        mostrarErro(context, impedimento);
        return;
      }
      Navigator.of(context).pushNamed('/pagamento');
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificando = false);
      mostrarErro(
        context,
        mensagemDeErro(e, 'Não foi possível verificar o horário'),
      );
    }
  }

  void _cancelar() {
    BookingFlow.limpar();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;
    final barbeiro = BookingFlow.barbeiroSelecionado;
    final dataHora = BookingFlow.dataHoraCompleta;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Confirmação'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                const Center(
                  child: IconeCirculo(
                    icone: Icons.check_rounded,
                    tamanho: 72,
                    destaque: true,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Revise seu agendamento',
                  textAlign: TextAlign.center,
                  style: AppTheme.titulo(size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confira os dados antes de confirmar',
                  textAlign: TextAlign.center,
                  style: AppTheme.texto(size: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                _linhaResumo(
                  'Serviço',
                  servico?.nome ?? '-',
                  detalhe: servico?.descricao,
                  icone: iconeDoServico(servico?.icone ?? ''),
                ),
                const SizedBox(height: 12),
                _linhaResumo(
                  'Barbeiro',
                  barbeiro?.nome ?? '-',
                  detalhe: barbeiro?.especialidade,
                  icone: Icons.person_outline_rounded,
                  // A foto do barbeiro, quando ele pôs uma (regra de
                  // negócio 22), no lugar do ícone.
                  avatar: barbeiro?.foto == null
                      ? null
                      : AvatarIniciais(
                          texto: barbeiro!.iniciais,
                          foto: barbeiro.foto,
                          tamanho: 44,
                        ),
                ),
                const SizedBox(height: 12),
                _linhaResumo(
                  'Data',
                  dataHora == null ? '-' : formatarDataExtenso(dataHora),
                  icone: Icons.calendar_month_outlined,
                ),
                const SizedBox(height: 12),
                _linhaResumo(
                  'Horário',
                  dataHora == null ? '-' : formatarHora(dataHora),
                  icone: Icons.schedule_rounded,
                ),
                const SizedBox(height: 20),
                // Escuro, e não amarelo: logo abaixo vem o botão amarelo.
                Cartao(
                  selected: true,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const TituloSecao('Valor total'),
                      Text(
                        formatarReal(servico?.preco ?? 0),
                        style: AppTheme.titulo(
                          size: 26,
                          color: AppColors.amarelo,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                BotaoPrincipal(
                  texto: _verificando
                      ? 'Verificando...'
                      : 'Continuar para o pagamento',
                  onPressed: _verificando ? null : _continuar,
                ),
                const SizedBox(height: 10),
                BotaoSecundario(
                  texto: 'Cancelar',
                  onPressed: _verificando ? null : _cancelar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaResumo(
    String rotulo,
    String valor, {
    String? detalhe,
    IconData? icone,
    Widget? avatar,
  }) {
    return Cartao(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (avatar != null || icone != null) ...[
            avatar ?? IconeCirculo(icone: icone!, tamanho: 44),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RotuloCampo(rotulo),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: AppTheme.texto(size: 15, weight: FontWeight.w600),
                ),
                if (detalhe != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detalhe,
                    style: AppTheme.texto(size: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
