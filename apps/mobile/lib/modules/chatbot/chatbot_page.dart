import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';

class HalamanChatbot extends StatefulWidget {
  const HalamanChatbot({super.key});

  @override
  State<HalamanChatbot> createState() => _HalamanChatbotState();
}

class _HalamanChatbotState extends State<HalamanChatbot> {
  static const List<String> _quickPrompts = <String>[
    'Koin BTC halal?',
    'Cara bayar zakat kripto',
    'Risiko stablecoin syariah',
  ];

  static const String _welcomeMessage =
      'Assalamu\'alaikum. Saya bisa bantu seputar crypto saja, termasuk konsep syariah, risiko, dan edukasi dasar. Tanyakan apa yang ingin kamu cek.';

  static const String _outsideScopeMessage =
      'Saat ini saya dibatasi untuk topik crypto saja. Coba tanyakan seputar koin, blockchain, wallet, exchange, trading, risiko, atau aspek syariah crypto.';

  static final RegExp _cryptoPattern = RegExp(
    r'\b('
    r'crypto|kripto|bitcoin|btc|ethereum|eth|altcoin|token|coin|koin|blockchain|web3|'
    r'nft|defi|wallet|exchange|trading|staking|mining|airdop|airdrop|stablecoin|'
    r'zakat|syariah|sharia|halal|haram|riba|maysir|gharar|onchain|on-chain'
    r')\b',
    caseSensitive: false,
  );

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _GroqChatService _groqChatService = _GroqChatService();

  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      sender: _Sender.assistant,
      text: _welcomeMessage,
    ),
  ];

  bool _isLoading = false;
  bool _includeDalil = true;
  _ResponseMode _responseMode = _ResponseMode.normal;

  bool get _isChatConfigured => AppConfig.isGroqConfigured;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isCryptoQuestion(String text) {
    return _cryptoPattern.hasMatch(text.toLowerCase());
  }

  Future<void> _sendMessage([String? quickPrompt]) async {
    final String text = (quickPrompt ?? _inputController.text).trim();
    if (text.isEmpty || _isLoading) {
      return;
    }

    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.user, text: text));
    });
    _scrollToBottom();

    if (!_isCryptoQuestion(text)) {
      setState(() {
        _messages.add(
          const _ChatMessage(
              sender: _Sender.assistant, text: _outsideScopeMessage),
        );
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String response = await _groqChatService.generateReply(
        messages: _messages,
        includeDalil: _includeDalil,
        responseMode: _responseMode,
      );

      setState(() {
        _messages.add(_ChatMessage(sender: _Sender.assistant, text: response));
      });
    } catch (error) {
      final String userMessage = _mapChatError(error);
      setState(() {
        _messages.add(
          _ChatMessage(
            sender: _Sender.assistant,
            text: userMessage,
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _mapChatError(Object error) {
    if (error is _ChatServiceException) {
      return error.userMessage;
    }

    if (error is StateError) {
      return 'API key belum terbaca. Pastikan `.env` berisi `GROQ_API_KEY=...` lalu lakukan full restart app.';
    }

    return 'Saya belum bisa menjawab sekarang. Terjadi kendala koneksi ke layanan AI, coba lagi sebentar.';
  }

  void _resetConversation() {
    setState(() {
      _messages
        ..clear()
        ..add(
          const _ChatMessage(
            sender: _Sender.assistant,
            text: _welcomeMessage,
          ),
        );
    });
    _scrollToBottom();
  }

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        bool localIncludeDalil = _includeDalil;
        _ResponseMode localResponseMode = _responseMode;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Pengaturan Chatbot',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Atur gaya jawaban Averroes Chatbot sesuai kebutuhanmu.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Sertakan Dalil',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bot akan mencoba menyertakan ayat atau hadits yang relevan saat menjawab.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: localIncludeDalil,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (bool value) {
                                  setModalState(
                                      () => localIncludeDalil = value);
                                  setState(() => _includeDalil = value);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Mode Jawaban',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: _ResponseMode.values
                                .map(
                                  (_ResponseMode mode) => Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: mode != _ResponseMode.values.last
                                            ? 8
                                            : 0,
                                      ),
                                      child: _ModeChip(
                                        label: mode.label,
                                        active: localResponseMode == mode,
                                        onTap: () {
                                          setModalState(
                                            () => localResponseMode = mode,
                                          );
                                          setState(() => _responseMode = mode);
                                        },
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD1FAE5)),
                      ),
                      child: Text(
                        'Catatan: chatbot bersifat edukatif dan bukan fatwa final atau saran investasi.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF065F46),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetConversation();
                        },
                        child: Text(
                          'Reset Chat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: Column(
        children: <Widget>[
          _HeaderChatbot(
            onOpenSettings: _showSettingsSheet,
            isConfigured: _isChatConfigured,
          ),
          if (!_isChatConfigured)
            const _ChatbotConfigNotice(),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemBuilder: (BuildContext context, int index) {
                final _ChatMessage message = _messages[index];
                return _MessageBubble(message: message);
              },
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemCount: _messages.length,
            ),
          ),
          _FooterChatbot(
            controller: _inputController,
            onSend: _sendMessage,
            isLoading: _isLoading,
            quickPrompts: _quickPrompts,
            enabled: _isChatConfigured,
          ),
        ],
      ),
    );
  }
}

class _HeaderChatbot extends StatelessWidget {
  const _HeaderChatbot({
    required this.onOpenSettings,
    required this.isConfigured,
  });

  final VoidCallback onOpenSettings;
  final bool isConfigured;

  String _trOr(String key, String fallback) {
    final String translated = key.tr;
    return translated == key ? fallback : translated;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            _IconCircle(
              icon: Symbols.arrow_back,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _trOr('chatbot_title', 'Averroes Chatbot'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isConfigured
                              ? const Color(0xFF13ECB9)
                              : const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConfigured
                            ? _trOr('chatbot_status_ready', 'Siap Membantu')
                            : _trOr(
                                'chatbot_status_unconfigured',
                                'Butuh Konfigurasi',
                              ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isConfigured
                              ? const Color(0xFF13ECB9)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _IconCircle(
              icon: Symbols.tune,
              color: const Color(0xFF9CA3AF),
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatbotConfigNotice extends StatelessWidget {
  const _ChatbotConfigNotice();

  String _trOr(String key, String fallback) {
    final String translated = key.tr;
    return translated == key ? fallback : translated;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        _trOr(
          'chatbot_unconfigured_message',
          'Chatbot belum dikonfigurasi untuk build ini. Isi GROQ_API_KEY di .env lalu lakukan full restart app.',
        ),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF92400E),
          height: 1.5,
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, this.color, this.onTap});

  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: color ?? const Color(0xFF111827)),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  String _trOr(String key, String fallback) {
    final String translated = key.tr;
    return translated == key ? fallback : translated;
  }

  @override
  Widget build(BuildContext context) {
    final bool isAssistant = message.sender == _Sender.assistant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:
          isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: <Widget>[
        if (isAssistant) ...<Widget>[
          const _AvatarAI(),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment:
                isAssistant ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                isAssistant
                    ? _trOr('chatbot_brand', 'AVERROES CHATBOT')
                    : 'ANDA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAssistant ? Colors.white : const Color(0xFF13ECB9),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomRight:
                        isAssistant ? const Radius.circular(18) : Radius.zero,
                    bottomLeft:
                        isAssistant ? Radius.zero : const Radius.circular(18),
                  ),
                  border: isAssistant
                      ? Border.all(color: const Color(0xFFF1F5F9))
                      : null,
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: isAssistant ? FontWeight.w500 : FontWeight.w600,
                    color: isAssistant
                        ? const Color(0xFF1F2937)
                        : const Color(0xFF0D1B18),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isAssistant) ...<Widget>[
          const SizedBox(width: 10),
          const _AvatarUser(),
        ],
      ],
    );
  }
}

class _AvatarAI extends StatelessWidget {
  const _AvatarAI();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFF13ECB9),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Symbols.smart_toy,
        size: 18,
        color: Color(0xFF0D1B18),
      ),
    );
  }
}

