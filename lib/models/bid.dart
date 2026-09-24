import 'package:cloud_firestore/cloud_firestore.dart';

enum BidStatus { pending, accepted, rejected }

BidStatus bidStatusFromString(String value) {
  switch (value) {
    case 'pending':
      return BidStatus.pending;
    case 'accepted':
      return BidStatus.accepted;
    case 'rejected':
      return BidStatus.rejected;
    default:
      throw ArgumentError('Unknown bid status: $value');
  }
}

class Bid {
  final String id;
  final String riderId;
  final String riderName;
  final double riderRating;
  final int riderRatingCount;
  final String? riderPhotoUrl;
  final String? riderVehicleType;
  final String? riderPlateNumber;
  final String? riderVehicleColor;
  final double price;
  final int? etaMinutes;
  final BidStatus status;
  final DateTime submittedAt;

  Bid({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderRating,
    this.riderRatingCount = 0,
    this.riderPhotoUrl,
    this.riderVehicleType,
    this.riderPlateNumber,
    this.riderVehicleColor,
    required this.price,
    this.etaMinutes,
    required this.status,
    required this.submittedAt,
  });

  factory Bid.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bid(
      id: doc.id,
      riderId: data['riderId'] as String,
      riderName: data['riderName'] as String,
      riderRating: (data['riderRating'] as num).toDouble(),
      // Defaults to 0 for bids submitted before this field existed —
      // reads as "no reviews yet" rather than crashing on a missing key.
      riderRatingCount: (data['riderRatingCount'] as num?)?.toInt() ?? 0,
      riderPhotoUrl: data['riderPhotoUrl'] as String?,
      riderVehicleType: data['riderVehicleType'] as String?,
      riderPlateNumber: data['riderPlateNumber'] as String?,
      riderVehicleColor: data['riderVehicleColor'] as String?,
      price: (data['price'] as num).toDouble(),
      etaMinutes: (data['etaMinutes'] as num?)?.toInt(),
      status: bidStatusFromString(data['status'] as String),
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
    );
  }
}

/// Live stream of bids for a given request, ordered cheapest-first.
/// Use in the customer app like:
///   StreamBuilder<List<Bid>>(stream: watchBids(requestId), ...)
Stream<List<Bid>> watchBids(String requestId) {
  return FirebaseFirestore.instance
      .collection('delivery_requests')
      .doc(requestId)
      .collection('bids')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
        final bids = snap.docs.map((d) => Bid.fromFirestore(d)).toList();
        bids.sort((a, b) => a.price.compareTo(b.price));
        return bids;
      });
}
