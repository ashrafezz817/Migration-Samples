# APEX Reference - Clinics

## Purpose

This directory contains the migrated Oracle APEX implementation corresponding to the legacy `Clinics` Oracle Form.

The implementation is provided as a **reference for the expected migration approach and quality level**. It is not intended to require future Forms to be reproduced using the exact same page structure or technical design.

During migration, legacy Forms functionality may be simplified, redesigned, split across multiple APEX pages, moved into other application domains, replaced with native APEX functionality, or intentionally left outside the current migration scope where appropriate.

The required business behavior should be preserved while avoiding unnecessary reproduction of Forms-specific implementation patterns and legacy data-model responsibilities.

## Migration Mapping

The legacy clinic-maintenance Form was migrated to:

* **Oracle APEX Page 52 - Clinics**
* **Oracle APEX Page 53 - Manage Clinic**

The legacy single-screen maintenance workflow was separated into a searchable report page and a focused modal maintenance page.

No dedicated backend package was introduced for Clinic CRUD operations. The migrated workflow uses native Oracle APEX reporting, form processing, validations, authorization checks, shared LOVs, and the existing database model.

Some responsibilities that existed in the legacy Form were intentionally not retained as Clinic-maintenance responsibilities. These are documented separately below.

## APEX Pages

### Page 52 - Clinics

Page 52 provides the main Clinic reference-data view using an Interactive Report.

The page allows authorized users to:

* Review Clinic records
* Search and filter Clinic data
* Open a Clinic for editing
* Create a new Clinic
* Review Clinic category and CCHI mapping
* Review new-patient and review-visit duration settings
* Review review-period configuration
* Review minimum and maximum patient age
* Review gender restrictions
* Review whether vital signs are required

The Create action is controlled by `CLINICS_CREATE`.

The edit link is available only to users with `CLINICS_UPDATE`.

The report also provides an application empty state when no Clinic records are available.

### Page 53 - Manage Clinic

Page 53 is implemented as a modal dialog using a native APEX Form based on the `CLINICS` table.

The page maintains the Clinic attributes that remain part of the current Clinic domain, including:

* English Clinic name
* Arabic Clinic name
* Clinic category
* CCHI code
* Whether vital signs are required
* New-patient duration
* Review-visit duration
* Review days
* Minimum patient age
* Maximum patient age
* Gender restriction

The page uses native APEX Automatic Row Processing for create, update, and delete operations.

Actions are controlled through the centralized permission model:

* `CLINICS_CREATE`
* `CLINICS_UPDATE`
* `CLINICS_DELETE`

The page includes validations for:

* Required English Clinic name
* Nonnegative duration and review-day values
* Minimum and maximum age between 0 and 150
* Minimum age not exceeding maximum age

Clinic deletion requires explicit confirmation and remains subject to the application's database relationships and business rules.

## Key Modernization Changes

### Separation of List and Maintenance Workflows

The legacy Form combined record browsing and maintenance in a single Oracle Forms screen.

The migrated implementation separates these responsibilities:

* Page 52 provides the searchable Clinic list.
* Page 53 provides focused create, update, and delete functionality in a modal dialog.

This replaces the legacy multi-record Forms block with a standard APEX report-and-form workflow.

### Native APEX Form Processing

Clinic maintenance is straightforward enough that a dedicated PL/SQL domain package is not required for the current CRUD workflow.

Page 53 uses native APEX Form initialization and Automatic Row Processing directly against `CLINICS`, with page validations and centralized authorization applied around those operations.

This demonstrates that migration architecture should match the actual business complexity rather than introducing an additional backend package for every Form.

### Centralized Authorization

The legacy Form used Forms security logic to control insert, update, delete, and query behavior.

The migrated implementation uses the target application's centralized permission model.

Clinic actions are controlled through `FND_APP_SECURITY` permissions instead of reproducing Forms block-property security behavior.

### Database-Backed Reference Data

The legacy Form dynamically populated Clinic categories using Forms runtime record-group logic and used a Forms LOV for CCHI Clinic mapping.

