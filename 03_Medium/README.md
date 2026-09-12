# Discount Packages

## Purpose

Provides maintenance of discount packages and offers by defining the offer header, validity period, pricing, and the individual services included in the package.

## Complexity

**Medium**

This Form represents a master-detail configuration workflow with multiple data blocks, embedded pricing logic, a service-selection LOV, detail-row calculations, and dependencies on pricing and insurance-network configuration.

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

These counts describe the legacy Oracle Forms module only. The migrated APEX reference implementation and its related backend components are documented separately under `APEX_Reference/`.

The Form contains:

* `OFFERS` - master database block
* `OFFERS_DTL` - detail database block containing the services included in the offer
* `TOOLS` - non-database utility block

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

## Legacy Dependencies

### Database Packages

No direct Oracle database package dependencies in the Form.

### Database Functions / Procedures

The Form references shared standalone database functionality including:

* `GetVersion` - used when initializing the Forms application window
* `GET_U_PREV20` - referenced by the shared `CHK_SEC` program unit for legacy operation-level security

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

The Forms relation coordinates detail queries and prevents masterless detail operations.

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

* Oracle APEX Page 63 - **Bundled Offers**
* Oracle APEX Page 64 - **Manage Bundled Offer**
* A migration reference extract of `BIL_OFFERS_ADMIN`
* Screenshots covering the main bundle page, empty state, and maintenance dialog
* A dedicated README describing the migrated architecture and modernization approach

The migration did not reproduce the Oracle Forms master-detail screen one-to-one. The original workflow was redesigned as a bundle-management workspace with a separate modal page for bundle-header maintenance.

Key changes include:

* Page 63 provides a searchable bundled-offer list, selected bundle overview, financial totals, savings presentation, and component maintenance.
* Bundle components are maintained through an APEX Interactive Grid rather than a Forms detail block.
* Page 64 provides focused create, update, and retirement actions for the bundle header.
* Header and component business operations are delegated to `BIL_OFFERS_ADMIN` rather than implemented as direct page DML.
* The backend resolves service pricing from the applicable cash price-list context and validates pricing on the server.
* Bundle totals are recalculated server-side after component changes.
* `OBJECT_VERSION_NUMBER` is used for optimistic locking on headers and detail rows.
* Bundle retirement uses logical deletion behavior and also retires active components.
* Bundle and component operations are scoped to the current information center.
* Authorization uses centralized application permissions for bundle creation, update, retirement, and component maintenance.
* The legacy `MAX(...) + 1` identifier-generation approach is no longer used by the APEX workflow.
* Forms-specific master-detail coordination and window behavior were replaced with native APEX interaction patterns.

The backend file under `APEX_Reference/backend/` is intentionally limited to the bundled-offer operations used by this sample and the private helpers those operations require. Unrelated functionality from the production package is not included.

The APEX implementation is provided as a reference for the expected migration approach and quality level. It is not intended to prescribe an exact one-to-one design for other Forms.

See [`APEX_Reference/README.md`](APEX_Reference/README.md) for details of the migrated implementation.

## Files

* `disc_packages.fmb` - Original Oracle Forms module
* `disc_packages.xml` - XML export of the Oracle Forms module
* `screenshot.png` - Screenshot of the current Oracle Forms user interface
* `APEX_Reference/` - Completed Oracle APEX reference implementation, page exports, backend reference extract, screenshots, and migration notes
