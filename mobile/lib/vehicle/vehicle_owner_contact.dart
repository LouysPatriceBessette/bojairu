/// Stable contact id for the local user as vehicle Propriétaire.
const String kVehicleOwnerSelfContactId = 'vehicle:owner:self';

/// Stable contact id for the local user as Emprunteur on a synced share.
const String kVehicleBorrowerSelfContactId = 'vehicle:borrower:self';

bool vehicleContactIsOwnerSelf(String contactId) =>
    contactId == kVehicleOwnerSelfContactId;

bool vehicleContactIsBorrowerSelf(String contactId) =>
    contactId == kVehicleBorrowerSelfContactId;
