# Payment Methods documentation

This document explains how **Payment Methods** are stored and used, and how they affect Sales and Cashflow.

## Firestore: `payment_methods` collection

Defined in `lib/data/firestore_collections.dart` as `FirestoreCollections.paymentMethods(db)`.

Each payment method document stores:

- **`name`** *(String)*: display name (e.g. `Cash`, `GCash`, `Card`).
- **`is_active`** *(bool)*: when `false`, the method is hidden from pickers (but existing sales keep their stored text).
- **Auditing**:
  - **`created_at`** *(Timestamp)*: server timestamp.
  - **`updated_at`** *(Timestamp)*: server timestamp.

Client-side model: `lib/models/payment_method_item.dart` (`PaymentMethodItem`).

## Creating / editing / deactivating

UI entrypoint: `lib/presentation/screens/payment_methods_screen.dart`

Repository: `lib/data/payment_methods_repository.dart` (`PaymentMethodsRepository`)

- **Create**: `create(name: ...)`
  - Validates name is not empty
  - Writes `{ name, is_active: true, created_at, updated_at }`
- **Edit**: `update(id: ..., name: ...)`
  - Updates `{ name, updated_at }`
- **Deactivate**: `deactivate(id: ...)`
  - Updates `{ is_active: false, updated_at }`

Listing/sorting:

- `watchAll()` lists all methods, then sorts active first, then by `created_at` when available.

## Using payment methods in Sales

### Picker (active methods only)

Sales screens show a dropdown fed by:

- `CatalogRepository.watchActivePaymentMethods()` (`lib/data/catalog_repository.dart`)
  - Filters to `is_active == true`

### How sales store the method

Sales do **not** store a payment method *id*. They store the method as **text**:

- Sale field **`payment_method`** *(String | null)* in `sales` documents
- Client model: `Sale.paymentMethod` (`lib/models/sale.dart`)

This is why deactivating or renaming a method does **not** rewrite old sales. Old sales keep whatever `payment_method` string was saved at the time.

## Cash payments and cashflow linkage

When a sale is created (`SalesRepository.createSale` in `lib/data/sales_repository.dart`), the app checks the payment method name. If it looks like **cash**, it also creates a `cashflow_entries` record for the drawer/ledger.

Cash detection rule:

- true if the payment method string is `cash` or starts with `cash` (case-insensitive)

Side-effect for cash:

- `CashflowRepository.createCashInForSale(...)` creates a cash-in entry linked by:
  - `reference_sale_id = <saleId>`

Important behaviors:

- Cashflow write is **best-effort** (sale still saves even if cashflow fails).
- Editing a sale’s `payment_method` later does **not** update cashflow entries automatically.
- Deleting a sale cleans up linked cashflow entries (if the `SalesRepository` instance was created with a `CashflowRepository`).

## Where payment methods appear

- **Add Sale**: optional dropdown; saved into `sales.payment_method`
- **Dashboard**: edit sale dialog includes payment method (optional)
- **Reports (Daily)**: sales are grouped by the saved `payment_method` string, not by payment method documents

