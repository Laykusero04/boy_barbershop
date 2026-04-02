# Barbers documentation

This document explains how **Barbers** are stored and managed, including the **percentage vs daily-rate** pay modes and how that impacts earnings calculations.

## Firestore: `barbers` collection

Defined in `lib/data/firestore_collections.dart` as `FirestoreCollections.barbers(db)`.

Each barber document stores:

- **`name`** *(String)*: display name.
- **`is_active`** *(bool)*: when `false`, barber is hidden from the **Add Sale** barber dropdown.
- **Compensation fields**:
  - **`compensation_type`** *(String)*: `'percent'` or `'daily'`.
    - Missing/unknown values default to **percent** (for legacy docs).
  - **`percentage_share`** *(number)*: 0–100 (used when `compensation_type == 'percent'`).
  - **`daily_rate`** *(number)*: \(\ge 0\) (used when `compensation_type == 'daily'`).
- **Auditing**:
  - **`created_at`** *(Timestamp)*: server timestamp.
  - **`updated_at`** *(Timestamp)*: server timestamp.

Client-side model: `lib/models/barber.dart` (`Barber.fromFirestoreMap`).

## App model

`lib/models/barber.dart` defines:

- `BarberCompensationType.percentage`
- `BarberCompensationType.dailyRate`

and the `Barber` fields:

- `percentageShare` (0–100)
- `dailyRate` (money amount)
- `compensationType`
- `isActive`

Parsing behavior:

- `compensation_type == 'daily'` → `dailyRate`
- anything else / missing → `percentage` (legacy-compatible)

## Creating a barber

UI entrypoint: `lib/presentation/screens/barbers_screen.dart`

Flow (two-step):

1. **Choose pay type** dialog:
   - **Percentage of sales**
   - **Daily rate**
2. **Details** dialog:
   - Name
   - The corresponding pay value (percent or daily rate)

Repository write: `lib/data/barbers_repository.dart` → `BarbersRepository.createBarber(...)`

Validation:

- Name is required
- If **percent**: `percentage_share` must be 0–100
- If **daily**: `daily_rate` must be a valid non-negative amount

Fields written:

- `name`
- `compensation_type` (`'percent'` or `'daily'`)
- `percentage_share` or `daily_rate` (the unused one is written as `0.0`)
- `is_active = true`
- `created_at`, `updated_at`

## Editing a barber

UI: `BarbersScreen` → **Edit** button.

Repository write: `BarbersRepository.updateBarber(...)`

Editable:

- Name
- Compensation type (Percent / Daily)
- The corresponding pay value

Fields updated:

- `name`
- `compensation_type`
- `percentage_share` / `daily_rate` (unused one set to `0.0`)
- `updated_at`

## Deactivating a barber

UI: `BarbersScreen` → **Deactivate** (only shown for active barbers).

Repository write: `BarbersRepository.deactivateBarber(barberId)`

Effect:

- Sets `is_active = false`
- Barber no longer appears in **Add Sale** dropdown (`CatalogRepository.watchActiveBarbers()` filters to `is_active == true`)
- Existing historical sales remain unchanged (they keep `barber_id`).

## How barber pay affects sales and earnings

Sales documents store `barber_id` (not the name and not the pay config). Earnings are computed at runtime by joining sales with the current barber record.

Current earning rules used by dashboard/breakdowns:

- **Percentage barber**:
  - Per-sale earnings: `sale.price * (percentageShare / 100)`
- **Daily-rate barber**:
  - Earnings for a set of sales: `dailyRate * numberOfDistinctSaleDaysWithAtLeastOneSale`
  - (In other words: one daily rate per day per barber, as long as they have at least one sale recorded that day.)

Key files:

- `lib/presentation/screens/dashboard/dashboard_logic.dart` (KPIs and barber share totals)
- `lib/presentation/screens/dashboard_screen.dart` (earnings card + sale tile display)
- `lib/presentation/screens/add_sale_screen.dart` (daily breakdown display)

