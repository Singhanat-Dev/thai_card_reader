import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:thai_card_reader/thai_card_reader.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _reader = ThaiCardReader.instance;

  bool _isLibOpen = false;
  bool _isReading = false;
  int _progress = 0;
  String _status = 'ยังไม่เปิดระบบ';
  String _readerName = '';
  CardData? _cardData;

  StreamSubscription<Map<String, dynamic>>? _cardEventSub;
  StreamSubscription<Map<String, dynamic>>? _usbEventSub;

  @override
  void initState() {
    super.initState();

    // ── ฟัง card reading progress events ──
    _cardEventSub = _reader.cardEvents.listen((event) {
      final resCode = event['ResCode']?.toString() ?? '';
      final val = int.tryParse(event['ResValue']?.toString() ?? '0') ?? 0;

      if (resCode == 'EVENT_NIDTEXT') {
        setState(() {
          _progress = val;
          _status = 'กำลังอ่านข้อมูล... $val%';
        });
      } else if (resCode == 'EVENT_NIDPHOTO') {
        setState(() {
          _progress = 100;
          _status = 'อ่านข้อมูลสำเร็จ';
        });
      } else if (resCode == 'EVENT_READERLIST') {
        final name = event['ResText']?.toString() ?? '';
        if (name.isNotEmpty) setState(() => _readerName = name);
      }
    });

    // ── ฟัง USB hardware events ──
    _usbEventSub = _reader.usbEvents.listen((event) {
      final type = event['event']?.toString() ?? '';
      switch (type) {
        case 'device_attached':
          setState(() => _status = 'เสียบเครื่องอ่านแล้ว: ${event['device_name']}');
          break;
        case 'device_detached':
          setState(() {
            _status = 'ถอดเครื่องอ่านแล้ว';
            _readerName = '';
          });
          break;
        case 'readers_found':
          final readers = (event['readers'] as List?)?.cast<String>() ?? [];
          if (readers.isNotEmpty) {
            setState(() => _readerName = readers.first);
          }
          break;
        case 'reader_not_found':
          setState(() => _status = 'ไม่พบเครื่องอ่านบัตร');
          break;
      }
    });
  }

  @override
  void dispose() {
    _cardEventSub?.cancel();
    _usbEventSub?.cancel();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _openLib() async {
    setState(() => _status = 'กำลังเปิดระบบ...');
    final error = await _reader.openLib();
    setState(() {
      if (error == null) {
        _isLibOpen = true;
        _status = 'เปิดระบบสำเร็จ';
      } else {
        _status = error;
      }
    });
  }

  Future<void> _closeLib() async {
    await _reader.closeLib();
    setState(() {
      _isLibOpen = false;
      _cardData = null;
      _readerName = '';
      _progress = 0;
      _status = 'ปิดระบบแล้ว';
    });
  }

  Future<void> _scanReader() async {
    setState(() {
      _status = 'กำลังค้นหาเครื่องอ่าน...';
      _readerName = '';
    });
    final result = await _reader.scanReaders();
    if (!_reader.isSuccess(result)) {
      setState(() => _status = 'ไม่พบเครื่องอ่านบัตร');
      return;
    }
    final name = (result?['ResValue']?.toString() ?? '')
        .split(';')
        .firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');
    if (name.isEmpty) {
      setState(() => _status = 'ไม่พบเครื่องอ่านบัตร');
      return;
    }
    final error = await _reader.selectReader(name);
    setState(() {
      if (error == null) {
        _readerName = name;
        _status = 'เชื่อมต่อเครื่องอ่านสำเร็จ';
      } else {
        _status = error;
      }
    });
  }

  Future<void> _readCard() async {
    setState(() {
      _isReading = true;
      _progress = 0;
      _cardData = null;
      _status = 'กำลังอ่านบัตร...';
    });
    final result = await _reader.readCard();
    setState(() {
      _isReading = false;
      if (result.isSuccess) {
        _cardData = result.data;
        _progress = 100;
        _status = 'อ่านบัตรสำเร็จ';
      } else {
        _status = result.error ?? 'อ่านบัตรไม่สำเร็จ';
      }
    });
  }

  void _clearCard() {
    setState(() {
      _cardData = null;
      _progress = 0;
      _status = _isLibOpen ? 'พร้อมอ่านบัตร' : 'ยังไม่เปิดระบบ';
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'อ่านบัตรประชาชน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLibOpen && _readerName.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'รีเฟรชสถานะ',
              onPressed: () => _reader.selectReader(_readerName),
            ),
          if (_isLibOpen)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'ปิดระบบ',
              onPressed: _closeLib,
            ),
        ],
      ),
      body: Column(
        children: [
          _StatusBar(
            isOpen: _isLibOpen,
            status: _status,
            readerName: _readerName,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ActionButtons(
                    isOpen: _isLibOpen,
                    isReading: _isReading,
                    onOpen: _openLib,
                    onScan: _scanReader,
                    onRead: _readCard,
                  ),
                  const SizedBox(height: 16),
                  if (_isReading)
                    _ProgressCard(progress: _progress, status: _status)
                  else if (_cardData != null)
                    _CardInfoPanel(data: _cardData!, onClear: _clearCard)
                  else
                    _EmptyState(isOpen: _isLibOpen),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.isOpen,
    required this.status,
    required this.readerName,
  });

  final bool isOpen;
  final String status;
  final String readerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: isOpen ? const Color(0xFF1565C0) : const Color(0xFF78909C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOpen ? Icons.check_circle : Icons.cancel,
                color: isOpen ? Colors.greenAccent : Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (readerName.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.usb, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  readerName,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isOpen,
    required this.isReading,
    required this.onOpen,
    required this.onScan,
    required this.onRead,
  });

  final bool isOpen;
  final bool isReading;
  final VoidCallback onOpen;
  final VoidCallback onScan;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isOpen)
              _PrimaryButton(
                icon: Icons.power_settings_new,
                label: 'เปิดระบบ',
                color: const Color(0xFF1565C0),
                onPressed: onOpen,
              )
            else ...[
              _PrimaryButton(
                icon: Icons.bluetooth_searching,
                label: 'สแกนเครื่องอ่านบัตร',
                color: const Color(0xFF00897B),
                onPressed: isReading ? null : onScan,
              ),
              const SizedBox(height: 10),
              _PrimaryButton(
                icon: Icons.credit_card,
                label: isReading ? 'กำลังอ่านบัตร...' : 'อ่านบัตรประชาชน',
                color: const Color(0xFFE53935),
                onPressed: isReading ? null : onRead,
                loading: isReading,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 15)),
      onPressed: onPressed,
    );
  }
}

