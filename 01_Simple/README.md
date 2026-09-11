| Component           | Count |
| ------------------- | ----: |
| Record Groups       |     1 |
| Data Source Columns |    19 |
| Alerts              |     2 |
| Canvases            |     1 |
| Windows             |     1 |
| Property Classes    |     1 |
| Visual Attributes   |    10 |
| Module Parameters   |     1 |
| Graphics objects    |     4 |

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

## Dependencies

### Database Packages

No direct Oracle database package dependencies were identified in the Form.

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

## Migration Considerations

The functionality can be implemented in Oracle APEX as a relatively small transactional workflow.

During migration:

* Shift reference generation should not retain the legacy `MAX(...) + 1` approach. A database sequence, identity mechanism, or centralized API should be used instead.
* Prevention of multiple simultaneous open shifts should be enforced transaction-safely in the database rather than relying only on Forms validation.
* Current user and information-center context should use the equivalent APEX application/session security context.
* Legacy Forms presentation and navigation utilities from shared Object Libraries do not need to be reproduced directly where equivalent APEX functionality exists.
* Business rules currently implemented in Forms triggers should preferably be centralized in reusable database logic where appropriate.

## Files

* `Cashier_Shifts_Open.fmb` — Original Oracle Forms module
* `Cashier_Shifts_Open.xml` — XML export for source inspection and analysis
* `screenshot.png` — Screenshot of the current Oracle Forms user interface
