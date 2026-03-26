# Boy Barbershop - Exact Single-User Migration Plan (Flutter + Firebase)

## Scope of this file

This is an exact migration blueprint based on your current PHP codebase in this project.
It is designed for **one user only** (shop owner / operator), not multi-user and not role-based.

Current pages mapped from code:
- `index.php` (dashboard + alerts + insights + ROI)
- `add_sale.php` (create/edit/delete sale + inventory deduction/restore)
- `services.php` (services + service inventory usage mapping)
- `barbers.php` (barber profiles + percentage share)
- `inventory.php` (stock and low-stock thresholds)
- `expenses.php`
- `cash_flow.php`
- `reports.php`
- `analytics.php`
- `sales_intelligence.php`
- `owner_insights.php`
- `investments.php`
- `payment_methods.php`
- `promos.php`

---

## 1) Product target (single user)

Build one Flutter app for one business owner to:
- record sales and expenses fast,
- track inventory auto-deduction per service,
- compute barber share and net profit,
- monitor ROI and investment recovery,
- see reports, analytics, and alerts in real time.

No user management screen required for MVP.
No multi-role permissions required.

---

## 2) Exact feature mapping from current code

## 2.1 Dashboard (`index.php`)
- Today metrics: customers, total sales, barber share, expenses, net profit.
- Month metrics: customers, sales, expenses, net profit.
- Top barber (today and month).
- Daily target progress (from `settings.daily_target`).
- Smart alerts:
  - below daily target,
  - low sales vs 30-day average,
  - low inventory stock (`stock_qty <= low_stock_threshold`),
  - high expenses vs monthly average.
- Today's sales list with edit/delete action.
- Barber earnings list for today.
- ROI section: total investment, total profit, ROI %, progress to payback.
- Insights section:
  - average monthly sales/expenses/profit,
  - suggested owner pay using `insight_owner_pay_percent`,
  - payback estimate,
  - optional goal using `insight_target_years`.

## 2.2 Sales (`add_sale.php`)
- Create sale with barber, service, price, payment method, notes.
- Edit sale.
- Delete sale.
- Optional promo support if `sales.promo_id` column exists.
- Auto inventory behavior:
  - on create/update: deduct stock by `service_inventory_usage.quantity_per_service`,
  - on delete / service-change update: restore previously deducted stock.

## 2.3 Services (`services.php`)
- Create/update/deactivate service.
- Service default price.
- Per-service inventory usage mapping via `service_inventory_usage`.

## 2.4 Barbers (`barbers.php`)
- Create/update/deactivate barber.
- Maintain `percentage_share` used for barber earnings and profit calculations.

## 2.5 Inventory (`inventory.php`)
- Create/update/deactivate inventory item.
- Track `stock_qty`, optional `unit`, and `low_stock_threshold`.
- Mark item as low when `stock_qty <= low_stock_threshold`.

## 2.6 Expenses (`expenses.php`)
- Add and list expenses by date/category/description/amount.
- Monthly and ranged totals used by dashboard/reports/insights.

## 2.7 Payment methods (`payment_methods.php`)
- Create/update/deactivate payment method.
- Used in sale form and cash flow filters.

## 2.8 Promos (`promos.php`)
- Create/update/activate/deactivate promos.
- Supports type/value/valid date range.
- Applied during sale recording when valid.

## 2.9 Investments (`investments.php`)
- Create/update/delete investment records.
- Used for ROI and payback metrics.

## 2.10 Analytics / Reports / Intelligence
- `analytics.php`: trends, target, and peak behavior.
- `reports.php`: print-ready and date-range summaries.
- `cash_flow.php`: cash in/out and drawer count.
- `sales_intelligence.php` + `owner_insights.php`: strategy and owner-focused insights.

---

## 3) Flutter page list (one-to-one replacement)

Main pages:
- `SplashPage`
- `DashboardPage` (replaces `index.php`)
- `AddSalePage` (create/edit/delete)
- `ServicesPage`
- `BarbersPage`
- `InventoryPage`
- `ExpensesPage`
- `CashFlowPage`
- `ReportsPage`
- `AnalyticsPage`
- `SalesIntelligencePage`
- `OwnerInsightsPage`
- `InvestmentsPage`
- `PaymentMethodsPage`
- `PromosPage`
- `SettingsPage` (for existing key-value settings only)

Suggested navigation:
- Bottom tabs: Dashboard, Sale, Reports, More
- More menu: Services, Barbers, Inventory, Expenses, Cash Flow, Investments, Promos, Payment Methods, Analytics, Insights, Settings

---

## 4) Exact data model for Firebase (based on current SQL tables)

Use Firestore collections named after current tables for easy migration.

## 4.1 `settings`
Document id: setting key (or generated id with `key` field)
Fields:
- `key` (string) -> examples:
  - `daily_target`
  - `insight_owner_pay_percent`
  - `insight_target_years`
- `value` (string/number)
- `updatedAt` (timestamp)

## 4.2 `barbers`
Fields:
- `name` (string)
- `percentage_share` (number)
- `is_active` (bool)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

## 4.3 `services`
Fields:
- `name` (string)
- `default_price` (number)
- `is_active` (bool)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

## 4.4 `inventory_items`
Fields:
- `item_name` (string)
- `stock_qty` (number)
- `low_stock_threshold` (number)
- `unit` (string, optional)
- `is_active` (bool)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

