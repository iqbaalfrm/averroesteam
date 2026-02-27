from datetime import datetime, timedelta
import os

from werkzeug.security import generate_password_hash

from .extensions import db
from .models import (
    Berita,
    Buku,
    Diskusi,
    Kelas,
    Materi,
    MateriProgress,
    Modul,
    Quiz,
    QuizSubmission,
    Screener,
    Sertifikat,
    User,
)


def seed_data():
    if not User.query.filter_by(role="admin").first():
        admin_email = os.getenv("ADMIN_EMAIL", "admin@averroes.local")
        admin_password = os.getenv("ADMIN_PASSWORD", "admin123")
        admin = User(
            nama="Administrator Averroes",
            email=admin_email,
            password_hash=generate_password_hash(admin_password),
            role="admin",
        )
        db.session.add(admin)

    # Dummy users for CRUD "Pengguna" and related entities.
    dummy_users = [
        ("Aisyah Rahma", "aisyah@averroes.local"),
        ("Fajar Pratama", "fajar@averroes.local"),
        ("Nadia Putri", "nadia@averroes.local"),
    ]
    for nama, email in dummy_users:
        if not User.query.filter_by(email=email).first():
            db.session.add(
                User(
                    nama=nama,
                    email=email,
                    password_hash=generate_password_hash("user12345"),
                    role="user",
                )
            )

    target_title = "Dasar Fiqh Muamalah Digital"
    target_desc = (
        "Kelas inti untuk memahami prinsip halal-haram, adab transaksi, dan penerapan fiqh "
        "muamalah pada aset digital secara bertahap."
    )

    kelas_target = Kelas.query.filter_by(judul=target_title).first()
    if not kelas_target:
        kelas_target = Kelas(judul=target_title, deskripsi=target_desc, tingkat="Pemula")
        db.session.add(kelas_target)
        db.session.flush()
    else:
        kelas_target.deskripsi = target_desc
        kelas_target.tingkat = "Pemula"

    kelas_lain = Kelas.query.filter(Kelas.id != kelas_target.id).all()
    for kelas in kelas_lain:
        modul_ids = [m.id for m in Modul.query.filter_by(kelas_id=kelas.id).all()]
        if modul_ids:
            materi_ids = [m.id for m in Materi.query.filter(Materi.modul_id.in_(modul_ids)).all()]
            if materi_ids:
                MateriProgress.query.filter(MateriProgress.materi_id.in_(materi_ids)).delete(
                    synchronize_session=False
                )
        quiz_ids = [q.id for q in Quiz.query.filter_by(kelas_id=kelas.id).all()]
        if quiz_ids:
            QuizSubmission.query.filter(QuizSubmission.quiz_id.in_(quiz_ids)).delete(synchronize_session=False)
        db.session.delete(kelas)
    db.session.flush()

    old_modul_ids = [m.id for m in Modul.query.filter_by(kelas_id=kelas_target.id).all()]
    if old_modul_ids:
        old_materi_ids = [m.id for m in Materi.query.filter(Materi.modul_id.in_(old_modul_ids)).all()]
        if old_materi_ids:
            MateriProgress.query.filter(MateriProgress.materi_id.in_(old_materi_ids)).delete(
                synchronize_session=False
            )
            Materi.query.filter(Materi.modul_id.in_(old_modul_ids)).delete(synchronize_session=False)
    old_quiz_ids = [q.id for q in Quiz.query.filter_by(kelas_id=kelas_target.id).all()]
    if old_quiz_ids:
        QuizSubmission.query.filter(QuizSubmission.quiz_id.in_(old_quiz_ids)).delete(synchronize_session=False)
    Quiz.query.filter_by(kelas_id=kelas_target.id).delete(synchronize_session=False)
    Sertifikat.query.filter_by(kelas_id=kelas_target.id).delete(synchronize_session=False)
    Modul.query.filter_by(kelas_id=kelas_target.id).delete(synchronize_session=False)
    db.session.flush()

    modul_specs = [
        (
            "Modul 1: Pengantar Fiqh Muamalah Digital",
            "Mengenal tujuan fiqh muamalah, ruang lingkup transaksi digital, dan kaidah dasar.",
            "Fiqh muamalah digital membahas cara bertransaksi secara adil, transparan, dan bebas unsur terlarang. "
            "Peserta memahami bahwa area muamalah berbeda dengan ibadah mahdhah: ruang ijtihad lebih luas selama "
            "tujuan syariah terjaga. Dalam praktik modern, transaksi melalui aplikasi, dompet digital, dan aset "
            "berbasis teknologi tetap wajib memenuhi prinsip keadilan, kerelaan, serta kejelasan hak dan kewajiban. "
            "Kita juga menekankan hifzh al-mal (menjaga harta) agar keputusan finansial tidak merusak diri, keluarga, "
            "atau masyarakat.\n\n"
            "Dalil ayat: QS. Al-Baqarah: 275 menegaskan Allah menghalalkan jual beli dan mengharamkan riba. "
            "Dalil ayat: QS. An-Nisa: 29 melarang memakan harta sesama dengan cara batil kecuali melalui perdagangan "
            "atas dasar suka sama suka.",
        ),
        (
            "Modul 2: Rukun dan Syarat Akad",
            "Memahami subjek akad, objek akad, ijab qabul, dan syarat sah perjanjian.",
            "Akad yang sah membutuhkan pihak yang cakap hukum, objek yang diketahui, serta kesepakatan tanpa paksaan. "
            "Dalam konteks digital, ijab qabul dapat berbentuk persetujuan elektronik, klik terms, atau tanda tangan "
            "digital selama unsur kerelaan dan kejelasan tidak hilang. Peserta belajar menilai apakah syarat transaksi "
            "ditulis secara terbuka: biaya, risiko, waktu penyelesaian, dan mekanisme komplain. Tanpa informasi ini, "
            "akad berpotensi cacat dan menimbulkan sengketa.\n\n"
            "Dalil ayat: QS. Al-Ma'idah: 1 memerintahkan orang beriman untuk menepati akad. "
            "Dalil hadits: 'Kaum muslimin terikat dengan syarat-syarat mereka' (HR. Abu Dawud, Tirmidzi).",
        ),
        (
            "Modul 3: Larangan Riba dalam Transaksi Modern",
            "Mempelajari bentuk riba dan penerapannya pada produk finansial digital.",
            "Riba terjadi ketika ada tambahan yang disyaratkan secara zalim dalam pertukaran atau utang piutang. "
            "Peserta mempelajari bentuk riba nasi'ah dan fadhl, lalu menilai produk modern yang tampak menguntungkan "
            "namun menyimpan unsur bunga terselubung. Kita bedakan antara biaya layanan nyata (ujrah) dengan tambahan "
            "yang tidak seimbang terhadap manfaat. Penekanan utama: keuntungan dalam Islam harus berjalan seiring "
            "dengan risiko usaha yang wajar, bukan imbal hasil pasti tanpa aktivitas produktif.\n\n"
            "Dalil ayat: QS. Al-Baqarah: 278-279 memerintahkan meninggalkan sisa riba. "
            "Dalil hadits: Rasulullah melaknat pemakan riba, pemberi riba, pencatat, dan saksinya (HR. Muslim).",
        ),
        (
            "Modul 4: Gharar dan Ketidakjelasan Informasi",
            "Menganalisis risiko ketidakjelasan objek, harga, dan mekanisme transaksi.",
            "Gharar muncul ketika informasi inti transaksi tidak jelas: objek, harga, kualitas, atau mekanisme "
            "penyerahan. Dalam aset digital, peserta dilatih membaca dokumen proyek, tokenomics, struktur biaya, "
            "dan hak pengguna agar tidak membeli sesuatu yang belum dipahami. Ketidakjelasan berlebihan akan "
            "mendorong sengketa dan ketidakadilan. Karena itu, transparansi data menjadi syarat moral sekaligus "
            "syariah dalam pengambilan keputusan investasi.\n\n"
            "Dalil hadits: Nabi melarang jual beli gharar (HR. Muslim). "
            "Dalil ayat: QS. Al-Baqarah: 282 mendorong pencatatan transaksi utang secara jelas untuk mencegah sengketa.",
        ),
        (
            "Modul 5: Maysir dan Spekulasi Berlebihan",
            "Mengenal batas antara investasi rasional dan praktik spekulatif menyerupai judi.",
            "Maysir menekankan keuntungan berbasis untung-untungan, bukan nilai ekonomi nyata. "
            "Peserta diajak membedakan aktivitas investasi dengan analisis yang terukur versus perilaku mengejar "
            "sensasi harga tanpa rencana. Modul ini menyoroti gejala FOMO, overtrading, dan keputusan emosional "
            "yang sering berakhir merusak harta. Prinsip syariah mendorong ketenangan, disiplin, dan kehati-hatian "
            "agar harta menjadi sarana maslahat, bukan sumber kerusakan.\n\n"
            "Dalil ayat: QS. Al-Ma'idah: 90 melarang khamr dan maysir. "
            "Dalil hadits: 'Tidak boleh menimbulkan bahaya bagi diri sendiri dan orang lain' (HR. Ibn Majah).",
        ),
        (
            "Modul 6: Kepemilikan dan Amanah Aset Digital",
            "Membahas konsep milkiyyah, hak akses, dan tanggung jawab penjagaan aset.",
            "Kepemilikan (milkiyyah) dalam Islam menuntut kemampuan menguasai, memanfaatkan, dan mempertanggungjawabkan "
            "aset dengan benar. Dalam konteks digital, amanah itu meliputi pengamanan private key, pengaturan akses, "
            "dan perlindungan data pribadi. Peserta belajar bahwa kelalaian keamanan bisa menimbulkan kerugian besar "
            "serta berdampak pada pihak lain. Karena itu, keamanan bukan hanya isu teknis, tetapi bagian dari adab "
            "muamalah dan tanggung jawab moral seorang muslim.\n\n"
            "Dalil ayat: QS. An-Nisa: 58 memerintahkan menyampaikan amanah kepada yang berhak. "
            "Dalil hadits: 'Tunaikan amanah kepada orang yang mempercayaimu' (HR. Abu Dawud, Tirmidzi).",
        ),
        (
            "Modul 7: Etika Informasi dan Transparansi",
            "Menegaskan pentingnya kejujuran data, keterbukaan risiko, dan anti-manipulasi.",
            "Etika muamalah melarang tadlis (penipuan) dan menyembunyikan cacat informasi. "
            "Peserta belajar menilai kredibilitas proyek melalui kualitas laporan, keterbukaan tim, dan konsistensi "
            "komunikasi publik. Modul ini menekankan bahwa promosi yang berlebihan tanpa pengungkapan risiko adalah "
            "bentuk ketidakjujuran yang merusak kepercayaan pasar. Transparansi bukan sekadar strategi branding, "
            "tetapi tuntutan etis dalam syariah.\n\n"
            "Dalil hadits: 'Siapa yang menipu maka ia bukan golongan kami' (HR. Muslim). "
            "Dalil ayat: QS. Al-Mutaffifin: 1-3 mengecam kecurangan dalam timbangan dan takaran.",
        ),
        (
            "Modul 8: Manajemen Risiko Syariah",
            "Menerapkan prinsip kehati-hatian, diversifikasi, dan batas kerugian.",
            "Syariah mendorong ikhtiar yang terukur, bukan sikap nekat. Modul ini membahas penyusunan rencana "
            "alokasi modal, batas kerugian, evaluasi berkala, dan disiplin terhadap strategi yang telah disusun. "
            "Peserta didorong memahami diversifikasi agar risiko tidak terkonsentrasi pada satu aset. Keputusan yang "
            "berbasis data dan tujuan jangka panjang lebih dekat dengan maqashid syariah dibanding keputusan impulsif "
            "yang dipicu emosi sesaat.\n\n"
            "Dalil ayat: QS. Al-Hashr: 18 memerintahkan memperhatikan apa yang dipersiapkan untuk hari esok. "
            "Dalil hadits: 'Ikatlah untamu lalu bertawakkal' (HR. Tirmidzi) sebagai prinsip ikhtiar sebelum tawakkal.",
        ),
        (
            "Modul 9: Studi Kasus Muamalah Aset Digital",
            "Membaca contoh kasus nyata dan menyusun penilaian hukum secara bertahap.",
            "Pada modul studi kasus, peserta berlatih menilai proyek utilitas, token komunitas, dan skema imbal hasil "
            "dengan kerangka fiqh muamalah. Setiap kasus dipetakan: jenis akadnya, manfaat nyatanya, risiko yang "
            "muncul, serta indikasi unsur terlarang. Tujuan utama modul ini adalah membangun kebiasaan berpikir "
            "sistematis dan tidak tergesa-gesa sebelum mengambil keputusan finansial.\n\n"
            "Dalil ayat: QS. Al-Hujurat: 6 memerintahkan tabayyun (verifikasi) sebelum bertindak. "
            "Dalil hadits: 'Tinggalkan yang meragukanmu menuju yang tidak meragukanmu' (HR. Tirmidzi, Nasa'i).",
        ),
        (
            "Modul 10: Rangkuman dan Persiapan Ujian",
            "Merangkum seluruh materi dan menyiapkan strategi menghadapi kuis akhir.",
            "Modul penutup merangkum peta konsep dari seluruh pembahasan: akad, riba, gharar, maysir, amanah, "
            "transparansi, hingga manajemen risiko. Peserta diarahkan meninjau kesalahan umum pemula dan teknik "
            "menjawab soal evaluasi berdasarkan pemahaman prinsip, bukan hafalan semata. Target akhirnya adalah "
            "membentuk pola pikir muamalah yang matang: hati-hati, adil, dan bertanggung jawab.\n\n"
            "Dalil ayat: QS. Az-Zumar: 9 memuliakan orang berilmu dibanding yang tidak berilmu. "
            "Dalil hadits: 'Barangsiapa menempuh jalan untuk mencari ilmu, Allah mudahkan baginya jalan ke surga' "
            "(HR. Muslim).",
        ),
    ]

    for idx, (judul, deskripsi, konten) in enumerate(modul_specs, start=1):
        modul = Modul(
            kelas_id=kelas_target.id,
            judul=judul,
            deskripsi=deskripsi,
            urutan=idx,
        )
        db.session.add(modul)
        db.session.flush()
        db.session.add(
            Materi(
                modul_id=modul.id,
                judul=f"Materi Bacaan {idx}",
                konten=konten,
                urutan=1,
            )
        )

    quiz_specs = [
        (
            "Dalam kaidah fiqh muamalah, hukum asal transaksi adalah?",
            "Haram sampai ada dalil yang membolehkan",
            "Mubah sampai ada dalil yang melarang",
            "Makruh dalam semua kondisi",
            "Wajib jika menguntungkan",
            "B",
        ),
        (
            "Unsur utama agar akad sah adalah berikut ini, kecuali:",
            "Pihak berakad yang cakap",
            "Objek akad yang jelas",
            "Kesepakatan tanpa paksaan",
            "Janji keuntungan pasti",
            "D",
        ),
        (
            "Tambahan yang disyaratkan dalam pinjaman termasuk kategori:",
            "Hibah",
            "Ujrah",
            "Riba",
            "Mudharabah",
            "C",
        ),
        (
            "Contoh gharar dalam transaksi digital adalah:",
            "Spesifikasi aset tidak jelas",
            "Biaya layanan transparan",
            "Akad tertulis rapi",
            "Bukti transaksi tersimpan",
            "A",
        ),
        (
            "Perilaku yang mendekati maysir adalah:",
            "Membeli aset setelah riset mendalam",
            "Masuk pasar hanya karena rumor viral",
            "Membaca whitepaper proyek",
            "Membagi risiko ke beberapa aset",
            "B",
        ),
        (
            "Tujuan utama manajemen risiko syariah adalah:",
            "Memaksimalkan leverage",
            "Menghapus semua risiko",
            "Menjaga harta dari mudarat berlebihan",
            "Mengejar profit harian",
            "C",
        ),
        (
            "Salah satu bentuk tadlis adalah:",
            "Menjelaskan risiko dengan jujur",
            "Menyembunyikan informasi penting proyek",
            "Mencatat transaksi dengan rapi",
            "Menghindari janji berlebihan",
            "B",
        ),
        (
            "Bukti persetujuan akad digital dapat dianggap sah jika:",
            "Tidak ada jejak sama sekali",
            "Ada kerelaan dan kejelasan syarat",
            "Hanya berdasarkan ucapan lisan pihak ketiga",
            "Harga bisa diubah sepihak kapan saja",
            "B",
        ),
        (
            "Sikap paling tepat saat menemukan proyek yang tidak transparan adalah:",
            "Tetap masuk karena potensi cuan tinggi",
            "Mengajak teman ikut segera",
            "Menunda keputusan sampai data jelas",
            "Menggunakan seluruh tabungan",
            "C",
        ),
        (
            "Dalam perspektif syariah, aset yang layak dipertimbangkan adalah yang:",
            "Tidak punya utilitas namun ramai promosi",
            "Memiliki manfaat jelas dan tata kelola terbuka",
            "Menjanjikan keuntungan tetap tanpa risiko",
            "Dikendalikan penuh oleh pihak anonim",
            "B",
        ),
        (
            "Yang termasuk amanah dalam kepemilikan aset digital adalah:",
            "Membagikan private key ke grup",
            "Mengabaikan keamanan akun",
            "Menjaga akses dan keamanan dompet",
            "Menyimpan seed phrase di media publik",
            "C",
        ),
        (
            "Jika seluruh materi selesai namun nilai kuis 60, maka sertifikat:",
            "Tetap terbit otomatis",
            "Tidak terbit karena belum mencapai batas kelulusan",
            "Terbit jika meminta ke admin",
            "Terbit hanya untuk modul awal",
            "B",
        ),
        (
            "Kapan strategi DCA lebih relevan digunakan?",
            "Saat ingin all-in satu kali",
            "Saat ingin disiplin akumulasi bertahap",
            "Saat mengejar untung cepat harian",
            "Saat tidak punya rencana risiko",
            "B",
        ),
        (
            "Contoh keputusan yang sesuai adab muamalah adalah:",
            "Mempromosikan aset tanpa paham risikonya",
            "Mencela pihak lain saat rugi",
            "Menyampaikan analisis dengan jujur dan proporsional",
            "Memaksa orang lain membeli aset tertentu",
            "C",
        ),
        (
            "Parameter awal sebelum membeli aset digital adalah:",
            "Tren influencer semata",
            "Ketersediaan utilitas, akad, dan transparansi",
            "Prediksi tanpa data",
            "Bonus referral terbesar",
            "B",
        ),
    ]

    for pertanyaan, a, b, c, d, jawaban in quiz_specs:
        db.session.add(
            Quiz(
                kelas_id=kelas_target.id,
                pertanyaan=pertanyaan,
                pilihan_a=a,
                pilihan_b=b,
                pilihan_c=c,
                pilihan_d=d,
                jawaban_benar=jawaban,
            )
        )

    db.session.add(
        Sertifikat(
            kelas_id=kelas_target.id,
            nama_template="Sertifikat Dasar Fiqh Muamalah Digital",
            deskripsi="Diberikan setelah menyelesaikan seluruh materi dan lulus kuis akhir (minimal 70).",
        )
    )

    if Buku.query.count() == 0:
        db.session.add_all(
            [
                Buku(
                    judul="Fiqh Muamalah Kontemporer",
                    penulis="Tim Averroes",
                    deskripsi="Panduan dasar muamalah modern.",
                    file_pdf=None,
                ),
                Buku(
                    judul="Aset Digital dan Syariah",
                    penulis="Averroes Research",
                    deskripsi="Telaah aset digital dari sudut pandang syariah.",
                    file_pdf=None,
                ),
            ]
        )

    if Screener.query.count() == 0:
        db.session.add_all(
            [
                Screener(nama_koin="Bitcoin", simbol="BTC", status="proses", alasan="Masih dalam kajian metodologi internal."),
                Screener(nama_koin="Ethereum", simbol="ETH", status="proses", alasan="Masih dalam kajian metodologi internal."),
                Screener(nama_koin="Tether", simbol="USDT", status="haram", alasan="Catatan ketidakjelasan underlying di beberapa aspek."),
                Screener(nama_koin="BNB", simbol="BNB", status="proses", alasan="Perlu kajian lanjutan struktur utilitas token."),
                Screener(nama_koin="Solana", simbol="SOL", status="halal", alasan="Memenuhi indikator utilitas dan transparansi dasar versi internal."),
            ]
        )

    if Berita.query.count() == 0:
        now = datetime.utcnow()
        for idx in range(1, 6):
            db.session.add(
                Berita(
                    judul=f"Update Pasar Syariah #{idx}",
                    ringkasan="Ringkasan berita aset digital syariah.",
                    konten="Konten berita lengkap untuk kebutuhan aplikasi Averroes.",
                    sumber_url="https://averroes.web.id",
                    published_at=now - timedelta(days=idx),
                )
            )

    if Diskusi.query.count() == 0:
        users = User.query.filter_by(role="user").limit(3).all()
        if users:
            topik = [
                (
                    users[0].id,
                    "Apakah staking termasuk gharar?",
                    "Saya masih bingung apakah staking masuk gharar atau tidak. Mohon pencerahan.",
                ),
                (
                    users[min(1, len(users) - 1)].id,
                    "Bagaimana cara baca screener syariah?",
                    "Indikator paling penting yang harus dilihat dulu apa ya?",
                ),
                (
                    users[min(2, len(users) - 1)].id,
                    "Portofolio pemula yang aman",
                    "Untuk pemula, lebih baik fokus belajar dulu atau langsung mulai nominal kecil?",
                ),
            ]
            for user_id, judul, isi in topik:
                db.session.add(Diskusi(user_id=user_id, judul=judul, isi=isi))

    fajar = User.query.filter_by(email="fajar@averroes.local").first()
    if fajar and Diskusi.query.filter_by(user_id=fajar.id, parent_id=None).count() == 0:
        thread1 = Diskusi(
            user_id=fajar.id,
            judul="Checklist Syariah Sebelum Beli Coin",
            isi="Teman-teman, ini checklist yang biasa saya pakai: cek utilitas, transparansi tim, tokenomics, dan potensi gharar. Ada tambahan?",
        )
        db.session.add(thread1)
        db.session.flush()
        db.session.add(
            Diskusi(
                user_id=fajar.id,
                parent_id=thread1.id,
                isi="Tambahan dari saya: hindari token yang model bisnisnya cuma hype tanpa produk nyata.",
            )
        )
        db.session.add(
            Diskusi(
                user_id=fajar.id,
                judul="Belajar DCA Spot Tanpa FOMO",
                isi="Saya lagi coba strategi DCA mingguan nominal kecil, fokus ke aset yang lolos screener syariah.",
            )
        )

    db.session.commit()
