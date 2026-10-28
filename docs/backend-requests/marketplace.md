# Backend requests: Marketplace

The portal is the lead's to change. Every item is additive and leaves each existing web response unchanged. The app works without any of them: where one is missing the screen shows the nearest true thing (named below), and each item says what the app already reads, so it starts showing the new data the day the API sends it.

## 1. A stable order across pages (a bug the app already feels)

**Why.** `GET /vendors` orders by `isPremium desc, planPriority desc, verificationLevel desc`, then the chosen sort (`rating`, `ratingCount`...). Two suppliers equal on all four have no fixed order, so Postgres may return them in a different order on the next page's query: a supplier can appear on two pages, or on none. The seeded directory has seven "InnoWork" companies of the same rating, so it shows up on the local database; a real directory has ties on `ratingCount` and `yearsExperience` all the time. The app drops a supplier it has already got when "Load more suppliers" repeats one (`MarketplaceController.loadMore`), but it cannot find one that was skipped.

**Diff** (`backend/src/modules/vendors/vendors.service.ts`, `findAll`'s `orderBy`): add a last key that is unique.

```ts
orderBy: [
  { isPremium: 'desc' },
  { planPriority: 'desc' },
  { verificationLevel: 'desc' },
  query.sortBy === 'projectsCompleted'
    ? { projectsCompleted: { sort: query.sortDir ?? 'desc', nulls: 'last' as const } }
    : buildOrderBy(query.sortBy, query.sortDir, SORTABLE, 'rating'),
  { id: 'asc' },   // <- new: a tie is broken the same way on every page
],
```

The same one-line tiebreaker belongs in `ServicesService.findAll` and `ProductsService.findAll` (`orderBy: buildOrderBy(..., SORTABLE)` followed by `{ id: 'asc' }`), whose pages the profile and the catalogue boards page through. The web's first page is unchanged except among exact ties.

## 2. The company registration number on a supplier's profile ("Reg. CIN-U74999KA2019PTC1")

**Why.** The profile design draws "Pvt Ltd • Reg. CIN-U74999KA2019PTC1" under the supplier's name. The portal stores no CIN (and publishes neither GSTIN nor PAN, correctly). The only registration number a listing publishes is `Vendor.msmeNumber`, the self-declared Udyam number, so a live profile reads "Pvt Ltd • Reg. UDYAM-..." and the design's line is a local seed trick (`tool/seed/marketplace.ts` writes the design's CIN into `msmeNumber`).

**Diff.** A nullable column and its read; the app already reads `company.cin` and prefers it over the Udyam number (`Supplier.registrationNumber`).

```prisma
// schema.prisma, model Company, beside legalStructure
/// Corporate Identity Number (MCA) or LLPIN: public registry data, shown on the supplier profile.
cin String?
```

```ts
// vendors.service.ts findOne, in the company select, beside legalStructure
cin: true,
```

plus `cin` on `CreateCompanyDto` / `CreateMyCompanyDto` / `COMPANY_FIELDS` if members are to enter it (`@IsOptional() @IsString() @MaxLength(21)`), with a migration file (`npm run db:migrate -w backend`). Nothing on the web changes until it chooses to print the field.

## 3. A photo on a service (the Products & services tab draws one per service)

**Why.** Each row of the profile's Products & services tab has a 64 x 64 dp photo (the design's drone, crawler, vacuum...). `Service` has no image column (a `Product` has `imageUrl`), so a live service row draws a tile with the service's first letter instead.

**Diff.** The same shape as a product's `imageUrl`:

```prisma
// model Service
imageUrl String?
```

and `imageUrl` in `CreateServiceDto` / `UpdateServiceDto` (`@IsOptional() @IsString() @MaxLength(500)`, a path under `/uploads`, not `@IsUrl()`: stored uploads are relative). The reads return the whole row already. The app reads `imageUrl` today (`CatalogService.imageUrl`), so nothing changes in the app.

## 4. Observation (no change asked): ratings carry the author's user id

`GET /vendors/:id` returns `ratings: [{ id, vendorId, authorId, score, comment, createdAt }]` (the whole `VendorRating` row), while the website's own review card says "names are not published". The app ignores `authorId` and shows "Verified buyer", but the id is a member id on a public endpoint. If the web may stop receiving it: `select: { id: true, score: true, comment: true, createdAt: true }` on `ratings` in `VendorsService.findOne`. It would change the web response, so it is left to the lead.

## 5. A quote request to one's own listing says why it is refused (found by the vendor role pass, 27 Oct)

A supplier who opens their own profile is offered the same bar as a buyer: *Request for Quote (RFQ)*, the message icon and *Rate this supplier*. The API refuses each, and two of its sentences are exact (`You cannot rate your own listing.`, `This is your own listing.`), but `POST /rfq` with `visibility TARGETED` and `vendorIds: [own listing]` answers `No valid companies to invite.`, which does not say that the company asked itself. Additive: when every `vendorIds` entry is the caller's own company, answer `This is your own listing.` as the messaging endpoint does. (The app's side, hiding the three controls on a listing the viewer owns, needs the viewer's company id in the sheet; `GET /vendors/:id` carries no `isOwner`, so an `isOwn: true` beside `rating` would let it.)

