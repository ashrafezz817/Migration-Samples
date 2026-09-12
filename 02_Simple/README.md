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

These counts describe the legacy Oracle Forms module only. The migrated APEX reference implementation and its related database objects are documented separately under `APEX_Reference/`.

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

## Legacy Dependencies

### Database Packages

No direct Oracle database package dependencies in the Form.

### Database Functions / Procedures

The Form references shared standalone database functions including:

* `GET_U_PREV20` - used by the security logic to determine allowed operations
* `GetVersion` - used when initializing the Forms window title

These are not counted in the `DB Packages` value in the technical summary because they are standalone database functions rather than package calls.

### LOVs

No LOV dependencies.

### Other Forms

No significant cross-Form dependency.

### Reports

No report dependencies.

### Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`

These libraries provide shared visual, interface, alert, and application behavior used by the legacy Forms application.

## APEX Reference Implementation

This sample has already been successfully migrated to Oracle APEX.

The completed reference implementation is available under `APEX_Reference/` and includes:

* Oracle APEX Page 24 - **Nationalities**
* Oracle APEX Page 25 - **Manage Nationality**
* Screenshots of both migrated pages
* A dedicated README describing the migrated architecture and modernization approach

The migration did not reproduce the Oracle Form one-to-one. The original maintenance screen was separated into a searchable report page and a focused modal create/edit page.

Key changes include:

* Page 24 uses an Interactive Report for nationality reference data.
* Page 25 uses a native APEX Form and Automatic Row Processing for create and update operations.
* The legacy `MAX(NATID) + 1` identifier generation was replaced with `NATIONALITY_SEQ.NEXTVAL`.
* Management actions use the centralized `NAT_MANAGE` permission through `FND_APP_SECURITY`.
* System nationalities remain visible but are protected from normal edit and status-change actions.
* Status changes are performed through a server-side AJAX process with permission, system-record, and current-status checks.
* Form validations were implemented using native APEX validations, including duplicate English name, Arabic name, and nationality-code checks.
* Forms-specific window, visual, and interface-direction behavior was replaced with standard APEX application behavior.
* Shared application styling is used for report status controls instead of page-specific CSS.

No dedicated database package was introduced for this migration. The workflow uses native APEX capabilities and existing application infrastructure because the business function is straightforward reference-data maintenance.

The APEX implementation is provided as a reference for the expected migration approach and quality level. It is not intended to prescribe an exact one-to-one design for other Forms.

See [`APEX_Reference/README.md`](APEX_Reference/README.md) for details of the migrated implementation.

## Files

* `Nat.fmb` - Original Oracle Forms module
* `Nat.xml` - XML export of the Oracle Forms module
* `screenshot.png` - Screenshot of the current Oracle Forms user interface
* `APEX_Reference/` - Completed Oracle APEX reference implementation, page exports, screenshots, and migration notes
