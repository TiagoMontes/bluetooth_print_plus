import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:bluetooth_print_plus_example/command_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

enum CmdType { Tsc, Cpcl, Esc }

class FunctionPage extends StatefulWidget {

  const FunctionPage({super.key});

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

  @override
  void deactivate() {
    super.deactivate();
    _disconnect();
  }

  void _disconnect() async {
    await BluetoothPrintPlus.disconnect();
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
      rangeFinal = rangeInicial + 1;
      modalVisible = false;
    });
  }

  void finalizarVenda() async {
    int inicial = rangeInicial;
    int quantidadeVendida = int.tryParse(_controllerQuantidade.text) ?? 0;

    // Adjust quantity for combo logic
    int quantidadeFinal = vendaPorCombo ? quantidadeVendida * 6 : quantidadeVendida;

    // Calculate the final sale value
    double totalVenda = vendaPorCombo
        ? (quantidadeFinal ~/ 6) * double.parse(valorCartela)
        : quantidadeVendida * double.parse(valorCartela);

    // Validate range
    int finalVenda = inicial + quantidadeFinal - 1;
    if (inicial <= 0 || quantidadeVendida <= 0 || finalVenda > int.parse(maxCartela) || inicial < int.parse(minCartela)) {
      _showAlert('Erro', 'O intervalo de venda é inválido ou está fora do intervalo configurado');
      return;
    }

    setState(() {
      totalQuantidade += quantidadeFinal;
      totalValor += totalVenda;
      intervalosVendidos.add({'inicial': inicial, 'final': finalVenda});
    });

    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);

    // Prepare printData
    final printData = '''
    \n\n
    ${String.fromCharCode(27)}${String.fromCharCode(97)}${String.fromCharCode(1)}${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(16)}Boa sorte
    ${String.fromCharCode(27)}${String.fromCharCode(97)}${String.fromCharCode(1)}--------------------------
    ${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(14)}Rodada: $rodada
    Quantidade: $quantidadeFinal${!vendaPorCombo ? ' x R\$${valorCartela}' : ''}
    Data/Hora: $formattedDate
    
    ${String.fromCharCode(27)}${String.fromCharCode(97)}${String.fromCharCode(1)}${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(20)}$inicial - $finalVenda
    
    ${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(16)}Total: R\$${totalVenda.toStringAsFixed(2)}\n
    \n\n
  ''';

    final Uint8List printDataBytes = Uint8List.fromList(utf8.encode(printData));
    try {
      await BluetoothPrintPlus.write(printDataBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impressão realizada com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao imprimir: $e")),
      );
    }

    // Update rangeInicial for next sale
    setState(() {
      rangeInicial = finalVenda + 1;
      _controllerQuantidade.clear();
    });
  }


  void finalizarRodada() async {
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);

    final printData = '''
      \n\n
      ${String.fromCharCode(27)}${String.fromCharCode(97)}${String.fromCharCode(1)}${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(16)}Rodada Finalizada!
      ${String.fromCharCode(27)}${String.fromCharCode(97)}${String.fromCharCode(1)}Intervalo: ${intervalosVendidos.first['inicial']}-${intervalosVendidos.last['final']}
      ${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(16)}Quantidade Vendida: $totalQuantidade
      ${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(16)}Total: R\$${totalValor.toStringAsFixed(2)}
      ${String.fromCharCode(27)}${String.fromCharCode(33)}${String.fromCharCode(16)}Data/Hora: $formattedDate
      \n\n
    ''';

    final Uint8List printDataBytes = Uint8List.fromList(utf8.encode(printData));
    try {
      await BluetoothPrintPlus.write(printDataBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impressão realizada com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao imprimir: $e")),
      );
    }
  }

    setState(() {
      rodada++;
      minCartela = '';
      maxCartela = '';
      rangeInicial = 0;
      rangeFinal = 0;
      valorCartela = '';
      totalQuantidade = 0;
      totalValor = 0.0;
      intervalosVendidos.clear();
    });
    _showAlert('Rodada Finalizada', 'Rodada ${rodada} iniciada');
  }

  void exibirModalCartela() {
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
                  cartelaInicialError = minCartela.isEmpty ? 'Campo obrigatório' : null;
                  cartelaFinalError = maxCartela.isEmpty ? 'Campo obrigatório' : null;
                  valorCartelaError = valorCartela.isEmpty ? 'Campo obrigatório' : null;
                });

                if (cartelaInicialError == null &&
                    cartelaFinalError == null &&
                    valorCartelaError == null) {
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
                    decoration: InputDecoration(
                      labelText: 'Cartela Inicial',
                      errorText: cartelaInicialError,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setModalState(() => minCartela = value),
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Cartela Final',
                      errorText: cartelaFinalError,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setModalState(() => maxCartela = value),
                  ),
                  SizedBox(height: 10),
                  SizedBox(height: 10),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: vendaPorCombo
                          ? 'Valor do Combo (ex: 15.00)'
                          : 'Valor Unitário (ex: 2.50)',
                      errorText: valorCartelaError,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setModalState(() {
                        valorCartela = value.replaceAll(',', '.');
                      });
                    },
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
                                valorCartela = '10';
                              } else {
                                valorCartela = '';
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

  @override
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
                        foregroundColor: Colors.white
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: exibirModalCartela,
                child: Text('Configurar Cartela'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white
                ),
              ),
              SizedBox(height: 10),
              Text(
                (minCartela.isNotEmpty && maxCartela.isNotEmpty) ? '$minCartela - $maxCartela' : 'Intervalo não definido',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(valorCartela.isNotEmpty ? 'Valor: R\$${valorCartela}' : 'Valor: Não definido'),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _controllerQuantidade,
                      decoration: InputDecoration(labelText: 'Quantidade'),
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
                    foregroundColor: Colors.white
                ),
                child: Text('Finalizar Venda'),
              ),
              SizedBox(height: 20),
              Text('Quantidade Total Vendida: $totalQuantidade'),
              Text('Valor Total Vendido: R\$${totalValor.toStringAsFixed(2)}'),
              Text(
                'Intervalos Vendidos: ${intervalosVendidos.isEmpty ? 'Nenhum' : '${intervalosVendidos.first['inicial']}-${intervalosVendidos.last['final']}' }',
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: finalizarRodada,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white
                ),
                child: Text('Finalizar Rodada', selectionColor: Colors.red),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
