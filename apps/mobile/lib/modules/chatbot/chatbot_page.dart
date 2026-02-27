import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: Column(
        children: <Widget>[
          const _HeaderChatbot(),
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
          ),
        ],
      ),
    );
  }
}

class _HeaderChatbot extends StatelessWidget {
  const _HeaderChatbot();

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
                    'Averroes AI Assistant',
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
                        decoration: const BoxDecoration(
                          color: Color(0xFF13ECB9),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Crypto Scope',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF13ECB9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const _IconCircle(icon: Symbols.tune, color: Color(0xFF9CA3AF)),
          ],
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
                isAssistant ? 'AVERROES AI' : 'ANDA',
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
  });

  final TextEditingController controller;
  final ValueChanged<String?> onSend;
  final bool isLoading;
  final List<String> quickPrompts;

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
                          onTap: isLoading ? null : () => onSend(prompt),
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
                    onSubmitted: isLoading ? null : (_) => onSend(null),
                    minLines: 1,
                    maxLines: 4,
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
                onTap: isLoading ? null : () => onSend(null),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF13ECB9),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x3313ECB9),
                        blurRadius: 10,
                        offset: Offset(0, 6),
                      ),
                    ],
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
                      : const Icon(
                          Symbols.send,
                          color: Color(0xFF0D1B18),
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

enum _Sender { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.sender, required this.text});

  final _Sender sender;
  final String text;
}

class _GroqChatService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  final Dio _dio = Dio();

  Future<String> generateReply({required List<_ChatMessage> messages}) async {
    final String apiKey = AppConfig.groqApiKey.trim();
    if (apiKey.isEmpty) {
      throw StateError('GROQ_API_KEY belum diset.');
    }

    final List<_ChatMessage> recentMessages = messages.length > 12
        ? messages.sublist(messages.length - 12)
        : messages;

    final List<Map<String, String>> promptMessages = <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content':
            'Anda adalah Averroes AI. Jawab hanya topik crypto (aset, blockchain, wallet, exchange, trading, risiko, keamanan, aspek syariah crypto). '
                'Jika pertanyaan di luar crypto, tolak dengan singkat dan arahkan ke topik crypto. '
                'Jangan memberi kepastian profit atau saran investasi pasti. '
                'Gunakan bahasa Indonesia natural, tidak kaku, dan ringkas. '
                'Jawaban maksimal 2-4 kalimat kecuali user minta detail.',
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
      'temperature': 0.3,
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