## 4.5 `service_inventory_usage`
Fields:
- `service_id` (reference or string id to `services`)
- `inventory_item_id` (reference or string id to `inventory_items`)
- `quantity_per_service` (number)

## 4.6 `payment_methods`
Fields:
- `name` (string)
- `is_active` (bool)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

## 4.7 `promos`
Fields:
- `name` (string)
- `promo_type` (string; fixed or percent)
- `value` (number)
- `valid_from` (timestamp/date)
- `valid_to` (timestamp/date)
- `is_active` (bool)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

## 4.8 `sales`
Fields:
- `barber_id` (reference/string)
- `service_id` (reference/string)
- `price` (number)
- `payment_method` (string; keep same compatibility as current app behavior)
- `notes` (string, optional)
- `sale_datetime` (timestamp)
- `promo_id` (reference/string, optional)
- `original_price` (number, optional)
- `discount_amount` (number, optional)

## 4.9 `expenses`
Fields:
- `expense_date` (date/timestamp)
- `category` (string)
- `description` (string)
- `amount` (number)
- `expense_type` (string, optional)
- `createdAt` (timestamp)

## 4.10 `investments`
Fields:
- `item_name` (string)
- `cost` (number)
- `investment_date` (date/timestamp)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

## 4.11 `drawer_counts`
Fields:
- `period_type` (string)
- `period_start` (date/timestamp)
- `period_end` (date/timestamp)
- `actual_cash` (number)
- `notes` (string, optional)
- `updatedAt` (timestamp)

---

## 5) Firebase services to use (minimal and exact)

For one-user setup, required:
- Firestore (all data above)
- Firebase App Check (recommended)
- Cloud Functions (for atomic sale + stock logic and aggregates)

Optional:
- Firebase Auth (single owner login)
- Crashlytics
- Analytics

If you want truly one-device, you can skip Auth initially and rely on local app lock.

---

## 6) Critical business logic that must stay exact

## 6.1 Sale create
1. Validate barber/service/payment.
2. Resolve final price (promo if valid).
3. Insert sale.
4. Deduct stock using `service_inventory_usage`.
5. Block commit if any required stock would become negative.

## 6.2 Sale update
1. Load previous sale.
2. Restore old service inventory usage.
3. Apply new sale data.
4. Deduct new service inventory usage.

## 6.3 Sale delete
1. Load sale.
2. Restore inventory based on original `service_id`.
3. Delete sale.

## 6.4 Profit formulas (same as current dashboard)
- `todayProfit = todaySales - todayBarberShare - todayExpenses`
- `monthProfit = monthSales - monthBarberShare - monthExpenses`
- `allProfit = allSales - allBarberShare - allExpenses`
- `roiPercent = (allProfit / totalInvestment) * 100` when investment > 0

## 6.5 Smart alerts (same behavior)
- target shortfall,
- low daily sales vs last 30 days average,
- low stock,
- high monthly expense vs average.

Implement 6.1/6.2/6.3 in Cloud Functions transaction-safe writes.

---

## 7) Migration phases (exact and practical)

## Phase 1 - Foundation
- Create Flutter app structure and shared theme.
- Create Firestore collections mirroring current SQL table names.
- Build repository layer per module.

## Phase 2 - Core master data
- Build pages: Barbers, Services, Inventory, Payment Methods, Promos.
- Implement deactivate toggles (`is_active`).
- Implement service-inventory usage editor.

## Phase 3 - Sales and inventory coupling
- Build Add Sale flow (create/edit/delete).
- Implement exact inventory deduction/restore transaction logic.
- Add today's sales list and quick edit/delete.

## Phase 4 - Financial modules
- Build Expenses, Investments, Cash Flow pages.
- Add drawer count behavior.
- Add Settings key-value editor for daily target and insight config.

## Phase 5 - Dashboard, Reports, Analytics
- Build Dashboard with all current metrics and alerts.
- Build Reports and Analytics screens based on existing queries.
- Add insights/payback calculations.

## Phase 6 - Data migration
- Export SQL to JSON/CSV by table.
- Import to Firestore preserving IDs if possible.
- Validate:
  - totals per day/month,
  - stock counts,
  - ROI values.

## Phase 7 - Stabilize and release
- Add offline cache and loading states.
- Add backup/export utilities.
- Final UAT against current PHP outputs.

---

## 8) Exact MVP checklist (single user)

- [ ] Dashboard parity with `index.php`
- [ ] Sales create/edit/delete with stock consistency
- [ ] Services with per-service inventory usage
- [ ] Barbers with percentage share
- [ ] Inventory with low-stock threshold
- [ ] Expenses + Investments + Cash Flow
- [ ] Payment methods + Promos
- [ ] Reports + Analytics + Owner insights
- [ ] Settings keys: `daily_target`, `insight_owner_pay_percent`, `insight_target_years`

---

## 9) Notes for future expansion (not in current scope)

Keep disabled for now:
- Multi-user roles
- Branch support
- Complex accounting ledger

This keeps migration exact to current behavior and avoids feature drift.

---

## 10) Final definition

This migration file is now:
- single-user only,
- directly based on your existing pages and SQL behavior,
- one-to-one in features, pages, formulas, and stored data.

Use this as the canonical implementation guide for Flutter + Firebase parity migration.

