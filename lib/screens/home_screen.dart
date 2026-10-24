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
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amarelo,
          backgroundColor: AppColors.card,
          onRefresh: _carregarDados,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _saudacao(usuario),
              const SizedBox(height: 20),
              const GoldDivider(),
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
                const SizedBox(height: 12),
                _gridAcessoRapido(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _navegacao(),
    );
  }

  Widget _saudacao(Cliente? usuario) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Olá, bem-vindo 👋',
                style: AppTheme.texto(size: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                usuario?.nome ?? 'Visitante',
                style: AppTheme.titulo(size: 24),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Abrir perfil',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => _irPara('/perfil'),
            child: AvatarIniciais(
              texto: usuario?.iniciais ?? '?',
              tamanho: 48,
              large: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardProximoHorario() {
    final proximo = _proximo;
    if (proximo == null) {
      return Cartao(
        onTap: () => _irPara('/servicos'),
        child: Row(
          children: [
            const Text('📅', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nenhum horário marcado',
                    style: AppTheme.texto(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toque para agendar seu próximo corte',
                    style: AppTheme.texto(size: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.amarelo),
          ],
        ),
      );
    }

    return Cartao(
      selected: true,
      onTap: () => _irPara('/agendamentos'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloSecao('Próximo horário'),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                proximo.servico?.icone ?? '💈',
                style: const TextStyle(fontSize: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proximo.servico?.nome ?? 'Serviço',
                      style: AppTheme.titulo(size: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatarDataExtenso(proximo.data),
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'com ${proximo.barbeiro?.nome ?? ''}',
                      style: AppTheme.texto(size: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatarHora(proximo.data),
                    style: AppTheme.titulo(size: 20, color: AppColors.amarelo),
                  ),
                  const SizedBox(height: 4),
                  const Etiqueta(texto: 'Confirmado', cor: AppColors.green),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardFidelidade() {
    return Cartao(
      onTap: () => _irPara('/fidelidade'),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 26)),
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
                Text(
                  '$_pontos pts',
                  style: AppTheme.titulo(size: 22, color: AppColors.amarelo),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.amarelo),
        ],
      ),
    );
  }

  Widget _gridAcessoRapido() {
    // A administração só aparece para a conta administradora.
    final ehAdmin = AuthService.instance.podeAdministrar;
    final itens = [
      ('💈', 'Ver Serviços', '/servicos'),
      ('📋', 'Meus Agendamentos', '/agendamentos'),
      ('⭐', 'Fidelidade', '/fidelidade'),
      if (ehAdmin)
        ('⚙️', 'Administração', '/admin')
      else
        ('👤', 'Meu Perfil', '/perfil'),
    ];

    return GradeDuasColunas(
      filhos: itens
          .map(
            (item) => Cartao(
              onTap: () => _irPara(item.$3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 10),
                  Text(
                    item.$2,
                    style: AppTheme.texto(size: 13, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _navegacao() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.dark,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
        onTap: _aoTocarNavegacao,
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.amarelo,
        unselectedItemColor: AppColors.muted,
        selectedLabelStyle: AppTheme.texto(size: 11, weight: FontWeight.w700),
        unselectedLabelStyle: AppTheme.texto(size: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Início'),
          BottomNavigationBarItem(
            icon: Icon(Icons.content_cut_outlined),
            label: 'Serviços',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
