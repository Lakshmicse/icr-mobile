/// The sentences My Products and My Services say, as the website words them (`messages/en/catalog.json`:
/// ProductsWorkspace, ProductSlideOver, ProductCard, ProductPhotoField, EmptyProducts, ServicesWorkspace,
/// ServiceSlideOver, ServiceCard, EmptyServices, ConfirmDeleteDialog, BulkActionBar; `common.json`:
/// SupplierListingNotice, StartSellingButton, NoCompany).
library;

class CatalogWords {
  CatalogWords._();

  // The pages
  static const productsTitle = 'My Products';
  // Subtitles, header buttons and empty states: the owner's recommended wording (07-supplier-mart.docx, 12 Nov 2026).
  static const productsSubtitle =
      'Manage the products your company offers. Add them to your ICR supplier profile and make them discoverable to '
      'buyers across the marketplace.';
  static const servicesTitle = 'My Services';
  static const servicesSubtitle =
      "Manage and showcase your company's services to improve marketplace visibility and attract buyer enquiries.";
  static const addProduct = 'Add Product';
  static const addService = 'Add Service';
  static const couldNotLoadProducts = 'Unable to load your products.';
  static const couldNotLoadServices = 'Unable to load your services.';
  static const retry = 'Try Again';
  static const searchProducts = 'Search Products';
  static const searchServices = 'Search Services';
  static const select = 'Select';
  static const done = 'Done';
  static String selectAll(int n) => 'Select All $n';
  static const clearSelection = 'Clear Selection';
  static String selected(int n) => '$n selected';
  static const delete = 'Delete';
  static const cancel = 'Cancel';
  static const clearFilters = 'Clear Filters';
  static const noProductsMatch = 'No Products Match';
  static const noServicesMatch = 'No Services Match Your Filters';
  static String allChip(int n) => 'All ($n)';
  static const noCategory = 'No Category';
  static const uncategorized = 'Uncategorized';
  static const worthFinishing = 'Needs attention:';
  static String withoutPhoto(int n) => '$n without a photo';
  static String withoutPrice(int n) => '$n without a price';
  static String withoutCategory(int n) => '$n without a category';

  // The stats line (the website's KPI tiles)
  static String products(int n) => n == 1 ? '1 product' : '$n products';
  static String services(int n) => n == 1 ? '1 service' : '$n services';
  static String categories(int n) => n == 1 ? '1 category' : '$n categories';
  static String withAPhoto(int n, int of) => '$n/$of with a photo';
  static String listingStrength(int pct) => 'Listing Strength $pct%';
  static const averageAcrossProducts = 'average across your products';

  // The services figures, under the owner's labels (the website's tiles: Total Services → Services Listed,
  // Categories → Service Categories, Avg Starting Price → Average Starting Price, Listing Strength → Listing Quality,
  // Most Complete → Best-Completed Listing). "With Turnaround" keeps its name: the owner's "On-Time Delivery" would
  // claim deliveries were measured, and the figure counts services that state a turnaround.
  static String servicesListed(int n) => 'Services Listed: $n';
  static String serviceCategories(int n) => 'Service Categories: $n';
  static String averageStartingPrice(String amount) => 'Average Starting Price: $amount';
  static String listingQuality(int pct) => 'Listing Quality: $pct%';
  static String withTurnaround(int n, int of) => 'With Turnaround: $n/$of';
  static String bestCompletedListing(String name) => 'Best-Completed Listing: $name';
  static const recentlyAdded = 'Recently Added';

  // The plan's listing places
  static String placesUsed(int used, int limit) => '$used of $limit listing places used';
  static String placesCounted(int products, int services) =>
      '${CatalogWords.products(products)} and ${CatalogWords.services(services)}. Your plan counts them together.';
  static const placesFull = ' To add another, remove one you no longer sell or move to a larger plan.';
  static const seePlans = 'See Plans';

  // Toasts
  static const productPublished = 'Product published.';
  static const productUpdated = 'Product updated.';
  static const productDeleted = 'Product deleted.';
  static const productDuplicated = 'Product duplicated. Edit the copy to make it a separate product.';
  static String productsDeleted(int n) => '$n products deleted.';
  static String someNotDeleted(int failed, int total) => '$failed of $total could not be deleted.';
  static const servicePublished = 'Service published.';
  static const serviceUpdated = 'Service updated.';
  static const serviceDeleted = 'Service deleted.';
  static const serviceDuplicated = 'Service duplicated.';
  static String servicesDeleted(int n) => n == 1 ? '1 service deleted.' : '$n services deleted.';
  static const someServicesNotDeleted = 'Some services could not be deleted.';

