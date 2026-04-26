import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';

class SquadChatSheet extends StatefulWidget {
  final int bulkRequestId;
  
  const SquadChatSheet({super.key, required this.bulkRequestId});

  @override
  State<SquadChatSheet> createState() => _SquadChatSheetState();
}

class _SquadChatSheetState extends State<SquadChatSheet> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    final messages = await _apiClient.getSquadMessages(widget.bulkRequestId);
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    
    // Optimistic UI update (shows the message instantly while sending to backend)
    final tempMessage = {
      "id": 99999, 
      "sender_name": "You", 
      "message": text, 
      "is_me": true,
    };
    
    setState(() {
      _messages.add(tempMessage);
      _messageController.clear();
    });
    _scrollToBottom();

    // Send to backend
    final error = await _apiClient.sendSquadMessage(widget.bulkRequestId, text);
    
    if (error == null) {
      // Silently refresh to get the real DB ID and timestamp
      _fetchMessages(); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
    
    if (mounted) setState(() => _isSending = false);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Takes up 75% of screen
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // 🔥 HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Squad Logistics Chat", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text("Coordinate your drop-off here", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),

          // 🔥 CHAT MESSAGES
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _messages.isEmpty
                    ? Center(child: Text("No messages yet.\nStart coordinating!", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey.shade400)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['is_me'] == true;

                          return FadeInUp(
                            duration: const Duration(milliseconds: 200),
                            child: Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe) ...[
                                      Text(msg['sender_name'], style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isMe ? Colors.green.shade600 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(isMe ? 16 : 0),
                                          bottomRight: Radius.circular(isMe ? 0 : 16),
                                        ),
                                      ),
                                      child: Text(
                                        msg['message'],
                                        style: GoogleFonts.poppins(color: isMe ? Colors.white : Colors.black87, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 🔥 INPUT FIELD
          Container(
            padding: EdgeInsets.only(left: 20, right: 20, top: 15, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 15, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle),
                    child: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}