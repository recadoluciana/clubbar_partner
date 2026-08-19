import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../caixa/caixa_page.dart';
import '../dashboard/dashboard_page.dart';
import '../leitor_qr/barman_home_page.dart';
import '../leitor_qr/porteiro_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  bool _mostrarSenha = false;
  bool _recuperando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _mensagem(String texto, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: erro ? ClubbarColors.erro : ClubbarColors.sucesso,
      ),
    );
  }

  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    if (email.isEmpty || senha.isEmpty) {
      _mensagem('Preencha e-mail e senha.', erro: true);
      return;
    }
    setState(() => _carregando = true);
    try {
      await AuthService.login(email, senha);
      final cargo = (await StorageService.getCargo() ?? '')
          .trim()
          .toUpperCase();
      if (!mounted) return;
      Widget? destino;
      if (cargo == 'CAIXA') {
        destino = const CaixaPage();
      } else if (cargo == 'GARCOM' || cargo == 'BARMAN') {
        destino = const BarmanHomePage();
      } else if (cargo == 'PORTEIRO') {
        destino = const PorteiroHomePage();
      } else if (cargo == 'SUPERADMIN' ||
          cargo == 'ADMIN' ||
          cargo == 'GERENTE') {
        destino = const DashboardPage();
      }
      if (destino == null) {
        await StorageService.clearToken();
        _mensagem('Usuário não possui cargo definido.', erro: true);
        return;
      }
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => destino!));
    } catch (e) {
      _mensagem(e.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<String?> _dialogoEmail() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: ClubbarColors.ambarClaro,
              child: Icon(Icons.lock_reset_rounded, color: ClubbarColors.preto),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Recuperar senha')),
          ],
        ),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informe o e-mail do seu usuário Partner. Enviaremos um código válido por 15 minutos.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) {
                    final email = valor?.trim() ?? '';
                    return email.contains('@') && email.contains('.')
                        ? null
                        : 'Informe um e-mail válido.';
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, controller.text.trim());
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Enviar código'),
          ),
        ],
      ),
    );
    controller.dispose();
    return email;
  }

  Future<Map<String, String>?> _dialogoCodigo(String email) async {
    final codigo = TextEditingController();
    final senha = TextEditingController();
    final confirmar = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var mostrarSenha = false;
    final resultado = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Criar nova senha'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Digite o código enviado para $email.'),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: codigo,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Código de 6 dígitos',
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) => (valor?.length ?? 0) == 6
                          ? null
                          : 'Informe os 6 dígitos.',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: senha,
                      obscureText: !mostrarSenha,
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setLocal(() => mostrarSenha = !mostrarSenha),
                          icon: Icon(
                            mostrarSenha
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (valor) => (valor?.length ?? 0) >= 6
                          ? null
                          : 'Use pelo menos 6 caracteres.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: confirmar,
                      obscureText: !mostrarSenha,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nova senha',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) => valor == senha.text
                          ? null
                          : 'As senhas não coincidem.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, {
                    'codigo': codigo.text,
                    'senha': senha.text,
                  });
                }
              },
              child: const Text('Redefinir senha'),
            ),
          ],
        ),
      ),
    );
    codigo.dispose();
    senha.dispose();
    confirmar.dispose();
    return resultado;
  }

  Future<void> _recuperarSenha() async {
    if (_recuperando) return;
    final email = await _dialogoEmail();
    if (email == null || !mounted) return;
    setState(() => _recuperando = true);
    try {
      final mensagem = await AuthService.solicitarRecuperacao(email);
      _mensagem(mensagem);
      if (!mounted) return;
      final dados = await _dialogoCodigo(email);
      if (dados == null) return;
      final retorno = await AuthService.redefinirSenha(
        email: email,
        codigo: dados['codigo']!,
        novaSenha: dados['senha']!,
      );
      _emailController.text = email;
      _senhaController.clear();
      _mensagem(retorno);
    } catch (e) {
      _mensagem(e.toString(), erro: true);
    } finally {
      if (mounted) setState(() => _recuperando = false);
    }
  }

  Widget _campoLogin() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 470),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ClubbarColors.branco,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ClubbarColors.borda),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bem-vindo de volta',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Acesse a gestão do seu estabelecimento.',
            style: TextStyle(
              fontSize: 15,
              color: ClubbarColors.textoSecundario,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.alternate_email_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _senhaController,
            obscureText: !_mostrarSenha,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _carregando ? null : _fazerLogin(),
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                icon: Icon(
                  _mostrarSenha ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _recuperando ? null : _recuperarSenha,
              child: Text(_recuperando ? 'Enviando...' : 'Recuperar senha'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _carregando ? null : _fazerLogin,
              style: FilledButton.styleFrom(
                backgroundColor: ClubbarColors.preto,
                foregroundColor: ClubbarColors.branco,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _carregando
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(
                _carregando ? 'Entrando...' : 'Entrar',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 17,
                color: ClubbarColors.sucesso,
              ),
              SizedBox(width: 6),
              Text(
                'Ambiente seguro para parceiros',
                style: TextStyle(
                  fontSize: 12,
                  color: ClubbarColors.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _marca({required bool compacta}) {
    return Padding(
      padding: EdgeInsets.all(compacta ? 8 : 42),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: compacta
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Image.asset('assets/images/logo.png', height: compacta ? 58 : 82),
          SizedBox(height: compacta ? 10 : 30),
          if (!compacta) ...[
            const Text(
              'Sua operação,\nsempre sob controle.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Acompanhe vendas, agenda, cardápio e financeiro em um só lugar.',
              style: TextStyle(
                color: Color(0xFFD6D6D6),
                fontSize: 17,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Beneficio(
                  icone: Icons.analytics_outlined,
                  texto: 'Indicadores em tempo real',
                ),
                _Beneficio(
                  icone: Icons.storefront_outlined,
                  texto: 'Gestão dos estabelecimentos',
                ),
                _Beneficio(
                  icone: Icons.event_available_outlined,
                  texto: 'Agenda e ingressos',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: ClubbarColors.preto,
        foregroundColor: ClubbarColors.branco,
        title: const Text(
          'Clubbar Partner',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Fechar aplicativo',
            onPressed: () async {
              await StorageService.clearToken();
              await SystemNavigator.pop();
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          if (desktop) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF111111),
                          Color(0xFF292000),
                          Color(0xFF5A4300),
                        ],
                      ),
                    ),
                    child: _marca(compacta: false),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: Center(child: _campoLogin()),
                  ),
                ),
              ],
            );
          }
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ClubbarColors.preto,
                  Color(0xFF3B2C00),
                  Color(0xFFF2F3F5),
                ],
                stops: [0, 0.3, 0.3],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              child: Column(
                children: [
                  _marca(compacta: true),
                  const SizedBox(height: 8),
                  _campoLogin(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Beneficio extends StatelessWidget {
  final IconData icone;
  final String texto;
  const _Beneficio({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 19, color: ClubbarColors.ambar),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