  // Deleting
  static String deleteOne(String name) => 'Delete “$name”?';
  static String deleteMany(int n) => 'Delete $n Products?';
  static String deleteManyServices(int n) => 'Delete $n Services?';
  static const deleteOneBody =
      'It will be removed from your supplier listing and the marketplace immediately. Links to it will stop working.';
  static const deleteManyBody =
      'They will be removed from your supplier listing and the marketplace immediately. Links to them will stop '
      'working.';
  static const thisProduct = 'this product';
  static const thisService = 'this service';

  // The row's menu
  static const edit = 'Edit';
  static const viewAsBuyer = 'View as Buyer';
  static const duplicate = 'Duplicate';
  static const productActions = 'Product actions';
  static const serviceActions = 'Service actions';
  static const priceOnRequest = 'Price on Request';
  static const noPriceSet = 'No price set';
  static const noProductDescription = 'No description yet. Buyers compare on specifications and pack size.';
  static const noServiceDescription = 'No description yet. Add one to help buyers understand this service.';
  static const listingStrengthLabel = 'Listing Strength';

  /// A service row's score, named as the services figures name it.
  static const listingQualityLabel = 'Listing Quality';
  static String addMissing(String missing) => 'Add: $missing';
  static const allFilledIn = 'All details buyers look for are complete.';
  static const fullyOptimized = 'Fully Optimized';

  // Empty
  static const noProductsYet = 'No Products Listed Yet';
  static const addWhatYouSell =
      'Showcase the products you offer to help buyers discover your offerings and request quotations.';
  static const addFirstProduct = 'Add Your First Product';
  static const stepPhotoTitle = 'Product Image';
  static const stepPhotoBody = 'Add a clear, high-quality photo.';
  static const stepCategoryTitle = 'Product Category';
  static const stepCategoryBody = 'Select the right category for easy discovery.';
  static const stepPriceTitle = 'Unit Price';
  // Not the owner's "Add a price or select “Price on Request”.": the editor has no such choice to select — a blank
  // price is what buyers read as "Price on request".
  static const stepPriceBody = 'Or leave it blank for “Price on Request”.';
  static const noServicesYet = 'No Services Listed Yet';
  static const createFirstService =
      "Add your company's services to showcase your expertise, improve discoverability and receive relevant buyer "
      'enquiries.';
  static const addFirstService = 'Add Your First Service';

  // No company (`common.NoCompany`), no listing (`common.SupplierListingNotice`, `StartSellingButton`)
  static const noCompanyTitle = "Your Account Isn't Linked to a Company";
  static const noCompanyLead = 'Jobs, products and services belong to a company.';
  static const noCompanyBody =
      '$noCompanyLead If your company is already on ICR, ask its admin to invite this email address. Accepting the '
      "invite links your account. If it is not on ICR yet, create it and you become its admin.";
  static const createACompany = 'Create a Company';
  static const notYoursTitle = 'This Page Is for Your Company’s Admins and Sellers';
  static const notYoursBody = 'Company admins and supplier accounts manage the catalogue.';
  static const noListing =
      'Your company does not sell on ICR yet. Start selling to appear in the Marketplace and respond to buyers’ '
      'requirements.';
  static const startSelling = 'Start Selling';
  static const starting = 'Starting…';
  static const couldNotStart = 'Unable to start selling. Try again.';
  static const askAdminToSell = 'Ask your company’s admin to start selling on ICR.';

