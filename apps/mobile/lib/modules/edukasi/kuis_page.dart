import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/services/auth_service.dart';
import 'edukasi_api.dart';

class HalamanKuis extends StatefulWidget {
  const HalamanKuis({required this.kelas, required this.detail, super.key});

  final KelasEdukasi kelas;
  final KelasDetailEdukasi detail;

  @override
  State<HalamanKuis> createState() => _HalamanKuisState();
}

class _HalamanKuisState extends State<HalamanKuis> {
  final EdukasiApi _api = EdukasiApi();

  bool _isSubmitting = false;
  bool _isLoadingProgress = true;
  String? _error;
  KelasProgressEdukasi? _progress;
  final Map<int, String> _selectedAnswerByQuizId = <int, String>{};

  List<KuisEdukasi> get _kuis => widget.detail.kuis;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    if (!AuthService.instance.sudahLogin) {
      setState(() {
        _isLoadingProgress = false;
      });
      return;
    }

    try {
      final KelasProgressEdukasi p =
          await _api.fetchKelasProgress(widget.kelas.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = p;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Gagal memuat progress quiz.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProgress = false;
        });
      }
    }
  }

  Future<void> _submitJawaban() async {
    if (!AuthService.instance.sudahLogin) {
      _showSnack('Login dulu untuk mengerjakan kuis.');
      return;
    }
    if (_kuis.isEmpty) {
      _showSnack('Belum ada soal kuis untuk kelas ini.');
      return;
    }
    if (_selectedAnswerByQuizId.length < _kuis.length) {
      _showSnack('Jawab semua soal sebelum dikumpulkan.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      for (final KuisEdukasi soal in _kuis) {
        final String? jawaban = _selectedAnswerByQuizId[soal.id];
        if (jawaban == null) {
          continue;
        }
        await _api.submitQuiz(quizId: soal.id, jawaban: jawaban);
      }
      await _loadProgress();
      _showSnack('Jawaban kuis berhasil dikirim.');
    } catch (_) {
      _showSnack('Gagal mengirim jawaban kuis.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _generateSertifikat() async {
    if (!AuthService.instance.sudahLogin) {
      _showSnack('Login dulu untuk generate sertifikat.');
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final SertifikatResult result =
          await _api.generateSertifikat(widget.kelas.id);
      if (!mounted) {
        return;
      }
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Sertifikat Berhasil Dibuat'),
          content: Text(
            'Kelas: ${result.kelas}\nNama Sertifikat: ${result.namaSertifikat}\nNomor: ${result.nomor}\nNilai: ${result.scorePercent}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (_) {
      _showSnack(
          'Belum memenuhi syarat sertifikat (selesaikan materi + nilai >= 70).');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          'Kuis: ${widget.kelas.judul}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProgress,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: <Widget>[
            if (_isLoadingProgress) ...<Widget>[
              const _InfoCard(text: 'Memuat progress kuis...'),
              const SizedBox(height: 8),
            ],
            if (_progress != null) _ProgressCard(progress: _progress!),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              _ErrorCard(message: _error!, onRetry: _loadProgress),
            ],
            const SizedBox(height: 12),
            if (_kuis.isEmpty)
              const _EmptyCard(text: 'Belum ada soal kuis di kelas ini.')
            else
              ..._kuis.asMap().entries.map((MapEntry<int, KuisEdukasi> entry) {
                final int idx = entry.key;
                final KuisEdukasi soal = entry.value;
                final List<MapEntry<String, String>> opsi = soal.pilihan.entries
                    .toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
                return _QuestionCard(
                  nomor: idx + 1,
                  soal: soal,
                  options: opsi,
                  selected: _selectedAnswerByQuizId[soal.id],
                  onSelect: (String value) {
                    setState(() {
                      _selectedAnswerByQuizId[soal.id] = value;
                    });
                  },
                );
              }),
            const SizedBox(height: 10),
            if (_progress?.isEligibleCertificate == true)
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _generateSertifikat,
                  child: const Text('Generate Sertifikat'),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed:
                (_isSubmitting || _isLoadingProgress) ? null : _submitJawaban,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF052E2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _isSubmitting ? 'Memproses...' : 'Kumpulkan Jawaban',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final KelasProgressEdukasi progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Progress Kelas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Materi ${progress.completedMateri}/${progress.totalMateri} · Quiz ${progress.answeredQuiz}/${progress.totalQuiz} · Nilai ${progress.scorePercent}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.nomor,
    required this.soal,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final int nomor;
  final KuisEdukasi soal;
  final List<MapEntry<String, String>> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Soal $nomor',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            soal.pertanyaan,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          ...options.map((MapEntry<String, String> entry) {
            return RadioListTile<String>(
              value: entry.key,
              groupValue: selected,
              onChanged: (String? value) {
                if (value != null) {
                  onSelect(value);
                }
              },
              title: Text(
                '${entry.key}. ${entry.value}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF334155),
                ),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