// ── Progress Card ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress, required this.status});

  final int progress;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.credit_card, size: 48, color: Color(0xFF1565C0)),
            const SizedBox(height: 16),
            Text(
              '$progress%',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFF1565C0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: isOpen
                  ? const Color(0xFF1565C0).withValues(alpha: 0.4)
                  : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isOpen
                  ? 'วางบัตรบนเครื่องอ่าน\nแล้วกดปุ่ม "อ่านบัตรประชาชน"'
                  : 'กดปุ่ม "เปิดระบบ" เพื่อเริ่มต้นใช้งาน',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card Info Panel ───────────────────────────────────────────────────────────

class _CardInfoPanel extends StatelessWidget {
  const _CardInfoPanel({required this.data, required this.onClear});

  final CardData data;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // รูปภาพ + ชื่อ
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoWidget(base64: data.photoBase64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.fullNameTh.isNotEmpty) ...[
                        Text(
                          data.fullNameTh,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (data.fullNameEn.isNotEmpty)
                        Text(
                          data.fullNameEn,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (data.idNumber.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _IdChip(label: data.idNumber),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ข้อมูลรายละเอียด
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow(label: 'วันเกิด', value: data.dateOfBirth),
                _InfoRow(label: 'เพศ', value: data.gender),
                _InfoRow(
                  label: 'ที่อยู่',
                  value: '${data.houseNo} ${data.address} ${data.province}'.trim(),
                ),
                _InfoRow(label: 'วันออกบัตร', value: data.issueDate),
                _InfoRow(
                  label: 'วันหมดอายุ',
                  value: data.expireDate,
                ),
                _InfoRow(label: 'เขตที่ออกบัตร', value: data.issueDistrict),
                _InfoRow(label: 'จังหวัดที่ออกบัตร', value: data.issueProvince),
                _InfoRow(label: 'หมายเลขคำขอ', value: data.requestNo),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('ล้างข้อมูล / อ่านบัตรใหม่'),
          onPressed: onClear,
        ),
      ],
    );
  }
}

class _PhotoWidget extends StatelessWidget {
  const _PhotoWidget({required this.base64});

  final String base64;

  @override
  Widget build(BuildContext context) {
    if (base64.isNotEmpty) {
      try {
        final bytes = base64Decode(base64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 80,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(),
          ),
        );
      } catch (_) {}
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person, size: 40, color: Colors.grey),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _IdChip extends StatelessWidget {
  const _IdChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge, size: 14, color: Color(0xFF1565C0)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
