import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class FirestoreCollections {
  FirestoreCollections._();

  static CollectionReference<Map<String, dynamic>> barbers(FirebaseFirestore db) =>
      db.collection('barbers');

  static CollectionReference<Map<String, dynamic>> services(FirebaseFirestore db) =>
      db.collection('services');

  static CollectionReference<Map<String, dynamic>> paymentMethods(
    FirebaseFirestore db,
  ) =>
      db.collection('payment_methods');

  static CollectionReference<Map<String, dynamic>> sales(FirebaseFirestore db) =>
      db.collection('sales');

  static CollectionReference<Map<String, dynamic>> promos(FirebaseFirestore db) =>
      db.collection('promos');

  static CollectionReference<Map<String, dynamic>> inventoryItems(
    FirebaseFirestore db,
  ) =>
      db.collection('inventory_items');
}

