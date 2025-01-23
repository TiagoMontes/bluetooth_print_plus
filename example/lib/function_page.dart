import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

enum CmdType { Tsc, Cpcl, Esc }

class FunctionPage extends StatefulWidget {
  final BluetoothDevice device;

  const FunctionPage(this.device, {super.key});

  @override
  State<FunctionPage> createState() => _FunctionPageState();
}

class _FunctionPageState extends State<FunctionPage> {
  CmdType cmdType = CmdType.Tsc;
  int rodada = 1;
  String minCartela = '';
  String maxCartela = '';
  int rangeInicial = 0;
  int rangeFinal = 0;
  String valorCartela = '';
  int totalQuantidade = 0;
  double totalValor = 0.0;
  List<Map<String, int>> intervalosVendidos = [];
  bool modalVisible = false;
  bool modalRodadaVisible = false;
  final TextEditingController _controllerQuantidade = TextEditingController();
  bool vendaPorCombo = false; // Default to off
  Map<String, dynamic>? ultimaVenda;

  @override
  void initState() {
    super.initState();
    carregarConfiguracaoLocal();
    carregarDadosVendaLocal();
    carregarUltimaVenda();
  }

  @override
  void deactivate() {
    super.deactivate();
    _disconnect();
  }

  void _disconnect() async {
    await BluetoothPrintPlus.disconnect();
  }

  // Salvar configurações
  Future<void> salvarConfiguracaoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('minCartela', minCartela);
    await prefs.setString('maxCartela', maxCartela);
    await prefs.setString('valorCartela', valorCartela);
    await prefs.setInt('rodada', rodada);
    await prefs.setInt('rangeInicial', rangeInicial);
    await prefs.setInt('rangeFinal', rangeFinal);
  }

// Carregar configurações
  Future<void> carregarConfiguracaoLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      minCartela = prefs.getString('minCartela') ?? '';
      maxCartela = prefs.getString('maxCartela') ?? '';
      valorCartela = prefs.getString('valorCartela') ?? '';
      rodada = prefs.getInt('rodada') ?? 1;
      rangeInicial = prefs.getInt('rangeInicial') ?? 0;
      rangeFinal = prefs.getInt('rangeFinal') ?? 0;
    });
  }

// Salvar dados de vendas
  Future<void> salvarDadosVendaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    print("Antes de salvar intervalosVendidos: $intervalosVendidos");
    await prefs.setInt('totalQuantidade', totalQuantidade);
    await prefs.setDouble('totalValor', totalValor);
    List<String> intervalosString = intervalosVendidos.map((map) => jsonEncode(map)).toList();

    // Salvando no SharedPreferences
    await prefs.setStringList('intervalosVendidos', intervalosString);

    // Verifique se os dados foram realmente salvos
    String? savedData = prefs.getString('intervalosVendidos');
    print("Dados salvos em intervalosVendidos: $savedData");
  }


