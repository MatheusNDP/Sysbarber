import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../services/validators.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Pagamento do agendamento (`/pagamento`).
///
/// O cliente escolhe **quando** pagar (agora ou na barbearia) e, se for agora,
/// **como** (Pix ou cartão). Os pontos de fidelidade só são creditados quando
/// o pagamento é efetivamente confirmado.
class PagamentoScreen extends StatefulWidget {
  const PagamentoScreen({super.key});

  @override
  State<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  TipoPagamento _tipo = TipoPagamento.antecipado;
  MetodoPagamento _metodo = MetodoPagamento.pix;
  bool _processando = false;

  final _numeroCtrl = TextEditingController();
  final _nomeCartaoCtrl = TextEditingController();
  final _validadeCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _nomeCartaoCtrl.dispose();
    _validadeCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  /// Payload do QR. É uma simulação identificada — não é um código Pix real.
  String get _payloadPix {
    final valor = (BookingFlow.servicoSelecionado?.preco ?? 0).toStringAsFixed(
      2,
    );
    final id = BookingFlow.agendamentoCriadoId ?? 0;
    return 'SYSBARBER|SIMULACAO|AGENDAMENTO=$id|VALOR=$valor|TCC';
  }

  Future<void> _confirmar() async {
    final usuario = AuthService.instance.usuarioAtual;
    final servico = BookingFlow.servicoSelecionado;
    final idAgendamento = BookingFlow.agendamentoCriadoId;

    if (usuario?.id == null || servico == null || idAgendamento == null) {
      mostrarErro(context, 'Não há agendamento para pagar');
      return;
    }

    // Cartão só é exigido quando o pagamento é antecipado por cartão.
    final pagaAgoraNoCartao =
        _tipo == TipoPagamento.antecipado &&
        _metodo == MetodoPagamento.cartao;

    if (pagaAgoraNoCartao) {
      final erro = Validators.validarCartao(
        numero: _numeroCtrl.text,
        nome: _nomeCartaoCtrl.text,
        validade: _validadeCtrl.text,
        cvv: _cvvCtrl.text,
      );
      if (erro != null) {
        mostrarErro(context, erro);
        return;
      }
    }

    setState(() => _processando = true);

    try {
      final db = DatabaseService.instance;
      final antecipado = _tipo == TipoPagamento.antecipado;
      final digitos = somenteDigitos(_numeroCtrl.text);

      final idPagamento = await db.criarPagamento(
        Pagamento(
          idAgendamento: idAgendamento,
          valor: servico.preco,
          metodo: antecipado ? _metodo.label : 'A combinar',
          status: 'Pendente',
          criadoEm: DateTime.now().toIso8601String(),
          tipo: _tipo.dbValue,
          cartaoFinal: pagaAgoraNoCartao && digitos.length >= 4
              ? digitos.substring(digitos.length - 4)
              : null,
        ),
      );

      // Só o pagamento antecipado é efetivado agora — e é a confirmação que
      // credita os pontos.
      if (antecipado) {
        await db.confirmarPagamento(idPagamento);
      }

      if (!mounted) return;
      setState(() => _processando = false);
      await _mostrarResultado(antecipado, servico.preco.round());
    } catch (e) {
      // Sem isto o botão ficaria travado em "PROCESSANDO..." para sempre.
      if (!mounted) return;
      setState(() => _processando = false);
      mostrarErro(context, 'Não foi possível registrar o pagamento: $e');
    }
  }

