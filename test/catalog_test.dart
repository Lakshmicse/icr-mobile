import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icr_mobile/features/catalog/catalog_models.dart';
import 'package:icr_mobile/features/catalog/catalog_photo_picker.dart';
import 'package:icr_mobile/features/catalog/catalog_repository.dart';
import 'package:icr_mobile/features/catalog/products_screen.dart';
import 'package:icr_mobile/features/catalog/services_screen.dart';

import 'helpers/account_harness.dart';
import 'helpers/fonts.dart';

/// A photo chooser that answers what a test queued, in order; null once the queue is empty (backed out).
class FakePhotoPicker extends CatalogPhotoPicker {
  FakePhotoPicker(this.queue);

  final List<PickedPhoto> queue;
  int picks = 0;

  @override
  Future<PickedPhoto?> pick() async {
    picks += 1;
    return queue.isEmpty ? null : queue.removeAt(0);
  }
}

/// A real 1×1 PNG, so the preview the editor draws from the picked bytes decodes.
final onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// My Products and My Services (the website's `/manage/products` and `/manage/services`), native since 12 Nov 2026:
/// the lists, the editors and what they send, deleting (asked first), the supplier-listing notice and the no-company
/// note.
void main() {
  setUpAll(loadAppFonts);

  late AccountHarness h;
  late DemoCatalogRepository repo;

  Future<void> pumpProducts(
    WidgetTester tester, {
    String role = 'COMPANY_ADMIN',
    String? companyId = 'co-1',
    DemoCatalogRepository? repository,
    FakePhotoPicker? picker,
    VoidCallback? onCreateCompany,
  }) async {
    repo = repository ?? DemoCatalogRepository();
    h = AccountHarness();
    await h.signIn(tester, userJson(role: role, companyId: companyId));
    usePhone(tester);
    await tester.pumpWidget(
      h.app(
        ProductsScreen(
          onBack: () {},
          repository: repo,
          photoPicker: picker ?? FakePhotoPicker([]),
          onCreateCompany: onCreateCompany,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpServices(
    WidgetTester tester, {
    String role = 'COMPANY_ADMIN',
    String? companyId = 'co-1',
    DemoCatalogRepository? repository,
  }) async {
    repo = repository ?? DemoCatalogRepository();
    h = AccountHarness();
    await h.signIn(tester, userJson(role: role, companyId: companyId));
    usePhone(tester);
    await tester.pumpWidget(h.app(ServicesScreen(onBack: () {}, repository: repo)));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  /// Taps something inside the open sheet, scrolling it into view first.
  Future<void> tapInSheet(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> typeInSheet(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, text);
    await tester.pumpAndSettle();
  }

  /// Opens a select field (its inner tap target) and picks a row of the list it shows.
  Future<void> pickFrom(WidgetTester tester, String fieldKey, String label) async {
    // The field's own InkWell comes first; a set value adds a clear button, which is an InkWell too.
    final field = find.descendant(of: find.byKey(Key(fieldKey)), matching: find.byType(InkWell)).first;
    await tapInSheet(tester, field);
    await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  bool saveEnabled(WidgetTester tester) {
    final button = find.descendant(of: find.byKey(const Key('sheet.save')), matching: find.byType(FilledButton));
    return tester.widget<FilledButton>(button).onPressed != null;
  }

  Future<void> save(WidgetTester tester) async {
    await tapInSheet(tester, find.byKey(const Key('sheet.save')));
  }

  Future<void> openRowMenu(WidgetTester tester, String rowKey, String tooltip) async {
    final row = find.byKey(Key(rowKey));
    await reveal(tester, row);
    await tester.tap(find.descendant(of: row, matching: find.byTooltip(tooltip)));
    await tester.pumpAndSettle();
  }

  group('My Products', () {
    testWidgets(
      "lists every product as the website's card: photo, name, category, price, status, strength; the tiles' figures",
      (tester) async {
        await pumpProducts(tester);
        expect(find.text('My Products'), findsOneWidget);
        expect(
          find.text(
            'Manage the products your company offers. Add them to your ICR supplier profile and make them '
            'discoverable to buyers across the marketplace.',
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: find.byKey(const Key('catalog.add')), matching: find.text('Add Product')),
          findsOneWidget,
        );
        expect(
          find.text('3 products · 2 categories · 1/3 with a photo · Listing Strength 67% average across your products'),
          findsOneWidget,
        );
        expect(find.text('2 without a photo'), findsOneWidget);
        expect(find.text('1 without a price'), findsOneWidget);
        expect(find.text('1 without a category'), findsOneWidget);
        await reveal(tester, find.byKey(const Key('product.p-1')));
        expect(find.text('Biometric Access Terminal'), findsOneWidget);
        expect(find.text('Access Control'), findsWidgets);
        expect(tester.widget<Text>(find.byKey(const Key('product.price.p-1'))).data, '₹18,500 / piece');
        expect(
          find.descendant(of: find.byKey(const Key('product.status.p-1')), matching: find.text('Complete')),
          findsOneWidget,
        );
        expect(tester.widget<Text>(find.byKey(const Key('product.price.p-2'))).data, '₹499.50 / can');
        expect(
          find.descendant(of: find.byKey(const Key('product.status.p-2')), matching: find.text('No Photo')),
          findsOneWidget,
        );
        await reveal(tester, find.byKey(const Key('product.p-3')));
        expect(tester.widget<Text>(find.byKey(const Key('product.price.p-3'))).data, 'Price on Request');
        expect(find.text('No Category'), findsOneWidget);
        expect(find.text('No description yet. Buyers compare on specifications and pack size.'), findsOneWidget);
        expect(find.byType(Card), findsNothing, reason: 'rows the whole width, hairlines between');
        expect(find.byKey(const Key('catalog.noListing')), findsNothing, reason: 'the company sells');
      },
    );

    testWidgets(
      "adding through the sheet sends the website's fields and nothing blank; the terms say what buyers see",
      (tester) async {
        await pumpProducts(tester);
        await tester.tap(find.byKey(const Key('catalog.add')));
        await tester.pumpAndSettle();
        expect(find.text('Add a Product'), findsOneWidget);
        expect(find.text('It will appear on your supplier listing and the marketplace product grid.'), findsOneWidget);
        expect(saveEnabled(tester), isFalse, reason: 'a product needs a name');

        await typeInSheet(tester, 'product.name', 'Taski R3 Cleaner 5L');
        expect(saveEnabled(tester), isTrue);
        await pickFrom(tester, 'catalog.category', 'Facility Management');
        await pickFrom(tester, 'catalog.subcategory', 'Housekeeping');
        await typeInSheet(tester, 'product.price', '499.5');
        await tapInSheet(tester, find.byKey(const Key('suggest.piece')));
        await pickFrom(tester, 'product.availability', 'In Stock');
        await typeInSheet(tester, 'product.term.warrantyMonths', '12');
        expect(find.text('Buyers see “1-year warranty”.'), findsOneWidget);
        await typeInSheet(tester, 'product.term.bulkPricingMinQty', '1');
        expect(find.text('Enter a value between 2 and 10,00,000.'), findsOneWidget);
        expect(saveEnabled(tester), isFalse, reason: 'an out-of-range term blocks the save');
        await typeInSheet(tester, 'product.term.bulkPricingMinQty', '50');
        expect(find.text('Buyers see “Bulk pricing from 50 piece”.'), findsOneWidget);

        await save(tester);
        expect(repo.sent.last, {
          'op': 'createProduct',
          'body': {
            'name': 'Taski R3 Cleaner 5L',
            'price': 499.5,
            'unit': 'piece',
            'availability': 'IN_STOCK',
            'warrantyMonths': 12,
            'bulkPricingMinQty': 50,
            'categoryKey': 'HOUSEKEEPING',
            'companyId': 'co-1',
          },
        });
        expect(find.text('Product published.'), findsOneWidget);
        await reveal(tester, find.text('Taski R3 Cleaner 5L'));
        expect(find.text('Taski R3 Cleaner 5L'), findsOneWidget, reason: 'the list is read again after the save');
      },
    );

    testWidgets('a photo goes up as it is picked and rides in the body; the wrong type and a big file are refused', (
      tester,
    ) async {
      final picker = FakePhotoPicker([
        PickedPhoto(bytes: onePixelPng, name: 'photo.gif'),
        PickedPhoto(bytes: List.filled(catalogPhotoMaxBytes + 1, 0), name: 'huge.png'),
        PickedPhoto(bytes: onePixelPng, name: 'photo.png'),
      ]);
      await pumpProducts(tester, picker: picker);
      await tester.tap(find.byKey(const Key('catalog.add')));
      await tester.pumpAndSettle();

      await tapInSheet(tester, find.byKey(const Key('product.photo.upload')));
      expect(find.text('Use a PNG, JPG or WEBP image.'), findsOneWidget);
      await tapInSheet(tester, find.byKey(const Key('product.photo.upload')));
      expect(find.text('This image is over 2MB. Compress it or select a smaller one.'), findsOneWidget);
      expect(repo.sent, isEmpty, reason: 'a refused file never reaches the API');

      await tapInSheet(tester, find.byKey(const Key('product.photo.upload')));
      expect(repo.sent.last['op'], 'uploadPhoto');
      expect((repo.sent.last['body'] as Map)['type'], 'image/png');
      expect(find.byKey(const Key('product.photo.replace')), findsOneWidget);
      expect(find.byKey(const Key('product.photo.remove')), findsOneWidget);

      await typeInSheet(tester, 'product.name', 'Visitor Badge Roll');
      await save(tester);
      expect(repo.sent.last['op'], 'createProduct');
      expect((repo.sent.last['body'] as Map)['imageUrl'], '/uploads/demo-100-photo.png');
    });

    testWidgets('editing sends every field, blanks as null, and the category only when it was changed', (tester) async {
      await pumpProducts(tester);
      await reveal(tester, find.byKey(const Key('product.p-2')));
      await tester.tap(find.byKey(const Key('product.p-2')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Product'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('product.name'))).controller!.text,
        'Industrial Floor Cleaner 5L',
      );
      expect(tester.widget<TextField>(find.byKey(const Key('product.price'))).controller!.text, '499.5');
      expect(find.text('Housekeeping'), findsWidgets, reason: 'the stored key is placed in the tree');

      await typeInSheet(tester, 'product.description', 'Dilutes 1:50 for scrubber-driers.');
      await save(tester);
      expect(repo.sent.last, {
        'op': 'updateProduct',
        'id': 'p-2',
        'body': {
          'name': 'Industrial Floor Cleaner 5L',
          'description': 'Dilutes 1:50 for scrubber-driers.',
          'price': 499.5,
          'unit': 'can',
          'imageUrl': null,
          'availability': null,
          'warrantyMonths': null,
          'returnDays': null,
          'freeDeliveryOver': null,
          'bulkPricingMinQty': null,
        },
      });
      expect(find.text('Product updated.'), findsOneWidget);
    });

    testWidgets('a changed category is sent as its key; clearing it sends an empty key', (tester) async {
      await pumpProducts(tester);
      await reveal(tester, find.byKey(const Key('product.p-2')));
      await tester.tap(find.byKey(const Key('product.p-2')));
      await tester.pumpAndSettle();
      await pickFrom(tester, 'catalog.category', 'Safety & Security');
      await pickFrom(tester, 'catalog.subcategory', 'Fire Safety');
      await save(tester);
      expect((repo.sent.last['body'] as Map)['categoryKey'], 'FIRE_SAFETY');
    });

    testWidgets('leaving an edited sheet asks before discarding', (tester) async {
      await pumpProducts(tester);
      await tester.tap(find.byKey(const Key('catalog.add')));
      await tester.pumpAndSettle();
      await typeInSheet(tester, 'product.name', 'Half typed');
      await tester.tap(find.byKey(const Key('sheet.cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Discard Your Changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(find.text('Add a Product'), findsNothing);
      expect(repo.sent, isEmpty);
    });

    testWidgets("the row's menu: delete asks first with the website's words, then sends; duplicate copies", (
      tester,
    ) async {
      await pumpProducts(tester);
      await openRowMenu(tester, 'product.p-3', 'Product actions');
      expect(find.text('View as Buyer'), findsOneWidget);
      await tester.tap(find.byKey(const Key('row.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Visitor Badge Printer”?'), findsOneWidget);
      expect(
        find.text(
          'It will be removed from your supplier listing and the marketplace immediately. Links to it will stop working.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty, reason: 'Cancel sends nothing');
      expect(find.byKey(const Key('product.p-3')), findsOneWidget);

      await openRowMenu(tester, 'product.p-3', 'Product actions');
      await tester.tap(find.byKey(const Key('row.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {'op': 'deleteProduct', 'id': 'p-3'});
      expect(find.byKey(const Key('product.p-3')), findsNothing);
      expect(find.text('Product deleted.'), findsOneWidget);

      await openRowMenu(tester, 'product.p-2', 'Product actions');
      await tester.tap(find.byKey(const Key('row.duplicate')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'createProduct',
        'body': {
          'companyId': 'co-1',
          'name': 'Industrial Floor Cleaner 5L (copy)',
          'description': 'Low-foam alkaline cleaner for scrubber-driers; one litre dilutes to 50.',
          'price': 499.5,
          'unit': 'can',
          'categoryKey': 'HOUSEKEEPING',
        },
      });
      expect(find.text('Product duplicated. Edit the copy to make it a separate product.'), findsOneWidget);
    });

    testWidgets('Select picks several and the bar deletes them together, asked first', (tester) async {
      await pumpProducts(tester);
      await tester.tap(find.byKey(const Key('catalog.select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog.selectAll')));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      await tester.tap(find.byKey(const Key('catalog.bulk.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete 3 Products?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.sent.where((s) => s['op'] == 'deleteProduct').length, 3);
      expect(find.text('3 products deleted.'), findsOneWidget);
      expect(find.text('No Products Listed Yet'), findsOneWidget);
    });

    testWidgets('search, the completeness filter and the category chips narrow the list; nothing left says so', (
      tester,
    ) async {
      await pumpProducts(tester);
      await tester.tap(find.byKey(const Key('catalog.todo.noPrice')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('product.p-3')));
      expect(find.byKey(const Key('product.p-1')), findsNothing);
      await tester.tap(find.byKey(const Key('catalog.todo.noPrice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog.category.c-hk')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('product.p-2')));
      expect(find.byKey(const Key('product.p-1')), findsNothing);
      await tester.enterText(find.byKey(const Key('catalog.search')), 'nothing like this');
      await tester.pumpAndSettle();
      expect(find.text('No Products Match'), findsOneWidget);
      await tester.tap(find.byKey(const Key('catalog.clearFilters')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('product.p-1')));
      expect(find.byKey(const Key('product.p-1')), findsOneWidget);
    });

    testWidgets("with no supplier listing the website's notice shows, and Start selling creates it in place", (
      tester,
    ) async {
      await pumpProducts(tester, repository: DemoCatalogRepository(hasListing: false));
      expect(find.byKey(const Key('catalog.noListing')), findsOneWidget);
      expect(
        find.text(
          'Your company does not sell on ICR yet. Start selling to appear in the Marketplace and respond to buyers’ '
          'requirements.',
        ),
        findsOneWidget,
      );
      await reveal(tester, find.byKey(const Key('product.p-1')));
      expect(
        find.text('Biometric Access Terminal'),
        findsOneWidget,
        reason: 'the catalogue belongs to the company either way',
      );
      // Back up to the notice, which sits above the list.
      await tester.scrollUntilVisible(
        find.byKey(const Key('catalog.startSelling')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog.startSelling')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {
        'op': 'startSelling',
        'body': {'companyId': 'co-1'},
      });
      expect(find.byKey(const Key('catalog.noListing')), findsNothing);
    });

    testWidgets("someone acting for no company sees the website's NoCompany, with Create a company when offered", (
      tester,
    ) async {
      var created = false;
      await pumpProducts(tester, companyId: null, onCreateCompany: () => created = true);
      expect(find.byKey(const Key('catalog.noCompany')), findsOneWidget);
      expect(find.text("Your Account Isn't Linked to a Company"), findsOneWidget);
      expect(find.textContaining('Jobs, products and services belong to a company.'), findsOneWidget);
      expect(find.byKey(const Key('catalog.list')), findsNothing);
      await tester.tap(find.byKey(const Key('catalog.createCompany')));
      expect(created, isTrue);
    });

    testWidgets('a role that does not manage the catalogue is told', (tester) async {
      await pumpProducts(tester, role: 'RECRUITER');
      expect(find.byKey(const Key('catalog.notYours')), findsOneWidget);
      expect(find.byKey(const Key('catalog.list')), findsNothing);
    });

    testWidgets("nothing yet shows the website's empty state with its three steps", (tester) async {
      await pumpProducts(tester, repository: DemoCatalogRepository(products: []));
      expect(find.text('No Products Listed Yet'), findsOneWidget);
      expect(
        find.text('Showcase the products you offer to help buyers discover your offerings and request quotations.'),
        findsOneWidget,
      );
      expect(find.text('Product Image'), findsOneWidget);
      expect(find.text('Add a clear, high-quality photo.'), findsOneWidget);
      expect(find.text('Product Category'), findsOneWidget);
      expect(find.text('Select the right category for easy discovery.'), findsOneWidget);
      expect(find.text('Unit Price'), findsOneWidget);
      expect(
        find.text('Or leave it blank for “Price on Request”.'),
        findsOneWidget,
        reason: 'the editor has no choice to select',
      );
      expect(
        find.descendant(of: find.byKey(const Key('catalog.addFirst')), matching: find.text('Add Your First Product')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('catalog.stats')), findsNothing);
      await tester.tap(find.byKey(const Key('catalog.addFirst')));
      await tester.pumpAndSettle();
      expect(find.text('Add a Product'), findsOneWidget);
    });

    testWidgets("the plan's listing places count products and services together", (tester) async {
      await pumpProducts(tester, repository: DemoCatalogRepository(listingLimit: 10));
      expect(find.text('6 of 10 listing places used'), findsOneWidget);
      expect(find.text('3 products and 3 services. Your plan counts them together.'), findsOneWidget);
      expect(find.byKey(const Key('catalog.seePlans')), findsNothing);
    });

    testWidgets('a list that cannot be read says so and can be tried again', (tester) async {
      await pumpProducts(tester, repository: DemoCatalogRepository(failList: true));
      expect(find.byKey(const Key('catalog.loadError')), findsOneWidget);
      expect(find.text('Could not load the catalogue.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets("a refused save keeps the sheet open with the API's sentence", (tester) async {
      await pumpProducts(tester, repository: DemoCatalogRepository(failWrites: true));
      await tester.tap(find.byKey(const Key('catalog.add')));
      await tester.pumpAndSettle();
      await typeInSheet(tester, 'product.name', 'One too many');
      await save(tester);
      expect(find.byKey(const Key('sheet.error')), findsOneWidget);
      expect(find.textContaining('Your plan lists up to 3 products and services.'), findsOneWidget);
      expect(find.text('Add a Product'), findsOneWidget);
    });
  });

  group('My Services', () {
    testWidgets("lists every service as the website's card, with the tiles' figures", (tester) async {
      await pumpServices(tester);
      expect(find.text('My Services'), findsOneWidget);
      expect(
        find.text(
          "Manage and showcase your company's services to improve marketplace visibility and attract buyer enquiries.",
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('catalog.add')), matching: find.text('Add Service')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Services Listed: 3 · Service Categories: 2 · Average Starting Price: ₹50,000 · Listing Quality: 76% · '
          'With Turnaround: 2/3 · Best-Completed Listing: Daily Office Housekeeping',
        ),
        findsOneWidget,
      );
      expect(find.text('Search Services'), findsOneWidget, reason: 'the search box hint');
      expect(
        find.descendant(of: find.byKey(const Key('catalog.filter')), matching: find.text('All Statuses')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('catalog.sort')), matching: find.text('Recently Added')),
        findsOneWidget,
      );
      expect(find.text('Housekeeping (2)'), findsOneWidget, reason: 'the category chips with their counts');
      await reveal(tester, find.byKey(const Key('service.s-1')));
      expect(find.text('Daily Office Housekeeping'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('service.category.s-1'))).data, 'Housekeeping');
      expect(
        find.descendant(of: find.byKey(const Key('service.s-1')), matching: find.text('Listing Quality')),
        findsOneWidget,
        reason: "a row's score is named as the figures name it",
      );
      expect(
        find.descendant(of: find.byKey(const Key('service.price.s-1')), matching: find.text('₹85,000 per month')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('service.status.s-1')), matching: find.text('Optimized')),
        findsOneWidget,
      );
      expect(find.text('48 hours to mobilise'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('service.s-2')));
      expect(
        find.descendant(of: find.byKey(const Key('service.price.s-2')), matching: find.text('No price set')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('service.status.s-2')), matching: find.text('Add 2 Details')),
        findsOneWidget,
      );
      await reveal(tester, find.byKey(const Key('service.s-3')));
      expect(tester.widget<Text>(find.byKey(const Key('service.category.s-3'))).data, 'Safety & Security');
      expect(find.text('No description yet. Add one to help buyers understand this service.'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets("adding through the sheet needs a name and a category, and sends the website's body", (tester) async {
      await pumpServices(tester);
      await tester.tap(find.byKey(const Key('catalog.add')));
      await tester.pumpAndSettle();
      expect(find.text('Add a Service'), findsOneWidget);
      await typeInSheet(tester, 'service.name', 'Deep Cleaning');
      expect(saveEnabled(tester), isFalse, reason: 'a service needs a category too');
      await pickFrom(tester, 'catalog.category', 'Facility Management');
      expect(saveEnabled(tester), isTrue);
      await pickFrom(tester, 'catalog.subcategory', 'Pest Control');
      expect(find.text('Add Sub-Category to My Public Listing'), findsOneWidget);
      await typeInSheet(tester, 'service.rate', '1200');
      await tapInSheet(tester, find.byKey(const Key('suggest.per visit')));
      await typeInSheet(tester, 'service.turnaround', '24 hours');
      await save(tester);
      expect(repo.sent.last, {
        'op': 'createService',
        'body': {
          'name': 'Deep Cleaning',
          'category': 'FACILITY_MANAGEMENT',
          'subcategory': 'PEST_CONTROL',
          'rate': 1200,
          'rateUnit': 'per visit',
          'turnaroundTime': '24 hours',
          'companyId': 'co-1',
          'addToListing': true,
        },
      });
      expect(find.text('Service published.'), findsOneWidget);
    });

    testWidgets('editing sends every field with blanks as null; the switch is for a new service only', (tester) async {
      await pumpServices(tester);
      await reveal(tester, find.byKey(const Key('service.s-3')));
      await tester.tap(find.byKey(const Key('service.s-3')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Service'), findsOneWidget);
      expect(find.byKey(const Key('service.addToListing')), findsNothing);
      await typeInSheet(tester, 'service.rate', '');
      await typeInSheet(tester, 'service.description', 'Statutory audit with report.');
      await save(tester);
      expect(repo.sent.last, {
        'op': 'updateService',
        'id': 's-3',
        'body': {
          'name': 'Annual Fire Audit',
          'category': 'SAFETY_SECURITY',
          'subcategory': null,
          'description': 'Statutory audit with report.',
          'rate': null,
          'rateUnit': 'per visit',
          'turnaroundTime': null,
        },
      });
      expect(find.text('Service updated.'), findsOneWidget);
    });

    testWidgets("a row's 'Add …' chip opens the editor on that service", (tester) async {
      await pumpServices(tester);
      await reveal(tester, find.byKey(const Key('service.status.s-2')));
      await tester.tap(find.byKey(const Key('service.status.s-2')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Service'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('service.name'))).controller!.text, 'Drone Facade Cleaning');
    });

    testWidgets('delete asks first, then sends; Cancel keeps the row', (tester) async {
      await pumpServices(tester);
      await openRowMenu(tester, 'service.s-2', 'Service actions');
      await tester.tap(find.byKey(const Key('row.delete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete “Drone Facade Cleaning”?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.sent, isEmpty);
      await openRowMenu(tester, 'service.s-2', 'Service actions');
      await tester.tap(find.byKey(const Key('row.delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm.ok')));
      await tester.pumpAndSettle();
      expect(repo.sent.last, {'op': 'deleteService', 'id': 's-2'});
      expect(find.byKey(const Key('service.s-2')), findsNothing);
      expect(find.text('Service deleted.'), findsOneWidget);
    });

    testWidgets("with no supplier listing the website's notice shows above the services", (tester) async {
      await pumpServices(tester, repository: DemoCatalogRepository(hasListing: false));
      expect(find.byKey(const Key('catalog.noListing')), findsOneWidget);
      await tester.tap(find.byKey(const Key('catalog.startSelling')));
      await tester.pumpAndSettle();
      expect(repo.sent.last['op'], 'startSelling');
      expect(find.byKey(const Key('catalog.noListing')), findsNothing);
    });

    testWidgets("someone acting for no company sees the website's NoCompany", (tester) async {
      await pumpServices(tester, companyId: null);
      expect(find.byKey(const Key('catalog.noCompany')), findsOneWidget);
      expect(find.byKey(const Key('catalog.createCompany')), findsNothing, reason: 'hidden until the lead wires it');
    });

    testWidgets("nothing yet shows the website's empty state", (tester) async {
      await pumpServices(tester, repository: DemoCatalogRepository(services: []));
      expect(find.text('No Services Listed Yet'), findsOneWidget);
      expect(
        find.text(
          "Add your company's services to showcase your expertise, improve discoverability and receive relevant "
          'buyer enquiries.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('catalog.addFirst')), matching: find.text('Add Your First Service')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('catalog.addFirst')));
      await tester.pumpAndSettle();
      expect(find.text('Add a Service'), findsOneWidget);
    });
  });

  group('the models', () {
    test('a product scores the six signals and words its one gap as the website does', () {
      const full = ProductItem(
        id: 'x',
        name: 'A',
        description: 'd',
        price: 10,
        unit: 'piece',
        imageUrl: '/uploads/a.png',
        category: ProductCategoryRef(id: 'c', name: 'C'),
      );
      expect(full.score, 100);
      expect(full.status.label, 'Complete');
      const noUnit = ProductItem(
        id: 'y',
        name: 'B',
        description: 'd',
        price: 10,
        imageUrl: '/uploads/a.png',
        category: ProductCategoryRef(id: 'c', name: 'C'),
      );
      expect(noUnit.status.label, 'Add Unit');
      expect(ProductItem.priceOf('0'), isNull, reason: 'zero is "on request"');
      expect(ProductItem.priceOf('499.5'), 499.5);
      expect(formatProductPrice(1450.5, 'kg'), '₹1,450.50 / kg');
      expect(productTermError(ProductTerm.freeDeliveryOver, '10000001'), 'Enter a value between ₹0 and ₹1,00,00,000.');
      expect(productTermError(ProductTerm.warrantyMonths, '1.5'), 'Enter a whole number.');
      expect(freeDeliveryLabel(0), 'Free delivery');
      expect(warrantyLabel(18), '18-month warranty');
    });

    test('a service scores the seven signals; its health drives the filter', () {
      const legacy = ServiceItem(
        id: 's',
        name: 'A',
        category: 'FACILITY_MANAGEMENT',
        description: 'd',
        rate: 1,
        rateUnit: 'per visit',
        turnaroundTime: '1 day',
      );
      expect(legacy.score, 86, reason: 'filed only at category level: 6/7 until edited');
      expect(legacy.status.label, 'Add Sub-Category');
      expect(legacy.health, ServiceHealth.improve);
      expect(const ServiceItem(id: 't', name: 'B', category: 'X').health, ServiceHealth.noPrice);
    });

    test('the sorts order by price with the unpriced last, and by what needs work first', () {
      final rows = DemoCatalogRepository.sampleProducts();
      expect(sortCatalog(rows, CatalogSort.priceAsc).map((p) => p.id), ['p-2', 'p-1', 'p-3']);
      expect(sortCatalog(rows, CatalogSort.priceDesc).map((p) => p.id), ['p-1', 'p-2', 'p-3']);
      expect(sortCatalog(rows, CatalogSort.leastComplete).map((p) => p.id), ['p-3', 'p-2', 'p-1']);
      expect(sortCatalog(rows, CatalogSort.recent).map((p) => p.id), ['p-3', 'p-2', 'p-1']);
    });
  });
}
