import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/database_service.dart';
import '../services/formatters.dart';
import '../services/validators.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// CRUD completo da equipe (`/admin` → Gerenciar Barbeiros).
///
/// Cada profissional tem nome, especialidade, telefone, e-mail e senha de
/// acesso ao app, além do salário.
class AdminBarbeirosScreen extends StatefulWidget {
  const AdminBarbeirosScreen({super.key});

  @override
  State<AdminBarbeirosScreen> createState() => _AdminBarbeirosScreenState();
}

class _AdminBarbeirosScreenState extends State<AdminBarbeirosScreen> {
  final _db = DatabaseService.instance;

  List<Barbeiro> _barbeiros = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _db.listarBarbeiros();
      if (!mounted) return;
      setState(() {
        _barbeiros = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      mostrarErro(context, 'Erro ao carregar barbeiros: $e');
    }
  }

  Future<void> _abrirFormulario({Barbeiro? barbeiro}) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioBarbeiro(barbeiro: barbeiro),
    );
    if (salvou == true && mounted) await _carregar();
  }

  Future<void> _excluir(Barbeiro b) async {
    if (b.id == null) return;

    // Excluir um barbeiro com agendamentos faria esses registros sumirem da
    // tela do cliente, porque a listagem usa INNER JOIN.
    final vinculados = await _db.contarAgendamentosDoBarbeiro(b.id!);
    if (!mounted) return;

    if (vinculados > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text('Não é possível excluir', style: AppTheme.serif(size: 18)),
          content: Text(
            '${b.nome} possui $vinculados agendamento(s) registrado(s). '
            'Excluí-lo faria esses atendimentos desaparecerem do histórico '
            'dos clientes.',
            style: AppTheme.sans(size: 13, color: AppColors.muted, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'ENTENDI',
                style: AppTheme.sans(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Excluir barbeiro?', style: AppTheme.serif(size: 18)),
        content: Text(
          '"${b.nome}" será removido permanentemente da equipe.',
          style: AppTheme.sans(size: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCELAR',
              style: AppTheme.sans(size: 13, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'EXCLUIR',
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    try {
      await _db.excluirBarbeiro(b.id!);
      if (!mounted) return;
      mostrarInfo(context, 'Barbeiro excluído');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      mostrarErro(context, 'Erro ao excluir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BarberAppBar(
        titulo: 'BARBEIROS',
        acoes: [
          IconButton(
            tooltip: 'Novo barbeiro',
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => _abrirFormulario(),
          ),
        ],
      ),
      body: Column(
        children: [
          const GoldDivider(),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _barbeiros.isEmpty
                ? const EstadoVazio(
                    icone: '✂️',
                    titulo: 'Nenhum barbeiro',
                    descricao: 'Use o botão + para cadastrar o primeiro.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: _barbeiros.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _card(_barbeiros[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(Barbeiro b) {
    return GoldCard(
      onTap: () => _abrirFormulario(barbeiro: b),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GoldAvatar(texto: b.iniciais, tamanho: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.nome, style: AppTheme.serif(size: 16)),
                    const SizedBox(height: 3),
                    Text(
                      b.especialidade,
                      style: AppTheme.sans(size: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.red,
                  size: 20,
                ),
                onPressed: () => _excluir(b),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _linha(Icons.phone_outlined, b.telefone.isEmpty ? '—' : b.telefone),
          const SizedBox(height: 6),
          _linha(Icons.mail_outline, b.email.isEmpty ? '—' : b.email),
          const SizedBox(height: 6),
          _linha(Icons.payments_outlined, formatarReal(b.salario)),
          const SizedBox(height: 6),
          _linha(
            Icons.star_outline,
            '${b.avaliacao.toStringAsFixed(1)} (${b.avaliacoes} avaliações)',
          ),
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String texto) {
    return Row(
      children: [
        Icon(icone, size: 15, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(size: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// FORMULÁRIO
// ---------------------------------------------------------------------------

/// Diálogo de cadastro/edição. Em widget próprio para que os
/// [TextEditingController] sigam o ciclo de vida do formulário.
class _FormularioBarbeiro extends StatefulWidget {
  final Barbeiro? barbeiro;

  const _FormularioBarbeiro({this.barbeiro});

  @override
  State<_FormularioBarbeiro> createState() => _FormularioBarbeiroState();
}

class _FormularioBarbeiroState extends State<_FormularioBarbeiro> {
  late final TextEditingController _nome;
  late final TextEditingController _especialidade;
  late final TextEditingController _telefone;
  late final TextEditingController _email;
  late final TextEditingController _salario;
  final _senha = TextEditingController();

  bool _ocultarSenha = true;
  bool _salvando = false;

  bool get _editando => widget.barbeiro != null;

  @override
  void initState() {
    super.initState();
    final b = widget.barbeiro;
    _nome = TextEditingController(text: b?.nome ?? '');
    _especialidade = TextEditingController(text: b?.especialidade ?? '');
    _telefone = TextEditingController(text: b?.telefone ?? '');
    _email = TextEditingController(text: b?.email ?? '');
    _salario = TextEditingController(
      text: b == null ? '' : formatarMoedaDeCentavos((b.salario * 100).round()),
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _especialidade.dispose();
    _telefone.dispose();
    _email.dispose();
    _salario.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final salario = moedaParaDouble(_salario.text);

    final erro = Validators.validarBarbeiro(
      nome: _nome.text,
      especialidade: _especialidade.text,
      telefone: _telefone.text,
      email: _email.text,
      senha: _senha.text,
      salario: salario,
      // Na edição, senha em branco mantém a atual.
      senhaObrigatoria: !_editando,
    );
    if (erro != null) {
      mostrarErro(context, erro);
      return;
    }

    setState(() => _salvando = true);

    try {
      final db = DatabaseService.instance;
      final email = _email.text.trim().toLowerCase();

      if (await db.emailBarbeiroExiste(email, ignorarId: widget.barbeiro?.id)) {
        if (!mounted) return;
        setState(() => _salvando = false);
        mostrarErro(context, 'Este e-mail já está cadastrado');
        return;
      }
      // Não pode colidir com o e-mail de um cliente.
      if (await db.emailExiste(email)) {
        if (!mounted) return;
        setState(() => _salvando = false);
        mostrarErro(context, 'Este e-mail já está cadastrado');
        return;
      }

      final anterior = widget.barbeiro;
      final senhaHash = _senha.text.isEmpty && anterior != null
          ? anterior.senhaHash
          : DatabaseService.hashSenha(_senha.text);

      final registro = Barbeiro(
        id: anterior?.id,
        nome: _nome.text.trim(),
        especialidade: _especialidade.text.trim(),
        avaliacao: anterior?.avaliacao ?? 0,
        avaliacoes: anterior?.avaliacoes ?? 0,
        iniciais: Barbeiro.iniciaisDe(_nome.text),
        telefone: _telefone.text.trim(),
        email: email,
        senhaHash: senhaHash,
        salario: salario,
      );

      if (_editando) {
        await db.atualizarBarbeiro(registro);
      } else {
        await db.cadastrarBarbeiro(registro);
      }

      if (!mounted) return;
      mostrarSucesso(
        context,
        _editando ? 'Barbeiro atualizado' : 'Barbeiro cadastrado',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarErro(context, 'Erro ao salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(
        _editando ? 'Editar barbeiro' : 'Novo barbeiro',
        style: AppTheme.serif(size: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _campo(_nome, 'Nome completo', capitalizar: true),
            _campo(_especialidade, 'Especialidade'),
            _campo(
              _telefone,
              'Telefone',
              teclado: TextInputType.phone,
              formatters: [TelefoneInputFormatter()],
            ),
            _campo(
              _email,
              'E-mail de acesso',
              teclado: TextInputType.emailAddress,
            ),
            _campo(
              _senha,
              _editando
                  ? 'Nova senha (deixe vazio para manter)'
                  : 'Senha de acesso (mín. 6)',
              obscuro: _ocultarSenha,
              sufixo: IconButton(
                icon: Icon(
                  _ocultarSenha
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                  size: 20,
                ),
                onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
              ),
            ),
            _campo(
              _salario,
              'Salário (R\$)',
              teclado: TextInputType.number,
              formatters: [MoedaInputFormatter()],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'CANCELAR',
            style: AppTheme.sans(size: 13, color: AppColors.muted),
          ),
        ),
        TextButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(
            _salvando ? 'SALVANDO...' : 'SALVAR',
            style: AppTheme.sans(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _campo(
    TextEditingController controller,
    String rotulo, {
    TextInputType teclado = TextInputType.text,
    List<dynamic>? formatters,
    bool obscuro = false,
    bool capitalizar = false,
    Widget? sufixo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        obscureText: obscuro,
        textCapitalization: capitalizar
            ? TextCapitalization.words
            : TextCapitalization.none,
        inputFormatters: formatters?.cast(),
        style: AppTheme.sans(size: 14),
        decoration: InputDecoration(labelText: rotulo, suffixIcon: sufixo),
      ),
    );
  }
}
