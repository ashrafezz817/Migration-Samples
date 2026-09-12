# APEX Reference - Cashier Shift Open

## Purpose

This directory contains the migrated Oracle APEX implementation corresponding to the legacy `Cashier_Shifts_Open` Oracle Form.

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page structure or technical design.

During migration, legacy Forms functionality may be simplified, redesigned, split across multiple APEX pages, moved into reusable database APIs, or replaced with native APEX functionality where appropriate.

The required business behavior should be preserved while avoiding unnecessary reproduction of Forms-specific implementation patterns.

## Migration Mapping

The legacy cashier-shift Form was migrated to:

* **Oracle APEX Page 49 - Start Cashier Shift**
* **`BIL_CASHIER_SHIFT`** - reusable backend API for cashier-shift operations

The APEX page handles the user interaction and presentation of the start-shift workflow.

The backend package contains the reusable business logic and transactional operations associated with cashier shifts.

## APEX Page

### Page 49 — Start Cashier Shift

Page 49 is implemented as a modal dialog.

The migrated workflow allows the cashier to:

* Enter the cash physically available at the beginning of the shift
* Start a new cashier shift
* See when an active shift already exists
* View the active shift reference
* View when the active shift started
* See the elapsed duration of the active shift

The current user and information center are obtained from the application session rather than being selected manually by the user.

The page also performs server-side validation before starting a shift, including:

* Starting cash is required
* Starting cash cannot be negative
* Information-center context must exist

If an open shift already exists, the page displays the active-shift state rather than presenting another Start Shift action.

## Backend API

### `BIL_CASHIER_SHIFT`

Cashier-shift business logic was moved into a reusable database package rather than being implemented entirely inside the APEX page.

Page 49 specifically invokes:

`BIL_CASHIER_SHIFT.START_SHIFT`

The package also provides operations for:

* Starting a cashier shift
* Ending a cashier shift
* Retrieving the current shift
* Retrieving an open-shift summary
* Determining whether a user has an open shift
* Validating whether an invoice can be created under the active-shift rules

The complete package is included because it demonstrates the backend architecture adopted during the migration.

Not every operation in the package belongs exclusively to Page 49. The package is a shared cashier-shift domain API used by related billing workflows.

## Key Modernization Changes

### Business Logic Moved Out of the UI

The legacy Form contained business rules directly inside Forms triggers.

The migrated implementation separates responsibilities:

* APEX handles presentation and page interaction
* `BIL_CASHIER_SHIFT` handles reusable cashier-shift business operations
* Database constraints and transactional logic protect critical rules

This reduces dependence on page execution order and allows the same business rules to be reused by other workflows.

### Shift Reference Generation

The legacy Form generated the shift reference using a `MAX(...) + 1` pattern.

The migrated implementation no longer calculates the next identifier in the page or package.

A new shift is inserted and the database-generated `SHIFT_SYSTEM_UNIQUE` value is returned to the caller.

This avoids the concurrency problems associated with `MAX(...) + 1`.

### Duplicate Open-Shift Protection

The legacy Form checked whether the cashier already had an active shift before inserting another record.

The migrated backend also protects this rule at the database/transaction level.

If an attempt to create a conflicting open shift reaches the insert operation, the backend converts the database conflict into a controlled business error.

The page-level active-shift check therefore improves the user experience, while the backend remains responsible for protecting the business rule.

### Application Context

The legacy Form depended heavily on Forms global variables.

The migrated implementation uses the application/session context for values such as:

* Current user
* Current information center
* Application permissions

The backend API can also accept explicit values where appropriate, allowing it to be reused outside the Page 49 UI.

### Centralized Shift Rules

The backend package provides a common location for cashier-shift rules used by related billing workflows.

For example, invoice creation can use the same API to determine whether:

* Shift control is enabled
* The user has an active shift
* The user is allowed to bypass the requirement

This avoids duplicating cashier-shift rules across individual APEX pages.

## Shared Dependencies

The reference implementation relies on application infrastructure outside this sample, including shared application settings, security/permission services, and related billing tables.

Examples include:

* `FND_APP_SETTINGS_PKG`
* `FND_APP_SECURITY`
* `CASHIER_SHIFT`
* Invoice/payment data used when closing or validating shifts

These components are part of the wider application architecture and are not necessarily included in this sample.

Therefore, the files in this directory should be treated as a **migration reference**, not as a standalone deployable application.

## Reference Scope

This implementation demonstrates the preferred modernization principle:

**Preserve the business workflow, but do not reproduce Oracle Forms architecture unnecessarily.**

A future migration does not need to use the same number of APEX pages, regions, processes, or database packages.

The appropriate design should depend on the functionality of the individual Form while following the same general objectives:

* Preserve required business behavior
* Centralize reusable business rules
* Enforce critical transactional rules in the backend
* Use native APEX capabilities where appropriate
* Remove obsolete Forms-specific behavior
* Improve maintainability and user experience

## Files

* `hmisfox_page_49.apx` — Oracle APEX Page 49 export
* `backend/BIL_CASHIER_SHIFT.sql` — complete cashier-shift backend package specification and body
* `screenshots/screenshot-no-open-shift.png` — APEX page when the cashier has no active shift
* `screenshots/screenshot-open-shift.png` — APEX page when an active cashier shift already exists
