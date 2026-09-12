# Clinics

## Purpose

Provides maintenance of clinic configuration used throughout the Healthcare Information System, including clinic identity, operational settings, patient restrictions, waiting-area configuration, external classification mapping, and related examination preferences.

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

A legacy record group named `DHS_CLINICS` also references:

* `DHS_CLINIC`

This record group exists in the Form definition but should be reviewed during migration to determine whether it is still functionally required.

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

## Dependencies

### Database Packages

No direct Oracle database package dependencies in the Form.

### Database Functions / Procedures

The Form references shared standalone database functionality including:

* `GET_U_PREV20` — used by the shared security logic to determine allowed insert, update, delete, and query operations
* `GetVersion` — used when initializing the Forms application window title

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

The exact legacy navigation relationship should be reviewed during migration because the Form checks for one module name while the open/navigation calls reference another.

### Reports

No report objects or report execution dependencies were identified.

### Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`
* `HMISBUTTON.olb`

These libraries provide shared visual, interface, button, alert, and application behavior used by the legacy Forms application.

## Migration Considerations

The core clinic-maintenance functionality can be implemented using a conventional Oracle APEX maintenance interface, but the configuration breadth and related dependencies should be treated as part of the migration scope.

During migration:

* `CLINICID` generation should not retain the legacy `MAX(CLINICID) + 1` approach. A database sequence, identity mechanism, or centralized API should be used instead.
* The special handling that excludes clinic ID `99` from identifier generation should be reviewed to determine whether it represents a current business rule or legacy behavior.
* Clinic system categories should use a normal database-backed APEX LOV rather than Forms runtime record-group creation.
* CCHI clinic mapping can be implemented using an APEX LOV or search dialog backed by `CLINICS_CCHI`.
* The purpose and current usage of the legacy `DHS_CLINICS` record group should be confirmed before reproducing it.
* Clinic age, gender, status, vital-sign, waiting-room, and operational configuration values should retain their required business behavior and validations.
* Authorization should use the target application's centralized permission model rather than reproducing Forms block-property security logic.
* The related examination-settings workflow should be migrated as an integrated APEX navigation flow rather than reproducing `OPEN_FORM` / `GO_FORM` behavior.
* The inconsistent legacy Form names used by the examination-settings navigation should be resolved during migration.
* Arabic and English presentation should use the application's standard localization and RTL/LTR mechanisms.
* Shared Forms window, button, and presentation utilities do not need direct equivalents where native APEX functionality provides the required behavior.
* Legacy localization logic associated with the `TRANS` table should be reviewed and retained only if still required by the target application.

## Files

* `Clinics.fmb` — Original Oracle Forms module
* `Clinics.xml` — XML export for source inspection and analysis
* `screenshot.png` — Screenshot of the current Oracle Forms user interface
