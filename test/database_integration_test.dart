// O Flutter não permite executar `test/` e `integration_test/` na mesma
// invocação de `flutter test`. Este arquivo apenas reexporta a suíte de
// integração para que um único `flutter test` rode os 37 testes do projeto.
//
// A suíte continua morando em integration_test/database_integration_test.dart.
import '../integration_test/database_integration_test.dart' as integracao;

void main() => integracao.main();
