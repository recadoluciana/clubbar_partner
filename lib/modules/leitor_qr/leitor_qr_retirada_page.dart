import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/services/api_service.dart';

class LeitorQrRetiradaScreen extends StatefulWidget {
const LeitorQrRetiradaScreen({super.key});

@override
State<LeitorQrRetiradaScreen> createState() =>
_LeitorQrRetiradaScreenState();
}

class _LeitorQrRetiradaScreenState extends State<LeitorQrRetiradaScreen> {
bool processando = false;
bool lendoQr = false;

Future<void> _processarQr(String raw) async {
if (processando) return;

```
setState(() => processando = true);

try {
  final data = jsonDecode(raw);

  final itvendaId = data['itvenda_id'];
  final loja = data['nmloja'];
  final cliente = data['nmcliente'];
  final produto = data['nmproduto'];
  final observacao = data['dsobsitvenda'];

  if (!mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('QR Code lido'),
      content: Text(
        'Cliente: $cliente\n'
        'Estabelecimento: $loja\n'
        'Produto: $produto\n'
        'Observação: ${observacao ?? ""}\n'
        'Item Venda: $itvendaId',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);

            setState(() {
              processando = false;
              lendoQr = false;
            });
          },
          child: const Text('Fechar'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final resposta = await ApiService.confirmarRetirada(
                itvendaId: itvendaId is int
                    ? itvendaId
                    : int.parse(itvendaId.toString()),
              );

              if (!mounted) return;

              Navigator.pop(context);

              if (resposta['already'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Este produto já foi entregue.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Produto entregue com sucesso.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }

              setState(() {
                processando = false;
                lendoQr = false;
              });

              return;
            } catch (e) {
              if (!mounted) return;

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Erro ao confirmar retirada: $e',
                  ),
                  backgroundColor: Colors.red,
                ),
              );

              setState(() {
                processando = false;
                lendoQr = false;
              });
            }
          },
          child: const Text('Confirmar retirada'),
        ),
      ],
    ),
  );
} catch (e) {
  setState(() {
    processando = false;
    lendoQr = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('QR Code inválido'),
    ),
  );
}
```

}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.black,
appBar: AppBar(
title: const Text('Leitor de retirada'),
backgroundColor: Colors.black,
foregroundColor: Colors.white,
actions: [
if (lendoQr)
IconButton(
icon: const Icon(Icons.close),
onPressed: () {
setState(() {
lendoQr = false;
processando = false;
});
},
),
],
),
body: lendoQr
? Stack(
children: [
MobileScanner(
onDetect: (capture) {
final barcode = capture.barcodes.firstOrNull;
final raw = barcode?.rawValue;

```
                if (raw != null && raw.isNotEmpty) {
                  _processarQr(raw);
                }
              },
            ),
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFFFC107),
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        )
      : Center(
          child: SizedBox(
            width: 260,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  lendoQr = true;
                  processando = false;
                });
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Ler QR Code',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
);
```

}
}
