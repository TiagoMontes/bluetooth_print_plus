import 'package:bluetooth_print_plus/bluetooth_print_plus.dart';
import 'package:flutter/material.dart';

class AppPage extends StatefulWidget {
  @override
  _AppPageState createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  BluetoothDevice? _device;
  int rodada = 1;
  String minCartela = '';
  String maxCartela = '';
  String nomeVendedor = '';
  String valorCartela = '';
  int rangeInicial = 0;
  int rangeFinal = 0;
  int totalQuantidade = 0;
  double totalValor = 0.0;
  List<String> intervalosVendidos = [];

  void configurarCartela() {
    // Lógica para abrir um modal ou configurar a cartela
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configurar Cartela"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => minCartela = value,
              decoration: const InputDecoration(labelText: "Cartela Inicial"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              onChanged: (value) => maxCartela = value,
              decoration: const InputDecoration(labelText: "Cartela Final"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              onChanged: (value) => nomeVendedor = value,
              decoration: const InputDecoration(labelText: "Nome do Vendedor"),
            ),
            TextField(
              onChanged: (value) => valorCartela = value,
              decoration: const InputDecoration(labelText: "Valor por Cartela"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                rangeInicial = int.tryParse(minCartela) ?? 0;
                rangeFinal = rangeInicial + 1;
              });
              Navigator.of(context).pop();
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  void finalizarVenda() async {
    if (rangeFinal <= rangeInicial || valorCartela.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Intervalo ou configurações inválidas.")),
      );
      return;
    }

    final quantidadeVendida = rangeFinal - rangeInicial;
    final double valor = double.tryParse(valorCartela) ?? 0.0;
    final double totalVenda = quantidadeVendida * valor;

    setState(() {
      totalQuantidade += quantidadeVendida;
      totalValor += totalVenda;
      intervalosVendidos.add("$rangeInicial-$rangeFinal");
      rangeInicial = rangeFinal + 1;
      rangeFinal = rangeInicial + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Venda finalizada! Total: R\$${totalVenda.toStringAsFixed(2)}")),
    );

    // Verifica se há um dispositivo Bluetooth conectado
    if (_device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum dispositivo Bluetooth conectado.")),
      );
      return;
    }

    // Dados para impressão
    final printData = '''
Venda Finalizada!
Vendedor: $nomeVendedor
Intervalo: ${rangeInicial - (rangeFinal - rangeInicial + 1)} - ${rangeFinal - 1}
Quantidade Vendida: $quantidadeVendida
Valor Unitário: R\$${valor.toStringAsFixed(2)}
Total: R\$${totalVenda.toStringAsFixed(2)}
''';

    try {
      // Conecta ao dispositivo e imprime
      await BluetoothPrintPlus.writeData(printData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impressão realizada com sucesso!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao imprimir: $e")),
      );
    }
  }


  void finalizarRodada() {
    setState(() {
      rodada++;
      minCartela = '';
      maxCartela = '';
      nomeVendedor = '';
      valorCartela = '';
      rangeInicial = 0;
      rangeFinal = 0;
      totalQuantidade = 0;
      totalValor = 0.0;
      intervalosVendidos.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Rodada $rodada iniciada!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Boa Sorte!")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  const Text(
                    "Boa Sorte!",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {}, // Pode abrir configuração de rodada
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                    child: Text(
                      "Rodada: $rodada",
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Configuração do Intervalo",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: configurarCartela,
              child: const Text("Configurar Cartela"),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                minCartela.isNotEmpty && maxCartela.isNotEmpty
                    ? "$minCartela - $maxCartela"
                    : "Intervalo não definido",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Vendedor: ${nomeVendedor.isNotEmpty ? nomeVendedor : 'Não definido'}"),
                Text("Valor: R\$${valorCartela.isNotEmpty ? valorCartela : 'Não definido'}"),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Definir Intervalo de Venda",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: "Inicial",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey,
                    ),
                    readOnly: true,
                    controller: TextEditingController(text: "$rangeInicial"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: "Final",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        rangeFinal = int.tryParse(value) ?? rangeInicial;
                      });
                    },
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: finalizarVenda,
              child: const Text("Finalizar Venda"),
            ),
            const SizedBox(height: 16),
            Text("Quantidade Total Vendida: $totalQuantidade"),
            Text("Valor Total Vendido: R\$${totalValor.toStringAsFixed(2)}"),
            Text(
              "Intervalos Vendidos: ${intervalosVendidos.isNotEmpty ? intervalosVendidos.join(', ') : 'Nenhum'}",
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: finalizarRodada,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                "Finalizar Rodada",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
