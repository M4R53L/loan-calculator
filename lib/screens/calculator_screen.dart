import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/loan_result.dart';
import '../services/loan_calculator.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController(text: '50000');
  final _primeController = TextEditingController(text: '1.6');
  final _marginController = TextEditingController(text: '5.1');
  final _monthsController = TextEditingController(text: '60');

  LoanResult? _result;
  bool _showSchedule = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₪',
    decimalDigits: 2,
    locale: 'he_IL',
  );

  final NumberFormat _percentFormat = NumberFormat.decimalPattern()..minimumFractionDigits = 1;

  @override
  void dispose() {
    _principalController.dispose();
    _primeController.dispose();
    _marginController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double principal = double.parse(_principalController.text);
    final double prime = double.parse(_primeController.text);
    final double margin = double.parse(_marginController.text);
    final int months = int.parse(_monthsController.text);

    final String? error = LoanCalculator.validateInputs(
      principal: principal,
      prime: prime,
      margin: margin,
      months: months,
    );

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _result = LoanCalculator.calculate(
        principal: principal,
        prime: prime,
        margin: margin,
        months: months,
        generateSchedule: _showSchedule,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חישוב ריבית של הבנק'),
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInputCard(),
                      const SizedBox(height: 16),
                      _buildCalculateButton(),
                      if (_result != null) ...[
                        const SizedBox(height: 24),
                        _buildResultCard(),
                        const SizedBox(height: 16),
                        _buildScheduleToggle(),
                        if (_showSchedule && _result?.schedule != null) ...[
                          const SizedBox(height: 16),
                          _buildScheduleTable(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'פרטי ההלוואה',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _principalController,
              label: 'הסכום של ההלוואה (₪)',
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _primeController,
                    label: 'פריים (%)',
                    icon: Icons.trending_up,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _marginController,
                    label: 'ריבית (%)',
                    icon: Icons.percent,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _monthsController,
              label: 'מספר חודשים',
              icon: Icons.calendar_month,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'שדה חובה';
        }
        if (double.tryParse(value) == null) {
          return 'מספר לא תקין';
        }
        return null;
      },
    );
  }

  Widget _buildCalculateButton() {
    return ElevatedButton.icon(
      onPressed: _calculate,
      icon: const Icon(Icons.calculate),
      label: const Text('חשב'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_result == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'תוצאות',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
            ),
            const Divider(height: 24),
            _buildResultRow(
              'ריבית שנתית',
              '${_percentFormat.format(_result!.annualRate)}%',
              subtitle: 'פריים + ריבית',
            ),
            const SizedBox(height: 12),
            _buildResultRow(
              'תשלום חודשי',
              _currencyFormat.format(_result!.monthlyPayment),
              isHighlight: true,
            ),
            const SizedBox(height: 12),
            _buildResultRow(
              'הסכום של הריבית',
              _currencyFormat.format(_result!.totalInterest),
            ),
            const SizedBox(height: 12),
            _buildResultRow(
              'סה"כ להחזר',
              _currencyFormat.format(_result!.totalPaid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {String? subtitle, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isHighlight ? 18 : 16,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.green[900] : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleToggle() {
    return SwitchListTile(
      title: const Text('הצג לוח סילוקין'),
      subtitle: const Text('פירוט תשלומים לפי חודשים'),
      value: _showSchedule,
      onChanged: (value) {
        setState(() {
          _showSchedule = value;
          if (value) {
            _calculate(); // Recalculate with schedule
          }
        });
      },
    );
  }

  Widget _buildScheduleTable() {
    final schedule = _result?.schedule;
    if (schedule == null || schedule.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue[700],
            child: Text(
              'לוח סילוקין',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowColor: MaterialStateProperty.all(Colors.blue[50]),
              columns: const [
                DataColumn(label: Text('חודש', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('תשלום', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ריבית', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('קרן', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('יתרה', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: schedule.take(12).map((row) {
                return DataRow(cells: [
                  DataCell(Text(row.month.toString())),
                  DataCell(Text(_currencyFormat.format(row.payment))),
                  DataCell(Text(_currencyFormat.format(row.interestPortion))),
                  DataCell(Text(_currencyFormat.format(row.principalPortion))),
                  DataCell(Text(_currencyFormat.format(row.remainingBalance))),
                ]);
              }).toList(),
            ),
          ),
          if (schedule.length > 12)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'מוצגים 12 חודשים ראשונים מתוך ${schedule.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
