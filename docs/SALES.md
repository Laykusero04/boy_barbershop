# Sales documentation

This document explains how **Sales** work in the app: data model, Firestore fields, how sales are created/updated/deleted, and how screens compute totals and earnings.

## Firestore: `sales` collection

Defined in `lib/data/firestore_collections.dart` as `FirestoreCollections.sales(db)`.

Each sale document stores:

- **`barber_id`** *(String)*: Firestore document id from `barbers`.
- **`service_id`** *(String)*: Firestore document id from `services`.
- **`price`** *(number)*: final charged amount (after promo/discount, if any). Must be \(\ge 0\).
- **`sale_day`** *(String)*: `YYYY-MM-DD` in **Asia/Manila** (used for most reporting).
- **`sale_datetime`** *(Timestamp)*: server timestamp of creation (used for ordering / range queries).
- **`payment_method`** *(String | null)*: optional label (e.g. `Cash`, `GCash`).
- **`notes`** *(String | null)*: optional free text.
- **Promo fields (optional)**:
  - **`promo_id`** *(String)*: promo document id.
  - **`original_price`** *(number)*: price before promo.
  - **`discount_amount`** *(number)*: discount applied.
- **Auditing**:
  - **`created_by_uid`** *(String | null)*: user uid that created the sale.
  - **`created_at`** *(Timestamp)*: server timestamp.
  - **`updated_at`** *(Timestamp)*: server timestamp (set on edit).

Client-side model: `lib/models/sale.dart` (`Sale.fromDoc`).

## Creating a sale

UI entrypoint: `lib/presentation/screens/add_sale_screen.dart` (**Add sale** tab).

Flow:

- User selects **Barber**, **Service**, enters **Price**, selects optional **Promo**, optional **Payment method**, optional **Notes**.
- Screen creates a `SaleCreate` object (`lib/models/sale_create.dart`) and calls:
  - `SalesRepository.createSale(...)` (`lib/data/sales_repository.dart`)

Validation (repository):

- `price` must be \(\ge 0\), not NaN/Infinity
- `barberId` required
- `serviceId` required
- `saleDayManila` must match `YYYY-MM-DD`

Write behavior:

- Writes to Firestore `sales` with `sale_datetime: FieldValue.serverTimestamp()` and `sale_day` as Manila day string.

### Cashflow side-effect (cash payments)

`SalesRepository` may be constructed with a `CashflowRepository` (it is in `AddSaleScreen`).

If the payment method is considered **cash** (`Cash`, or anything starting with `cash`, case-insensitive), `createSale` also creates a cashflow entry via:

- `CashflowRepository.createCashInForSale(...)` (`lib/data/cashflow_repository.dart`)

This creates a document in `cashflow_entries` with:

- `reference_sale_id = <saleId>`
- `flow_type = cashIn`
- `category = "Cash sale"` (default)
- `amount = sale price`
- `occurred_day = sale_day`
- `occurred_at = serverTimestamp()`

This cashflow write is **best-effort**: if it fails, the sale still saves.

## Editing a sale

Sales can be edited from:

- `AddSaleScreen` (**Sales** tab): edit dialog updates selected fields
- `DashboardScreen`: edit dialog updates selected fields

Repository method:

- `SalesRepository.updateSaleFields(...)`

Fields updated:

- `price`
- `payment_method`
- `notes`
- `updated_at = serverTimestamp()`

Important: edits do **not** change `barber_id`, `service_id`, `sale_day`, or `sale_datetime`.

Cashflow note: `updateSaleFields` does **not** update cashflow entries. Only **delete** cleans up cashflow links (see below).

## Deleting a sale

Repository method:

- `SalesRepository.deleteSale(saleId)`

Behavior:

- Deletes the sale document.
- If `SalesRepository` was created with a `CashflowRepository`, it also deletes any `cashflow_entries` that reference the sale via `reference_sale_id`.

## Querying / listing sales

SalesRepository provides multiple readers for different reliability needs:

- **Day view (fast ordering)**: `watchSalesForDay(saleDay, limit)`
  - Queries: `where('sale_day' == day)` + `orderBy('sale_datetime', desc)`
  - Sorted again client-side because `sale_datetime` can be temporarily null after `serverTimestamp`.

- **Day view (safe)**: `watchSalesForDaySafe(saleDay, limit)`
  - Does **not** order by `sale_datetime` (useful when legacy docs have invalid `sale_datetime` types).

- **Range by Manila days**: `watchSalesForRangeDays(startDay, endDay, limit)`
  - Queries on `sale_day` and orders by `sale_day`, then sorts client-side.

- **Range by UTC timestamps**: `watchSalesForRangeUtc(startUtcInclusive, endUtcExclusive, limit)`
  - Queries on `sale_datetime` timestamp range (useful for true timestamp windows).

- **Fetch (one-time) for multiple days**:
  - `fetchSalesForDays(...)` (orders by `sale_datetime`)
  - `fetchSalesForDaysSafe(...)` (no ordering by `sale_datetime`)

## Totals and reporting

### Dashboard totals

Dashboard KPIs use `lib/presentation/screens/dashboard/dashboard_logic.dart`:

- **Sales total**: sum of `Sale.price`
- **Estimated barber share total**:
  - If a barber is **percentage-based**: add `sale.price * (percentageShare/100)`
  - If a barber is **daily-rate**: add `dailyRate` once per `(barber_id, sale_day)` pair that has at least one sale
- **Net profit estimate**: `salesTotal - barberShareTotal - expensesTotal`

### Daily report (Reports screen)

`lib/presentation/screens/reports_screen.dart` (Daily tab) shows:

- total sales + sales grouped by payment method (from sales documents)
- expenses grouped by category (from expenses documents)
- cashflow drawer totals (from cashflow entries)

## Barber earnings rules (reference)

Barber pay configuration is stored on the barber document (see `lib/models/barber.dart`):

- **Percentage**: earnings are a percentage of sales.
- **Daily rate**: earnings are computed as `dailyRate * numberOfDistinctSaleDaysWithAtLeastOneSale`.

Where it’s displayed:

- `AddSaleScreen` daily breakdown totals use the same rule.
- `DashboardScreen` earnings card and sale tiles display daily-rate vs percent appropriately.

