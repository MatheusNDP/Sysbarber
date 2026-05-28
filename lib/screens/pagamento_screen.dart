import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/booking_flow.dart';
import '../models/models.dart';

class PagamentoScreen extends StatefulWidget {
  const PagamentoScreen({super.key});

  @override
  State<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  MetodoPagamento _metodo = MetodoPagamento.pix;
  bool _processando = false;

  Future<void> _confirmarPagamento() async {
    final servico = BookingFlow.servicoSelecionado;
    final agId = BookingFlow.agendamentoCriadoId;
    final cliente = AuthService.instance.usuarioAtual;
    if (servico == null || agId == null || cliente == null) return;

    setState(() => _processando = true);

    final valor = servico.preco;
    await DatabaseService.instance.criarPagamento(Pagamento(
      idAgendamento: agId,
      valor: valor,
      metodo: _metodo,
    ));

    // Adiciona pontos de fidelidade
    final pts = valor.round();
    await DatabaseService.instance.adicionarPontos(
      cliente.id!,
      pts,
      '${servico.nome} · ${BookingFlow.barbeiroSelecionado?.nome ?? ""}',
    );

    if (!mounted) return;
    setState(() => _processando = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.gold),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.green, size: 28),
            const SizedBox(width: 10),
            Text('Confirmado!',
                style: GoogleFonts.playfairDisplay(
                    color: AppColors.gold, fontSize: 20)),
          ],
        ),
        content: Text(
          'Pagamento confirmado via ${_metodo.label}. Agendamento registrado e você ganhou $pts pontos de fidelidade!',
          style: GoogleFonts.dmSans(color: AppColors.text, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              BookingFlow.limpar();
              Navigator.pop(context);
              Navigator.popUntil(context, (r) => r.settings.name == '/home');
            },
            child: Text('OK',
                style: GoogleFonts.dmSans(
                    color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;
    final barb = BookingFlow.barbeiroSelecionado;
    final valor = servico?.preco ?? 0.0;

    return Scaffold(
      appBar: const BarberAppBar(title: 'PAGAMENTO'),
      body: SafeArea(
        child: Column(
          children: [
            const GoldDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.25)),
                        gradient: const LinearGradient(
                          colors: [AppColors.card, AppColors.card2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text('VALOR TOTAL', style: AppTheme.goldLabel()),
                          const SizedBox(height: 4),
                          Text(
                            'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: GoogleFonts.playfairDisplay(
                              color: AppColors.gold,
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (servico != null && barb != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${servico.nome} · ${barb.nome}',
                              style: AppTheme.subtitle(size: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionLabel('Forma de pagamento'),
                    _metodoCard(
                      MetodoPagamento.pix,
                      icone: Icons.pix,
                      titulo: 'Pix',
                      subtitulo: 'Pagamento instantâneo',
                    ),
                    _metodoCard(
                      MetodoPagamento.cartao,
                      icone: Icons.credit_card,
                      titulo: 'Cartão de Crédito/Débito',
                      subtitulo: 'Visa, Master, Elo',
                    ),
                    _metodoCard(
                      MetodoPagamento.dinheiro,
                      icone: Icons.attach_money,
                      titulo: 'Dinheiro',
                      subtitulo: 'Pagar no local',
                    ),
                    const SizedBox(height: 18),
                    GoldButton(
                      label: _processando
                          ? 'PROCESSANDO...'
                          : 'CONFIRMAR PAGAMENTO',
                      onPressed: _processando ? null : _confirmarPagamento,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metodoCard(MetodoPagamento m,
      {required IconData icone,
      required String titulo,
      required String subtitulo}) {
    final isSel = _metodo == m;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        selected: isSel,
        onTap: () => setState(() => _metodo = m),
        child: Row(
          children: [
            Icon(icone, color: AppColors.gold, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: GoogleFonts.dmSans(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: AppTheme.subtitle(size: 12)),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? AppColors.gold : Colors.transparent,
                border: Border.all(
                  color: isSel
                      ? AppColors.gold
                      : AppColors.gold.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSel
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
