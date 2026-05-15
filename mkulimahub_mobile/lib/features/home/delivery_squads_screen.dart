import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mkulimahub_mobile/core/api_client.dart';
import 'package:animate_do/animate_do.dart';
import 'package:mkulimahub_mobile/features/home/squad_chat_screen.dart';
import 'package:mkulimahub_mobile/features/home/unattended_dropoff_screen.dart';
import 'package:mkulimahub_mobile/features/home/receiving_dashboard.dart';
import 'package:mkulimahub_mobile/features/home/order_tracking_map.dart';

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
        final data = results[0] as List<dynamic>? ?? [];
        final profile = results[1] as Map<String, dynamic>?;
        if (profile != null) _currentUserId = profile['id'];

        if (widget.targetSquadId != null) {
          _myPledges = data.where((p) => p['bulk_request'] != null && p['bulk_request']['id'] == widget.targetSquadId).toList();
        } else {
          _myPledges = data.where((p) {
            String s = p['status'] ?? 'unknown';
            return s != 'rejected' && s != 'refunded' && s != 'completed' && s != 'paid';
          }).toList();
        }
        _isLoading = false;
      });
    }
  }

  void _showVotingSheet(Map<String, dynamic> bulkRequest) {
    final TextEditingController pitchController = TextEditingController();
    bool isSubmitting = false;
    List<dynamic> candidates = bulkRequest['candidates'] ?? [];
    bool hasVoted = bulkRequest['has_voted'] ?? false;
    bool hasPitched = _currentUserId != null && candidates.any((c) => c['farmer_id'] == _currentUserId);

    showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle), child: const Icon(LucideIcons.vote, color: Colors.purple)),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Squad Election", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text("Elect a coordinator for ${bulkRequest['buyer_name']}.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (hasVoted)
                            Container(
                              padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text("You have securely cast your vote. Waiting for the winner...", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800))),
                                ],
                              ),
                            ),
                          if (candidates.isNotEmpty) ...[
                            Text("Current Candidates:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                            const SizedBox(height: 10),
                            ...candidates.map((c) => Container(
                              margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(border: Border.all(color: Colors.purple.shade100), borderRadius: BorderRadius.circular(16), color: Colors.purple.shade50.withOpacity(0.3)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(backgroundColor: Colors.purple.shade100, child: const Icon(LucideIcons.user, color: Colors.purple)),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c['farmer_name'] ?? 'Candidate', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text("${c['votes'] ?? 0} Votes Cast", style: GoogleFonts.poppins(color: Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      if (!hasVoted)
                                        ElevatedButton(
                                          onPressed: () async {
                                            final error = await _apiClient.castSquadVote(bulkRequest['id'], c['candidate_id']);
                                            if (mounted) {
                                              Navigator.pop(context);
                                              if (error == null) {
                                                _loadMyPledges();
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vote cast successfully!"), backgroundColor: Colors.green));
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                          child: const Text("Vote", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12), width: double.infinity,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                    child: Text('"${c['pitch'] ?? 'I will ensure safe delivery!'}"', style: GoogleFonts.poppins(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black87)),
                                  )
                                ],
                              ),
                            )).toList(),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.alertCircle, color: Colors.orange, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text("No candidates yet! First person to pitch gets a major advantage.", style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade800))),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 25),
                          if (!hasPitched) ...[
                            const Divider(),
                            const SizedBox(height: 10),
                            Text("Run for Coordinator", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: pitchController,
                              decoration: InputDecoration(
                                hintText: "E.g., I have a secure storehouse. Vote for me!",
                                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                filled: true, fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isSubmitting ? null : () async {
                                  if (pitchController.text.trim().isEmpty) return;
                                  setSheetState(() => isSubmitting = true);
                                  final error = await _apiClient.runForSquadCoordinator(bulkRequest['id'], pitchController.text.trim());
                                  if (mounted) {
                                    Navigator.pop(context);
                                    if (error == null) {
                                      _loadMyPledges();
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are on the ballot!"), backgroundColor: Colors.green));
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text("Submit Candidacy", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  Widget _buildPremiumButton({required String title, required IconData icon, required List<Color> gradientColors, required VoidCallback? onTap, bool isPulsing = false}) {
    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200), width: double.infinity,
      decoration: BoxDecoration(
          gradient: onTap == null ? null : LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: onTap == null ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap == null ? [] : [BoxShadow(color: gradientColors.last.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: onTap == null ? Colors.grey.shade500 : Colors.white, size: 18),
                const SizedBox(width: 10),
                Flexible(child: Text(title, style: GoogleFonts.poppins(color: onTap == null ? Colors.grey.shade600 : Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
              ],
            ),
          ),
        ),
      ),
    );
    return isPulsing ? Pulse(duration: const Duration(seconds: 2), child: button) : button;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: Icon(LucideIcons.arrowLeft, color: Colors.teal.shade900), onPressed: () => Navigator.pop(context)),
        title: Text("Squad Tracker", style: GoogleFonts.poppins(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true,
        actions: [if (widget.targetSquadId == null) IconButton(icon: const Icon(LucideIcons.refreshCcw, color: Colors.teal), onPressed: _loadMyPledges)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _myPledges.isEmpty
          ? Center(child: Text("No delivery squads found.", style: GoogleFonts.poppins(color: Colors.grey)))
          : RefreshIndicator(
        onRefresh: _loadMyPledges,
        color: Colors.teal,
        child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _myPledges.length,
            itemBuilder: (context, index) {
              final pledge = _myPledges[index];
              final bulkRequest = pledge['bulk_request'] ?? {};

              String squadStatus = bulkRequest['squad_status'] ?? 'unknown';
              bool isCoordinator = bulkRequest['coordinator_id'] == _currentUserId;
              bool isPickup = bulkRequest['delivery_method']?.toString().contains('Pickup') ?? false;
              bool isPaymentSecured = bulkRequest['payment_status'] == 'deposit_paid' || bulkRequest['payment_status'] == 'fully_paid_escrow' || bulkRequest['payment_status'] == 'fully_paid';

              List roster = bulkRequest['squad_roster'] ?? [];
              bool allAudited = true;
              bool anyInTransit = false;
              bool anyDelivered = false;

              if (roster.isNotEmpty) {
                for (var member in roster) {
                  String mStatus = member['status'] ?? 'unknown';
                  if (mStatus == 'pledged' || mStatus == 'pending_audit') {
                    allAudited = false;
                  }
                  if (mStatus == 'in_transit') anyInTransit = true;
                  if (mStatus == 'delivered' || mStatus == 'completed' || mStatus == 'paid') anyDelivered = true;
                }
              } else { allAudited = false; }

              if (anyDelivered) squadStatus = 'delivered';
              else if (anyInTransit) squadStatus = 'in_transit';

              double myPledgedKg = (pledge['pledged_weight_kg'] ?? 0).toDouble();
              double myActualKg = (pledge['actual_weight_kg'] ?? myPledgedKg).toDouble();
              double pricePerKg = (bulkRequest['price_per_kg'] ?? 0).toDouble();
              double myExpectedPayout = myActualKg * pricePerKg;

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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(LucideIcons.truck, color: Colors.teal.shade700)),
                                const SizedBox(width: 15),
                                Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Contract #BR-${bulkRequest['id']}", style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(bulkRequest['buyer_name'] ?? 'Buyer', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ])),
                                IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadChatScreen(squadId: bulkRequest['id'], squadName: bulkRequest['crop_name'] ?? 'Produce'))), icon: const Icon(LucideIcons.messageCircle), color: Colors.teal.shade700)
                              ],
                            ),

                            // 🔥 THE FIX: SHOW DESTINATION DETAILS IN SQUADS
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade100)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [Icon(LucideIcons.mapPin, size: 14, color: Colors.teal.shade800), const SizedBox(width: 8), Text("Destination Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade900))]),
                                  const SizedBox(height: 4),
                                  Text("${bulkRequest['ward'] ?? 'Address Pending'}, ${bulkRequest['county'] ?? ''}".trim(), style: GoogleFonts.poppins(fontSize: 11, color: Colors.teal.shade800)),
                                  const SizedBox(height: 8),
                                  Row(children: [Icon(LucideIcons.phone, size: 14, color: Colors.teal.shade800), const SizedBox(width: 8), Expanded(child: Text(bulkRequest['buyer_phone'] ?? 'No Phone', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900)))]),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade100)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("My Contribution", style: GoogleFonts.poppins(color: Colors.green.shade800, fontSize: 12)), Text("${myActualKg.toStringAsFixed(1)} KG", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900))]),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("My Payout", style: GoogleFonts.poppins(color: Colors.green.shade800, fontSize: 12)), Text("KES ${(myExpectedPayout).toStringAsFixed(0)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900))]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Action Center", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 14)),
                                  const SizedBox(height: 15),

                                  if (squadStatus == 'gathering')
                                    _buildPremiumButton(title: "Waiting for more farmers...", icon: LucideIcons.users, gradientColors: [Colors.grey.shade400, Colors.grey.shade500], onTap: null)

                                  else if (squadStatus == 'voting')
                                    _buildPremiumButton(title: "Elect Squad Coordinator", icon: LucideIcons.vote, gradientColors: [Colors.purple.shade400, Colors.deepPurple.shade700], onTap: () => _showVotingSheet(bulkRequest), isPulsing: true)

                                  else if (squadStatus == 'active' || squadStatus == 'in_transit' || squadStatus == 'delivered') ...[
                                      if (!isPaymentSecured)
                                        _buildPremiumButton(title: "Awaiting Buyer Payment...", icon: LucideIcons.lock, gradientColors: [Colors.orange.shade400, Colors.orange.shade700], onTap: null)
                                      else ...[

                                        if (pledge['status'] == 'pledged') ...[
                                          _buildPremiumButton(
                                              title: "Digital Drop-off", icon: LucideIcons.camera, gradientColors: [Colors.teal.shade400, Colors.teal.shade700],
                                              onTap: () async {
                                                await Navigator.push(context, MaterialPageRoute(builder: (_) => UnattendedDropoffScreen(squadId: bulkRequest['id'], cropName: bulkRequest['crop_name'] ?? 'Produce')));
                                                _loadMyPledges();
                                              }
                                          ),
                                          const SizedBox(height: 10),
                                          _buildPremiumButton(
                                              title: "Hand to Coordinator in Person", icon: LucideIcons.handMetal, gradientColors: [Colors.blue.shade400, Colors.blue.shade700],
                                              onTap: () async {
                                                final error = await _apiClient.updateIndividualPledgeStatus(pledge['id'], 'pending_audit');
                                                if (error == null) _loadMyPledges();
                                              }
                                          ),
                                        ]
                                        else if (pledge['status'] == 'pending_audit')
                                          _buildPremiumButton(title: "Awaiting Coordinator Audit...", icon: LucideIcons.loader, gradientColors: [Colors.orange.shade400, Colors.orange.shade700], onTap: null)
                                        else if (pledge['status'] == 'received')
                                            _buildPremiumButton(title: "Goods Verified & Loaded ✅", icon: LucideIcons.checkCircle, gradientColors: [Colors.green.shade400, Colors.green.shade700], onTap: null)
                                          else if (pledge['status'] == 'in_transit')
                                              _buildPremiumButton(
                                                  title: "Track Live Location 🗺️", icon: LucideIcons.map, gradientColors: [Colors.blue.shade400, Colors.blue.shade700],
                                                  onTap: () {
                                                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingMap(
                                                        entityName: "Contract #BR-${bulkRequest['id']}", status: "Dispatched to Buyer"
                                                    )));
                                                  }
                                              )
                                            else if (pledge['status'] == 'delivered')
                                                _buildPremiumButton(title: "Arrived at Destination 📍", icon: LucideIcons.mapPin, gradientColors: [Colors.indigo.shade400, Colors.indigo.shade700], onTap: null)
                                              else if (pledge['status'] == 'paid' || pledge['status'] == 'completed')
                                                  _buildPremiumButton(title: "Payment Secured ✅", icon: LucideIcons.checkCircle, gradientColors: [Colors.green.shade400, Colors.green.shade700], onTap: null)
                                                else if (pledge['status'] == 'returning' || pledge['status'] == 'disputed')
                                                    _buildPremiumButton(title: "Dispute Active (See My Deliveries)", icon: LucideIcons.alertTriangle, gradientColors: [Colors.red.shade400, Colors.red.shade700], onTap: null)
                                                  else if (pledge['status'] == 'rejected' || pledge['status'] == 'refunded')
                                                      _buildPremiumButton(title: "Produce Cancelled / Refunded ❌", icon: LucideIcons.xCircle, gradientColors: [Colors.grey.shade400, Colors.grey.shade600], onTap: null),

                                        // COORDINATOR MASTER CONTROLS
                                        if (isCoordinator) ...[
                                          const SizedBox(height: 20),
                                          const Divider(),
                                          const SizedBox(height: 10),
                                          Text("Coordinator Controls", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                                          const SizedBox(height: 10),

                                          if (squadStatus == 'active') ...[
                                            _buildPremiumButton(
                                                title: "Audit & Verify Drop-offs", icon: LucideIcons.clipboardCheck, gradientColors: [Colors.indigo.shade400, Colors.indigo.shade700],
                                                onTap: () async {
                                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivingDashboard()));
                                                  _loadMyPledges();
                                                },
                                                isPulsing: !allAudited
                                            ),
                                            const SizedBox(height: 10),

                                            if (allAudited)
                                              _buildPremiumButton(
                                                  title: isPickup ? "Goods Ready for Buyer Pickup" : "Start Delivery Transit",
                                                  icon: LucideIcons.truck, gradientColors: [Colors.black87, Colors.black],
                                                  onTap: () async {
                                                    final error = await _apiClient.updateSquadDeliveryStatus(bulkRequest['id'], 'in_transit');
                                                    if (error == null) _loadMyPledges();
                                                  }
                                              )
                                            else
                                              _buildPremiumButton(title: "Verify active goods to start transit", icon: LucideIcons.lock, gradientColors: [Colors.grey.shade400, Colors.grey.shade500], onTap: null)
                                          ]

                                          else if (squadStatus == 'in_transit') ...[
                                            _buildPremiumButton(
                                                title: "View Live Tracking Map", icon: LucideIcons.map, gradientColors: [Colors.blue.shade400, Colors.blue.shade700],
                                                onTap: () {
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingMap(
                                                      entityName: "Squad Delivery #BR-${bulkRequest['id']}", status: "En Route"
                                                  )));
                                                }
                                            ),
                                            const SizedBox(height: 10),
                                            _buildPremiumButton(
                                                title: "Mark as Arrived (Ping Buyer)", icon: LucideIcons.mapPin, gradientColors: [Colors.indigo.shade400, Colors.indigo.shade700],
                                                onTap: () async {
                                                  final error = await _apiClient.updateSquadDeliveryStatus(bulkRequest['id'], 'delivered');
                                                  if (error == null) _loadMyPledges();
                                                }
                                            )
                                          ]
                                          else
                                            _buildPremiumButton(title: "Waiting for Buyer QA...", icon: LucideIcons.loader, gradientColors: [Colors.orange.shade400, Colors.orange.shade700], onTap: null)
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