import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _agendamentos = 0;
  int _clientes = 0;
  int _barbeiros = 0;
  int _servicos = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final ags = await DatabaseService.instance.contarAgendamentos();
    final cls = await DatabaseService.instance.contarClientes();
    final brs = (await DatabaseService.instance.listarBarbeiros()).length;
    final svs = (await DatabaseService.instance.listarServicos()).length;
    if (!mounted) return;
    setState(() {
      _agendamentos = ags;
      _clientes = cls;
      _barbeiros = brs;
      _servicos = svs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.gold),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MODO ADMINISTRADOR',
                            style: AppTheme.goldLabel()),
                        const SizedBox(height: 2),
                        Text(
                          'Painel de Controle',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.settings, color: AppColors.gold, size: 28),
                ],
              ),
            ),
            const GoldDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(child: _stat('$_agendamentos', 'Agendamentos')),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('$_barbeiros', 'Barbeiros')),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('$_clientes', 'Clientes')),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('$_servicos', 'Serviços')),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel('Gerenciamento'),
                    _adminItem(Icons.content_cut, 'Gerenciar Serviços',
                        '$_servicos serviços cadastrados', () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const _GerenciarServicos()));
                      _carregar();
                    }),
                    _adminItem(Icons.person_outline, 'Gerenciar Barbeiros',
                        '$_barbeiros profissionais ativos', () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const _ListaBarbeiros()));
                    }),
                    _adminItem(Icons.people_outline, 'Gerenciar Clientes',
                        '$_clientes clientes cadastrados', () {
                      _showSnack('Funcionalidade em desenvolvimento');
                    }),
                    _adminItem(Icons.bar_chart, 'Relatórios',
                        'Faturamento e agendamentos', () {
                      _showSnack('Relatórios em desenvolvimento');
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String numero, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(numero,
              style: GoogleFonts.playfairDisplay(
                color: AppColors.gold,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.dmSans(
                color: AppColors.muted,
                fontSize: 9,
              )),
        ],
      ),
    );
  }

  Widget _adminItem(IconData icone, String titulo, String subtitulo,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GoldCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icone, color: AppColors.gold, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: GoogleFonts.dmSans(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: AppTheme.subtitle(size: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.gold.withOpacity(0.6), size: 22),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.gold,
        content: Text(message, style: const TextStyle(color: Colors.black)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Sub-tela: Gerenciar Serviços (CRUD funcional) ───────────────────
class _GerenciarServicos extends StatefulWidget {
  const _GerenciarServicos();

  @override
  State<_GerenciarServicos> createState() => _GerenciarServicosState();
}

class _GerenciarServicosState extends State<_GerenciarServicos> {
  List<Servico>? _servicos;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final l = await DatabaseService.instance.listarServicos();
    if (!mounted) return;
    setState(() => _servicos = l);
  }

  Future<void> _excluir(Servico s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Excluir serviço?',
            style: GoogleFonts.playfairDisplay(
                color: AppColors.gold, fontSize: 18)),
        content: Text('Deseja excluir "${s.nome}"?',
            style: GoogleFonts.dmSans(color: AppColors.text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: GoogleFonts.dmSans(color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Excluir',
                  style: GoogleFonts.dmSans(
                      color: AppColors.red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseService.instance.excluirServico(s.id!);
    _carregar();
  }

  Future<void> _editarOuNovo([Servico? s]) async {
    final result = await showDialog<Servico>(
      context: context,
      builder: (_) => _ServicoFormDialog(servico: s),
    );
    if (result == null) return;
    if (s == null) {
      await DatabaseService.instance.cadastrarServico(result);
    } else {
      await DatabaseService.instance.atualizarServico(result);
    }
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GERENCIAR SERVIÇOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => _editarOuNovo(),
          ),
        ],
      ),
      body: SafeArea(
        child: _servicos == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _servicos!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = _servicos![i];
                  return GoldCard(
                    onTap: () => _editarOuNovo(s),
                    child: Row(
                      children: [
                        Text(s.icone, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.nome,
                                  style: GoogleFonts.dmSans(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(
                                'R\$ ${s.preco.toStringAsFixed(2).replaceAll('.', ',')} · ${s.duracaoMinutos}min',
                                style: AppTheme.subtitle(size: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.red, size: 22),
                          onPressed: () => _excluir(s),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ServicoFormDialog extends StatefulWidget {
  final Servico? servico;
  const _ServicoFormDialog({this.servico});

  @override
  State<_ServicoFormDialog> createState() => _ServicoFormDialogState();
}

class _ServicoFormDialogState extends State<_ServicoFormDialog> {
  late TextEditingController _nome;
  late TextEditingController _desc;
  late TextEditingController _preco;
  late TextEditingController _dur;
  late TextEditingController _icone;

  @override
  void initState() {
    super.initState();
    final s = widget.servico;
    _nome = TextEditingController(text: s?.nome ?? '');
    _desc = TextEditingController(text: s?.descricao ?? '');
    _preco = TextEditingController(text: s?.preco.toString() ?? '');
    _dur = TextEditingController(text: s?.duracaoMinutos.toString() ?? '');
    _icone = TextEditingController(text: s?.icone ?? '💈');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.gold)),
      title: Text(widget.servico == null ? 'Novo Serviço' : 'Editar Serviço',
          style: GoogleFonts.playfairDisplay(
              color: AppColors.gold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: _nome,
                decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 10),
            TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Descrição')),
            const SizedBox(height: 10),
            TextField(
                controller: _preco,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Preço (R\$)')),
            const SizedBox(height: 10),
            TextField(
                controller: _dur,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Duração (minutos)')),
            const SizedBox(height: 10),
            TextField(
                controller: _icone,
                decoration: const InputDecoration(labelText: 'Ícone (emoji)')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.dmSans(color: AppColors.muted))),
        TextButton(
          onPressed: () {
            final s = Servico(
              id: widget.servico?.id,
              nome: _nome.text.trim(),
              descricao: _desc.text.trim(),
              preco: double.tryParse(_preco.text.replaceAll(',', '.')) ?? 0,
              duracaoMinutos: int.tryParse(_dur.text) ?? 30,
              icone: _icone.text.isEmpty ? '💈' : _icone.text,
            );
            Navigator.pop(context, s);
          },
          child: Text('Salvar',
              style: GoogleFonts.dmSans(
                  color: AppColors.gold, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─── Sub-tela: Lista de Barbeiros (consulta) ─────────────────────────
class _ListaBarbeiros extends StatelessWidget {
  const _ListaBarbeiros();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GERENCIAR BARBEIROS')),
      body: SafeArea(
        child: FutureBuilder<List<Barbeiro>>(
          future: DatabaseService.instance.listarBarbeiros(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.gold));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: snap.data!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = snap.data![i];
                return GoldCard(
                  child: Row(
                    children: [
                      GoldAvatar(text: b.iniciais, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.nome,
                                style: GoogleFonts.dmSans(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text(b.especialidade,
                                style: AppTheme.subtitle(size: 12)),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    color: AppColors.gold, size: 12),
                                const SizedBox(width: 3),
                                Text('${b.avaliacao} (${b.avaliacoes})',
                                    style: AppTheme.subtitle(size: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
