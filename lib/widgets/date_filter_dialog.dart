import 'package:flutter/material.dart';

class DateFilterDialog extends StatefulWidget {
  final Function(DateTime, DateTime) onFilter;

  const DateFilterDialog({super.key, required this.onFilter});

  @override
  State<DateFilterDialog> createState() => _DateFilterDialogState();
}

class _DateFilterDialogState extends State<DateFilterDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('按日期筛选'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('开始日期'),
            subtitle: Text(
              _startDate.toString().split(' ')[0],
              style: const TextStyle(fontSize: 16),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _selectStartDate,
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('结束日期'),
            subtitle: Text(
              _endDate.toString().split(' ')[0],
              style: const TextStyle(fontSize: 16),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _selectEndDate,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onFilter(_startDate, _endDate);
          },
          child: const Text('应用'),
        ),
      ],
    );
  }
}
