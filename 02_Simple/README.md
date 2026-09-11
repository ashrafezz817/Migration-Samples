# Nationalities

## Purpose

Provides maintenance of nationality reference data used throughout the Healthcare Information System.

## Complexity

**Simple**

This Form represents a small reference-data maintenance screen with one database block, a limited number of fields and triggers, and no master-detail, report, or cross-Form workflow.

## Main Functionality

* Creates and maintains nationality records
* Stores the nationality name
* Supports an Arabic nationality description
* Stores a shortened or standardized nationality description
* Maintains a display/sort order
* Defines whether VAT is applicable through the `PAY_VAT` setting
* Automatically generates the nationality identifier for new records
* Applies user permissions to insert, update, delete, and query operations

## Technical Summary

| Component      | Count |
| -------------- | ----: |
| Blocks         |     1 |
| Items          |     6 |
| Triggers       |     6 |
| Program Units  |     5 |
| LOVs           |     0 |
| Relations      |     0 |
| DB Packages    |     0 |
| Report Objects |     0 |

The Form contains a single database block, `NAT`, based on the `NATIONALITY` table.

## Main Database Objects

### Tables

* `NATIONALITY`

`NATIONALITY` is the primary reference-data table maintained by the Form.

The Form also contains legacy localization logic in the `DO_INTERFACE` program unit that references the shared `TRANS` table. This logic is not part of the core nationality maintenance transaction.

## Key Business Logic

The Form contains logic for:

* Validating that the nationality description is provided
* Automatically assigning a new `NATID` during insert
* Applying user permissions for insert, update, delete, and query operations
* Configuring right-to-left or left-to-right presentation according to the current application language
* Positioning and initializing the Forms window

The legacy `PRE-INSERT` logic generates a new nationality identifier using:

`MAX(NATID) + 1`

## Forms Characteristics

* One database block
* Six data-entry items
* Reference-data CRUD workflow
* Item, block, and form-level triggers
* Five Forms program units
* Embedded PL/SQL validation
* Global-variable usage
* Shared security logic
* Arabic and English interface-direction handling
* Shared Forms Object Library dependencies
* No LOVs
* No master-detail relationships
* No report objects

## Dependencies

### Database Packages

No direct Oracle database package dependencies were identified in the Form.

### Database Functions / Procedures

The Form references shared standalone database functions including:

* `GET_U_PREV20` — used by the security logic to determine allowed operations
* `GetVersion` — used when initializing the Forms window title

These are not counted in the `DB Packages` value in the technical summary because they are standalone database functions rather than package calls.

### LOVs

No Forms LOV objects are defined.

### Other Forms

No significant cross-Form dependency was identified.

### Reports

No report objects or report execution dependencies were identified.

### Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`

These libraries provide shared visual, interface, alert, and application behavior used by the legacy Forms application.

## Migration Considerations

The functionality can be implemented in Oracle APEX as a straightforward reference-data maintenance page.

During migration:

* `NATID` generation should not retain the legacy `MAX(NATID) + 1` approach. A database sequence, identity mechanism, or centralized API should be used instead.
* Authorization should be implemented using the target application's centralized permission model rather than reproducing Forms block-property security logic.
* Required-field validation should be implemented using database constraints and/or APEX validations as appropriate.
* Arabic and English presentation should use the application's standard localization and RTL/LTR mechanisms rather than reproducing Forms-specific interface code.
* Shared Forms visual and window-management logic does not need to be recreated where Oracle APEX provides equivalent behavior.
* Legacy localization logic associated with the `TRANS` table should be reviewed and retained only if it is still required by the target application.

## Files

* `Nat.fmb` — Original Oracle Forms module
* `Nat.xml` — XML export for source inspection and analysis
* `screenshot.png` — Screenshot of the current Oracle Forms user interface
