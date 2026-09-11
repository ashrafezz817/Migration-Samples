# Discount Packages

## Purpose

Provides maintenance of discount packages and offers by defining the offer header, validity period, pricing, and the individual services included in the package.

## Complexity

**Medium**

This Form represents a master-detail configuration workflow with multiple data blocks, embedded pricing logic, a service-selection LOV, detail-row calculations, and dependencies on the pricing and insurance-network configuration.

## Main Functionality

* Creates and maintains discount packages and offers
* Defines the offer name and validity period
* Associates the offer with the current information center
* Determines the applicable price list
* Adds individual services to an offer
* Retrieves the normal service price and default discount
* Records the offer price for each service
* Calculates the total normal price of the package
* Calculates the total offer price
* Maintains the relationship between the offer header and its service details
* Prevents deletion of an offer while matching detail records exist

## Technical Summary

| Component      | Count |
| -------------- | ----: |
| Blocks         |     3 |
| Items          |    24 |
| Triggers       |    14 |
| Program Units  |     8 |
| LOVs           |     1 |
| Relations      |     1 |
| DB Packages    |     0 |
| Report Objects |     0 |

The Form contains:

* `OFFERS` — master database block
* `OFFERS_DTL` — detail database block containing the services included in the offer
* `TOOLS` — non-database utility block

The master-detail relationship is defined by `OFFERS_OFFERS_DTL`.

## Main Database Objects

### Primary Tables

* `OFFERS`
* `OFFERS_DTL`

`OFFERS` stores the package or offer header information.

`OFFERS_DTL` stores the individual services and pricing details belonging to each offer.

### Supporting Tables

* `INSURANCE_NET_WORKS`
* `PRICE_PLAN_M`
* `PRICE_PLAN_DTL`
* `SERVICES`

These objects are used to determine the applicable price list and retrieve service information, normal pricing, and default discounts.

The Form also contains legacy localization logic in the `DO_INTERFACE` program unit that references the shared `TRANS` table.

## Key Business Logic

The Form contains logic for:

* Assigning the current information center to a new offer
* Determining the applicable `LIST_ID` from the configured insurance network and price plan
* Automatically assigning an offer identifier
* Defaulting the offer start date to the current date
* Defaulting the offer end date to 30 days after the start date
* Coordinating the `OFFERS` and `OFFERS_DTL` master-detail blocks
* Preventing a master offer from being deleted while detail records still exist
* Retrieving service information through the `SERVICES` LOV
* Retrieving the normal service price and default discount
* Calculating the total normal price from the offer detail rows
* Calculating the total offer price from the offer detail rows
* Copying those calculated totals to the offer header
* Retrieving the service description when existing detail records are queried
* Generating a unique row identifier for new detail records
* Defaulting or enforcing the service quantity used by the legacy package design

The legacy implementation generates identifiers using `MAX(...) + 1` patterns for both the offer identifier and detail row identifier.

## Forms Characteristics

* Two database blocks
* One non-database utility block
* Master-detail workflow
* One Forms relation
* One service-selection LOV
* Dynamic pricing lookup
* Header totals derived from detail records
* Item, block, and form-level triggers
* Embedded PL/SQL business logic
* Forms-generated master-detail coordination logic
* Global-variable usage
* Shared Forms Object Library dependencies
* No report objects

## Dependencies

### Database Packages

No direct Oracle database package dependencies in the Form.

### Database Functions / Procedures

The Form references shared standalone database functionality including:

* `GetVersion` — used when initializing the Forms application window
* `GET_U_PREV20` — referenced by the shared `CHK_SEC` program unit for legacy operation-level security

These are not counted in the `DB Packages` value because they are standalone database functions rather than package calls.

### LOVs

#### `SERVICES`

The service LOV allows a service to be selected for an offer and returns:

* Service code
* Service description
* Normal price
* Default discount

Its query uses pricing and network configuration from:

* `INSURANCE_NET_WORKS`
* `PRICE_PLAN_DTL`
* `SERVICES`

The returned values populate the `OFFERS_DTL` detail record.

### Master-Detail Relationship

The Form defines the relation:

`OFFERS_OFFERS_DTL`

The relationship joins the detail block to the offer header using:

* `LIST_ID`
* `OFERID`

The legacy Forms relation automatically coordinates detail queries and prevents masterless detail operations.

### Other Forms

No significant cross-Form dependency.

### Reports

No report objects or report execution dependencies.

### Shared Forms Libraries

The Form references shared Oracle Forms Object Libraries including:

* `BUSINESSXP.olb`
* `HMISTEXT.olb`
* `HMISCANVAS.olb`

These libraries provide shared visual, interface, alert, and application behavior used by the legacy Forms application.

## Migration Considerations

The functionality maps well to an Oracle APEX master-detail or parent/child maintenance interface, but several parts of the existing Forms implementation should be redesigned rather than reproduced directly.

During migration:

* The `OFFERS` and `OFFERS_DTL` relationship should be implemented using normal database foreign-key relationships and an appropriate APEX master-detail interface.
* `OFERID` and detail `ROW_ID` generation should not retain the legacy `MAX(...) + 1` implementation. Sequences, identity columns, or centralized database APIs should be used instead.
* Price-list determination should be centralized in reusable database logic rather than duplicated in page-level processing.
* Normal service price, discount, and offer-price calculations should have clearly defined server-side rules so that pricing cannot depend only on client-side page state.
* Package totals should be recalculated and validated on the server before saving.
* Referential integrity between offer headers and detail rows should be enforced by database constraints rather than relying on Forms master-detail triggers.
* Deletion rules should be enforced transaction-safely in the database.
* Service selection can be implemented using an APEX LOV or search dialog backed by the appropriate price-list query.
* Legacy Forms-generated coordination units such as `QUERY_MASTER_DETAILS`, `CLEAR_ALL_MASTER_DETAILS`, and `CHECK_PACKAGE_FAILURE` do not need direct equivalents in APEX.
* Shared Forms visual and window-management behavior does not need to be reproduced where native APEX functionality provides an equivalent user experience.
* Legacy localization logic associated with the `TRANS` table should be reviewed and retained only if still required by the target application.

## Files

* `disc_packages.fmb` — Original Oracle Forms module
* `disc_packages.xml` — XML export for source inspection and analysis
* `screenshot.png` — Screenshot of the current Oracle Forms user interface
