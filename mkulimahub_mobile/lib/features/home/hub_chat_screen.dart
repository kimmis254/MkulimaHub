import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:mkulimahub_mobile/features/home/home_screen.dart'; 
import 'package:intl/intl.dart'; 

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
  
  Timer? _refreshTimer; 

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    
    // Poll for new messages silently every 5 seconds
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

  // 🔥 PREMIUM CENTER-SCREEN TOAST
  void _showPremiumToast(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(isError ? LucideIcons.alertCircle : LucideIcons.checkCircle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message, 
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)
                )
              ),
            ],
          ),
        ),
        backgroundColor: isError ? Colors.red.shade800 : Colors.teal.shade800,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.45,
          left: 24,
          right: 24,
        ),
        elevation: 15,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
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
        _messages = data ?? []; 
        if (!silent) _isLoading = false;
      });
      
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
    
    // Optimistic UI update
    final optimisticMsg = {
      'sender_name': _myFullName,
      'message': text,
      'timestamp': DateTime.now().toIso8601String() 
    };
    
    setState(() {
      _messages.add(optimisticMsg);
      _messageController.clear();
    });
    _scrollToBottom();
    
    final error = await _apiClient.postHubMessage(widget.hubName, text);
    
    if (error != null) {
      setState(() => _messages.removeLast());
      if (mounted) _showPremiumToast(context, error, isError: true);
    }
    
    setState(() => _isSending = false);
  }

  Future<void> _leaveHub() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.logOut, color: Colors.red.shade600),
            const SizedBox(width: 10),
            Text("Leave Co-op?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text("Are you sure you want to leave ${widget.hubName}? You will stop receiving messages and updates.", style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey.shade600))
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); 
              setState(() => _isLoading = true);
              
              final error = await _apiClient.leaveHub();
              
              if (mounted) {
                if (error == null) {
                  _showPremiumToast(context, "Left Co-op successfully.");
                  Navigator.pop(context, true); 
                } else {
                  setState(() => _isLoading = false);
                  _showPremiumToast(context, error, isError: true);
                }
              }
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, elevation: 0),
            child: Text("Leave", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );
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
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24), // 🔥 Prevents edge-to-edge stretching
              child: SingleChildScrollView( // 🔥 Prevents keyboard overflow
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                      child: Icon(LucideIcons.store, color: Colors.blue.shade700, size: 32),
                    ),
                    const SizedBox(height: 15),
                    Text("Create Joint Listing", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    // 🔥 Fixed RenderFlex Issue
                    Text(
                      "Push your pooled crops to buyers", 
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]), 
                      textAlign: TextAlign.center,
                      softWrap: true, // Allows wrapping
                    ),
                    const SizedBox(height: 25),
                    
                    _buildPremiumDialogField(controller: cropController, label: "Crop Name (e.g., Mangoes)", icon: LucideIcons.sprout),
                    const SizedBox(height: 15),
                    _buildPremiumDialogField(controller: weightController, label: "Total Weight (KG)", icon: LucideIcons.scale, isNumber: true),
                    const SizedBox(height: 15),
                    _buildPremiumDialogField(controller: priceController, label: "Price per KG (KES)", icon: LucideIcons.banknote, isNumber: true),
                    
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : () async {
                              if (cropController.text.isEmpty || weightController.text.isEmpty || priceController.text.isEmpty) {
                                _showPremiumToast(context, "Please fill all fields", isError: true);
                                return;
                              }

                              setDialogState(() => isSubmitting = true);
                              
                              final data = {
                                "crop_name": cropController.text.trim(),
                                "target_weight_kg": double.tryParse(weightController.text) ?? 0.0,
                                "price_per_kg": double.tryParse(priceController.text) ?? 0.0,
                              };

                              // 🔥 USE THE NEW HUB POOL ENDPOINT!
                              final error = await _apiClient.createHubPool(widget.hubName, data);
                              
                              if (error == null && context.mounted) {
                                Navigator.pop(context); 
                                await _fetchMessages(silent: true);
                                _scrollToBottom();
                                _showPremiumToast(context, "Joint Listing Published!");
                              } else if (context.mounted) {
                                setDialogState(() => isSubmitting = false);
                                _showPremiumToast(context, error ?? "Error saving listing.", isError: true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.blue.shade700, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0
                            ),
                            child: isSubmitting 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text("Publish", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildPremiumDialogField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  String _formatTime(String? isoTimestamp) {
    if (isoTimestamp == null) return "";
    try {
      final date = DateTime.parse(isoTimestamp).toLocal();
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return "";
    }
  }
  Widget _buildInteractivePoolCard(String payload, String? timestamp) {
    // Payload format: POOL_REQ|contract_id|crop|target|price|total_pledged|status
    final parts = payload.split('|');
    if (parts.length < 5) return const SizedBox.shrink();

    final contractId = int.tryParse(parts[1]) ?? 0;
    final crop = parts[2];
    final target = double.tryParse(parts[3]) ?? 1.0;
    final price = parts[4];

    // 🔥 Extract the dynamic data from Python (Default to 0 if it's an old message)
    final currentPledged = parts.length > 5 ? (double.tryParse(parts[5]) ?? 0.0) : 0.0;
    final status = parts.length > 6 ? parts[6] : "Open";

    // Logic Checks
    final isFulfilled = status.toLowerCase() == 'fulfilled' || currentPledged >= target;
    double progress = currentPledged / target;
    if (progress > 1.0) progress = 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isFulfilled ? Colors.green.shade200 : Colors.orange.shade200, width: 2),
        boxShadow: [BoxShadow(color: isFulfilled ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: isFulfilled ? Colors.green.shade50 : Colors.orange.shade100, shape: BoxShape.circle),
                    child: Icon(isFulfilled ? LucideIcons.checkCircle : LucideIcons.store, color: isFulfilled ? Colors.green.shade700 : Colors.orange.shade800, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Co-op Aggregation Goal", style: GoogleFonts.poppins(fontSize: 12, color: isFulfilled ? Colors.green.shade700 : Colors.orange.shade800, fontWeight: FontWeight.bold)),
                      Text(crop, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                    ],
                  ),
                ],
              ),
              // 🔥 DYNAMIC BADGE
              if (isFulfilled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text("100% FULL", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                )
            ],
          ),
          const SizedBox(height: 15),

          // 🔥 LIVE PROGRESS BAR
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Pool Progress", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                  Text("${currentPledged.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} KG", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: isFulfilled ? Colors.green.shade700 : Colors.orange.shade700)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade100,
                  color: isFulfilled ? Colors.green.shade500 : Colors.orange.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Target Weight", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                    Text("${target.toStringAsFixed(0)}kg", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Target Price", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                    Text("KES $price / kg", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green.shade700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          
          // 🔥 DYNAMIC LOCKING BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isFulfilled ? null : () => _showPledgeDialog(contractId, crop, target - currentPledged),
              icon: Icon(isFulfilled ? LucideIcons.lock : LucideIcons.plus, color: isFulfilled ? Colors.grey.shade500 : Colors.white, size: 18),
              label: Text(isFulfilled ? "Goal Reached" : "Pledge Produce", style: GoogleFonts.poppins(color: isFulfilled ? Colors.grey.shade500 : Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFulfilled ? Colors.grey.shade200 : Colors.orange.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showPledgeDialog(int contractId, String crop, double remainingAmount) {
    final weightController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Pledge $crop", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("How many kilograms are you committing to this Hub Pool?", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text("Maximum allowed: ${remainingAmount.toStringAsFixed(0)} KG", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                const SizedBox(height: 15),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: "E.g., 50",
                    suffixText: "KG",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final weight = double.tryParse(weightController.text.trim());
                  if (weight == null || weight <= 0) return;
                  
                  if (weight > remainingAmount) {
                     _showPremiumToast(context, "Cannot exceed remaining amount of ${remainingAmount.toStringAsFixed(0)}kg", isError: true);
                     return;
                  }

                  setDialogState(() => isSubmitting = true);
                  
                  final error = await _apiClient.createPledge(contractId, weight);
                  
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (error == null) {
                      _showPremiumToast(context, "Pledge added successfully!");
                      _fetchMessages(silent: true); // 🔥 Refresh the chat to update the progress bar instantly!
                    } else {
                      _showPremiumToast(context, error, isError: true);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: isSubmitting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Confirm Pledge"),
              )
            ],
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, 
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Colors.green.shade800,
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
                  child: const Icon(LucideIcons.users, color: Colors.white, size: 20)
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.hubName, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.lightGreenAccent, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text("Digital Co-op • Live", style: GoogleFonts.poppins(color: Colors.green.shade200, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Icon(LucideIcons.store, color: Colors.green.shade800, size: 20)
                ),
                tooltip: "Create Joint Listing",
                onPressed: _showJointListingDialog,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10.0, right: 8.0),
              child: PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreVertical, color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (value) {
                  if (value == 'leave') _leaveHub();
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(LucideIcons.logOut, color: Colors.red.shade600, size: 18),
                        const SizedBox(width: 10),
                        Text("Leave Co-op", style: GoogleFonts.poppins(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.messagesSquare, size: 50, color: Colors.grey.shade300),
                            const SizedBox(height: 15),
                            Text("Start the conversation!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 16)),
                            Text("Coordinate your harvests here.", style: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        )
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderName = msg['sender_name'] ?? 'Unknown';
                          final isMe = senderName == _myFullName;
                          
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
    if (message.startsWith("POOL_REQ|")) {
      return _buildInteractivePoolCard(message, timestamp);
    }

    bool isSystemMessage = message.startsWith("🎉 NEW JOINT LISTING");
    final timeString = _formatTime(timestamp);

    if (isSystemMessage) return _buildSystemMessage(message, timeString);

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 20 : 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) 
            SizedBox(
              width: 32, 
              child: showAvatar 
                ? CircleAvatar(radius: 16, backgroundColor: Colors.green.shade100, child: Text(senderName[0].toUpperCase(), style: TextStyle(fontSize: 14, color: Colors.green.shade800, fontWeight: FontWeight.bold)))
                : null
            ),
          
          if (!isMe) const SizedBox(width: 10),

          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(senderName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                ),
              
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isMe ? Colors.green.shade800 : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : (showAvatar ? Radius.zero : const Radius.circular(20)),
                    bottomRight: isMe ? (showAvatar ? Radius.zero : const Radius.circular(20)) : const Radius.circular(20),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  border: isMe ? null : Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  message, 
                  style: GoogleFonts.poppins(fontSize: 14, color: isMe ? Colors.white : Colors.black87, height: 1.4)
                ),
              ),
              
              if (timeString.isNotEmpty && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                  child: Text(timeString, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String message, String timeString) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade800], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(LucideIcons.megaphone, size: 16, color: Colors.white)),
              const SizedBox(width: 10),
              Text("HUB ANNOUNCEMENT", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: Colors.white, height: 1.5)),
          const SizedBox(height: 12),
          Text(timeString, style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue.shade100)),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.grey.shade50.withOpacity(0.0), Colors.grey.shade50, Colors.grey.shade50]
        )
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
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null, 
                keyboardType: TextInputType.multiline,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Message the Co-op...",
                  // 🔥 Removed the accidental spaces here!
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade500, Colors.green.shade700]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                ),
                child: _isSending 
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.send, color: Colors.white, size: 18),
              ),
            )
          ],
        ),
      ),
    );
  }
}