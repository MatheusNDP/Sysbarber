import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/erros.dart';
import '../theme/app_theme.dart';
import '../widgets/animacoes.dart';
import '../widgets/common_widgets.dart';
import 'admin_relatorios_screen.dart';
import 'admin_screen.dart';
import 'agendamentos_screen.dart';
import 'perfil_screen.dart';
import 'servicos_screen.dart';

/// Área principal (`/home`), com a barra de navegação fixa embaixo e as abas
/// do perfil de quem entrou: o cliente tem Início, Serviços, Agenda e Perfil;
/// o administrador, Painel, Agenda (a geral), Relatórios e Perfil; o
/// barbeiro, Agenda (a dele) e Perfil. Trocar de aba não abre uma tela nova:
/// a barra continua no lugar e marca a aba atual.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// As abas do perfil logado, na ordem da barra.
  static List<(Aba, IconData, String)> abasDoPerfil(AuthService auth) {
    const agenda = (Aba.agenda, Icons.calendar_month_outlined, 'Agenda');
    const perfil = (Aba.perfil, Icons.person_outline_rounded, 'Perfil');
    if (auth.ehBarbeiro) return const [agenda, perfil];
    if (auth.podeAdministrar) {
      return const [
        (Aba.painel, Icons.space_dashboard_outlined, 'Painel'),
        agenda,
        (Aba.relatorios, Icons.bar_chart_rounded, 'Relatórios'),
        perfil,
      ];
    }
    return const [
      (Aba.inicio, Icons.home_rounded, 'Início'),
      (Aba.servicos, Icons.content_cut_rounded, 'Serviços'),
      agenda,
      perfil,
    ];
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _abas = HomeScreen.abasDoPerfil(AuthService.instance);

  /// Posição da aba atual na barra.
  int _atual = 0;

  /// 1 quando a aba nova fica à direita da anterior na barra, -1 quando
  /// fica à esquerda: a aba nova entra por esse lado.
  int _sentido = 1;

  void _irParaIndice(int indice) {
    if (indice == _atual) return;
    setState(() {
      _sentido = indice > _atual ? 1 : -1;
      _atual = indice;
    });
  }

  void _irParaAba(Aba aba) {
    final indice = _abas.indexWhere((a) => a.$1 == aba);
    if (indice >= 0) _irParaIndice(indice);
  }

  /// A tela de cada aba. É montada de novo a cada troca e relê o banco: o
  /// que mudou em outra aba (um cancelamento, por exemplo) já aparece.
  Widget _tela(Aba aba) => switch (aba) {
    Aba.inicio => const _Inicio(),
    Aba.servicos => const ServicosScreen(),
    Aba.agenda => AgendamentosScreen(
      agendaGeral: AuthService.instance.podeAdministrar,
    ),
    Aba.perfil => const PerfilScreen(),
    Aba.painel => const AdminScreen(),
    Aba.relatorios => const AdminRelatoriosScreen(),
  };

  /// A aba nova entra deslizando do lado da opção tocada e a anterior sai
  /// pelo outro lado, as duas esmaecendo. A que sai não recebe mais toques.
  Widget _transicao(Widget aba, Animation<double> animacao) {
    final entrando = aba.key == ValueKey(_atual);
    final inicio = Offset(0.12 * _sentido * (entrando ? 1 : -1), 0);
    return FadeTransition(
      opacity: animacao,
      child: SlideTransition(
        position: Tween(begin: inicio, end: Offset.zero).animate(animacao),
        child: IgnorePointer(ignoring: !entrando, child: aba),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // O voltar do Android, fora da primeira aba, volta para ela.
      canPop: _atual == 0,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _irParaIndice(0);
      },
      child: NavegacaoPrincipal(
        abas: {for (final a in _abas) a.$1},
        irParaAba: _irParaAba,
        child: Scaffold(
          // O conteúdo passa por trás da barra de navegação translúcida.
          extendBody: true,
          body: AnimatedSwitcher(
            duration: BarraNavegacao.duracao,
            switchInCurve: BarraNavegacao.curva,
            switchOutCurve: BarraNavegacao.curva,
            // Uma função nova a cada troca faz a aba que sai também usar o
            // sentido atual (o AnimatedSwitcher refaz as transições).
            transitionBuilder: (aba, animacao) => _transicao(aba, animacao),
            child: KeyedSubtree(
              key: ValueKey(_atual),
              child: _tela(_abas[_atual].$1),
            ),
          ),
          bottomNavigationBar: BarraNavegacao(
            atual: _atual,
            onTap: _irParaIndice,
            itens: [for (final a in _abas) (a.$2, a.$3)],
          ),
        ),
      ),
    );
  }
}

/// Aba Início do cliente: próximo horário, pontos e acesso rápido.
class _Inicio extends StatefulWidget {
  const _Inicio();

  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
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

  /// Troca para outra aba da navegação principal.
  void _irParaAba(Aba aba, String rota) =>
      NavegacaoPrincipal.abrir(context, aba, rota);

  @override
  Widget build(BuildContext context) {
    final usuario = AuthService.instance.usuarioAtual;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.amarelo,
          backgroundColor: AppColors.card,
          onRefresh: _carregarDados,
          child: Cascata(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              // Embaixo, o espaço da barra de navegação, que fica por cima.
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                ItemDaCascata(ordem: 0, child: _saudacao(usuario)),
                const SizedBox(height: 24),
                if (_carregando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.amarelo,
                      ),
                    ),
                  )
                else if (_erro != null)
                  EstadoErro(
                    mensagem: _erro!,
                    onTentarNovamente: _carregarDados,
                  )
                else
                  // Os cards só existem depois de carregar: a cascata deles
                  // começa nessa hora, logo depois da saudação.
                  Cascata(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ItemDaCascata(ordem: 1, child: _cardProximoHorario()),
                        const SizedBox(height: 16),
                        ItemDaCascata(ordem: 2, child: _cardFidelidade()),
                        const SizedBox(height: 28),
                        ItemDaCascata(
                          ordem: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const TituloSecao('Acesso rápido'),
                              const SizedBox(height: 14),
                              _atalhos(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
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
            onTap: () => _irParaAba(Aba.perfil, '/perfil'),
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
        onTap: () => proximo == null
            ? _irParaAba(Aba.servicos, '/servicos')
            : _irParaAba(Aba.agenda, '/agendamentos'),
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
                ContagemAnimada(
                  valor: _pontos,
                  formatar: (n) => '$n pts',
                  estilo: AppTheme.titulo(size: 22),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }

  Widget _atalhos() {
    // Serviços, Agenda e Perfil são abas; a Fidelidade abre por cima.
    final itens = <(IconData, String, VoidCallback)>[
      (
        Icons.content_cut_rounded,
        'Serviços',
        () => _irParaAba(Aba.servicos, '/servicos'),
      ),
      (
        Icons.calendar_month_outlined,
        'Agenda',
        () => _irParaAba(Aba.agenda, '/agendamentos'),
      ),
      (Icons.star_outline_rounded, 'Fidelidade', () => _irPara('/fidelidade')),
      (
        Icons.person_outline_rounded,
        'Perfil',
        () => _irParaAba(Aba.perfil, '/perfil'),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in itens)
          Expanded(
            child: AtalhoCirculo(
              icone: item.$1,
              rotulo: item.$2,
              onTap: item.$3,
            ),
          ),
      ],
    );
  }
}
