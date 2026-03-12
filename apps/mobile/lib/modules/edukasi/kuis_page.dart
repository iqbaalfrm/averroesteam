import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/services/auth_service.dart';
import '../../app/routes/app_routes.dart';
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
  final Map<String, String> _selectedAnswerByQuizId = <String, String>{};

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
        _error = 'edu_quiz_progress_failed'.tr;
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
      _showSnack('edu_login_to_quiz'.tr);
      return;
    }
    if (_kuis.isEmpty) {
      _showSnack('edu_no_quiz_for_class'.tr);
      return;
    }
    if (_selectedAnswerByQuizId.length < _kuis.length) {
      _showSnack('edu_answer_all_first'.tr);
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
      if (!mounted) return;
      final KelasProgressEdukasi? p = _progress;
      if (p == null) {
        _showSnack('edu_quiz_submit_success'.tr);
        return;
      }
      await showDialog<void>(
        context: context,
        barrierColor: const Color(0x99040B18),
        builder: (BuildContext context) => _ResultDialogCard(
          correctQuiz: p.correctQuiz,
          totalQuiz: p.totalQuiz,
          scorePercent: p.scorePercent,
          onClose: () => Navigator.of(context).pop(),
          onDownload: p.scorePercent >= 95
              ? () async {
                  Navigator.of(context).pop();
                  await _generateSertifikat();
                }
              : null,
        ),
      );
    } catch (_) {
      _showSnack('edu_quiz_submit_failed'.tr);
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
      _showSnack('edu_login_to_certificate'.tr);
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
          title: Text('edu_certificate_created'.tr),
          content: Text(
            "${'class_label'.tr}${result.kelas}\n${result.namaSertifikat}\n${result.nomor}\n${'score_percent'.trParams(<String, String>{
                  'score': '${result.scorePercent}'
                })}",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Get.toNamed(RuteAplikasi.sertifikat);
              },
              child: Text('edu_view_in_profile'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common_close'.tr),
            ),
          ],
        ),
      );
    } catch (_) {
      _showSnack('edu_not_eligible_certificate'.tr);
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
          'edu_quiz_title'.trParams(
            <String, String>{'class': widget.kelas.judul},
          ),
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
              _InfoCard(text: 'edu_loading_quiz_progress'.tr),
              const SizedBox(height: 8),
            ],
            if (_progress != null) _ProgressCard(progress: _progress!),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              _ErrorCard(message: _error!, onRetry: _loadProgress),
            ],
            const SizedBox(height: 12),
            if (_kuis.isEmpty)
              _EmptyCard(text: 'edu_no_quiz'.tr)
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
                  child: Text('edu_download_certificate'.tr),
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
              _isSubmitting ? 'edu_processing'.tr : 'edu_submit_answers'.tr,
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

class _ResultDialogCard extends StatelessWidget {
  const _ResultDialogCard({
    required this.correctQuiz,
    required this.totalQuiz,
    required this.scorePercent,
    required this.onClose,
    this.onDownload,
  });

  final int correctQuiz;
  final int totalQuiz;
  final int scorePercent;
  final VoidCallback onClose;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final bool passed = scorePercent >= 95;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF8FFFC), Colors.white],
          ),
          border: Border.all(color: const Color(0xFFD6F5EA)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x26040B18),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    passed ? Symbols.workspace_premium : Symbols.info,
                    color: const Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    passed ? 'edu_passed'.tr : 'edu_not_passed'.tr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$scorePercent%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'edu_correct_answers'.trParams(
                  <String, String>{
                    'correct': '$correctQuiz',
                    'total': '$totalQuiz',
                  },
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              passed ? 'edu_certificate_ready'.tr : 'edu_min_score_notice'.tr,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'common_close'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                if (onDownload != null) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onDownload,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: const Color(0xFF0EA5A4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'edu_download'.tr,
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
            'edu_class_progress'.tr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'edu_class_progress_summary'.trParams(
              <String, String>{
                'done': '${progress.completedMateri}',
                'total': '${progress.totalMateri}',
                'answered': '${progress.answeredQuiz}',
                'totalQuiz': '${progress.totalQuiz}',
                'score': '${progress.scorePercent}',
              },
            ),
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
            'edu_question_label'.trParams(
              <String, String>{'number': '$nomor'},
            ),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: Text('try_again'.tr),
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
