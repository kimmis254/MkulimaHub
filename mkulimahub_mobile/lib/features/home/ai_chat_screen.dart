import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  
  // 🔥 ROLE & INVISIBLE CONTEXT STATE
  bool _isBuyer = false;
  bool _isLoadingRole = true;
  String _userName = "User";
  String _location = "Kenya";
  String _businessDetails = "Agriculture";

  // 🔥 "TAP, DON'T TYPE" CHIPS
  final List<String> _buyerChips = [
    "📉 Predict Maize price trends",
    "🚚 Transport costs to Nairobi",
    "🌾 Who is harvesting Potatoes?",
  ];

  final List<String> _farmerChips = [
    "⛅ Today's Weather",
    "🐛 My leaves have yellow spots",
    "💰 Current price of beans",
  ];

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndInitialize();
  }

  Future<void> _loadUserRoleAndInitialize() async {
    final role = await _apiClient.getUserRole();
    final profile = await _apiClient.getProfile(); // Fetch the invisible context!
    
    setState(() {
      _isBuyer = (role == 'buyer');
      
      // Silently store the context to send to the backend later
      if (profile != null) {
        _userName = profile['full_name'] ?? "User";
        _location = profile['county'] ?? "Kenya";
        _businessDetails = _isBuyer ? (profile['bio'] ?? "Procurement") : (profile['main_crops'] ?? "Farming");
      }
      
      if (_isBuyer) {
        _messages.add({
          "sender": "ai", 
          "text": "Hello, $_userName! I am your Market Intel Assistant 📊. I analyze live market prices, supply trends, and harvest seasons across $_location. What are you looking to source today?"
        });
      } else {
        _messages.add({
          "sender": "ai", 
          "text": "Jambo $_userName! I am MkulimaBot 🌱. I use Live Weather, ML Models, and Agronomy databases to help you farm better in $_location. What's on your mind today?"
        });
      }
      
      _isLoadingRole = false;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent, 
          duration: const Duration(milliseconds: 300), 
          curve: Curves.easeOut
        );
      });
    }
  }

  Future<void> _sendMessage([String? predefinedText]) async {
    final text = predefinedText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _isTyping = true;
    });
    
    _controller.clear();
    _scrollToBottom();

    // 🔥 SENDING THE INVISIBLE CONTEXT
    final response = await _apiClient.askAdvancedAI(
      message: text,
      role: _isBuyer ? "buyer" : "farmer",
      userName: _userName,
      location: _location,
      businessDetails: _businessDetails,
    );

    if (mounted) {
      setState(() {
        _messages.add({"sender": "ai", "text": response});
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Color primaryColor = _isBuyer ? Colors.teal.shade800 : Colors.green.shade800;
    final Color lightColor = _isBuyer ? Colors.teal.shade50 : Colors.green.shade50;
    final Color gradientEnd = _isBuyer ? Colors.teal.shade500 : Colors.green.shade500;
    final String botName = _isBuyer ? "Market Intel" : "MkulimaBot";
    final String botStatus = _isBuyer ? "Online • Procurement AI" : "Online • AI Agronomist";
    final String inputHint = _isBuyer ? "Ask about prices, supply hubs..." : "Ask about weather, pests...";
    final List<String> activeChips = _isBuyer ? _buyerChips : _farmerChips;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: IconButton(icon: const Icon(LucideIcons.arrowLeft, color: Colors.white), onPressed: () => Navigator.pop(context)),
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8), 
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), 
                  child: Icon(_isBuyer ? LucideIcons.barChart2 : LucideIcons.bot, color: Colors.white, size: 22)
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(botName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.lightGreenAccent, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(botStatus, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'user';
                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildPremiumBubble(msg['text']!, isMe, primaryColor, lightColor)
                );
              },
            ),
          ),
          
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Pulse(
                      infinite: true,
                      child: CircleAvatar(backgroundColor: lightColor, radius: 12, child: Icon(LucideIcons.bot, size: 14, color: primaryColor))
                    ),
                    const SizedBox(width: 10),
                    Text("$botName is analyzing...", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            
          // 🔥 SUGGESTION CHIPS (Tap, Don't Type)
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: activeChips.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: primaryColor.withOpacity(0.3)),
                    label: Text(activeChips[index], style: GoogleFonts.poppins(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w500)),
                    onPressed: () => _sendMessage(activeChips[index]), // Instantly sends the message!
                  ),
                );
              },
            ),
          ),
            
          // 🔥 Premium Floating Input Area
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                border: Border.all(color: Colors.grey.shade200)
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null, 
                      keyboardType: TextInputType.multiline,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: inputHint,
                        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isTyping ? null : () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [gradientEnd, primaryColor]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                      ),
                      child: const Icon(LucideIcons.send, color: Colors.white, size: 18),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPremiumBubble(String text, bool isMe, Color primaryColor, Color lightColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(backgroundColor: lightColor, radius: 16, child: Icon(_isBuyer ? LucideIcons.barChart2 : LucideIcons.bot, size: 18, color: primaryColor)),
            const SizedBox(width: 10),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isMe ? primaryColor : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                border: isMe ? null : Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 20),
                )
              ),
              child: Text(
                text, 
                style: GoogleFonts.poppins(
                  fontSize: 14, 
                  color: isMe ? Colors.white : Colors.black87, 
                  height: 1.5 
                )
              ),
            )
          ),
          
          if (!isMe) const SizedBox(width: 40),
        ],
      ),
    );
  }
}