  Future<void> _mostrarResultado(bool antecipado, int pontos) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (antecipado ? AppColors.green : AppColors.gold)
                    .withValues(alpha: 0.15),
                border: Border.all(
                  color: antecipado ? AppColors.green : AppColors.gold,
                ),
              ),
              child: Icon(
                antecipado ? Icons.check : Icons.schedule,
                color: antecipado ? AppColors.green : AppColors.gold,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              antecipado ? 'Pagamento confirmado!' : 'Agendamento reservado!',
              textAlign: TextAlign.center,
              style: AppTheme.serif(size: 19),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              antecipado
                  ? 'Pagamento via ${_metodo.label} registrado com sucesso.'
                  : 'Você optou por pagar na barbearia. O pagamento fica '
                        'pendente até o profissional confirmar o '
                        'recebimento no balcão.',
              textAlign: TextAlign.center,
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                antecipado
                    ? '⭐ Você ganhou $pontos pontos'
                    : '⭐ $pontos pontos liberados após o pagamento',
                textAlign: TextAlign.center,
                style: AppTheme.sans(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          GoldButton(
            texto: 'OK',
            expandido: false,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );

    if (!mounted) return;
    BookingFlow.limpar();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;
    final antecipado = _tipo == TipoPagamento.antecipado;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'PAGAMENTO'),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _cartaoValor(servico),
                const SizedBox(height: 26),
                const SectionLabel('Quando pagar'),
                const SizedBox(height: 12),
                ...TipoPagamento.values.map(_opcaoTipo),
                if (antecipado) ...[
                  const SizedBox(height: 26),
                  const SectionLabel('Forma de pagamento'),
                  const SizedBox(height: 12),
                  _opcaoMetodo(MetodoPagamento.pix, '📱', 'Pix', 'QR Code'),
                  const SizedBox(height: 10),
                  _opcaoMetodo(
                    MetodoPagamento.cartao,
                    '💳',
                    'Cartão de Crédito/Débito',
                    'Informe os dados do cartão',
                  ),
                  const SizedBox(height: 20),
                  if (_metodo == MetodoPagamento.pix)
                    _blocoPix()
                  else
                    _blocoCartao(),
                ] else ...[
                  const SizedBox(height: 20),
                  _avisoNaBarbearia(),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GoldButton(
              texto: _processando
                  ? 'PROCESSANDO...'
                  : antecipado
                  ? 'CONFIRMAR PAGAMENTO'
                  : 'RESERVAR E PAGAR NA BARBEARIA',
              onPressed: _processando ? null : _confirmar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoValor(Servico? servico) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SectionLabel('Valor total'),
          const SizedBox(height: 10),
          Text(
            formatarReal(servico?.preco ?? 0),
            style: AppTheme.serif(size: 40, color: AppColors.gold),
          ),
          const SizedBox(height: 6),
          Text(
            servico?.nome ?? '',
            style: AppTheme.sans(size: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _opcaoTipo(TipoPagamento tipo) {
    final selecionado = _tipo == tipo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GoldCard(
        selected: selecionado,
        onTap: () => setState(() => _tipo = tipo),
        child: Row(
          children: [
            Text(
              tipo == TipoPagamento.antecipado ? '⚡' : '🏪',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipo.label,
                    style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tipo.descricao,
                    style: AppTheme.sans(size: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            _radio(selecionado),
          ],
        ),
      ),
    );
  }

  Widget _opcaoMetodo(
    MetodoPagamento metodo,
    String icone,
    String titulo,
    String descricao,
  ) {
    final selecionado = _metodo == metodo;
    return GoldCard(
      selected: selecionado,
      onTap: () => setState(() => _metodo = metodo),
      child: Row(
        children: [
          Text(icone, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  descricao,
                  style: AppTheme.sans(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          _radio(selecionado),
        ],
      ),
    );
  }

  Widget _radio(bool selecionado) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selecionado ? AppColors.gold : AppColors.muted,
          width: 1.5,
        ),
      ),
      child: selecionado
          ? Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
              ),
            )
          : null,
    );
  }

  Widget _blocoPix() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: QrImageView(
              data: _payloadPix,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aponte a câmera para o QR Code',
            style: AppTheme.sans(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _payloadPix,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(size: 11, color: AppColors.muted),
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar código',
                  icon: const Icon(
                    Icons.copy,
                    size: 18,
                    color: AppColors.gold,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _payloadPix),
                    );
                    if (!mounted) return;
                    mostrarInfo(context, 'Código copiado');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _avisoSimulacao(
            'Pix em modo demonstração: o QR Code é gerado de verdade, mas '
            'não há integração bancária. Confirmar registra o pagamento no '
            'sistema.',
          ),
        ],
      ),
    );
  }

  Widget _blocoCartao() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _campoCartao(
            controller: _numeroCtrl,
            rotulo: 'Número do cartão',
            hint: '0000 0000 0000 0000',
            formatters: [const CartaoInputFormatter()],
            teclado: TextInputType.number,
          ),
          _campoCartao(
            controller: _nomeCartaoCtrl,
            rotulo: 'Nome impresso no cartão',
            hint: 'JOAO D SILVA',
            capitalizar: true,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _campoCartao(
                  controller: _validadeCtrl,
                  rotulo: 'Validade',
                  hint: 'MM/AA',
                  formatters: [const ValidadeCartaoInputFormatter()],
                  teclado: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campoCartao(
                  controller: _cvvCtrl,
                  rotulo: 'CVV',
                  hint: '000',
                  formatters: [const CvvInputFormatter()],
                  teclado: TextInputType.number,
                ),
              ),
            ],
          ),
          _avisoSimulacao(
            'Simulação: o número é validado pelo algoritmo de Luhn, mas '
            'nenhuma cobrança é feita. O sistema guarda apenas os 4 últimos '
            'dígitos — nunca o número completo.',
          ),
        ],
      ),
    );
  }

  Widget _campoCartao({
    required TextEditingController controller,
    required String rotulo,
    required String hint,
    List<TextInputFormatter>? formatters,
    TextInputType teclado = TextInputType.text,
    bool capitalizar = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(rotulo),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: teclado,
            inputFormatters: formatters,
            textCapitalization: capitalizar
                ? TextCapitalization.characters
                : TextCapitalization.none,
            style: AppTheme.sans(size: 14),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  Widget _avisoNaBarbearia() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagamento pendente',
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Seu horário fica reservado. Você paga no balcão no dia do '
                  'atendimento e o profissional confirma o recebimento — só '
                  'então os pontos de fidelidade são creditados.',
                  style: AppTheme.sans(
                    size: 12,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoSimulacao(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 14, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: AppTheme.sans(
                size: 11,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
