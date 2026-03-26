# Boy Barbershop - Project Start Plan (Flutter + Firebase)

## Purpose

This file converts `php-migration.md` into a practical kickoff plan for starting the project with clear priorities, setup tasks, and delivery checkpoints.

Project goal:
- Build a **single-user** Flutter app with Firebase backend.
- Keep behavior **exactly aligned** with current PHP app logic.
- Deliver MVP in phased increments without feature drift.

---

## 1) Week 0: Kickoff decisions (before coding)

Confirm these fixed decisions first:
- Scope: single owner user only (no branch support, role field reserved for future).
- Architecture: Flutter app + Firebase Auth + Firestore (no Cloud Functions).
- Data parity: keep SQL table naming mapped to Firestore collections.
- Business logic parity: sale create/update/delete with stock consistency must match existing behavior.

Output of Week 0:
- Finalized migration scope and MVP checklist copied from `php-migration.md`.
- Agreed page map and navigation.
- Agreed Firebase project/environment naming.

---

## 2) Day 1 setup checklist (environment + base app)

### 2.1 Local tools
- Install/update Flutter SDK and verify `flutter doctor`.
- Install Firebase CLI and FlutterFire CLI.
- Confirm Android/iOS build targets run on local machine.

### 2.2 Firebase project bootstrap
- Create Firebase project for this app.
- Enable Email/Password in Firebase Auth.
- Enable Firestore.
- Initialize FlutterFire config and generate `firebase_options.dart`.
- Create Firestore indexes only when query errors require them.

### 2.3 Authentication bootstrap
- Build login page using Firebase Auth (Email/Password).
- Create `users/{uid}` document after first sign-in.
- User document for now:
  - `role: 1` (admin),
  - `is_active: true`,
  - `createdAt`, `updatedAt`.
- Add auth guard to route unauthorized users to login.

### 2.4 App foundation
- Create app folder structure (features, shared UI, data, domain).
- Set a shared theme and base typography/colors.
- Add app-level routing and navigation shell:
  - Bottom tabs: Dashboard, Sale, Reports, More.
  - More menu for all remaining modules.

Output of Day 1:
- App launches and connects to Firebase.
- Empty placeholder pages for all mapped modules.

---

## 3) Foundation sprint (Phase 1)

Build the foundation required for all features:
- Firestore collection contracts for:
  - `settings`, `barbers`, `services`, `inventory_items`,
  - `service_inventory_usage`, `payment_methods`, `promos`,
  - `sales`, `expenses`, `investments`, `drawer_counts`, `users`.
- Repository layer per module (read/write APIs).
- Shared models with validation for numeric fields, IDs, and timestamps.
- Reusable UI components:
  - list/table cards,
  - forms + validation,
  - loading/error/empty states.

Exit criteria:
- CRUD scaffolding works for at least one module end-to-end.
- Firestore read/write patterns are standardized.

---

## 4) Build order (recommended execution sequence)

Use this exact order to reduce blockers:

1. Master data modules
- `BarbersPage`
- `ServicesPage`
- `InventoryPage`
- `PaymentMethodsPage`
- `PromosPage`
- `service_inventory_usage` editor

2. Sales + stock coupling (highest risk area)
- `AddSalePage` create/edit/delete
- Flutter `runTransaction` / batched writes for:
  - sale create + stock deduction,
  - sale update (restore old + apply new),
  - sale delete + stock restore,
  - block negative stock commits

3. Financial modules
- `ExpensesPage`
- `InvestmentsPage`
- `CashFlowPage`
- `SettingsPage` for:
  - `daily_target`,
  - `insight_owner_pay_percent`,
  - `insight_target_years`

4. Metrics and intelligence
- `DashboardPage` parity with all required metrics/alerts
- `ReportsPage`
- `AnalyticsPage`
- `SalesIntelligencePage`
- `OwnerInsightsPage`

---

## 5) Non-negotiable parity rules

These must remain exact to current behavior:
- Profit formulas:
  - `todayProfit = todaySales - todayBarberShare - todayExpenses`
  - `monthProfit = monthSales - monthBarberShare - monthExpenses`
  - `allProfit = allSales - allBarberShare - allExpenses`
  - `roiPercent = (allProfit / totalInvestment) * 100` when investment > 0
- Smart alerts:
  - below target,
  - low sales vs 30-day average,
  - low stock threshold,
  - high monthly expenses vs average
- Sale transaction behavior must be atomic and inventory-safe.

---

## 6) Suggested delivery timeline

If working solo, use this baseline:
- Week 1: Foundation + master data modules.
- Week 2: Sales flow + Flutter transaction stock coupling.
- Week 3: Financial modules + settings.
- Week 4: Dashboard + reports + analytics + insights.
- Week 5: SQL-to-Firestore migration + parity validation.
- Week 6: Stabilization, UAT, polish, release prep.

Adjust based on complexity discovered in reports/analytics parity.

---

## 7) Data migration plan (when feature-complete enough)

Steps:
1. Export SQL data per table (JSON/CSV).
2. Write import scripts preserving IDs where possible.
3. Import to Firestore collections with mapped schema.
4. Run parity validation checks:
   - daily/month totals,
   - inventory levels,
   - barber share outputs,
   - ROI and payback values.

Only proceed to release once parity checks pass.

---

## 8) QA and acceptance gates

### Functional gate
- All MVP checklist items from `php-migration.md` are complete.
- No missing core page from one-to-one mapping.

### Data integrity gate
- No negative stock from any sale operation path.
- Edit/delete sale always restores or re-deducts correctly.

### Parity gate
- Dashboard numbers match PHP outputs for same date ranges.
- Alert triggers match the original logic.

### Stability gate
- Handles offline/slow network gracefully.
- Includes backup/export utility for owner.

---

## 9) Immediate next actions (start now)

1. Create feature folders and routing shell.
2. Build login + auth guard using Firebase Auth.
3. Create `users` collection logic with `role: 1` for current admin user.
4. Implement Firestore model + repository for `barbers` as reference module.
5. Replicate the same pattern for `services`, `inventory_items`, and `payment_methods`.
6. Build `service_inventory_usage` mapping UI.
7. Implement Flutter transaction logic for sale create/update/delete before finalizing sales UI.

This order minimizes rework and secures the most critical business logic first.
