# Backend Reference - Patient Invoice

## Purpose

This directory contains the backend implementation included with the migrated Patient Invoice reference on Oracle APEX Page 48.

The backend is intentionally broader than a thin list of procedures called directly from the page. A complex invoice workflow cannot be assessed accurately from the APEX page alone because a large part of the migration effort is contained in server-side import, pricing, calculation, validation, and invoice-creation logic.

At the same time, this directory does not contain the entire billing backend. Functionality unrelated to the Patient Invoice workflow is intentionally excluded.

## Backend Architecture

The reference follows this general structure:

```text
Page 48 - Patient Invoice
        |
        v
BIL_INVOICE_API
        |
        +--> BIL_IMPORT
        |
        +--> BIL_INVOICE_ENGINE
        |
        +--> shared payment, queue, stock, print and messaging services
```

`BIL_INVOICE_API` acts as the Page 48 orchestration layer.

`BIL_IMPORT` prepares invoice lines originating from service requests, new visits, and packages.

`BIL_INVOICE_ENGINE` performs the authoritative invoice calculation and invoice persistence path used by both preview and final creation.

This separation keeps page orchestration, source import, and financial calculation responsibilities distinct.

## Included Files

### `BIL_INVOICE_API.sql`

This file is a **migration reference extract** limited to the Patient Invoice workflow.

It contains the Page 48 operations required for:

- Loading Bundled Offer components into the invoice grid
- Reconstructing hidden Bundled Offer parent rows before authoritative calculation
- Loading package lines
- Calculating the complete editable invoice preview
- Building request and new-visit import preview collections
- Creating the final invoice and coordinating downstream posting
- Building the invoice print URL
- Sending the invoice message

The exposed Page 48 operations are:

- `GET_BUNDLED_OFFER_IG_LINES`
- `EXPAND_BUNDLED_OFFER_IG_LINES`
- `GET_PACKAGE_LINES`
- `CALCULATE_EDITABLE_INVOICE_PREVIEW`
- `BUILD_IMPORT_PREVIEW_COLLECTION`
- `CREATE_FULL_INVOICE`
- `BUILD_PRINT_URL`
- `SEND_INVOICE_MESSAGE`

Older or unrelated package operations are intentionally not included.

### `BIL_INVOICE_ENGINE.sql`

`BIL_INVOICE_ENGINE` contains the authoritative financial and persistence logic behind the invoice workflow.

Its public surface is deliberately small:

- `GET_PACKAGE_DEFINITION_TOKEN`
- `PREVIEW_INVOICE`
- `CREATE_INVOICE`

The package body is substantial because it contains the business rules that make this sample complex. The included logic covers areas such as:

- Patient and payer context validation
- Service and price-list resolution
- Service pricing
- Plan and manual discounts
- Patient and company financial shares
- VAT calculation
- Package validation and package pricing methods
- Bundled Offer validation and pricing evidence
- Quantity validation
- Request and approval evidence
- Invoice totals
- Final discount handling
- Cash amount calculation
- Invoice header and detail persistence
- Protection against stale or inconsistent package and offer definitions

The engine is kept in the sample because replacing it with a single call such as `PREVIEW_INVOICE` or `CREATE_INVOICE` would hide a major part of the actual migration effort.

### `BIL_IMPORT.sql`

`BIL_IMPORT` contains the source-to-invoice conversion logic used by the Patient Invoice workflow.

It covers:

- Service-request import
- Session-scoped request-line selection support
- Approval checks for requested services
- Request price validation
- Expansion of requested packages
- Manual package expansion
- New consultation or review visit service resolution
- Package definition evidence
- Conversion of imported lines into `BIL_INVOICE_ENGINE` input records

The package supports the distinction between the source transaction and the final authoritative invoice calculation. Imported request prices, package definitions, and visit services are validated again against the current billing context before invoice creation.

## Preview and Final Creation

Page 48 does not treat browser-side calculations as authoritative.

The editable grid is converted to backend line structures and passed through `BIL_INVOICE_ENGINE` for the complete invoice calculation. The resulting preview returns calculated values such as:

- Gross amount
- Discounts
- Net amount
- Patient share
- Company share
- Patient VAT
- Company VAT
- Amount due
- Payment status

Before final invoice creation, the server recalculates the invoice again from the submitted lines rather than trusting previously displayed browser values.

This means the same backend rules are used for preview and final creation.

## Package and Bundled Offer Handling

Packages and Bundled Offers require additional server-side evidence because the visible Interactive Grid does not necessarily contain every logical row used by the calculation engine.

For packages, the backend retains package identity, pricing method, component order, parent relationship, and a package-definition token.

For Bundled Offers, Page 48 displays the component rows while the zero-value logical parent is hidden from the user. `BIL_INVOICE_API` reconstructs the parent before preview and invoice creation and validates the submitted component evidence against the current offer definition.

This allows the user interface to remain simple without weakening server-side validation.

## Final Invoice Orchestration

`CREATE_FULL_INVOICE` coordinates the final transaction after the invoice lines have been validated and recalculated.

The workflow can include:

- Invoice creation
- Payment posting
- Doctor queue posting
- Stock posting
- Print URL generation
- Invoice messaging
- Request-id protection against accidental duplicate invoice creation

The specialized implementations behind payment, queue, stock, printing, and messaging are shared application services and are outside this sample.

## Shared Dependencies

These backend files depend on wider billing and application infrastructure that is not included in this directory.

Examples include:

- `BIL_TYPES`
- `BIL_PATIENT_CONTEXT`
- `BIL_SERVICE_CONTEXT`
- `BIL_PRICE_RULE`
- `BIL_CLASS_RULE`
- `BIL_OFFER_RULE`
- `BIL_PAYMENT`
- `BIL_QUEUE_POSTING`
- `BIL_STOCK_POSTING`
- `BIL_REPORTS_PRINT`
- `BIL_MESSAGE`
- `INS_COMP_UTIL`
- Oracle APEX collections and session context

Major data structures used by the workflow include:

- `T_INV`
- `D_INV`
- `SERVICES`
- `PRICE_PLAN_DTL`
- `PACKAGE_DTL`
- `OFFERS`
- `OFFERS_DTL`
- `PAT_SERV_REQ`
- `V_SERVICES_REQ`
- `BIL_REQUEST_INV_SELECTION`
- `BIL_INVOICE_CREATE_REQUEST`
- `PAT_VISIT_M`
- `DOCTORS`
- `DOCTOR_CONSULTATION`

These dependencies remain part of the wider application architecture rather than being copied into the migration sample.

## Reference Boundary

The purpose of these files is to expose enough backend logic to demonstrate the real complexity of the Patient Invoice migration without publishing unrelated billing functionality.

The reference boundary therefore includes:

- Page-facing invoice orchestration
- Request, visit, and package import logic
- Package and Bundled Offer reconstruction and validation
- Authoritative pricing and financial calculation
- Invoice persistence
- Coordination with downstream billing services

The boundary stops at reusable application services whose internal implementation is not necessary to understand the invoice migration, including payment, queue, stock, reporting, messaging, and shared billing-rule infrastructure.

The files in this directory are not a standalone deployable billing subsystem. They rely on the surrounding HMIS application schema, shared packages, tables, sequences, triggers, application context, and configuration.

## Migration Principle

The reference demonstrates an important migration principle for complex Oracle Forms modules:

**Move authoritative business rules out of the browser and into reusable server-side components, while keeping the APEX page focused on workflow and user interaction.**

A future migration does not need to reproduce these exact package boundaries. The important requirement is that complex billing behavior remains centralized, testable, transactional, and protected from client-side manipulation.
