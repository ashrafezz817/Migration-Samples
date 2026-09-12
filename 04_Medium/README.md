# Clinics

## Purpose

Provides maintenance of clinic configuration used throughout the Healthcare Information System, including clinic identity, operational settings, patient restrictions, waiting-area information, external classification mapping, and related examination preferences.

## Complexity

**Medium**

Although the Form contains a single database block, it manages a relatively broad set of clinic configuration attributes and includes dynamic reference-data loading, external-code mapping, security logic, localization behavior, and navigation to a related configuration Form.

## Main Functionality

* Creates and maintains clinic records
* Maintains English and Arabic clinic names
* Assigns a system category/type to each clinic
* Configures whether vital signs are required
* Maintains expected appointment or service times for new and existing patients
* Defines review-period settings
* Defines minimum and maximum patient age
* Defines applicable patient gender
* Identifies general clinics
* Controls clinic availability/hold status
* Maintains clinic location information
* Maintains primary and secondary waiting-room information
* Maps clinics to a CCHI clinic code and description
* Maintains operational and financial planning values
* Provides access to additional examination settings associated with the clinic
* Applies user permissions to insert, update, delete, and query operations

## Technical Summary

| Component      | Count |
| -------------- | ----: |
| Blocks         |     1 |
| Items          |    26 |
| Triggers       |     9 |
| Program Units  |     6 |
| LOVs           |     1 |
| Relations      |     0 |
| DB Packages    |     0 |
| Report Objects |     0 |

These counts describe the legacy Oracle Forms module only. The migrated APEX reference implementation is documented separately under `APEX_Reference/`.

The Form contains a single database block, `CLINICS`, based on the `CLINICS` table.

Despite the single-block design, the Form contains a relatively large number of configuration attributes and interacts with several supporting reference-data and application components.

## Main Database Objects

### Primary Table

* `CLINICS`

`CLINICS` is the primary setup table maintained by the Form.

### Supporting Objects

* `CLINICS_CCHI`
* `SYS_CAT_TYPES`

`CLINICS_CCHI` supplies the external clinic-code mapping used by the CCHI LOV.

`SYS_CAT_TYPES` is queried during Form initialization to populate the clinic system-category list dynamically.

The Form also contains legacy localization logic in the `DO_INTERFACE` program unit that references the shared `TRANS` table.

A legacy record group named `DHS_CLINICS` references:

* `DHS_CLINIC`

## Key Business Logic

The Form contains logic for:

* Validating that the clinic English name is provided
* Automatically generating the clinic identifier when a new clinic is inserted
* Loading the available system-category values dynamically from `SYS_CAT_TYPES`
* Applying user permissions for insert, update, delete, and query operations
* Retrieving the mapped clinic name when a CCHI code is present
* Supporting Arabic and English interface direction
* Opening a related examination-preference Form for the selected clinic
* Passing the selected clinic identifier to that related Form
* Initializing shared Forms interface and window behavior

The legacy `PRE-INSERT` logic generates `CLINICID` using a `MAX(CLINICID) + 1` pattern, excluding clinic ID `99` from the calculation.

## Forms Characteristics

* One database block
* 26 items
* Nine Forms triggers
* Six Forms program-unit objects
* One LOV
* Dynamic list population from database reference data
* Embedded PL/SQL validation and initialization
* Cross-Form navigation
* Parameter passing between Forms
* Global-variable usage
* Operation-level security logic
* Arabic and English interface-direction handling
* Shared Forms Object Library dependencies
* No master-detail relationships
* No report objects

## Legacy Dependencies

### Database Packages

No database package dependencies.

### Database Functions / Procedures

The Form references shared standalone database functionality including:

* `GET_U_PREV20` - used by the shared security logic to determine allowed insert, update, delete, and query operations
* `GetVersion` - used when initializing the Forms application window title

These are not counted in the `DB Packages` value because they are standalone database functions rather than package calls.

### LOVs

#### `CCHI_CLINICS`

The Form defines one LOV used to map a clinic to an external clinic code.

The LOV is based on `CLINICS_CCHI` and returns:

* Clinic code to `CLINICS.CCHI_CODE`
* Clinic name to `CLINICS.CCHI_NAME`

`CCHI_NAME` is a non-database display item used to show the description of the selected code.

### Dynamic Lists

The `SYS_CAT_TYPE` item is populated during Form initialization from:

* `SYS_CAT_TYPES`

The Form creates and populates a Forms record group dynamically and uses it to populate the list item.

This dependency is separate from the defined `CCHI_CLINICS` LOV.

