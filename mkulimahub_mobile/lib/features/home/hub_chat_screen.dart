import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart'; 

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

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    if (_myFullName == null) {
      final profile = await _apiClient.getProfile();
      _myFullName = profile?['full_name'] ?? '';
    }

    final data = await _apiClient.getHubMessages(widget.hubName);
    setState(() {
      _messages = data;
      _isLoading = false;
    });
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    
    final error = await _apiClient.postHubMessage(widget.hubName, text);
    
    if (error == null) {
      _messageController.clear();
      await _fetchMessages(); 
    } else {
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
                    TextField(
                      controller: cropController,
                      decoration: InputDecoration(
                        labelText: "Crop Name (e.g., Mangoes)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(LucideIcons.sprout, color: Colors.green),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Total Pooled Weight (KG)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(LucideIcons.scale, color: Colors.green),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Asking Price per KG (KES)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(LucideIcons.banknote, color: Colors.green),
                      ),
                    ),
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
                      
                      marketplaceKey.currentState?.loadHarvests();
                      
                      await _apiClient.postHubMessage(
                        widget.hubName, 
                        "🎉 I just created a Joint Listing for ${weightController.text}kg of ${cropController.text} at KES ${priceController.text}/kg! It is now live on the marketplace."
                      );
                      await _fetchMessages();
                      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        elevation: 0,
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
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white, size: 20),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchMessages();
            },
          )
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
                        padding: const EdgeInsets.all(20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderName = msg['sender_name'] ?? 'Unknown';
                          final isMe = senderName == _myFullName;
                          return _buildMessageBubble(senderName, msg['message'], isMe);
                        },
                      ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green[800], shape: BoxShape.circle),
                    child: _isSending 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(LucideIcons.send, color: Colors.white, size: 20),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String senderName, String message, bool isMe) {
    bool isSystemMessage = message.startsWith("🎉 I just created a Joint Listing");

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4, right: 12),
              child: Text(senderName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            ),
          
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSystemMessage ? Colors.blue[50] : (isMe ? Colors.green[100] : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                ),
                border: Border.all(color: isSystemMessage ? Colors.blue[200]! : (isMe ? Colors.green[200]! : Colors.grey[200]!)),
              ),
              child: Text(message, style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }
}