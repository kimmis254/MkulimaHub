import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mkulimahub_mobile/features/home/squad_chat_screen.dart';
import 'package:mkulimahub_mobile/features/home/unattended_dropoff_screen.dart';
import 'package:mkulimahub_mobile/features/home/receiving_dashboard.dart';

class DeliverySquadsScreen extends StatefulWidget {
  final int? targetSquadId;
  const DeliverySquadsScreen({super.key, this.targetSquadId});

  @override
  State<DeliverySquadsScreen> createState() => _DeliverySquadsScreenState();
}

class _DeliverySquadsScreenState extends State<DeliverySquadsScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _myPledges = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadMyPledges();
  }

  Future<void> _loadMyPledges() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([_apiClient.getMyPledges(), _apiClient.getProfile()]);
    if (mounted) {
      setState(() {
        _myPledges = (results[0] as List<dynamic>?) ?? [];
        _currentUserId = (results[1] as Map<String, dynamic>?)?['id'];
        _isLoading = false;
      });
    }
  }

  void _showVotingSheet(Map<String, dynamic> bulkRequest) {
    showModalBottomSheet(
        context: context, backgroundColor: Colors.white, isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          bool isSubmitting = false;
          final pitchController = TextEditingController();
          List candidates = bulkRequest['candidates'] ?? [];
          bool hasVoted = bulkRequest['has_voted'] ?? false;
          bool iAmRunning = candidates.any((c) => c['farmer_id'] == _currentUserId);

          return StatefulBuilder(
              builder: (context, setSheetState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 20),
                        Text("Squad Election", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text("Who should lead this delivery? The Coordinator handles the truck and receives the goods at the hub.", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                        const SizedBox(height: 20),
                        if (candidates.isEmpty)
                          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)), child: Text("No candidates yet. Step up and lead!", style: GoogleFonts.poppins(color: Colors.purple.shade800)))
                        else ...[
                          Text("Candidates on the Ballot:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ...candidates.map((c) => Container(
                            margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c['farmer_name'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('"${c['pitch']}"', style: GoogleFonts.poppins(color: Colors.grey.shade600, fontStyle: FontStyle.italic, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text("${c['votes']} Votes", style: GoogleFonts.poppins(color: Colors.purple.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                                ])),
                                if (!hasVoted && c['farmer_id'] != _currentUserId)
                                  ElevatedButton(
                                    onPressed: () async {
                                      final error = await _apiClient.castSquadVote(bulkRequest['id'], c['candidate_id']);
                                      if (mounted) {
                                        Navigator.pop(context);
                                        if (error == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote cast successfully!"), backgroundColor: Colors.green));
                                          _loadMyPledges();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    child: Text("Vote", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  )
                              ],
                            ),
                          )).toList()
                        ],
                        const SizedBox(height: 20),
                        if (!iAmRunning) ...[
                          const Divider(), const SizedBox(height: 10),
                          Text("Want to lead?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          TextField(controller: pitchController, maxLines: 2, decoration: InputDecoration(hintText: "Why should you lead? (e.g., I have a Probox ready...)", filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : () async {
                                if (pitchController.text.isEmpty) return;
                                setSheetState(() => isSubmitting = true);
                                final error = await _apiClient.runForSquadCoordinator(bulkRequest['id'], pitchController.text.trim());
                                if (mounted) {
                                  Navigator.pop(context);
                                  if (error == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are on the ballot!"), backgroundColor: Colors.green));
                                    _loadMyPledges();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("Submit Candidacy", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ] else if (candidates.isNotEmpty) ...[
                          Center(child: Padding(padding: const EdgeInsets.only(top: 10), child: Text("You are running in this election! Good luck.", style: GoogleFonts.poppins(color: Colors.green.shade700, fontWeight: FontWeight.bold))))
                        ]
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildPremiumButton({required String title, required IconData icon, required List<Color> gradientColors, VoidCallback? onTap, bool isPulsing = false}) {
    Widget button = Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: gradientColors.last.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
    if (onTap != null) button = GestureDetector(onTap: onTap, child: button);
    if (isPulsing) return Pulse(infinite: true, child: button);
    return button;
  }

  Widget _buildTimeline(String status, bool isCoordinator, bool isPickup) {
    int currentStep = 0;
    if (status == 'active') currentStep = 1;
    if (status == 'in_transit') currentStep = 2;
    if (status == 'delivered') currentStep = 3;

    return Row(
      children: [
        _buildTimelineStep("Gather", currentStep >= 0, isFirst: true),
        _buildTimelineLine(currentStep >= 1),
        _buildTimelineStep(isPickup ? "Wait" : "Transit", currentStep >= 1),
        _buildTimelineLine(currentStep >= 2),
        _buildTimelineStep(isPickup ? "Pickup" : "Arrive", currentStep >= 2),
        _buildTimelineLine(currentStep >= 3),
        _buildTimelineStep("Paid", currentStep >= 3, isLast: true),
      ],
    );
  }

  Widget _buildTimelineStep(String label, bool isActive, {bool isFirst = false, bool isLast = false}) {
    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(color: isActive ? Colors.teal.shade600 : Colors.grey.shade300, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          child: isActive ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: isActive ? Colors.teal.shade800 : Colors.grey.shade500, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildTimelineLine(bool isActive) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16), height: 3,
        color: isActive ? Colors.teal.shade600 : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: Colors.teal.shade900), onPressed: () => Navigator.pop(context)),
        title: Text("Squad Tracker", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true,
        actions: [
          if (widget.targetSquadId == null)
            IconButton(icon: const Icon(LucideIcons.refreshCcw, color: Colors.teal), onPressed: _loadMyPledges)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _myPledges.isEmpty
          ? Center(child: Text("No delivery squads found.", style: GoogleFonts.poppins(color: Colors.grey)))
          : RefreshIndicator(
        onRefresh: _loadMyPledges,
        child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _myPledges.length,
            itemBuilder: (context, index) {
              final pledge = _myPledges[index];
              final bulkRequest = pledge['bulk_request'];
              if (widget.targetSquadId != null && bulkRequest['id'] != widget.targetSquadId) return const SizedBox.shrink();

              String squadStatus = bulkRequest['squad_status'] ?? 'gathering';
              bool isCoordinator = bulkRequest['coordinator_id'] == _currentUserId;
              bool isPool = bulkRequest['buyer_name'].startsWith("Hub Pool:");

              // 🔥 PAYMENT & PICKUP STATE
              bool isPaymentSecured = bulkRequest['payment_status'] == 'deposit_paid' || bulkRequest['payment_status'] == 'fully_paid_escrow' || bulkRequest['payment_status'] == 'fully_paid';
              bool isPickup = bulkRequest['delivery_method']?.contains("Pickup") ?? false;

              return FadeInUp(
                delay: Duration(milliseconds: index * 100),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.teal.shade100, width: 1.5), boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                        child: Row(
                          children: [
                            Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(LucideIcons.users, color: Colors.teal.shade700)),
                            const SizedBox(width: 15),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isPool ? "Co-op Internal Hub" : "Corporate Contract", style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(isPool ? bulkRequest['buyer_name'].replaceFirst('Hub Pool: ', '') : bulkRequest['buyer_name'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ])),
                            IconButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadChatScreen(squadId: bulkRequest['id'], squadName: bulkRequest['crop_name']))),
                              icon: const Icon(LucideIcons.messageCircle), color: Colors.teal.shade700,
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTimeline(squadStatus, isCoordinator, isPickup),
                            const SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("My Contribution", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)), Text("${pledge['pledged_weight_kg']} KG", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900))]),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Squad Target", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)), Text("${bulkRequest['target_weight_kg']} KG", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900))]),
                              ],
                            ),
                            const Divider(height: 30),

                            // 🔥 ACTION PANEL
                            Container(
                              padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Your Action Required", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                                  const SizedBox(height: 10),

                                  if (squadStatus == 'gathering')
                                    _buildPremiumButton(title: "Waiting for more farmers...", icon: LucideIcons.users, gradientColors: [Colors.grey.shade300, Colors.grey.shade400], onTap: null)

                                  else if (squadStatus == 'voting')
                                    _buildPremiumButton(title: "Elect Squad Coordinator", icon: LucideIcons.vote, gradientColors: [Colors.purple.shade400, Colors.deepPurple.shade700], onTap: () => _showVotingSheet(bulkRequest), isPulsing: true)

                                  else if (squadStatus == 'active' || squadStatus == 'in_transit' || squadStatus == 'delivered') ...[
                                      if (!isPaymentSecured)
                                        _buildPremiumButton(title: "Awaiting Buyer Payment...", icon: LucideIcons.lock, gradientColors: [Colors.orange.shade400, Colors.orange.shade700], onTap: null)
                                      else ...[
                                        if (pledge['status'] == 'pledged' || pledge['status'] == 'rejected')
                                          _buildPremiumButton(
                                              title: "Proceed to Digital Drop-off", icon: LucideIcons.box, gradientColors: [Colors.teal.shade400, Colors.teal.shade700],
                                              onTap: () async {
                                                await Navigator.push(context, MaterialPageRoute(builder: (_) => UnattendedDropoffScreen(squadId: bulkRequest['id'], cropName: bulkRequest['crop_name'] ?? 'Produce')));
                                                _loadMyPledges();
                                              }, isPulsing: true
                                          )
                                        else if (pledge['status'] == 'pending_audit')
                                          _buildPremiumButton(title: "Drop-off under audit...", icon: LucideIcons.loader, gradientColors: [Colors.orange.shade400, Colors.orange.shade700], onTap: null)
                                        else if (pledge['status'] == 'paid' || pledge['status'] == 'completed')
                                            _buildPremiumButton(title: "Payment Received ✅", icon: LucideIcons.checkCircle, gradientColors: [Colors.green.shade400, Colors.green.shade700], onTap: null)
                                          else
                                            _buildPremiumButton(title: "Drop-off Verified ✅", icon: LucideIcons.checkCircle, gradientColors: [Colors.green.shade400, Colors.green.shade700], onTap: null),

                                        if (isCoordinator) ...[
                                          const SizedBox(height: 15),
                                          const Divider(),
                                          const SizedBox(height: 10),
                                          Text("Coordinator Controls", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                          const SizedBox(height: 10),

                                          if (isPickup)
                                            _buildPremiumButton(title: "Awaiting Buyer Pickup 📍", icon: LucideIcons.mapPin, gradientColors: [Colors.blue.shade300, Colors.blue.shade500], onTap: null)
                                          else ...[
                                            if (squadStatus == 'active')
                                              _buildPremiumButton(title: "Start Delivery Transit", icon: LucideIcons.truck, gradientColors: [Colors.blue.shade400, Colors.blue.shade700], onTap: () async {
                                                final error = await _apiClient.updateSquadDeliveryStatus(bulkRequest['id'], 'in_transit');
                                                if (error == null) _loadMyPledges();
                                              })
                                            else if (squadStatus == 'in_transit')
                                              _buildPremiumButton(title: "Mark as Arrived", icon: LucideIcons.mapPin, gradientColors: [Colors.indigo.shade400, Colors.indigo.shade700], onTap: () async {
                                                final error = await _apiClient.updateSquadDeliveryStatus(bulkRequest['id'], 'delivered');
                                                if (error == null) _loadMyPledges();
                                              })
                                            else
                                              _buildPremiumButton(title: "Waiting for Buyer QA...", icon: LucideIcons.loader, gradientColors: [Colors.orange.shade400, Colors.orange.shade700], onTap: null)
                                          ]
                                        ]
                                      ]
                                    ]
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
        ),
      ),
    );
  }
}