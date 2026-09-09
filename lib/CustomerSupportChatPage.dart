import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CustomerSupportChatPage extends StatefulWidget {
  final String? initialPhone;
  final String? initialName;

  const CustomerSupportChatPage({super.key, this.initialPhone, this.initialName});

  @override
  State<CustomerSupportChatPage> createState() => _CustomerSupportChatPageState();
}

class _CustomerSupportChatPageState extends State<CustomerSupportChatPage> {
  static const String chatApiUrl = "https://agnicarrental.com/admin2025/support_chat.php";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = TextEditingController() as ScrollController? ?? ScrollController();

  String? _customerPhone;
  String? _customerName;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  final List<String> _quickQuestions = [
    "Are tolls & driver allowances included?",
    "How do I track my assigned driver?",
    "What is your cancellation policy?",
    "Can I change my pickup time?"
  ];

  @override
  void initState() {
    super.initState();
    _initCustomerProfile();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initCustomerProfile() async {
    String? phone = widget.initialPhone;
    String? name = widget.initialName;

    if (phone == null || phone.isEmpty) {
      phone = await _storage.read(key: 'phoneNumber') ??
              await _storage.read(key: 'phone') ??
              await _storage.read(key: 'userPhone');
    }

    if (name == null || name.isEmpty) {
      name = await _storage.read(key: 'userName') ??
             await _storage.read(key: 'name');
    }

    setState(() {
      _customerPhone = phone;
      _customerName = name ?? "Valued Customer";
    });

    if (_customerPhone != null && _customerPhone!.isNotEmpty) {
      _fetchMessages();
      _startPolling();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_customerPhone != null && _customerPhone!.isNotEmpty) {
        _fetchMessages(isSilent: true);
      }
    });
  }

  Future<void> _fetchMessages({bool isSilent = false}) async {
    if (_customerPhone == null || _customerPhone!.isEmpty) return;

    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      final uri = Uri.parse(
        "$chatApiUrl?action=get_messages&user_phone=$_customerPhone&user_type=customer&reader=customer"
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List rawList = data['messages'] ?? [];
          final newMessages = rawList.map((m) => Map<String, dynamic>.from(m)).toList();

          setState(() {
            _messages = newMessages;
            _isLoading = false;
          });

          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error fetching support messages: $e");
      if (!isSilent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _messageController.text).trim();
    if (text.isEmpty || _customerPhone == null || _isSending) return;

    if (presetText == null) {
      _messageController.clear();
    }

    setState(() => _isSending = true);

    try {
      final bodyData = {
        'user_type': 'customer',
        'user_phone': _customerPhone,
        'sender_type': 'customer',
        'sender_name': _customerName ?? 'Customer',
        'message': text,
      };

      final response = await http.post(
        Uri.parse("$chatApiUrl?action=send_message"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(bodyData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            _messages.add(Map<String, dynamic>.from(data['data']));
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showPhoneInputDialog() {
    final phoneInputCtrl = TextEditingController();
    final nameInputCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.support_agent, color: Color(0xFFFF8F00)),
            const SizedBox(width: 8),
            Text(
              "Rentox Support",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Please provide your mobile number so our travel desk can assist you.",
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameInputCtrl,
              decoration: InputDecoration(
                labelText: "Your Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneInputCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Mobile Number *",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8F00),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final p = phoneInputCtrl.text.trim();
              final n = nameInputCtrl.text.trim();
              if (p.length >= 10) {
                await _storage.write(key: 'phoneNumber', value: p);
                if (n.isNotEmpty) await _storage.write(key: 'userName', value: n);
                Navigator.pop(ctx);
                setState(() {
                  _customerPhone = p;
                  _customerName = n.isNotEmpty ? n : "Passenger";
                });
                _fetchMessages();
                _startPolling();
              }
            },
            child: const Text("Start Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E232F),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFF8F00).withOpacity(0.2),
              child: const Icon(Icons.headset_mic, color: Color(0xFFFF8F00), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Rentox Customer Care",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Online • 24/7 Travel Desk",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => _fetchMessages(),
          ),
        ],
      ),
      body: _customerPhone == null || _customerPhone!.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent, size: 64, color: Colors.amber[700]),
                    const SizedBox(height: 16),
                    Text(
                      "24/7 Rentox Customer Support",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Connect directly with our operations team to get answers about fares, cab tracking, and trip bookings.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8F00),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text(
                        "Start Conversation",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showPhoneInputDialog,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFFFFFBEB),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Booking queries, cab tracking, and 24/7 driver coordination.",
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat Messages Feed
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8F00)))
                      : _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 10),
                                  Text(
                                    "How can our team help you today?",
                                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMe = msg['sender_type'] == 'customer';
                                final timeStr = (msg['created_at'] ?? '').toString();
                                final displayTime = timeStr.contains(' ')
                                    ? timeStr.split(' ')[1].substring(0, 5)
                                    : '';

                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe ? const Color(0xFF1E232F) : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(14),
                                        topRight: const Radius.circular(14),
                                        bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(2),
                                        bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(14),
                                      ),
                                      border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              "Rentox Support",
                                              style: GoogleFonts.inter(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFFFF8F00),
                                              ),
                                            ),
                                          ),
                                        Text(
                                          msg['message'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            color: isMe ? Colors.white : const Color(0xFF1E293B),
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayTime,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: isMe ? Colors.white60 : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // Quick Question Suggestion Chips
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickQuestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      return ActionChip(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        label: Text(
                          _quickQuestions[idx],
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
                        ),
                        onPressed: () => _sendMessage(_quickQuestions[idx]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Bottom Message Input Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: "Ask a question...",
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isSending ? null : () => _sendMessage(),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF8F00),
                              shape: BoxShape.circle,
                            ),
                            child: _isSending
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.send, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
