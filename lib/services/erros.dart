import 'dart:developer' as developer;

import '../models/models.dart';

/// Traduz uma exceção em mensagem para o usuário.
///
/// Regra de negócio chega como foi escrita ("O horário 09:00 não está mais
/// livre"). Qualquer outra falha vira [contexto] + um pedido para tentar de
/// novo: o texto da exceção (SQL, nomes de tabela, pilha) vai só para o log,
/// nunca para a tela.
String mensagemDeErro(Object erro, String contexto) {
  if (erro is RegraNegocioException) return erro.mensagem;
  developer.log(contexto, name: 'sysbarber', error: erro);
  return '$contexto. Tente novamente.';
}
