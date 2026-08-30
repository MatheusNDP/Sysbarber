import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Escolha do profissional (`/barbeiro`).
class BarbeiroScreen extends StatefulWidget {
  const BarbeiroScreen({super.key});

  @override
  State<BarbeiroScreen> createState() => _BarbeiroScreenState();
}

class _BarbeiroScreenState extends State<BarbeiroScreen> {
  List<Barbeiro> _barbeiros = [];
  Barbeiro? _selecionado;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final barbeiros = await DatabaseService.instance.listarBarbeiros();
    if (!mounted) return;
    final anterior = BookingFlow.barbeiroSelecionado;
    setState(() {
      _barbeiros = barbeiros;
      // Uma escolha anterior pode ter ficado indisponível nesse meio-tempo.
      _selecionado = barbeiros.any((b) => b.id == anterior?.id && b.ativo)
          ? anterior
          : null;
      _carregando = false;
    });
  }

  void _continuar() {
    BookingFlow.barbeiroSelecionado = _selecionado;
    Navigator.of(context).pushNamed('/horario');
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'PROFISSIONAL'),
      body: Column(
        children: [
          const GoldDivider(),
          if (servico != null) _faixaServico(servico),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: _barbeiros.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _cardBarbeiro(_barbeiros[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GoldButton(
              texto: 'CONTINUAR',
              onPressed: _selecionado == null ? null : _continuar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _faixaServico(Servico servico) {
    return Container(
      width: double.infinity,
      color: AppColors.dark,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(servico.icone, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Serviço escolhido'),
                const SizedBox(height: 3),
                Text(
                  servico.nome,
                  style: AppTheme.sans(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Text(
            formatarReal(servico.preco),
            style: AppTheme.serif(size: 17, color: AppColors.gold),
          ),
        ],
      ),
    );
  }

  Widget _cardBarbeiro(Barbeiro b) {
    final selecionado = _selecionado?.id == b.id;

    // Indisponível continua visível, mas esmaecido e sem seleção: o cliente
    // entende que o profissional existe e só não está atendendo agora.
    if (!b.ativo) {
      return Opacity(
        opacity: 0.45,
        child: GoldCard(
          child: Row(
            children: [
              GoldAvatar(texto: b.iniciais, tamanho: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.nome, style: AppTheme.serif(size: 17)),
                    const SizedBox(height: 3),
                    Text(
                      b.especialidade,
                      style: AppTheme.sans(size: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    const GoldBadge(
                      texto: 'Indisponível',
                      cor: AppColors.muted,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.block, color: AppColors.muted, size: 22),
            ],
          ),
        ),
      );
    }

    return GoldCard(
      selected: selecionado,
      onTap: () => setState(() => _selecionado = b),
      child: Row(
        children: [
          GoldAvatar(texto: b.iniciais, tamanho: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.nome, style: AppTheme.serif(size: 17)),
                const SizedBox(height: 3),
                Text(
                  b.especialidade,
                  style: AppTheme.sans(size: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      b.avaliacao.toStringAsFixed(1),
                      style: AppTheme.sans(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${b.avaliacoes})',
                      style: AppTheme.sans(size: 12, color: AppColors.muted),
                    ),
                    if (selecionado) ...[
                      const SizedBox(width: 10),
                      const GoldBadge(texto: 'Selecionado ✓'),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selecionado ? AppColors.gold : Colors.transparent,
              border: Border.all(
                color: selecionado ? AppColors.gold : AppColors.muted,
                width: 1.5,
              ),
            ),
            child: selecionado
                ? const Icon(Icons.check, size: 15, color: Colors.black)
                : null,
          ),
        ],
      ),
    );
  }
}
