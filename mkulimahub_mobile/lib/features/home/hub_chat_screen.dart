import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart'; 
import 'package:intl/intl.dart'; // 🔥 Ensure you add 'intl: ^0.19.0' to pubspec.yaml

class HubChatScreen extends StatefulWidget {
  final String hubName;
  const HubChatScreen({super.key, required this.hubName});

  @override
  State<HubChatScreen> createState() => _HubChatScreenState();
}

class _HubChatScreenState extends State<HubChatScreen> {
  final ApiClient _apiClient = ApiClient();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  String? _myFullName; 
  bool _isLoading = true;
  bool _isSending = false;
  
  Timer? _refreshTimer; // 🔥 For real-time updates

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    
    // 🔥 Start polling for new messages every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final profile = await _apiClient.getProfile();
    _myFullName = profile?['full_name'] ?? '';
    await _fetchMessages(silent: false);
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    
    final data = await _apiClient.getHubMessages(widget.hubName);
    
    if (mounted) {
      setState(() {
        _messages = data ?? []; // Ensure we don't pass null
        if (!silent) _isLoading = false;
      });
      
      // Only scroll to bottom on initial load or if we are already near the bottom
      if (!silent) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    
    // Optimistic UI update: Add message locally immediately for snappy feel
    final optimisticMsg = {
      'sender_name': _myFullName,
      'message': text,
      'timestamp': DateTime.now().toIso8601String() // Assuming backend uses standard ISO strings
    };
    
    setState(() {
      _messages.add(optimisticMsg);
      _messageController.clear();
    });
    _scrollToBottom();
    
    // Actually send to backend
    final error = await _apiClient.postHubMessage(widget.hubName, text);
    
    if (error != null) {
      // Revert optimistic update if it failed
      setState(() {
         _messages.removeLast();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
    
    setState(() => _isSending = false);
  }

  void _showJointListingDialog() {
    final cropController = TextEditingController();
    final weightController = TextEditingController();
    final priceController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                    child: const Icon(LucideIcons.store, color: Colors.blue, size: 30),
                  ),
                  const SizedBox(height: 10),
                  Text("Create Joint Listing", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Push your pooled crops to buyers", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogField(controller: cropController, label: "Crop Name (e.g., Mangoes)", icon: LucideIcons.sprout),
                    const SizedBox(height: 15),
                    _buildDialogField(controller: weightController, label: "Total Pooled Weight (KG)", icon: LucideIcons.scale, isNumber: true),
                    const SizedBox(height: 15),
                    _buildDialogField(controller: priceController, label: "Asking Price per KG (KES)", icon: LucideIcons.banknote, isNumber: true),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (cropController.text.isEmpty || weightController.text.isEmpty || priceController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
                      return;
                    }

                    setDialogState(() => isSubmitting = true);
                    
                    final specialCropName = "${cropController.text.trim()} (${widget.hubName} Pool)";
                    final data = {
                      "crop_name": specialCropName,
                      "weight_kg": double.tryParse(weightController.text) ?? 0,
                      "price_per_kg": double.tryParse(priceController.text) ?? 0,
                    };

                    final error = await _apiClient.addHarvest(data);
                    
                    if (error == null && context.mounted) {
                      Navigator.pop(context); 
                      
                      // NOTE: Ensure marketplaceKey is correctly defined globally if you use this
                      marketplaceKey.currentState?.loadHarvests();
                      
                      await _apiClient.postHubMessage(
                        widget.hubName, 
                        "🎉 NEW JOINT LISTING\n\nWe just pooled ${weightController.text}kg of ${cropController.text} at KES ${priceController.text}/kg! It is now live on the marketplace."
                      );
                      await _fetchMessages(silent: true);
                      _scrollToBottom();
                      
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joint Listing Published!"), backgroundColor: Colors.green));
                    } else if (context.mounted) {
                      setDialogState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? "Error"), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("List on Market", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildDialogField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon, color: Colors.green),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }

  // Formats the timestamp nicely (e.g., "10:45 AM")
  String _formatTime(String? isoTimestamp) {
    if (isoTimestamp == null) return "";
    try {
      final date = DateTime.parse(isoTimestamp).toLocal();
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Slightly darker background for chat contrast
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        elevation: 2,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(widget.hubName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Digital Cooperative", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.store, color: Colors.white, size: 22),
            tooltip: "Create Joint Listing",
            onPressed: _showJointListingDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _messages.isEmpty
                    ? Center(child: Text("Start the conversation!\nCoordinate your harvests here.", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(15),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderName = msg['sender_name'] ?? 'Unknown';
                          final isMe = senderName == _myFullName;
                          
                          // Check if previous message is from same sender to group bubbles
                          bool showAvatar = true;
                          if (index > 0) {
                            final prevSender = _messages[index - 1]['sender_name'];
                            if (prevSender == senderName) showAvatar = false;
                          }

                          return _buildMessageBubble(senderName, msg['message'], msg['timestamp'], isMe, showAvatar);
                        },
                      ),
          ),
          
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String senderName, String message, String? timestamp, bool isMe, bool showAvatar) {
    bool isSystemMessage = message.startsWith("🎉 NEW JOINT LISTING");
    final timeString = _formatTime(timestamp);

    if (isSystemMessage) {
      return _buildSystemMessage(message, timeString);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 15 : 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) 
            SizedBox(
              width: 30, 
              child: showAvatar 
                ? CircleAvatar(radius: 14, backgroundColor: Colors.green[200], child: Text(senderName[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)))
                : null
            ),
          
          if (!isMe) const SizedBox(width: 8),

          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(senderName, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                ),
              
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? Colors.green[100] : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : (showAvatar ? Radius.zero : const Radius.circular(20)),
                    bottomRight: isMe ? (showAvatar ? Radius.zero : const Radius.circular(20)) : const Radius.circular(20),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2))],
                  border: Border.all(color: isMe ? Colors.green[200]! : Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
                  ],
                ),
              ),
              
              // Timestamp below the bubble
              if (timeString.isNotEmpty && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(timeString, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500])),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Special UI for Announcements
  Widget _buildSystemMessage(String message, String timeString) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.megaphone, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text("HUB ANNOUNCEMENT", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800])),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 6),
          Text(timeString, style: GoogleFonts.poppins(fontSize: 9, color: Colors.blue[300])),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 24), // Extra bottom padding for safe area
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null, // Allow expanding for multi-line messages
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: "Message the Co-op...",
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.green[800], shape: BoxShape.circle),
              child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(LucideIcons.send, color: Colors.white, size: 20),
            ),
          )
        ],
      ),
    );
  }
}