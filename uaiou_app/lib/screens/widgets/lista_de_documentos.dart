import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:uaiou/core/documentos/documento.dart';
import 'package:uaiou/core/documentos/estado_documentos.dart';
import 'package:uaiou/core/uploads/repositorio_uploads.dart';
import 'package:uaiou/core/uploads/seletor_de_imagem.dart';
import 'package:uaiou/screens/widgets/visao_carregavel.dart';

/// ===============================================================
/// DOCUMENTOS DE CADASTRO — RF-A04.5 e RF-A04.8
/// ===============================================================
///
/// Mostra o que já foi enviado, o que falta e o que voltou rejeitado
/// **com o motivo** — sem isso o usuário rejeitado fica sem saída
/// dentro do app.
///
/// O que pedir vem de `missingTypes` (RF-06.1): é o servidor que sabe
/// quais documentos o papel exige, não o app.
class ListaDeDocumentos extends StatelessWidget {
  const ListaDeDocumentos({super.key});

  static const Color _corPrincipal = Color.fromRGBO(254, 98, 29, 1);

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoDocumentos>();

    return VisaoCarregavel<SituacaoDocumental>(
      estado: estado.estado,
      aoTentarNovamente: estado.carregar,
      textoVazio: 'Nenhum documento exigido',
      iconeVazio: Icons.folder_open,
      construir: (situacao) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (estado.erroDeEnvio != null) _Erro(estado.erroDeEnvio!),

          ...situacao.vigentes.map(
            (documento) =>
                _LinhaDeDocumento(tipo: documento.tipo, documento: documento),
          ),

          // O que ainda não foi enviado nenhuma vez.
          ...situacao.faltando.map((tipo) => _LinhaDeDocumento(tipo: tipo)),

          if (situacao.completo) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Todos os documentos foram enviados.',
                    style: TextStyle(fontSize: 13, color: Colors.green),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  final String mensagem;
  const _Erro(this.mensagem);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        mensagem,
        style: const TextStyle(color: Colors.red, fontSize: 13),
      ),
    );
  }
}

class _LinhaDeDocumento extends StatelessWidget {
  final PropositoUpload tipo;
  final Documento? documento;

  const _LinhaDeDocumento({required this.tipo, this.documento});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoDocumentos>();
    final envio = estado.envios[tipo];
    final status = documento?.status;

    // Rejeitado e ausente pedem ação; pendente e aprovado, não.
    final precisaEnviar =
        documento == null || status == StatusDocumento.rejeitado;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icone(status), size: 20, color: _cor(status)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tipo.rotulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                status?.rotulo ?? 'Pendente de envio',
                style: TextStyle(fontSize: 12, color: _cor(status)),
              ),
            ],
          ),

          // RF-A04.8 — sem o motivo, o usuário rejeitado não sabe o
          // que corrigir.
          if (documento?.motivoDaRejeicao != null) ...[
            const SizedBox(height: 8),
            Text(
              documento!.motivoDaRejeicao!,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ],

          if (envio != null) ...[
            const SizedBox(height: 12),
            _Progresso(tipo: tipo, progresso: envio.progresso),
          ] else if (precisaEnviar) ...[
            const SizedBox(height: 10),
            _BotoesDeEnvio(tipo: tipo, reenvio: documento != null),
          ],
        ],
      ),
    );
  }

  IconData _icone(StatusDocumento? status) => switch (status) {
    StatusDocumento.aprovado => Icons.verified,
    StatusDocumento.rejeitado => Icons.error_outline,
    StatusDocumento.pendente => Icons.hourglass_top,
    _ => Icons.upload_file,
  };

  Color _cor(StatusDocumento? status) => switch (status) {
    StatusDocumento.aprovado => Colors.green,
    StatusDocumento.rejeitado => Colors.red,
    StatusDocumento.pendente => Colors.orange,
    _ => Colors.grey,
  };
}

/// RF-A04.7 — progresso visível e envio cancelável.
class _Progresso extends StatelessWidget {
  final PropositoUpload tipo;
  final double progresso;

  const _Progresso({required this.tipo, required this.progresso});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso == 0 ? null : progresso,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation(
                ListaDeDocumentos._corPrincipal,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.read<EstadoDocumentos>().cancelar(tipo),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _BotoesDeEnvio extends StatelessWidget {
  final PropositoUpload tipo;
  final bool reenvio;

  const _BotoesDeEnvio({required this.tipo, required this.reenvio});

  Future<void> _escolher(BuildContext context, OrigemDaImagem origem) async {
    final estado = context.read<EstadoDocumentos>();
    final seletor = context.read<SeletorDeImagem>();

    final imagem = await seletor.escolher(origem);
    // Desistir ou negar a permissão não trava a tela (RF-A04.9).
    if (imagem == null) return;

    await estado.enviarDocumento(
      tipo: tipo,
      bytes: imagem.bytes,
      tipoDeConteudo: imagem.tipoDeConteudo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final temCamera = context.read<SeletorDeImagem>().temCamera;

    return Row(
      children: [
        if (temCamera) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _escolher(context, OrigemDaImagem.camera),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Câmera'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _escolher(context, OrigemDaImagem.galeria),
            style: ElevatedButton.styleFrom(
              backgroundColor: ListaDeDocumentos._corPrincipal,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(reenvio ? 'Reenviar' : 'Enviar'),
          ),
        ),
      ],
    );
  }
}
