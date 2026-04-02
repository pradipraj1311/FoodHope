import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverrideHubSheet extends StatefulWidget {
  final String donationId;
  final List<Map<String, dynamic>> allDestinations;
  final String recommendedId;

  const OverrideHubSheet({super.key, required this.donationId, required this.allDestinations, required this.recommendedId});

  @override
  State<OverrideHubSheet> createState() => _OverrideHubSheetState();
}

class _OverrideHubSheetState extends State<OverrideHubSheet> {
  final List<String> overrideOptions = [
    '1. I regularly work with this Hub', '2. Recommended Hub is not responding',
    '3. Recommended Hub is full', '4. This Hub is closer',
    '5. This Hub distributes faster', '6. Food type not accepted',
    '7. Personal trust', '8. Other (write manually)'
  ];
  late String selectedOverrideReason;
  TextEditingController otherReasonController = TextEditingController();
  String? proposedNgoId;
  String? proposedNgoName;

  @override
  void initState() {
    super.initState();
    selectedOverrideReason = overrideOptions[0];
  }

  Widget _buildTrustBadge(String type) {
    String label = "Verified"; IconData icon = Icons.verified; Color color = Colors.green.shade700;
    if (type == 'Volunteer Group') { label = "Group"; icon = Icons.star; color = Colors.blue.shade700; }
    else if (type == 'Religious Trust') { label = "Trust"; icon = Icons.temple_hindu; color = Colors.orange.shade800; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Change Drop-off Hub", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)), const SizedBox(height: 15),
          DropdownButtonFormField<String>(isExpanded: true, value: selectedOverrideReason, decoration: const InputDecoration(border: OutlineInputBorder()), items: overrideOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (val) => setState(() => selectedOverrideReason = val!)),
          if (selectedOverrideReason.contains('Other')) ...[const SizedBox(height: 10), TextField(controller: otherReasonController, decoration: const InputDecoration(hintText: "Please specify...", border: OutlineInputBorder()))],
          const SizedBox(height: 20), const Text("Select New Destination:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 5),
          SizedBox(
            height: 200,
            child: ListView.builder(
                itemCount: widget.allDestinations.length,
                itemBuilder: (context, index) {
                  var ngo = widget.allDestinations[index];
                  if (ngo['id'] == widget.recommendedId) return const SizedBox.shrink();
                  bool isSelected = proposedNgoId == ngo['id'];
                  return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(ngo['data']['distributorName'] ?? 'Distributor', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${ngo['distKm'].toStringAsFixed(1)} km away"),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [_buildTrustBadge(ngo['data']['distributorType'] ?? 'NGO'), const SizedBox(width: 8), isSelected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.circle_outlined)]),
                      onTap: () => setState(() { proposedNgoId = ngo['id']; proposedNgoName = ngo['data']['distributorName']; })
                  );
                }
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (proposedNgoId == null) return;
                    String finalReason = selectedOverrideReason.contains('Other') ? "Other: ${otherReasonController.text.trim()}" : selectedOverrideReason;
                    await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({'selectedNgoId': proposedNgoId, 'selectedNgoName': proposedNgoName, 'changeReason': finalReason, 'isHubConfirmed': false});
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Confirm Change", style: TextStyle(fontWeight: FontWeight.bold))
              )
          )
        ],
      ),
    );
  }
}