// Carregar dados de vendas
  Future<void> carregarDadosVendaLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      totalQuantidade = prefs.getInt('totalQuantidade') ?? 0;
      totalValor = prefs.getDouble('totalValor') ?? 0.0;

      List<String>? intervalosString = prefs.getStringList('intervalosVendidos');

      if (intervalosString != null) {
        // Convertendo de volta para List<Map<String, int>>
        intervalosVendidos = intervalosString.map((string) => Map<String, int>.from(jsonDecode(string))).toList();
      } else {
        // Retorna uma lista vazia se não houver dados
        intervalosVendidos = [];
      }
    });
  }

  Future<void> salvarUltimaVenda(Map<String, dynamic> venda) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ultimaVenda', jsonEncode(venda));
  }

  Future<void> carregarUltimaVenda() async {
    final prefs = await SharedPreferences.getInstance();
    String? vendaJson = prefs.getString('ultimaVenda');
    if (vendaJson != null) {
      setState(() {
        ultimaVenda = jsonDecode(vendaJson);
      });
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void salvarConfiguracao() {
    if (minCartela.isEmpty || maxCartela.isEmpty || int.parse(minCartela) >= int.parse(maxCartela)) {
      _showAlert('Erro', 'Por favor, insira valores válidos para o intervalo inicial e final');
      return;
    }
    if (valorCartela.isEmpty) {
      _showAlert('Erro', 'Por favor, preencha o valor por cartela');
      return;
    }

    setState(() {
      rangeInicial = int.parse(minCartela);
      rangeFinal = int.parse(maxCartela);
      modalVisible = false;
    });

    salvarConfiguracaoLocal(); // Salvar localmente
  }

  void finalizarVenda() async {
    int inicial = rangeInicial;
    int quantidadeVendida = int.tryParse(_controllerQuantidade.text) ?? 0;
    int quantidadeFinal = vendaPorCombo ? quantidadeVendida * 6 : quantidadeVendida;
    double totalVenda = vendaPorCombo
        ? (quantidadeFinal ~/ 6) * double.parse(valorCartela)
        : quantidadeVendida * double.parse(valorCartela);
    int finalVenda = inicial + quantidadeFinal - 1;

    if (inicial <= 0 ||
        quantidadeVendida <= 0 ||
        finalVenda > rangeFinal ||
        inicial < int.parse(minCartela)) {
      _showAlert('Erro', 'Intervalo inválido.');
      return;
    }

    setState(() {
      totalQuantidade += quantidadeFinal;
      totalValor += totalVenda;
      intervalosVendidos.add({'inicial': inicial, 'final': finalVenda});
      rangeInicial = finalVenda + 1;
    });

    salvarDadosVendaLocal();

    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);

    if (quantidadeVendida > 0) {
      setState(() {
        ultimaVenda = {
          'rodada': rodada,
          'quantidadeFinal': quantidadeFinal,
          'valorCartela': valorCartela,
          'inicial': inicial,
          'finalVenda': finalVenda,
          'totalVenda': totalVenda.toStringAsFixed(2),
          'dataHora': formattedDate,
        };
      });

      salvarUltimaVenda(ultimaVenda!); // Salvar a última venda localmente
    }

    try {
      // Configure o perfil da impressora
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      // Gera o conteúdo para impressão
      List<int> bytes = [];
      bytes += generator.text('Boa sorte',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.hr(); // Linha separadora
      bytes += generator.text('Rodada: $rodada',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.text(
          'Quantidade: $quantidadeFinal${!vendaPorCombo ? ' x R\$${valorCartela}' : ''}',
          styles: PosStyles(align: PosAlign.left));
      bytes += generator.text('Data/Hora: $formattedDate',
          styles: PosStyles(align: PosAlign.left));
      bytes += generator.hr();
      bytes += generator.text('Cartelas',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.text('$inicial - $finalVenda',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.text('Total: R\$${totalVenda.toStringAsFixed(2)}',
          styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.cut(); // Finaliza a impressão com corte

      final Uint8List data = Uint8List.fromList(bytes);

      await BluetoothPrintPlus.write(data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impressão realizada com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao imprimir: $e")),
      );
    }

    _controllerQuantidade.clear();
  }

  void finalizarRodada() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);

    // Calcula o intervalo restante
    int restanteInicial = intervalosVendidos.isEmpty
        ? int.parse(minCartela)
        : intervalosVendidos.last['final']! + 1;
    int restanteFinal = int.parse(maxCartela);

    // Verifica se todo o intervalo foi vendido
    String restante =
    (restanteInicial > restanteFinal) ? '0' : '$restanteInicial - $restanteFinal';

    // Configura o gerador ESC/POS
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Adiciona os textos formatados
    bytes += generator.text(
      'Rodada Finalizada!',
      styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
    );
    bytes += generator.text(
      'Intervalo: ${intervalosVendidos.isNotEmpty ? '${intervalosVendidos.first['inicial']}-${intervalosVendidos.last['final']}' : 'Nenhum'}',
      styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2),
    );
    bytes += generator.text(
      'Quantidade Vendida: $totalQuantidade',
      styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2),
    );
    bytes += generator.text(
      'Total: R\$${totalValor.toStringAsFixed(2)}',
      styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2),
    );
    bytes += generator.text(
      'Data/Hora: $formattedDate',
      styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2),
    );
    bytes += generator.text(
      'Restante: $restante',
      styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2),
    );
    bytes += generator.cut(); // Finaliza o papel com corte

    // Envia os dados para impressão
    try {
      await BluetoothPrintPlus.write(Uint8List.fromList(bytes));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impressão realizada com sucesso!")),
      );
      setState(() {
        rodada++;
        minCartela = '';
        maxCartela = '';
        valorCartela = '';
        rangeInicial = 0;
        rangeFinal = 0;
        totalQuantidade = 0;
        totalValor = 0.0;
        intervalosVendidos.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao imprimir: $e")),
      );
    }
  }

  void adicionarMaisCartelas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final TextEditingController _controllerQuantidade = TextEditingController();
        String? errorText;

        void validarCampos() {
          setState(() {
            if (_controllerQuantidade.text.isEmpty ||
                int.tryParse(_controllerQuantidade.text) == null) {
              errorText = 'Por favor, insira uma quantidade válida';
            } else {
              errorText = null;
              int quantidade = int.parse(_controllerQuantidade.text);

              // Verifica se o combo está ativado e ajusta a quantidade
              if (vendaPorCombo) {
                quantidade *= 6;
              }

              setState(() {
                rangeFinal += quantidade; // Atualiza o range final
              });

              Navigator.pop(context);
            }
          });
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16.0,
            left: 16.0,
            right: 16.0,
          ),
          child: Wrap(
            children: [
              Text(
                'Adicionar Mais Cartelas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                vendaPorCombo
                    ? 'Insira a quantidade de combos (multiplicado por 6)'
                    : 'Insira a quantidade de cartelas',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _controllerQuantidade,
                decoration: InputDecoration(
                  labelText: 'Quantidade',
                  errorText: errorText,
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: validarCampos,
                    child: Text('Adicionar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void exibirModalCartela() {
    final TextEditingController minCartelaController = TextEditingController(text: minCartela);
    final TextEditingController maxCartelaController = TextEditingController(text: maxCartela);
    final TextEditingController valorCartelaController = TextEditingController(text: valorCartela);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16.0,
            left: 16.0,
            right: 16.0,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              String? cartelaInicialError;
              String? cartelaFinalError;
              String? valorCartelaError;

              void validarCampos() {
                setModalState(() {
                  cartelaInicialError = minCartelaController.text.isEmpty ? 'Campo obrigatório' : null;
                  cartelaFinalError = maxCartelaController.text.isEmpty ? 'Campo obrigatório' : null;
                  valorCartelaError = valorCartelaController.text.isEmpty ? 'Campo obrigatório' : null;
                });

                if (cartelaInicialError == null &&
                    cartelaFinalError == null &&
                    valorCartelaError == null) {
                  setState(() {
                    minCartela = minCartelaController.text;
                    maxCartela = maxCartelaController.text;
                    valorCartela = valorCartelaController.text;
                  });
                  salvarConfiguracao();
                  Navigator.pop(context);
                }
              }

              return Wrap(
                children: [
                  Text(
                    'Configurar Cartela',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: minCartelaController,
                    decoration: InputDecoration(
                      labelText: 'Cartela Inicial',
                      errorText: cartelaInicialError,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: maxCartelaController,
                    decoration: InputDecoration(
                      labelText: 'Cartela Final',
                      errorText: cartelaFinalError,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: valorCartelaController,
                    decoration: InputDecoration(
                      labelText: vendaPorCombo
                          ? 'Valor do Combo (ex: 15.00)'
                          : 'Valor Unitário (ex: 2.50)',
                      errorText: valorCartelaError,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Venda por combo: ${vendaPorCombo ? "Ativado" : "Desativado"}'),
                        ElevatedButton(
                          onPressed: () {
                            setModalState(() {
                              vendaPorCombo = !vendaPorCombo;
                              if (vendaPorCombo) {
                                valorCartelaController.text = '10'; // Valor padrão para combos
                              } else {
                                valorCartelaController.text = '1'; // Ajusta para 1 ao desativar
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vendaPorCombo ? Colors.green : Colors.grey,
                          ),
                          child: Text(vendaPorCombo ? 'Desativar' : 'Ativar'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: validarCampos,
                        child: Text('Salvar'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void exibirModalRodada() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final TextEditingController _controllerRodada = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16.0,
            left: 16.0,
            right: 16.0,
          ),
          child: Wrap(
            children: [
              Text(
                'Configurar Rodada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _controllerRodada,
                decoration: InputDecoration(labelText: 'Número da Rodada'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end, // Alinha o botão à direita
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0), // Padding de 16px em cima e embaixo
                    child: ElevatedButton(
                      onPressed: () {
                        if (_controllerRodada.text.isEmpty) {
                          _showAlert('Erro', 'Por favor, insira um número válido para a rodada');
                          return;
                        }
                        setState(() {
                          rodada = int.parse(_controllerRodada.text);
                        });
                        Navigator.pop(context); // Fecha o modal
                      },
                      child: Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Boa Sorte!'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rodada: $rodada',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: () => exibirModalRodada(),
                    child: Text('Configurar Rodada'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: exibirModalCartela,
                child: Text('Configurar Cartela'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (minCartela.isNotEmpty && maxCartela.isNotEmpty)
                        ? '$minCartela - $rangeFinal'
                        : 'Intervalo não definido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: adicionarMaisCartelas,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white, // Ajusta o tamanho do botão
                    ),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 24, // Aumenta o tamanho da fonte
                        fontWeight: FontWeight.bold, // Torna o texto mais destacado
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(valorCartela.isNotEmpty
                  ? 'Valor: R\$${valorCartela}'
                  : 'Valor: Não definido'),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _controllerQuantidade,
                      decoration: InputDecoration(labelText: 'Quantidade'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 10),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: finalizarVenda,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                child: Text('Finalizar Venda'),
              ),
              SizedBox(height: 20),
              Text('Quantidade Total Vendida: $totalQuantidade'),
              Text('Valor Total Vendido: R\$${totalValor.toStringAsFixed(2)}'),
              Text(
                'Intervalos Vendidos: ${intervalosVendidos.isEmpty ? 'Nenhum' : '${intervalosVendidos.first['inicial']}-${intervalosVendidos.last['final']}'}',
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: finalizarRodada,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                child: Text('Finalizar Rodada', selectionColor: Colors.red),
              ),
              SizedBox(height: 20),

              // Adicionar o histórico da última venda
              if (ultimaVenda != null)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Última Venda',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Rodada: ${ultimaVenda!['rodada']}'),
                      Text('Quantidade: ${ultimaVenda!['quantidadeFinal']}'),
                      Text('Cartelas: ${ultimaVenda!['inicial']} - ${ultimaVenda!['finalVenda']}'),
                      Text('Total: R\$${ultimaVenda!['totalVenda']}'),
                      Text('Data/Hora: ${ultimaVenda!['dataHora']}'),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          if (ultimaVenda == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Nenhuma venda disponível para reimpressão")),
                            );
                            return;
                          }

                          try {
                            // Configura o gerador ESC/POS
                            final profile = await CapabilityProfile.load();
                            final generator = Generator(PaperSize.mm58, profile);
                            List<int> bytes = [];

                            // Adiciona os textos formatados
                            bytes += generator.text(
                              'Boa sorte',
                              styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
                            );
                            bytes += generator.hr();
                            bytes += generator.text(
                              'Rodada: ${ultimaVenda!['rodada']}',
                              styles: PosStyles(align: PosAlign.center, height: PosTextSize.size2),
                            );
                            bytes += generator.text(
                              'Quantidade: ${ultimaVenda!['quantidadeFinal']}',
                              styles: PosStyles(align: PosAlign.left, height: PosTextSize.size1),
                            );
                            bytes += generator.text(
                              'Data/Hora: ${ultimaVenda!['dataHora']}',
                              styles: PosStyles(align: PosAlign.left, height: PosTextSize.size1),
                            );
                            bytes += generator.hr();
                            bytes += generator.text(
                              'Cartelas',
                              styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
                            );
                            bytes += generator.text(
                              '${ultimaVenda!['inicial']} - ${ultimaVenda!['finalVenda']}',
                              styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
                            );
                            bytes += generator.text(
                              'Total: R\$${ultimaVenda!['totalVenda']}',
                              styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2),
                            );
                            bytes += generator.hr();
                            bytes += generator.text(
                              'Reimpressao',
                              styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1),
                            );
                            bytes += generator.cut(); // Finaliza o papel com corte

                            // Envia os dados para impressão
                            await BluetoothPrintPlus.write(Uint8List.fromList(bytes));

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Última venda reimpressa com sucesso!")),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Erro ao reimprimir: $e")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // Fundo preto
                          foregroundColor: Colors.white, // Texto branco
                        ),
                        child: Text('Reimprimir Última Venda'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
