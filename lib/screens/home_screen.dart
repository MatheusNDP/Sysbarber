import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Tela principal (`/home`).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;

  Agendamento? _proximo;
  int _pontos = 0;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final usuario = AuthService.instance.usuarioAtual;
    if (usuario?.id == null) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    if (_erro != null) {
      setState(() {
        _erro = null;
        _carregando = true;
      });
    }

    try {
      final agendamentos = await _db.listarAgendamentosCliente(usuario!.id!);
      final pontos = await _db.obterPontos(usuario.id!);
      final agora = DateTime.now();

      // O próximo horário é o confirmado mais próximo ainda no futuro.
      final futuros =
          agendamentos
              .where(
                (a) =>
                    a.status == StatusAgendamento.confirmado &&
                    a.data.isAfter(agora),
              )
              .toList()
            ..sort((a, b) => a.data.compareTo(b.data));

      if (!mounted) return;
      setState(() {
        _proximo = futuros.isEmpty ? null : futuros.first;
        _pontos = pontos;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = mensagemDeErro(e, 'Não foi possível carregar o início');
      });
    }
  }

  /// Navega e recarrega os dados ao voltar.
  Future<void> _irPara(String rota) async {
    await Navigator.of(context).pushNamed(rota);
    if (mounted) _carregarDados();
  }

  void _aoTocarNavegacao(int indice) {
    switch (indice) {
      case 1:
        _irPara('/servicos');
        break;
      case 2:
        _irPara('/agendamentos');
        break;
      case 3:
        _irPara('/perfil');
        break;
      default:
        _carregarDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioAtual;

    return Scaffold(
      // O conteúdo passa por trás da barra de navegação translúcida.
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.amarelo,
          backgroundColor: AppColors.card,
          onRefresh: _carregarDados,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              _saudacao(usuario),
              const SizedBox(height: 24),
              if (_carregando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.amarelo),
                  ),
                )
              else if (_erro != null)
                EstadoErro(mensagem: _erro!, onTentarNovamente: _carregarDados)
              else ...[
                _cardProximoHorario(),
                const SizedBox(height: 16),
                _cardFidelidade(),
                const SizedBox(height: 28),
                const TituloSecao('Acesso rápido'),
                const SizedBox(height: 14),
                _atalhos(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BarraNavegacao(
        atual: 0,
        onTap: _aoTocarNavegacao,
        itens: const [
          (Icons.home_rounded, 'Início'),
          (Icons.content_cut_rounded, 'Serviços'),
          (Icons.calendar_month_outlined, 'Agenda'),
          (Icons.person_outline_rounded, 'Perfil'),
        ],
      ),
    );
  }

  Widget _saudacao(Cliente? usuario) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Abrir perfil',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => _irPara('/perfil'),
            child: AvatarIniciais(
              texto: usuario?.iniciais ?? '?',
              tamanho: 52,
              large: true,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, bem-vindo',
                style: AppTheme.texto(size: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                usuario?.nome ?? 'Visitante',
                style: AppTheme.titulo(size: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Cartão amarelo de destaque: o próximo horário ou o convite para agendar.
  Widget _cardProximoHorario() {
    final proximo = _proximo;
    final textoEscuro = Colors.black.withValues(alpha: 0.7);

    final Widget conteudo;
    if (proximo == null) {
      conteudo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nenhum horário marcado',
            style: AppTheme.titulo(size: 20, color: Colors.black),
          ),
          const SizedBox(height: 6),
          Text(
            'Toque para agendar seu próximo corte',
            style: AppTheme.texto(size: 13, color: textoEscuro),
          ),
          const SizedBox(height: 18),
          _pilulaEscura('Agendar', Icons.arrow_forward_rounded),
        ],
      );
    } else {
      conteudo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Próximo horário',
                  style: AppTheme.texto(
                    size: 13,
                    weight: FontWeight.w600,
                    color: textoEscuro,
                  ),
                ),
              ),
              Text(
                formatarHora(proximo.data),
                style: AppTheme.titulo(size: 26, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            proximo.servico?.nome ?? 'Serviço',
            style: AppTheme.titulo(size: 20, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Text(
            formatarDataExtenso(proximo.data),
            style: AppTheme.texto(size: 13, color: textoEscuro),
          ),
          Text(
            'com ${proximo.barbeiro?.nome ?? ''}',
            style: AppTheme.texto(size: 13, color: textoEscuro),
          ),
          const SizedBox(height: 18),
          _pilulaEscura('Confirmado', Icons.check_rounded),
        ],
      );
    }

    return Material(
      color: AppColors.amarelo,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _irPara(proximo == null ? '/servicos' : '/agendamentos'),
        child: Stack(
          children: [
            // Tesoura grande e apagada no canto, no lugar de uma foto.
            Positioned(
              right: -18,
              bottom: -22,
              child: Icon(
                proximo == null
                    ? Icons.content_cut_rounded
                    : iconeDoServico(proximo.servico?.icone ?? ''),
                size: 130,
                color: Colors.black.withValues(alpha: 0.07),
              ),
            ),
            Padding(padding: const EdgeInsets.all(20), child: conteudo),
          ],
        ),
      ),
    );
  }

  /// Pílula preta dentro do cartão amarelo.
  Widget _pilulaEscura(String texto, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const ShapeDecoration(
        color: Colors.black,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            style: AppTheme.texto(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.amarelo,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icone, size: 16, color: AppColors.amarelo),
        ],
      ),
    );
  }

  Widget _cardFidelidade() {
    return Cartao(
      onTap: () => _irPara('/fidelidade'),
      child: Row(
        children: [
          const IconeCirculo(
            icone: Icons.star_outline_rounded,
            cor: AppColors.amarelo,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pontos de fidelidade',
                  style: AppTheme.texto(size: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text('$_pontos pts', style: AppTheme.titulo(size: 22)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _atalhos() {
    // A administração só aparece para a conta administradora.
    final ehAdmin = AuthService.instance.podeAdministrar;
    final itens = [
      (Icons.content_cut_rounded, 'Serviços', '/servicos'),
      (Icons.calendar_month_outlined, 'Agenda', '/agendamentos'),
      (Icons.star_outline_rounded, 'Fidelidade', '/fidelidade'),
      if (ehAdmin)
        (Icons.admin_panel_settings_outlined, 'Painel', '/admin')
      else
        (Icons.person_outline_rounded, 'Perfil', '/perfil'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in itens)
          Expanded(
            child: AtalhoCirculo(
              icone: item.$1,
              rotulo: item.$2,
              onTap: () => _irPara(item.$3),
            ),
          ),
      ],
    );
  }
}
