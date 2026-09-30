import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class FoodItemEntry {
  String name;
  double quantity;
  String unit;
  FoodItemEntry({this.name = '', this.quantity = 0.0, this.unit = 'KG'});
}

class PostFoodSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const PostFoodSheet({super.key, required this.userData, required this.uid});

  @override
  State<PostFoodSheet> createState() => _PostFoodSheetState();
}

class _PostFoodSheetState extends State<PostFoodSheet> {
  final List<FoodItemEntry> _items = [FoodItemEntry()];
  String foodType = 'Veg'; 
  bool isProcessing = false;
  int peopleFed = 20;
  final List<int> peopleOptions = [5, 10, 20, 50, 100, 200, 500];

  List<String> _suggestedFoodItems = ['Rice', 'Dal', 'Roti', 'Sabji', 'Khichdi', 'Biryani', 'Bread', 'Curry'];

  @override
  void initState() {
    super.initState();
    _loadFoodSuggestions();
  }

  Future<void> _loadFoodSuggestions() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('food_suggestions').get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _suggestedFoodItems = snapshot.docs.map((doc) => doc.id).toList();
        });
      }
    } catch (e) {
      debugPrint("Suggestions load failed: $e");
    }
  }

  // Senior Dev: Precision address builder to ensure proper visibility for volunteers
  String _getDonorFullAddress() {
    String business = (widget.userData['businessName'] ?? '').trim();
    String building = (widget.userData['exactAddress'] ?? '').trim();
    String street = (widget.userData['streetName'] ?? '').trim();
    String city = (widget.userData['city'] ?? '').trim();

    List<String> parts = [];
    if (business.isNotEmpty) parts.add(business);
    if (building.isNotEmpty && !business.toLowerCase().contains(building.toLowerCase())) parts.add(building);
    if (street.isNotEmpty && !building.toLowerCase().contains(street.toLowerCase())) parts.add(street);
    if (city.isNotEmpty && !street.toLowerCase().contains(city.toLowerCase())) parts.add(city);

    return parts.isEmpty ? "Location: $city" : parts.join(", ");
  }

  void _addItem() => setState(() => _items.add(FoodItemEntry()));
  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _publishDonation() async {
    if (_items.any((item) => item.name.isEmpty || item.quantity <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all item details!")));
      return;
    }
    setState(() => isProcessing = true);

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      List<Map<String, dynamic>> foodData = [];
      for (var item in _items) {
        String normalizedName = item.name.trim().split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '').join(' ');
        foodData.add({'name': normalizedName, 'quantity': item.quantity, 'unit': item.unit});
        FirebaseFirestore.instance.collection('food_suggestions').doc(normalizedName).set({'lastUsed': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }

      String pin = (1000 + Random().nextInt(9000)).toString();

      await FirebaseFirestore.instance.collection('donations').add({
        'donorUid': widget.uid,
        'businessName': widget.userData['businessName'] ?? widget.userData['name'] ?? 'Donor',
        'city': widget.userData['city'],
        'latitude': widget.userData['latitude'] ?? 0.0,
        'longitude': widget.userData['longitude'] ?? 0.0,
        'fullAddress': _getDonorFullAddress(), // Proper location fix
        'items': foodData,
        'foodItem': _items.map((e) => "${e.quantity}${e.unit} ${e.name}").join(", "), 
        'foodType': foodType,
        'peopleFed': peopleFed, 
        'exactExpiryTime': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 4))),
        'status': 'Available',
        'postedAt': FieldValue.serverTimestamp(),
        'pickupOtp': pin,
      });

      if (mounted) {
        Navigator.pop(context); Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rescue is Live! 🚀"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("Post Surplus Food", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 20),
          
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Autocomplete<String>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                                  return _suggestedFoodItems.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (String selection) => _items[index].name = selection,
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  controller.addListener(() => _items[index].name = controller.text);
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(hintText: "What are you donating?*", border: InputBorder.none),
                                  );
                                },
                              ),
                            ),
                            if (_items.length > 1) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _removeItem(index)),
                          ],
                        ),
                        const Divider(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(hintText: "Qty (e.g. 5.5)", border: InputBorder.none, prefixIcon: Icon(Icons.scale, size: 16)),
                                onChanged: (val) => _items[index].quantity = double.tryParse(val) ?? 0,
                              ),
                            ),
                            DropdownButton<String>(
                              value: _items[index].unit,
                              underline: const SizedBox(),
                              items: ['KG', 'Litre'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) => setState(() => _items[index].unit = val!),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_circle_outline), label: const Text("Add Another Item")),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: peopleFed,
                  decoration: const InputDecoration(labelText: "Est. People Fed", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                  items: peopleOptions.map((v) => DropdownMenuItem(value: v, child: Text("$v People"))).toList(),
                  onChanged: (v) => setState(() => peopleFed = v!),
                ),
              ),
              const SizedBox(width: 15),
              DropdownButton<String>(
                value: foodType,
                items: ['Veg', 'Non-Veg'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: t == 'Veg' ? Colors.green : Colors.red, fontWeight: FontWeight.bold)))).toList(),
                onChanged: (v) => setState(() => foodType = v!),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: isProcessing ? null : _publishDonation, child: const Text("PUBLISH RESCUE", style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}
