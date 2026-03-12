import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/services/auth_service.dart';
import 'edukasi_api.dart';
import 'kuis_page.dart';
import 'materi_detail_page.dart';

class HalamanDetailKelas extends StatefulWidget {
  const HalamanDetailKelas({required this.kelas, super.key});

  final KelasEdukasi kelas;

  @override
  State<HalamanDetailKelas> createState() => _HalamanDetailKelasState();
}

class _HalamanDetailKelasState extends State<HalamanDetailKelas> {
  final EdukasiApi _api = EdukasiApi();

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;
  KelasDetailEdukasi? _detail;
  KelasProgressEdukasi? _progress;
  Set<String> _completedMateriIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final KelasDetailEdukasi detail =
          await _api.fetchKelasDetail(widget.kelas.id);
      KelasProgressEdukasi? progress = _progress;
      if (AuthService.instance.sudahLogin) {
        try {
          progress = await _api.fetchKelasProgress(widget.kelas.id);
        } catch (_) {
          // Biarkan detail kelas tetap tampil walau endpoint progress gagal.
          progress = null;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _progress = progress;
        _completedMateriIds =
            progress == null ? <String>{} : progress.completedMateriIds.toSet();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'edu_load_detail_error'.tr;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeMateri(MateriEdukasi materi) async {
    if (!AuthService.instance.sudahLogin) {
      _showSnack('edu_login_to_save_progress'.tr);
      return;
    }
    setState(() {
      _isActionLoading = true;
    });
    try {
      await _api.completeMateri(materi.id);
      await _loadData();
      _showSnack('edu_mark_complete_success'.tr);
    } catch (_) {
      _showSnack('edu_mark_complete_failed'.tr);
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  Future<void> _openMateri(ModulEdukasi modul, MateriEdukasi materi) async {
    final bool completed = _completedMateriIds.contains(materi.id);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HalamanDetailMateri(
          kelasJudul: widget.kelas.judul,
          modulUrutan: modul.urutan,
          modulJudul: modul.judul,
          materi: materi,
          sudahSelesai: completed,
          isActionLoading: _isActionLoading,
          onComplete: () => _completeMateri(materi),
        ),
      ),
    );
    await _loadData();
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isMateriComplete() {
    final KelasProgressEdukasi? p = _progress;
    if (p == null) {
      return false;
    }
    return p.completedMateri >= p.totalMateri && p.totalMateri > 0;
  }

  @override
  Widget build(BuildContext context) {
    final KelasDetailEdukasi? detail = _detail;
    final bool canOpenQuiz = detail != null && _isMateriComplete();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          'edu_class_detail_title'.tr,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: <Widget>[
            _KelasHeader(kelas: widget.kelas, progress: _progress),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _loadData)
            else if (detail == null)
              _EmptyCard(text: 'edu_no_class_detail'.tr)
            else ...<Widget>[
              _sectionTitle('edu_materials_and_modules'.tr),
              const SizedBox(height: 10),
              ...detail.modul.map(
                (ModulEdukasi modul) => _ModulCard(
                  modul: modul,
                  completedMateriIds: _completedMateriIds,
                  isActionLoading: _isActionLoading,
                  onCompleteMateri: _completeMateri,
                  onOpenMateri: (item) => _openMateri(modul, item),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: canOpenQuiz
                ? () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HalamanKuis(
                          kelas: widget.kelas,
                          detail: detail,
                        ),
                      ),
                    );
                    await _loadData();
                  }
                : null,
            icon:
                Icon(_isMateriComplete() ? Symbols.quiz : Symbols.lock_outline),
            label: Text(
              _isMateriComplete()
                  ? 'edu_continue_quiz'.tr
                  : 'edu_finish_materials_first'.tr,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: const Color(0xFF052E2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

class _KelasHeader extends StatelessWidget {
  const _KelasHeader({required this.kelas, required this.progress});

  final KelasEdukasi kelas;
  final KelasProgressEdukasi? progress;

  @override
  Widget build(BuildContext context) {
    final int percent = progress?.progressMateriPercent ?? 0;
    final int done = progress?.completedMateri ?? 0;
    final int total = progress?.totalMateri ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kelas.judul,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kelas.deskripsi,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'edu_material_progress'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                Text(
                  '$done/$total ($percent%)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (percent.clamp(0, 100)) / 100.0,
                minHeight: 7,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModulCard extends StatelessWidget {
  const _ModulCard({
    required this.modul,
    required this.completedMateriIds,
    required this.isActionLoading,
    required this.onCompleteMateri,
    required this.onOpenMateri,
  });

  final ModulEdukasi modul;
  final Set<String> completedMateriIds;
  final bool isActionLoading;
  final Future<void> Function(MateriEdukasi) onCompleteMateri;
  final Future<void> Function(MateriEdukasi) onOpenMateri;

  @override
  Widget build(BuildContext context) {
    final int totalMateriModul = modul.materi.length;
    final int selesaiModul =
        modul.materi.where((m) => completedMateriIds.contains(m.id)).length;
    final String cleanTitle = _cleanModulTitle(modul.judul, modul.urutan);
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'edu_module_label'.trParams(
                    <String, String>{'index': '${modul.urutan}'},
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF047857),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'edu_module_progress'.trParams(
                  <String, String>{
                    'done': '$selesaiModul',
                    'total': '$totalMateriModul',
                  },
                ),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cleanTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            modul.deskripsi,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          if (modul.materi.isEmpty)
            _EmptyCard(text: 'edu_empty_module_material'.tr)
          else
            ...modul.materi.map(
              (MateriEdukasi item) {
                final bool completed = completedMateriIds.contains(item.id);
                return _MateriCard(
                  item: item,
                  completed: completed,
                  isActionLoading: isActionLoading,
                  onComplete: () => onCompleteMateri(item),
                  onOpen: () => onOpenMateri(item),
                );
              },
            ),
        ],
      ),
    );
  }

  String _cleanModulTitle(String rawTitle, int urutan) {
    final pattern =
        RegExp('^\\s*modul\\s*$urutan\\s*[:\\-]?\\s*', caseSensitive: false);
    return rawTitle.replaceFirst(pattern, '').trim();
  }
}

class _MateriCard extends StatelessWidget {
  const _MateriCard({
    required this.item,
    required this.completed,
    required this.isActionLoading,
    required this.onComplete,
    required this.onOpen,
  });

  final MateriEdukasi item;
  final bool completed;
  final bool isActionLoading;
  final VoidCallback onComplete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'edu_material_label'.trParams(
                <String, String>{'index': '${item.urutan}'},
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.judul,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.konten,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Symbols.visibility, size: 16),
                    label: Text(
                      'edu_read_detail'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      foregroundColor: const Color(0xFF047857),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (completed || isActionLoading) ? null : onComplete,
                    icon: Icon(
                        completed ? Symbols.check_circle : Symbols.task_alt),
                    label: Text(
                      completed ? 'edu_done'.tr : 'edu_mark_done'.tr,
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(38),
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF052E2B),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
