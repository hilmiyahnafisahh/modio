import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/services/profile_update_service.dart';
import '../../data/profile_repository.dart';

/// ─────────────────────────────────────────────────────────────────
/// INFORMASI PROFIL PAGE  –  Tampil & edit data pengguna (persisten)
/// ─────────────────────────────────────────────────────────────────

class InformasiProfilPage extends StatefulWidget {
  const InformasiProfilPage({super.key});

  @override
  State<InformasiProfilPage> createState() => _InformasiProfilPageState();
}

class _InformasiProfilPageState extends State<InformasiProfilPage> {
  bool _isEditing  = false;
  bool _isLoading  = true;
  bool _isSaving   = false;

  final _namaCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _noHpCtrl       = TextEditingController();
  final _namaUsahaCtrl  = TextEditingController();
  final _jenisUsahaCtrl = TextEditingController();
  final _alamatCtrl     = TextEditingController();

  final _repo = ProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    _muatData();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _noHpCtrl.dispose();
    _namaUsahaCtrl.dispose();
    _jenisUsahaCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  // ── Load dari DB ─────────────────────────────────────────────────
  Future<void> _muatData() async {
    final data = await _repo.bacaProfil();
    if (!mounted) return;
    setState(() {
      _namaCtrl.text       = data['profil_nama']        ?? '';
      _emailCtrl.text      = data['profil_email']       ?? '';
      _noHpCtrl.text       = data['profil_no_hp']       ?? '';
      _namaUsahaCtrl.text  = data['profil_nama_usaha']  ?? '';
      _jenisUsahaCtrl.text = data['profil_jenis_usaha'] ?? '';
      _alamatCtrl.text     = data['profil_alamat']      ?? '';
      _isLoading = false;
    });
  }

  // ── Simpan ke DB ─────────────────────────────────────────────────
  Future<void> _simpan() async {
    setState(() => _isSaving = true);
    try {
      await _repo.simpanInfoPribadi(
        nama:        _namaCtrl.text.trim(),
        email:       _emailCtrl.text.trim(),
        noHp:        _noHpCtrl.text.trim(),
        namaUsaha:   _namaUsahaCtrl.text.trim(),
        jenisUsaha:  _jenisUsahaCtrl.text.trim(),
        alamat:      _alamatCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving  = false;
      });
      // Notifikasi ke dashboard dan halaman lain bahwa profil telah diperbarui
      ProfileUpdateService().notifyProfileUpdated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profil berhasil diperbarui',
            style: TextStyle(
              color: context.gelap ? AppColors.darkBg : AppColors.white,
            ),
          ),
          backgroundColor: context.warnaMasuk,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan. Coba lagi.',
            style: TextStyle(
              color: context.gelap ? AppColors.darkBg : AppColors.white,
            ),
          ),
          backgroundColor: context.warnaKeluar,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _toggleEdit() {
    if (_isEditing) {
      _simpan();
    } else {
      setState(() => _isEditing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.warnaTeksUtama,
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
        ),
        title: Text(
          'Informasi Profil',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
              ),
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _toggleEdit,
              child: _isSaving
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.primary))
                  : Text(
                      _isEditing ? 'Simpan' : 'Ubah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: scheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // ── Avatar ────────────────────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline,
                            size: 46,
                            color: scheme.onPrimary,
                          ),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    width: 2),
                              ),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 14,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Data Pribadi ──────────────────────────────────
                  _buildSectionLabel('DATA PRIBADI'),
                  const SizedBox(height: 8),
                  _buildFieldGroup([
                    _FieldItem(label: 'Nama Lengkap', controller: _namaCtrl,
                        icon: Icons.person_outline),
                    _FieldItem(label: 'Email', controller: _emailCtrl,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    _FieldItem(label: 'Nomor HP', controller: _noHpCtrl,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone),
                  ]),
                  const SizedBox(height: 20),

                  // ── Data Usaha ────────────────────────────────────
                  _buildSectionLabel('DATA USAHA'),
                  const SizedBox(height: 8),
                  _buildFieldGroup([
                    _FieldItem(label: 'Nama Usaha',
                        controller: _namaUsahaCtrl,
                        icon: Icons.store_outlined),
                    _FieldItem(label: 'Jenis Usaha',
                        controller: _jenisUsahaCtrl,
                        icon: Icons.category_outlined),
                    _FieldItem(label: 'Alamat', controller: _alamatCtrl,
                        icon: Icons.location_on_outlined, maxLines: 3),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.warnaTeksMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildFieldGroup(List<_FieldItem> fields) {
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.warnaGaris),
      ),
      child: Column(
        children: List.generate(fields.length, (index) {
          final field  = fields[index];
          final isLast = index == fields.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(field.icon, size: 18, color: context.warnaTeksMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.warnaTeksMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _isEditing
                              ? TextField(
                                  controller: field.controller,
                                  maxLines: field.maxLines,
                                  keyboardType: field.keyboardType,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: context.warnaTeksUtama,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 1.5),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: context.warnaGaris),
                                    ),
                                  ),
                                )
                              : Text(
                                  field.controller.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: context.warnaTeksUtama,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1, indent: 46, color: context.warnaGaris),
            ],
          );
        }),
      ),
    );
  }

}

class _FieldItem {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;

  const _FieldItem({
    required this.label,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });
}


