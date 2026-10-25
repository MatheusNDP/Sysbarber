import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/booking_flow.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
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
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (_erro != null) {
      setState(() {
        _erro = null;
        _carregando = true;
      });
    }
    try {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar os profissionais');
      });
    }
  }

  void _continuar() {
    BookingFlow.barbeiroSelecionado = _selecionado;
    Navigator.of(context).pushNamed('/horario');
  }

  @override
  Widget build(BuildContext context) {
    final servico = BookingFlow.servicoSelecionado;

    return Scaffold(
      appBar: const BarberAppBar(titulo: 'Profissional'),
      body: Column(
        children: [
          if (servico != null) _faixaServico(servico),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  )
                : _erro != null
                ? EstadoErro(mensagem: _erro!, onTentarNovamente: _carregar)
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
            child: BotaoPrincipal(
              texto: 'Continuar',
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
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconeCirculo(
            icone: iconeDoServico(servico.icone),
            tamanho: 42,
            destaque: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RotuloCampo(
                  BookingFlow.reagendando == null
                      ? 'Serviço escolhido'
                      : 'Reagendando o horário de '
                            '${formatarDataHora(BookingFlow.reagendando!.data)}',
                ),
                const SizedBox(height: 3),
                Text(
                  servico.nome,
                  style: AppTheme.texto(size: 14, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            formatarReal(servico.preco),
            style: AppTheme.titulo(size: 17, color: AppColors.amarelo),
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
        child: Cartao(
          child: Row(
            children: [
              AvatarIniciais(texto: b.iniciais, tamanho: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.nome,
                      style: AppTheme.titulo(size: 16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      b.especialidade,
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    const Etiqueta(texto: 'Indisponível', cor: AppColors.muted),
                  ],
                ),
              ),
              const Icon(Icons.block_rounded, color: AppColors.muted, size: 22),
            ],
          ),
        ),
      );
    }

    return Cartao(
      selected: selecionado,
      onTap: () => setState(() => _selecionado = b),
      child: Row(
        children: [
          AvatarIniciais(texto: b.iniciais, tamanho: 52, large: selecionado),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.nome,
                  style: AppTheme.titulo(size: 16, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  b.especialidade,
                  style: AppTheme.texto(size: 12, color: AppColors.muted),
                ),
                if (selecionado) ...[
                  const SizedBox(height: 8),
                  const Etiqueta(texto: 'Selecionado ✓'),
                ],
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selecionado ? AppColors.amarelo : Colors.transparent,
              border: Border.all(
                color: selecionado ? AppColors.amarelo : AppColors.muted,
                width: 1.5,
              ),
            ),
            child: selecionado
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.black)
                : null,
          ),
        ],
      ),
    );
  }
}
