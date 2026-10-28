# Backend requests: requirements (RFQ)

The portal is the lead's to change. Every item is additive and leaves each existing web response unchanged. The app works without them: where one is missing the control does the nearest true thing (named below).

## 1. A supplier edits or withdraws their own quote (not built; the app messages the buyer instead)

**Why.** "My Bids" has a bid in the Submitted and Shortlisted tabs that the supplier may want to correct (price, lead time, note, files) or take back. `BidsService` has `create` (supplier), `update` (the buyer's triage) and `award` (the buyer), and nothing for the supplier's own quote after it is placed; the website has no such control either (no "withdraw" or "edit" anywhere under `components/bids` or `components/rfq`). Until then the app's "Message buyer" opens the thread with the buyer, which is how it is done today.

**Endpoints** (`backend/src/modules/rfq/rfq.controller.ts`, declared beside `createBid`, same `@Roles(VENDOR, COMPANY_ADMIN, SUPER_ADMIN)`):

```ts
@Patch(':id/bids/mine')
updateMyBid(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: UpdateMyBidDto) {
  return this.bids.updateMine(user, id, dto);
}

@Delete(':id/bids/mine')
withdrawMyBid(@CurrentUser() user: AuthUser, @Param('id') id: string) {
  return this.bids.withdrawMine(user, id);
}
```

`:id/bids/mine` must be declared **before** `@Patch(':id/bids/:bidId')`, or "mine" is read as a bid id.

**DTO** (`dto/bid.dto.ts`): the same three fields as `CreateBidDto`, all optional, plus the attachment list (sent whole, as a requirement's edit does):

```ts
export class UpdateMyBidDto extends PartialType(CreateBidDto) {}
```

**Service** (`bids.service.ts`):

```ts
/** The supplier changes their own quote while it can still be weighed. */
async updateMine(user: AuthUser, rfqId: string, dto: UpdateMyBidDto) {
  const { bid, rfq } = await this.ownOpenBid(user, rfqId);
  // Same price rule as create(): an RFQ quote keeps a price, an enquiry reply keeps a price or a message.
  const enquiry = rfq.kind === RfqKind.ENQUIRY;
  const totalAmount = dto.totalAmount !== undefined ? dto.totalAmount : bid.totalAmount;
  const message = dto.message !== undefined ? dto.message : bid.message;
  if (!enquiry && totalAmount == null) throw badRequest('errors.rfq.aQuoteNeedsYourPrice');
  if (enquiry && totalAmount == null && !message?.trim()) throw badRequest('errors.rfq.addAMessageOrAnIndicative');
  return this.prisma.quote.update({
    where: { id: bid.id },
    data: {
      ...(dto.totalAmount !== undefined ? { totalAmount: dto.totalAmount } : {}),
      ...(dto.message !== undefined ? { message: dto.message } : {}),
      ...(dto.leadTimeDays !== undefined ? { leadTimeDays: dto.leadTimeDays } : {}),
      ...(dto.attachments ? { attachments: { deleteMany: {}, create: dto.attachments.map(...as create()) } } : {}),
    },
    include: { attachments: { orderBy: { createdAt: 'asc' } } },
  });
}

/** Takes the quote back; the invitation (if there was one) is open again. */
async withdrawMine(user: AuthUser, rfqId: string) {
  const { bid, vendorId } = await this.ownOpenBid(user, rfqId);
  await this.prisma.$transaction([
    this.prisma.quote.delete({ where: { id: bid.id } }),
    this.prisma.rfqInvite.updateMany({
      where: { rfqId, vendorId, status: RfqInviteStatus.RESPONDED },
      data: { status: RfqInviteStatus.INVITED, respondedAt: null },
    }),
  ]);
  return { success: true };
}

/** The caller's own quote on a requirement that still takes responses; refuses anything settled. */
private async ownOpenBid(user: AuthUser, rfqId: string) {
  const vendor = await this.access.resolveVendor(user);
  if (!vendor) throw forbidden('errors.vendors.noSupplierListing');
  const bid = await this.prisma.quote.findUnique({ where: { rfqId_vendorId: { rfqId, vendorId: vendor.id } } });
  if (!bid) throw notFound('errors.rfq.bidNotFound');
  const rfq = await this.prisma.rfq.findUnique({ where: { id: rfqId } });
  if (!rfq || rfq.status !== RfqStatus.PUBLISHED) throw badRequest('errors.rfq.thisRequirementIsNotOpenFor');
  if (rfq.dueDate && rfq.dueDate.getTime() < Date.now()) throw badRequest('errors.rfq.theDeadlineForResponsesToThis');
  if (bid.isAwarded || bid.status === 'REJECTED') throw badRequest('errors.rfq.anAwardedBidCannotChangeStatus');
  return { bid, rfq, vendorId: vendor.id };
}
```

(`errors.rfq.*` keys are the existing ones; a withdrawn or changed quote needs no new sentence. A new key `errors.rfq.bidSettled` would word the last refusal better; add it to `errors.json` and rebuild `@icr/shared` if wanted.)

Notes: a withdrawn quote on a staged RFQ leaves the supplier's `RfqSupplierResponse` (`quoteId` goes null by `onDelete: SetNull`), so they stay shortlisted and may quote again. The buyer is not notified (no new notification key); the thread stays open for the supplier to say so.

**Unit spec** (`bids.service.spec.ts`, beside the `create` cases): an edit changes only the fields sent; an RFQ quote cannot lose its price; an enquiry reply cannot lose both price and message; an awarded or declined bid, a closed requirement and a passed deadline are refused; a withdrawal deletes the quote and re-opens the invitation; someone else's quote is `bidNotFound` (the key is the caller's vendor and the requirement, so there is no way to name another supplier's).

**App side: already built, switched off.** `RfqRepository.updateBid(rfqId, body)` / `withdrawBid(rfqId)` call `PATCH|DELETE /rfq/:id/bids/mine`; the Opportunity page's "Your bid" card has "Edit bid" (the form prefilled from a `BidDraft`) and "Withdraw" (asks first), enabled while the requirement is live and the bid is Submitted or Shortlisted. They are drawn only when `RfqRepository.supportsBidChanges` is true, which `ApiRfqRepository` leaves false until this ships (widget tests prove both states). **When the endpoints are live:** construct `ApiRfqRepository(api: ..., supportsBidChanges: true)` and flip the expectations of the live test `the portal has no call yet to change or withdraw a bid` (today `PATCH` answers 400, because it lands on the buyer's `:bidId` route with "mine" as the id, and `DELETE` 404/405).

## 2. `CreateBidDto.totalAmount` has no ceiling: 1,000,000,000,000 or more answers 500 (found by the vendor role pass, 27 Oct)

`POST /rfq/:id/bids` with `totalAmount: 1e12` answers `500 Internal server error`: the `Quote.totalAmount` column is `Decimal(14, 2)`, so a twelfth digit before the point overflows it, and the DTO only says `@Min(0)`. The app never sends it (its form refuses above 999,999,999,999, `RfqLimits.maxBidAmount`, and `test/live/role_vendor_live_test.dart` stores exactly that amount), but a client that does gets a server error instead of a sentence.

```ts
@Max(999_999_999_999.99)   // beside @Min(0) on CreateBidDto.totalAmount
```

The same applies to `budget` on a requirement if its column is the same size (not checked).

## 3. Nothing else so far

Everything else the screens use is an existing endpoint (`/rfq/*`, `/vendors/me/access`, `/notifications`, `/categories`, `/locations`, `/uploads`).