class _AvatarUser extends StatelessWidget {
  const _AvatarUser();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E7EB),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Symbols.person,
        size: 18,
        color: Color(0xFF6B7280),
      ),
    );
  }
}

class _FooterChatbot extends StatelessWidget {
  const _FooterChatbot({
    required this.controller,
    required this.onSend,
    required this.isLoading,
    required this.quickPrompts,
    required this.enabled,
  });

  final TextEditingController controller;
  final ValueChanged<String?> onSend;
  final bool isLoading;
  final List<String> quickPrompts;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickPrompts
                  .map((String prompt) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _QuickPill(
                          label: prompt,
                          onTap: !enabled || isLoading
                              ? null
                              : () => onSend(prompt),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted:
                        !enabled || isLoading ? null : (_) => onSend(null),
                    minLines: 1,
                    maxLines: 4,
                    enabled: enabled,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1F2937),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Tanyakan seputar crypto...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: !enabled || isLoading ? null : () => onSend(null),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: enabled
                        ? const Color(0xFF13ECB9)
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: enabled
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x3313ECB9),
                              blurRadius: 10,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF0D1B18),
                            ),
                          ),
                        )
                      : Icon(
                          Symbols.send,
                          color: enabled
                              ? Color(0xFF0D1B18)
                              : Color(0xFF9CA3AF),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  const _QuickPill({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF064E3B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFF064E3B) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Sender { user, assistant }

enum _ResponseMode {
  singkat('Singkat'),
  normal('Normal'),
  detail('Detail');

  const _ResponseMode(this.label);

  final String label;
}

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});

  final _Sender sender;
  final String text;
}