The migrated implementation uses normal APEX shared LOVs for these reference-data relationships.

This removes Forms-specific runtime list-management logic while preserving the required reference-data behavior.

### Validation Improvements

The migrated form uses explicit APEX validations for values that belong to the current Clinic model.

Examples include age-range validation and nonnegative duration/review values.

Validation is presented through the APEX form workflow instead of Forms trigger behavior.

## Waiting Areas Moved Out of the Clinic Domain

The legacy `CLINICS` record contained the following attributes:

* `LOCATION`
* `WATING_ROOM`
* `WATING_ROOM2`

These values are not retained in the migrated Clinic-maintenance pages.

Waiting-area configuration is now modeled as its own application domain using:

* `CLN_WAITING_AREAS`
* `CLN_WAITING_AREA_DOCTORS`
* `CLN_WAITING_AREAS_API`

Waiting areas are configured independently and doctors are assigned to waiting areas through the dedicated waiting-area model.

This removes the legacy assumption that a Clinic directly owns a location and two waiting-room text fields.

`CLN_WAITING_AREAS_API` is not included in this sample because it belongs to the separate waiting-area configuration domain rather than Pages 52 and 53.

## Legacy Attributes Not Carried Forward

The following legacy Clinic fields are intentionally not migrated into the current Clinic-maintenance model because they do not belong to the current Clinic domain:

* `STOP_MY_CLINIC`
* `GENRAL_CLINIC`
* `MONTHLY_AVR_SAL`
* `INC_FACTOR`
* `INC_AVR`
* `DAY_OUT_NEW_VISIT_C`
* `DAY_OUT_FOLOW_VISIT_C`
* `DAY_OUT_NEW_PAT_C`
* `MONTHLY_OPERATION_C`

Their presence in the legacy Form does not require them to be reproduced in the APEX Clinic pages.

This is an example of migration being used to clean up domain boundaries rather than copying every legacy database item into the new interface.

## Functionality Outside the Current Migration Scope

The legacy Form included an **Examinations Setting** action that opened a separate Forms workflow and passed the current Clinic identifier.

That workflow has not been migrated as part of the current Clinics implementation.

It should therefore be treated as functionality outside the present Sample 4 migration scope rather than as functionality implemented by Pages 52 or 53.

## Shared Dependencies

The Clinic reference implementation relies on application and database components outside this sample, including:

* `CLINICS`
* `CLINICS_CCHI`
* Clinic-category reference data
* Shared CCHI and Clinic-category APEX LOVs
* `FND_APP_SECURITY`
* Shared APEX authorization schemes
* Shared application empty-state styling

The wider application also contains the separate waiting-area domain described above, but those objects are not deployment dependencies of the Clinic CRUD pages themselves.

These components are part of the wider application architecture and are not necessarily included in this sample.

Therefore, the files in this directory should be treated as a **migration reference**, not as a standalone deployable application.

## Reference Scope

This implementation demonstrates the preferred modernization principle:

**Preserve the required business behavior, but do not reproduce Oracle Forms architecture or legacy domain boundaries unnecessarily.**

A future migration does not need to use the same number of APEX pages, regions, processes, or database objects.

The appropriate design should depend on the functionality of the individual Form while following the same general objectives:

* Preserve required current business behavior
* Use native APEX capabilities where appropriate
* Centralize authorization through the target application's permission model
* Replace Forms runtime lists with normal APEX reference-data components
* Apply server-side validation to maintained business data
* Move responsibilities into the correct application domain when the legacy model mixed unrelated concerns
* Do not carry obsolete or misplaced legacy fields forward without a current business requirement
* Remove obsolete Forms-specific navigation, window, and presentation behavior
* Improve maintainability and user experience

## Files

* `hmisfox_page_52.apx` - Oracle APEX Page 52 export for the Clinics report
* `hmisfox_page_53.apx` - Oracle APEX Page 53 export for the Manage Clinic modal form
* `screenshots/screenshot-p52.png` - Screenshot of the migrated Clinics report
* `screenshots/screenshot-p53.png` - Screenshot of the migrated Manage Clinic page