### Other Forms

The **Examinations Setting** action opens a related legacy Forms module associated with clinic examination preferences.

The navigation logic passes the current `CLINICID` as a parameter and references:

* `OBJC_LIST_PREF_C`
* `M_OBJC_LIST_PREF_CLINIC`

### Reports

No report dependencies.

### Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`
* `HMISBUTTON.olb`

These libraries provide shared visual, interface, button, alert, and application behavior used by the legacy Forms application.

## APEX Reference Implementation

This sample has already been migrated to Oracle APEX for the current Clinic maintenance scope.

The completed reference implementation is available under `APEX_Reference/` and includes:

* Oracle APEX Page 52 - **Clinics**
* Oracle APEX Page 53 - **Manage Clinic**
* Screenshots of both migrated pages
* A dedicated README describing the migrated architecture and modernization decisions

The migration did not reproduce every field and action from the legacy Form. The Clinic domain was simplified so that only attributes that currently belong to Clinic maintenance remain on Pages 52 and 53.

Key changes include:

* Page 52 uses an Interactive Report for clinic reference and configuration data.
* Page 53 uses a native APEX Form and Automatic Row Processing for clinic create, update, and delete operations.
* Create, update, and delete actions use the centralized `CLINICS_CREATE`, `CLINICS_UPDATE`, and `CLINICS_DELETE` permissions.
* Clinic categories and CCHI mappings use standard APEX LOV mechanisms instead of Forms runtime record-group behavior.
* Page-level validations enforce required clinic name, valid nonnegative timing values, and valid patient age ranges.
* The legacy `MAX(CLINICID) + 1` logic is not reproduced in the APEX page workflow. `CLINICID` is not maintained manually by the user.
* Forms-specific window, interface-direction, and navigation behavior was replaced with standard APEX application behavior where applicable.

### Waiting-Area Configuration Moved Out of Clinics

The legacy Form stored clinic location and waiting-room information directly in the `CLINICS` record through:

* `LOCATION`
* `WATING_ROOM`
* `WATING_ROOM2`

These fields are not part of the migrated Clinic maintenance pages.

Waiting-area configuration is now a separate domain using:

* `CLN_WAITING_AREAS`
* `CLN_WAITING_AREA_DOCTORS`
* `CLN_WAITING_AREAS_API`

Waiting areas are configured independently and doctors are assigned to waiting areas through the dedicated waiting-area model rather than storing waiting-room text directly against a Clinic.

The waiting-area tables and API are part of the wider application architecture and are not included in this Clinic sample because Pages 52 and 53 do not directly maintain them.

### Legacy Fields Not Carried Forward

The following legacy Clinic fields are intentionally not part of the migrated Clinic-maintenance model:

* `STOP_MY_CLINIC`
* `GENRAL_CLINIC`
* `MONTHLY_AVR_SAL`
* `INC_FACTOR`
* `INC_AVR`
* `DAY_OUT_NEW_VISIT_C`
* `DAY_OUT_FOLOW_VISIT_C`
* `DAY_OUT_NEW_PAT_C`
* `MONTHLY_OPERATION_C`

These values are not carried forward simply because they existed on the legacy Form. They do not belong to the current Clinic maintenance domain.

### Examinations Setting

The legacy **Examinations Setting** action is not included in the current APEX migration scope.

The current Clinic reference implementation therefore does not reproduce the legacy `OPEN_FORM` / `GO_FORM` workflow to `M_OBJC_LIST_PREF_CLINIC`.

This does not imply that the workflow is permanently retired. It has not been migrated as part of the current Clinic implementation.

### Native APEX Processing

No dedicated Clinic database package was introduced for Pages 52 and 53.

The migrated workflow uses native APEX reporting, form processing, validations, LOVs, and authorization because the remaining Clinic-maintenance operations are straightforward reference/configuration-data maintenance.

This demonstrates that migration architecture should match the actual business responsibility rather than introducing additional backend layers where they are not required.

The APEX implementation is provided as a reference for the expected migration approach and quality level. It is not intended to prescribe an exact one-to-one design for other Forms.

See [`APEX_Reference/README.md`](APEX_Reference/README.md) for details of the migrated implementation.

## Files

* `Clinics.fmb` - Original Oracle Forms module
* `Clinics.xml` - XML export of the Oracle Forms module
* `screenshot.png` - Screenshot of the current Oracle Forms user interface
* `APEX_Reference/` - Completed Oracle APEX reference implementation, page exports, screenshots, and migration notes