class _GroqChatService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  final Dio _dio = Dio();

  Future<String> generateReply({
    required List<_ChatMessage> messages,
    required bool includeDalil,
    required _ResponseMode responseMode,
  }) async {
    final String apiKey = AppConfig.groqApiKey.trim();
    if (apiKey.isEmpty) {
      throw StateError('GROQ_API_KEY belum diset.');
    }

    final List<_ChatMessage> recentMessages = messages.length > 12
        ? messages.sublist(messages.length - 12)
        : messages;

    final String dalilInstruction = includeDalil
        ? 'Jika relevan, sertakan dalil yang kuat dari Al-Qur\'an atau hadits sahih/hasan yang masyhur, lalu hubungkan secara singkat ke konteks muamalah atau crypto. '
            'Jangan mengarang ayat, hadits, nama kitab, atau nomor rujukan. Jika tidak yakin pada redaksi atau sumber yang presisi, katakan bahwa dalil perlu diverifikasi dan jangan tampilkan kutipan palsu. '
            'Untuk dalil, prioritaskan ayat Al-Qur\'an terlebih dahulu. Jika memakai hadits, utamakan hadits yang populer dan kuat derajatnya. '
        : 'Jangan sertakan dalil kecuali user memintanya secara eksplisit. ';

    final String modeInstruction = switch (responseMode) {
      _ResponseMode.singkat =>
        'Utamakan jawaban sangat ringkas, sekitar 1-2 kalimat.',
      _ResponseMode.normal => 'Utamakan format jawaban 2-4 kalimat.',
      _ResponseMode.detail =>
        'Berikan jawaban sedikit lebih lengkap, maksimal 1 paragraf pendek atau beberapa poin singkat bila memang perlu.',
    };

    final List<Map<String, String>> promptMessages = <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content': 'Anda adalah Averroes Chatbot, asisten edukasi crypto syariah dalam aplikasi Averroes. '
            'Jawab hanya topik crypto: aset kripto, blockchain, wallet, exchange, trading spot, risiko, keamanan, zakat aset kripto, dan aspek syariah terkait crypto. '
            'Jika pertanyaan di luar topik tersebut, tolak dengan singkat lalu arahkan user kembali ke topik crypto syariah. '
            'Gunakan bahasa Indonesia yang natural, ramah, singkat, dan tidak bertele-tele. '
            'Utamakan jawaban praktis yang mudah dipahami pemula. '
            'Jangan menjanjikan profit, jangan memberi sinyal beli/jual, dan jangan menyebut sesuatu pasti naik atau pasti aman. '
            'Jika user bertanya halal/haram, jelaskan bahwa jawaban bersifat edukatif, bukan fatwa final, lalu sebutkan alasan singkat seperti manfaat proyek, mekanisme transaksi, unsur riba, gharar, maysir, atau underlying aset jika relevan. '
            '$dalilInstruction'
            'Jika informasi tidak cukup, katakan keterbatasannya secara jujur dan minta user kirim nama koin, ticker, atau konteks yang lebih spesifik. '
            '$modeInstruction '
            'Bila menyertakan dalil, boleh tambah 1 blok singkat dengan awalan "Dalil:". Pakai bullet hanya jika user meminta daftar atau langkah.',
      },
      ...recentMessages.map(
        (_ChatMessage message) => <String, String>{
          'role': message.sender == _Sender.user ? 'user' : 'assistant',
          'content': message.text,
        },
      ),
    ];

    final Map<String, dynamic> payload = <String, dynamic>{
      'model': AppConfig.groqModel,
      'messages': promptMessages,
      'temperature': 0.2,
      'top_p': 0.9,
      'max_tokens': 220,
    };

    late final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_baseUrl/chat/completions',
        data: payload,
        options: Options(
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );
    } on DioException catch (error) {
      throw _ChatServiceException(_mapDioErrorToUserMessage(error));
    }

    final Map<String, dynamic> data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    final List<dynamic> choices =
        (data['choices'] as List<dynamic>?) ?? <dynamic>[];
    if (choices.isEmpty) {
      return 'Saya belum mendapatkan jawaban yang valid. Coba ulangi pertanyaan crypto kamu.';
    }

    final Map<String, dynamic> firstChoice =
        choices.first as Map<String, dynamic>;
    final Map<String, dynamic> message =
        (firstChoice['message'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final dynamic content = message['content'];
    String text = '';
    if (content is String) {
      text = content.trim();
    } else if (content is List<dynamic>) {
      text = content
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> part) => (part['text'] as String?) ?? '')
          .join('\n')
          .trim();
    }

    if (text.isEmpty) {
      return 'Saya belum bisa membentuk jawaban yang jelas. Coba pertanyaan crypto yang lebih spesifik.';
    }

    return _normalizeAnswer(text);
  }

  String _normalizeAnswer(String text) {
    final String compact = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (compact.length <= 520) {
      return compact;
    }
    return '${compact.substring(0, 520).trim()}...';
  }

  String _mapDioErrorToUserMessage(DioException error) {
    final int? status = error.response?.statusCode;
    final dynamic rawData = error.response?.data;

    String apiMessage = '';
    if (rawData is Map<String, dynamic>) {
      final dynamic err = rawData['error'];
      if (err is Map<String, dynamic>) {
        apiMessage = (err['message'] as String?)?.trim() ?? '';
      }
    }

    if (status == 400 || status == 401 || status == 403) {
      return 'Permintaan ke Groq ditolak (${status ?? '-'}). '
          'Kemungkinan API key tidak valid, dibatasi, atau API belum diaktifkan. '
          '${apiMessage.isNotEmpty ? 'Detail: $apiMessage' : ''}';
    }

    if (status == 429) {
      return 'Kuota/rate limit Groq tercapai. Coba lagi beberapa saat.';
    }

    if (status != null) {
      return 'Layanan Groq error ($status). '
          '${apiMessage.isNotEmpty ? "Detail: $apiMessage" : "Coba lagi nanti."}';
    }

    return 'Gagal terhubung ke Groq. Periksa koneksi internet emulator/device.';
  }
}

class _ChatServiceException implements Exception {
  const _ChatServiceException(this.userMessage);

  final String userMessage;
}
