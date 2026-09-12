# Cashier Shift Open

## Purpose

Allows a cashier to start a new cashier shift and record the opening cash balance.

## Complexity

**Simple**

This Form represents a relatively straightforward transactional workflow with one primary database block, limited embedded business logic, and few external dependencies.

## Main Functionality

* Creates a new cashier shift
* Associates the shift with the logged-in user
* Records the opening cash balance
* Prevents multiple open shifts for the same user
* Generates a shift reference
* Associates the shift with the current information center
* Initializes the shift date, time, and status

## Technical Summary

| Component      | Count |
| -------------- | ----: |
| Blocks         |     2 |
| Items          |     8 |
| Triggers       |     6 |
| Program Units  |     3 |
| LOVs           |     1 |
| Relations      |     0 |
| DB Packages    |     0 |
| Report Objects |     0 |

These counts describe the legacy Oracle Forms module only. The migrated APEX reference implementation and its backend components are documented separately under `APEX_Reference/`.

The Form contains one primary database block, `CASHIER_SHIFT`, and one non-database utility block, `TOOLS`.

## Main Database Objects

### Tables

* `CASHIER_SHIFT`
* `USERS_TABLE`

`CASHIER_SHIFT` is the primary transactional table.

`USERS_TABLE` is queried by the user LOV used to resolve the current cashier.

## Key Business Logic

The Form contains logic for:

* Checking whether the current user already has an open shift
* Populating the current user and information center
* Setting the shift date and start time
* Initializing the shift status
* Generating the next shift reference
* Preventing creation of another active shift for the same cashier

The legacy implementation generates the shift reference using a `MAX(...) + 1` pattern.

## Forms Characteristics

* One primary database block
* One non-database utility block
* Insert-oriented workflow
* One LOV
* Item, block, and form-level triggers
* Embedded PL/SQL validation
* Global-variable usage
* Shared Forms Object Library dependencies
* No master-detail relationship

## Legacy Dependencies

### Database Packages

No direct Oracle database package dependencies were identified in the legacy Form.

### LOVs

* `LOV577` — retrieves user information from `USERS_TABLE`

### Other Forms

No significant cross-Form dependency was identified.

### Reports

No report objects or report execution dependencies were identified.

### Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`

These libraries provide shared visual, interface, and application behavior used by the legacy Forms application.

## APEX Reference Implementation

This sample has already been successfully migrated to Oracle APEX.

The completed reference implementation is available under `APEX_Reference/` and includes:

* Oracle APEX Page 49 — **Start Cashier Shift**
* The shared `BIL_CASHIER_SHIFT` backend package
* Screenshots showing the page with and without an active cashier shift
* A dedicated README describing the migrated architecture and modernization approach

The migration did not reproduce the Oracle Form one-to-one. The resulting implementation separates the UI from reusable backend business logic.

Key changes include:

* The start-shift workflow is implemented as an APEX modal page.
* Current user and information-center values are obtained from the application session rather than manually selected in the page.
* Cashier-shift operations are centralized in the reusable `BIL_CASHIER_SHIFT` package.
* The legacy `MAX(...) + 1` shift-reference generation is no longer used; the database-generated identifier is returned after insert.
* Duplicate active-shift protection is enforced in the backend rather than relying only on UI validation.
* Shared shift rules can be reused by related billing workflows, including invoice shift validation.

The APEX implementation is provided as a reference for the expected migration approach and quality level. It is not intended to prescribe an exact one-to-one design for other Forms.

See [`APEX_Reference/README.md`](APEX_Reference/README.md) for details of the migrated implementation.

## Files

* `Cashier_Shifts_Open.fmb` — Original Oracle Forms module
* `Cashier_Shifts_Open.xml` — XML export for source inspection and analysis
* `screenshot.png` — Screenshot of the current Oracle Forms user interface
* `APEX_Reference/` — Completed Oracle APEX reference implementation, backend package, screenshots, and migration notes
