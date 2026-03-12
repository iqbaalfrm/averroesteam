import 'package:get/get.dart';

import '../middlewares/auth_required_popup_middleware.dart';
import '../../modules/edukasi/edukasi_page.dart';
import '../../modules/chatbot/chatbot_page.dart';
import '../../modules/login/login_page.dart';
import '../../modules/lupa_password/lupa_password_page.dart';
import '../../modules/lupa_password/verifikasi_otp_page.dart';
import '../../modules/register/register_page.dart';
import '../../modules/pasar/pasar_page.dart';
import '../../modules/portofolio/portofolio_page.dart';
import '../../modules/psikolog/psikolog_page.dart';
import '../../modules/diskusi/diskusi_page.dart';
import '../../modules/reels/reels_page.dart';
import '../../modules/screener/screener_page.dart';
import '../../modules/shell/shell_page.dart';
import '../../modules/zikir/zikir_page.dart';
import '../../modules/zakat/zakat_page.dart';
import '../../modules/konsultasi/konsultasi_page.dart';
import '../../modules/pustaka/pustaka_page.dart';
import '../../modules/bantuan/bantuan_page.dart';
import '../../modules/notifikasi/notifikasi_page.dart';
import '../../modules/edit_profil/edit_profil_page.dart';
import '../../modules/sertifikat/sertifikat_page.dart';
import '../../modules/kebijakan_privasi/kebijakan_privasi_page.dart';
import 'app_routes.dart';

class HalamanAplikasi {
  const HalamanAplikasi._();

  static final List<GetPage<dynamic>> halaman = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: RuteAplikasi.awal,
      page: () => const HalamanShell(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.beranda,
      page: () => const HalamanShell(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.edukasi,
      page: () => const HalamanEdukasi(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.penyaring,
      page: () => const HalamanScreener(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.pasar,
      page: () => const HalamanPasar(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.diskusi,
      page: () => const HalamanDiskusi(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.portofolio,
      page: () => const HalamanPortofolio(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.pustaka,
      page: () => const HalamanPustaka(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.zakat,
      page: () => const HalamanZakat(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.psikolog,
      page: () => const HalamanPsikolog(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.konsultasi,
      page: () => const HalamanKonsultasi(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.zikir,
      page: () => const HalamanZikir(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.bantuan,
      page: () => const HalamanBantuan(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.notifikasi,
      page: () => const HalamanNotifikasi(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.editProfil,
      page: () => const HalamanEditProfil(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.sertifikat,
      page: () => const HalamanSertifikat(),
      middlewares: <GetMiddleware>[AuthRequiredPopupMiddleware()],
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.kebijakanPrivasi,
      page: () => const HalamanKebijakanPrivasi(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.reels,
      page: () => const HalamanReels(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.chatbot,
      page: () => const HalamanChatbot(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.login,
      page: () => const HalamanLogin(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.register,
      page: () => const HalamanRegister(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.lupaPassword,
      page: () => const HalamanLupaPassword(),
    ),
    GetPage<dynamic>(
      name: RuteAplikasi.verifikasiOtp,
      page: () => const HalamanVerifikasiOTP(),
    ),
  ];
}
