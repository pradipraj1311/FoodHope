import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const VolunteerHomeTab({super.key, required this.userData, required this.uid});

  @override
  State<VolunteerHomeTab> createState() => _VolunteerHomeTabState();
}

class _VolunteerHomeTabState extends State<VolunteerHomeTab> {
  String _searchQuery = "";
  String _selectedFilter = "All";

  Future<void> _startDelivery(BuildContext context, String donationId) async {
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'In Transit',
      'volunteerUid': widget.uid,
      'volunteerName': widget.userData['name'] ?? 'Volunteer',
      'pickupTime': DateTime.now(),
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery Started! Please head to the donor.")));
  }

  Future<void> _completeDelivery(BuildContext context, String donationId) async {
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Completed',
      'dropoffTime': DateTime.now(),
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food Successfully Delivered! Great job!")));
  }

  Widget _buildFilterChip(String label, IconData icon) {
    bool isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.green.shade700),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          ],
        ),
        selected: isSelected,
        selectedColor: Colors.green.shade700,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = selected ? label : "All";
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String userCity = widget.userData['city'] ?? 'Unknown City';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 1. ACTIVE DELIVERY CARD (Sticky at top)
        // ==========================================
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('donations')
              .where('volunteerUid', isEqualTo: widget.uid)
              .where('status', isEqualTo: 'In Transit').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

            var activePost = snapshot.data!.docs.first;
            Map<String, dynamic> postData = activePost.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade600]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.directions_bike, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text("ACTIVE DELIVERY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                    ],
                  ),
                  const Divider(color: Colors.white54, height: 25),
                  Text("📦 ${postData['foodItem']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text("📍 Pickup: ${postData['businessName']}", style: const TextStyle(fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => _completeDelivery(context, activePost.id),
                      child: const Text("Mark as Delivered", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        ),

        // ==========================================
        // 2. SWIGGY STYLE SEARCH & FILTERS
        // ==========================================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: "Search for food (e.g., 'Roti', 'Cake')",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip("All", Icons.filter_list),
                    _buildFilterChip("Veg Only", Icons.grass),
                    _buildFilterChip("Expiring Soon", Icons.timer),
                    _buildFilterChip("Large Qty (>50)", Icons.group),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text("Recommended Rescues", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),

        // ==========================================
        // 3. FILTERED FEED
        // ==========================================
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('city', isEqualTo: userCity)
                .where('status', isEqualTo: 'Available')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No available food in this area.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)));

              // Apply Client-Side Filtering
              var filteredDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;

                // 1. Search Query Filter
                if (_searchQuery.isNotEmpty) {
                  String foodItem = (data['foodItem'] ?? '').toString().toLowerCase();
                  if (!foodItem.contains(_searchQuery)) return false;
                }

                // 2. Chip Filters
                if (_selectedFilter == "Veg Only" && data['category'] != "Veg Only") return false;
                if (_selectedFilter == "Large Qty (>50)" && (data['quantity'] ?? 0) < 50) return false;
                if (_selectedFilter == "Expiring Soon") {
                  String expiry = data['expiry'] ?? '';
                  if (!expiry.contains('2 hours') && !expiry.contains('1 hour')) return false;
                }

                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text("No food matches your filters.", style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var post = filteredDocs[index];
                  Map<String, dynamic> postData = post.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(postData['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                              Chip(
                                label: Text(postData['category'] ?? 'Food', style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.green.shade50,
                                side: BorderSide.none,
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(Icons.people, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text("Feeds approx ${postData['quantity']}", style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(children: [const Icon(Icons.storefront, size: 18, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(postData['businessName'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)))]),
                          const SizedBox(height: 5),
                          Row(children: [const Icon(Icons.timer, size: 18, color: Colors.redAccent), const SizedBox(width: 8), Text("Expires: ${postData['expiry'] ?? 'Soon'}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity, height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _startDelivery(context, post.id),
                              icon: const Icon(Icons.motorcycle),
                              label: const Text("Accept Delivery", style: TextStyle(fontSize: 16)),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}