  // The product editor (`ProductSlideOver`)
  static const addAProduct = 'Add a Product';
  static const editProduct = 'Edit Product';
  static const productAddSubtitle = 'It will appear on your supplier listing and the marketplace product grid.';
  static const productEditSubtitle = 'Changes appear on your listing and the marketplace when you save.';
  static const publishProduct = 'Publish Product';
  static const saveChanges = 'Save Changes';
  static const photo = 'Photo';
  static const theFirstThingBuyersSee = 'The first thing buyers see. Without one, the card shows a category icon.';
  static const basicDetails = 'Basic Details';
  static const productName = 'Product Name';
  static const nameHelper = 'Include the brand, model and size, e.g. “Taski R3 Cleaner 5L”.';
  static const productNameRequired = 'Enter a product name.';
  static const category = 'Category';
  static const subCategory = 'Sub-Category';
  static const pickACategory = 'Select a category';
  static const pickASubCategory = 'Select a sub-category';
  static const pickACategoryFirst = 'Select a category, then a sub-category.';
  static const categoryHelper = 'Buyers filter the product grid by category. The sub-category narrows it further.';
  static String filedUnder(String name) => 'Filed under “$name”. Select a category to move it.';
  static const description = 'Description';
  static const productDescriptionHelper =
      'Describe the product, its use, the pack size and the specifications buyers compare.';
  static const pricing = 'Pricing';
  static const leaveThePriceBlank = 'Leave the price blank to show buyers “Price on Request”.';
  static const price = 'Price';
  static const beforeGst = 'Before GST.';
  static const priceInvalid = 'Enter a price above ₹0 with up to two decimals.';
  static const soldPer = 'Sold Per';
  static const unitPlaceholder = 'piece';
  static const pieceBoxLitre = 'piece, box, litre…';
  static const stockTerms = 'Stock & Terms';
  static const optionalSayOnlyWhatYou =
      'Optional. Enter only what you will honour. Buyers see a line for each term you enter and nothing for one you '
      'leave blank.';
  static const availability = 'Availability';
  static const aBadgeOnTheProduct = 'A badge on the product grid and page. Keep it current.';
  static const notStated = 'Not stated';
  static const warranty = 'Warranty';
  static const months = 'months';
  static const returnsWithin = 'Returns Within';
  static const days = 'days';
  static const freeDeliveryOver = 'Free Delivery Over';
  static const bulkPricingFrom = 'Bulk Pricing From';
  static const units = 'units';
  static const leaveBlank = 'Leave blank to show nothing.';
  static const zeroShipsFree = '0 means every order ships free.';
  static const bulkQuantity = 'The quantity your bulk rate starts at.';
  static String buyersSee(String line) => 'Buyers see “$line”.';
  static const howBuyersSeeIt = 'How Buyers See It';

  // The photo field (`ProductPhotoField`)
  static const uploadPhoto = 'Upload Product Photo';
  static const replacePhoto = 'Replace Product Photo';
  static const replace = 'Replace';
  static const remove = 'Remove';
  static const photoHelper = 'PNG, JPG or WEBP, up to 2MB. A plain background works best on the card.';
  static const wrongType = 'Use a PNG, JPG or WEBP image.';
  static const tooLarge = 'This image is over 2MB. Compress it or select a smaller one.';
  static const uploadFailed = 'Upload failed. Check the file and try again.';

  // The service editor (`ServiceSlideOver`)
  static const addAService = 'Add a Service';
  static const editService = 'Edit Service';
  static const serviceAddSubtitle = 'Publish a service buyers can discover and quote.';
  static const serviceEditSubtitle = 'Update details and re-optimize your listing.';
  static const publishService = 'Publish Service';
  static const serviceName = 'Service Name';
  static const serviceNameRequired = 'Enter a service name.';
  static const categoryRequired = 'Select a category.';
  static const serviceDescriptionHelper = 'Describe scope, inclusions and what makes this service stand out.';
  static const shownToBuyersAsThe = 'Shown to buyers as the starting price.';
  static const startingPrice = 'Starting Price';
  static const pricingModel = 'Pricing Model';
  static const perVisit = 'per visit';
  static const serviceDelivery = 'Service Delivery';
  static const turnaroundTime = 'Turnaround Time';
  static const turnaroundPlaceholder = 'e.g. 24 hours, 2–3 days';
  static const marketplaceVisibility = 'Marketplace Visibility';
  static const controlHowThisServiceSurfaces = 'Control how this service appears in discovery.';
  static const addCategoryToMy = 'Add Category to My Public Listing';
  static const addSubCategoryToMy = 'Add Sub-Category to My Public Listing';
  static const helpsBuyersFindCategory = 'Helps buyers find your company under this category.';
  static const helpsBuyersFindSubCategory = 'Helps buyers find your company under this sub-category.';
  static const featuredPlacementSoon =
      'Featured placement, media galleries and per-service analytics are coming soon. They will appear here '
      'without any change to your existing services.';
}
