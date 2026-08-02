import '../db/app_database.dart';
import 'vehicle_owner_contact.dart';

/// Active role for a vehicle quick-action form, derived from navigation entry.
///
/// - [VehicleUsageRole.owner]: entered via **Véhicule** hub on an owned vehicle.
/// - [VehicleUsageRole.borrower]: entered via **Partage de véhicule** on an
///   accessible vehicle owned by someone else (another app instance once relay
///   sync exists).
enum VehicleUsageRole {
  owner,
  borrower,
}

enum VehicleUsageAccessDenial {
  vehicleNotFound,
  notOwnedVehicleForOwnerPath,
  ownVehicleOnBorrowerPath,
  missingBorrowerIdentity,
}

/// Navigation context passed into shared quick-action forms.
class VehicleUsageContext {
  const VehicleUsageContext({
    required this.role,
    required this.actingContactId,
  });

  const VehicleUsageContext.owner()
      : role = VehicleUsageRole.owner,
        actingContactId = kVehicleOwnerSelfContactId;

  const VehicleUsageContext.borrower({required this.actingContactId})
      : role = VehicleUsageRole.borrower;

  final VehicleUsageRole role;
  final String actingContactId;

  bool get isOwner => role == VehicleUsageRole.owner;
  bool get isBorrower => role == VehicleUsageRole.borrower;
  bool get persistsLocally => isOwner;
  bool get forwardsToOwner => isBorrower;
}

bool vehicleIsOwnedBySelf(Vehicle vehicle) =>
    vehicle.ownerContactId == kVehicleOwnerSelfContactId;

/// Whether [openUse] may be ended by the actor in [context].
///
/// A Propriétaire must not end an Emprunteur's open session (and vice versa):
/// only the attributed actor may close that use.
bool canEndUseSessionAsActor({
  required VehicleUse? openUse,
  required VehicleUsageContext context,
}) {
  if (openUse == null) return false;
  return openUse.attributedContactId == context.actingContactId;
}

VehicleUsageAccessDenial? denyVehicleUsageAccess({
  required Vehicle? vehicle,
  required VehicleUsageContext context,
}) {
  if (vehicle == null) {
    return VehicleUsageAccessDenial.vehicleNotFound;
  }
  final own = vehicleIsOwnedBySelf(vehicle);
  if (context.isOwner && !own) {
    return VehicleUsageAccessDenial.notOwnedVehicleForOwnerPath;
  }
  if (context.isBorrower && own) {
    return VehicleUsageAccessDenial.ownVehicleOnBorrowerPath;
  }
  if (context.isBorrower && context.actingContactId.isEmpty) {
    return VehicleUsageAccessDenial.missingBorrowerIdentity;
  }
  return null;
}
