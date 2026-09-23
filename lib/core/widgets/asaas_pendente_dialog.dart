import 'package:flutter/material.dart';

import '../../modules/financeiro_onboarding/titulares_financeiros_page.dart';
import '../theme/clubbar_colors.dart';

bool erroIndicaPendenteAsaas(Object erro) {
  final texto = erro.toString().toLowerCase();
  return texto.contains('asaas_pendente') ||
      texto.contains('conta de recebimentos asaas') ||
      texto.contains('conta no asaas ainda não foi aprovada') ||
      texto.contains('temporariamente indisponível para compras');
}

Future<void> mostrarDialogoAsaasPendente(
  BuildContext context, {
  required String recurso,
}) async {
  if (!context.mounted) return;

  final abrirConfiguracao = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.account_balance_outlined,
        color: ClubbarColors.primaria,
        size: 36,
      ),
      title: const Text('Ative seus recebimentos no Asaas'),
      content: Text(
        'Para publicar $recurso e receber pagamentos pelo Clubbar, a empresa precisa criar e ter aprovada a conta de recebimentos no Asaas.\n\n'
        'Acesse Titular financeiro, informe os dados solicitados e conclua o cadastro. Depois da aprovação do Asaas, volte aqui e publique novamente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Agora não'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Configurar conta Asaas'),
        ),
      ],
    ),
  );

  if (!context.mounted || abrirConfiguracao != true) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const TitularesFinanceirosPage()),
  );
}
