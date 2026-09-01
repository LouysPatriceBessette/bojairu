package license

// Canonical Play product ids and granted modules, matching docs/store-mapping.md.

const (
	ModuleHousing        = "housing"
	ModuleVehicle        = "vehicle"
	ModuleVehicleSharing = "vehicle-sharing"

	PlatformGooglePlay  = "google_play"
	PlatformServerGrant = "server_grant"
	ProductAllModules   = "bojairu.bundle.all_modules"
)

// Product describes one sellable Play subscription (standalone or bundle).
type Product struct {
	ProductID      string
	BundleID       string // empty for standalones
	GrantedModules []string
}

var playCatalog = []Product{
	{ProductID: "bojairu.housing", GrantedModules: []string{ModuleHousing}},
	{ProductID: "bojairu.vehicle", GrantedModules: []string{ModuleVehicle}},
	{ProductID: "bojairu.vehicle_sharing", GrantedModules: []string{ModuleVehicleSharing}},
	{
		ProductID:      "bojairu.bundle.housing_vehicle_sharing",
		BundleID:       "housing_vehicle_sharing",
		GrantedModules: []string{ModuleHousing, ModuleVehicleSharing},
	},
	{
		ProductID:      "bojairu.bundle.vehicle_vehicle_sharing",
		BundleID:       "vehicle_vehicle_sharing",
		GrantedModules: []string{ModuleVehicle, ModuleVehicleSharing},
	},
	{
		ProductID:      "bojairu.bundle.housing_vehicle",
		BundleID:       "housing_vehicle",
		GrantedModules: []string{ModuleHousing, ModuleVehicle},
	},
	{
		ProductID:      ProductAllModules,
		BundleID:       "all_modules",
		GrantedModules: []string{ModuleHousing, ModuleVehicle, ModuleVehicleSharing},
	},
}

var playCatalogByID map[string]Product

func init() {
	playCatalogByID = make(map[string]Product, len(playCatalog))
	for _, p := range playCatalog {
		playCatalogByID[p.ProductID] = p
	}
}

// LookupPlayProduct returns the catalog row for a Play product id.
func LookupPlayProduct(productID string) (Product, bool) {
	p, ok := playCatalogByID[productID]
	return p, ok
}

// KnownPlayProductIDs returns the seven catalog product ids.
func KnownPlayProductIDs() []string {
	out := make([]string, 0, len(playCatalog))
	for _, p := range playCatalog {
		out = append(out, p.ProductID)
	}
	return out
}

func grantsModule(modules []string, module string) bool {
	for _, m := range modules {
		if m == module {
			return true
		}
	}
	return false
}
