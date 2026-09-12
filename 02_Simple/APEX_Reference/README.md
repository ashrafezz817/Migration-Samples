# APEX Reference - Nationalities

## Purpose

This directory contains the migrated Oracle APEX implementation corresponding to the legacy `Nat` Oracle Form.

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page structure or technical design.

During migration, legacy Forms functionality may be simplified, redesigned, split across multiple APEX pages, moved into reusable database APIs, or replaced with native APEX functionality where appropriate.

The required business behavior should be preserved while avoiding unnecessary reproduction of Forms-specific implementation patterns.

## Migration Mapping

The legacy nationality-maintenance Form was migrated to:

* **Oracle APEX Page 24 - Nationalities**
* **Oracle APEX Page 25 - Manage Nationality**

The legacy single-screen maintenance workflow was separated into a report page and a modal maintenance page.

No dedicated database package was introduced for this sample. The migrated workflow uses native Oracle APEX reporting, form processing, validations, authorization checks, and database objects where appropriate.

## APEX Pages

### Page 24 - Nationalities

Page 24 provides the main nationality reference-data view.

The page uses an Interactive Report to display nationality records and allows authorized users to:

* Review nationality reference data
* Search and filter nationality records
* Open a nationality for editing
* Create a new nationality
* Change the active or inactive status of a nationality

Management actions are controlled using the application permission model through `FND_APP_SECURITY.HAS_PERMISSION('NAT_MANAGE')`.

System nationalities are protected from normal maintenance actions. Their edit action is not presented and their status control is rendered as non-interactive.

The status-change workflow also validates the rule in the server-side AJAX process before performing the update.

The report uses the shared application CSS stylesheet.

### Page 25 - Manage Nationality

Page 25 is implemented as a modal dialog for creating and maintaining nationality records.

The form maintains:

* English nationality name
* Arabic nationality name
* Nationality code
* Sort order
* Default language
* VAT applicability
* Status

The page uses a native APEX Form based on the `NATIONALITY` table and Automatic Row Processing for insert and update operations.

The page includes validations for:

* Required English nationality name
* Required Arabic nationality name
* Valid VAT values
* Valid status values
* Valid language values
* Unique English nationality name
* Unique Arabic nationality name
* Unique nationality code when provided

Create and update actions are available only to users with the `NAT_MANAGE` permission.

## Key Modernization Changes

### Separation of List and Maintenance Workflows

The legacy Form combined reference-data viewing and maintenance in a single Forms screen.

The migrated implementation separates these responsibilities:

* Page 24 provides the searchable reference-data list and lightweight status actions.
* Page 25 provides focused create and edit functionality in a modal dialog.

This produces a simpler user workflow while still preserving the original nationality-maintenance functionality.

### Native APEX Form Processing

This sample does not introduce a dedicated PL/SQL business API because the nationality workflow is straightforward reference-data maintenance.

Page 25 uses native APEX Form processing and validations directly against the `NATIONALITY` table.

This demonstrates that migration architecture should match the complexity of the business function rather than introducing additional backend layers where they are not required.

### Nationality Identifier Generation

The legacy Form generated `NATID` using a `MAX(NATID) + 1` pattern.

The migrated implementation uses:

`NATIONALITY_SEQ.NEXTVAL`

The identifier is assigned before the native APEX insert process.

This removes the concurrency risk associated with the legacy `MAX(...) + 1` approach.

### Centralized Authorization

The legacy Form applied operation permissions through Forms security logic.

The migrated implementation uses the application authorization model through `FND_APP_SECURITY.HAS_PERMISSION`.

The `NAT_MANAGE` permission controls management actions such as:

* Creating a nationality
* Editing a nationality
* Changing nationality status

This avoids reproducing Forms block-property security behavior in the APEX implementation.

### Protected System Records

The migrated data model distinguishes system-maintained nationality records using `IS_SYSTEM`.

System nationalities remain visible in the report but are not presented as normal editable records.

Their status controls are also non-interactive, while the server-side status process independently protects the same rule before an update is performed.

### Status Management

Nationality status is represented using `ACTIVE` and `INACTIVE` values.

### Validation Improvements

The migrated form uses explicit APEX validations for reference-data integrity, including duplicate-name and duplicate-code checks.

Validation messages are presented directly to the user through the APEX form workflow instead of relying on Forms trigger behavior.

### Localization and Presentation

The legacy Form contained Forms-specific interface-direction and localization logic.

The migrated implementation uses the application's standard APEX presentation and language mechanisms instead of reproducing Forms window-management and interface code.

English and Arabic nationality values remain part of the maintained business data.

## Shared Dependencies

The reference implementation relies on application and database components outside this sample, including:

* `NATIONALITY`
* `NATIONALITY_SEQ`
* `FND_APP_SECURITY`
* The shared APEX authorization scheme used by the application
* Shared application CSS used by report controls

These components are part of the wider application architecture and are not necessarily included in this sample.

Therefore, the files in this directory should be treated as a **migration reference**, not as a standalone deployable application.

## Reference Scope

This implementation demonstrates the preferred modernization principle:

**Preserve the business workflow, but do not reproduce Oracle Forms architecture unnecessarily.**

A future migration does not need to use the same number of APEX pages, regions, processes, or database objects.

The appropriate design should depend on the functionality of the individual Form while following the same general objectives:

* Preserve required business behavior
* Use native APEX capabilities where appropriate
* Centralize authorization through the target application's permission model
* Protect critical rules on the server side
* Replace unsafe legacy identifier-generation patterns
* Remove obsolete Forms-specific behavior
* Improve maintainability and user experience

## Files

* `hmisfox_page_24.apx` - Oracle APEX Page 24 export for the Nationalities report
* `hmisfox_page_25.apx` - Oracle APEX Page 25 export for the Manage Nationality modal form
* `screenshots/screenshot-p24.png` - Screenshot of the migrated Nationalities report
* `screenshots/screenshot-p25.png` - Screenshot of the migrated Manage Nationality page
