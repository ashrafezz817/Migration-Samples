# Oracle Forms to Oracle APEX Migration Samples

## Overview

This repository contains representative samples from an existing Healthcare Information System (HIS) that is being evaluated for migration from **Oracle Forms to Oracle APEX**.

The complete application contains approximately 550 Oracle Forms, with business logic distributed between Oracle Forms and the Oracle Database. Based on the current application inventory, the Forms are classified into approximately 150 Simple, 200 Medium, and 200 Complex modules.

These samples were selected to represent different functional areas and levels of migration complexity.

The samples are representative examples only and should not be interpreted as the complexity distribution of the complete application.

Each numbered sample includes the legacy Oracle Forms implementation and an Oracle APEX reference implementation showing the migration approach already used in the target application. These references demonstrate the expected migration approach and quality level, but they are not intended to require future Forms to be reproduced using the exact same page structure or technical design.

## Sample Overview

| Sample | Area | Complexity | Purpose |
| --- | --- | --- | --- |
| [Cashier Shift Open](./01_Simple/) | Billing / Cashier | Simple | Opens a cashier financial shift |
| [Nationalities](./02_Simple/) | Setup | Simple | Reference-data maintenance |
| [Discount Packages](./03_Medium/) | Billing | Medium | Package and discount configuration |
| [Clinics](./04_Medium/) | Clinical Setup | Medium | Clinic configuration and mapping |
| [Small Cash Invoice](./05_Complex/) | Billing | Complex | Operational invoicing workflow |
| [Patient](./06_Complex/) | Patient Management | Complex | Patient registration and management |

## Technical Profile

The figures below describe the structural footprint of the legacy Oracle Forms modules.

| Sample | Blocks | Items | Triggers | Program Units | LOVs | Relations | DB Packages | Report Objects |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Cashier Shift Open | 2 | 8 | 6 | 3 | 1 | 0 | 0 | 0 |
| Nationalities | 1 | 6 | 6 | 5 | 0 | 0 | 0 | 0 |
| Discount Packages | 3 | 24 | 14 | 8 | 1 | 1 | 0 | 0 |
| Clinics | 1 | 26 | 9 | 6 | 1 | 0 | 0 | 0 |
| Small Cash Invoice | 5 | 202 | 95 | 30 | 15 | 2 | 1 | 1 |
| Patient | 2 | 170 | 119 | 20 | 10 | 0 | 2 | 0 |

> **Note:** Blocks, Items, Triggers, Program Units, LOVs, Relations, and Report Objects are structural Oracle Forms object counts. DB Packages represents distinct active Oracle database package references in the Form code. External reports, database objects, shared libraries, other Forms, and indirect dependencies are documented separately and are not necessarily reflected in these counts.

## APEX Reference Implementations

The APEX references demonstrate several different migration patterns rather than applying one technical solution to every Form.

| Legacy Sample | APEX Reference | Backend Approach |
| --- | --- | --- |
| Cashier Shift Open | Page 49 - Start Cashier Shift | Scoped `BIL_CASHIER_SHIFT` API |
| Nationalities | Pages 24 and 25 - Nationalities / Manage Nationality | Native APEX report and form processing |
| Discount Packages | Pages 63 and 64 - Bundled Offers / Manage Bundled Offer | Scoped `BIL_OFFERS_ADMIN` API |
| Clinics | Pages 52 and 53 - Clinics / Manage Clinic | Native APEX report and form processing |
| Small Cash Invoice | Page 48 - Patient Invoice | `BIL_INVOICE_API`, `BIL_IMPORT`, and `BIL_INVOICE_ENGINE` reference extracts |
| Patient | Pages 17 and 19 - Patients / Patient Demographics | `PATIENT_MGMT_PKG` patient-management API |

The references show that migration may include:

- Replacing straightforward Forms CRUD with native APEX functionality
- Splitting one large Form into multiple focused APEX pages
- Moving authoritative business rules into reusable database APIs
- Separating responsibilities that were combined in a legacy Form
- Retiring or excluding legacy functionality that is no longer part of the target workflow
- Improving transaction safety, optimistic locking, concurrency handling, and server-side validation
- Keeping shared application services outside an individual migration sample when their internal implementation is not required to understand the workflow

The APEX exports represent the current migrated state of the corresponding workflows. A visible control or legacy field in an export should not automatically be interpreted as a target migration requirement when the individual sample README explicitly marks that functionality as outside scope.

For example, the Patient reference still contains residual Discount Card controls in Page 19, but Discount Card functionality is **not part of the intended Patient migration scope** and should not be included in the migration estimate for that sample.

## Complexity Classification

The classifications used in this repository describe the expected **Forms-to-APEX migration effort**.

### Simple

Typically contains characteristics such as:

- One primary database block
- Limited number of items and triggers
- Straightforward CRUD or transactional behavior
- Limited embedded PL/SQL
- Few external dependencies
- No significant master-detail workflow

### Medium

Typically contains one or more of the following:

- Multiple blocks or master-detail behavior
- More extensive Forms trigger logic
- Dynamic LOVs or record groups
- Embedded business rules
- Cross-Form navigation
- Shared Forms library dependencies
- Database procedure or package calls

### Complex

Typically contains several of the following:

- Multiple interacting data blocks
- Large numbers of items and triggers
- Significant embedded PL/SQL business logic
- Complex validations and calculations
- Multiple database dependencies
- Calls to other Forms, reports, packages, or external services
- Workflow or transaction-state logic
- Significant functionality that must be redesigned rather than directly reproduced in APEX

## Contents of Each Sample

Each numbered sample directory contains the legacy source material:

- **`.fmb`** - Original Oracle Forms module
- **`.xml`** - XML export of the Form
- **`screenshot.png`** - Screenshot of the Oracle Forms user interface
- **`README.md`** - Description of the legacy Form, its functionality, technical characteristics, dependencies, and APEX migration reference

Each numbered sample also contains an **`APEX_Reference/`** directory with the corresponding migrated implementation. Depending on the sample, this can include:

- Oracle APEX page exports
- APEX screenshots
- Scoped backend SQL packages
- JavaScript resources used by the migrated workflow
- An APEX-specific README describing the migration mapping, modernization decisions, shared dependencies, and reference boundary

Not every APEX reference contains a custom database package. Native APEX processing is intentionally used where it is sufficient for the workflow.

## Supplemental Examples

The [`Extras/`](./Extras/) directory contains additional Oracle Forms XML exports and screenshots from other areas of the application.

These files are supplemental reference material only. They are **not part of the six representative Simple, Medium, and Complex samples**, are not included in the Technical Profile counts, and do not have corresponding APEX reference implementations in this repository.

They are included to give reviewers additional exposure to the wider Forms application without expanding the defined six-sample estimation scope.

## Migration Expectations

The objective of the migration is not to reproduce Oracle Forms behavior one-to-one.

The required business behavior should be preserved while the implementation is modernized where appropriate.

The reference implementations demonstrate that legacy functionality may be:

- Simplified or redesigned
- Split across multiple APEX pages
- Moved into reusable database APIs
- Replaced with native APEX functionality
- Separated into a more appropriate application domain
- Excluded when the functionality is obsolete or outside the current migration scope

The exact APEX page structure and package boundaries shown in these samples are reference designs, not mandatory templates for every remaining Form.

The individual sample READMEs define the migration scope when the current APEX export contains residual or not-yet-removed functionality.

## Backend Reference Scope

Backend files included under `APEX_Reference/` are scoped to demonstrate the business logic relevant to that sample.

They are not intended to expose the complete production backend.

For complex workflows, the reference may include more than the page-facing procedure alone when the underlying calculation, import, validation, or persistence logic is material to understanding the migration effort.

Shared application infrastructure such as security, settings, messaging, reporting, queue, stock, insurance utilities, and other reusable services may remain outside the sample and are documented as dependencies where relevant.

The APEX references should therefore not be treated as standalone deployable applications or database subsystems.

## Shared Dependencies

Individual Forms and APEX references may depend on shared application components that are not included with every sample, including:

- Oracle Forms Object Libraries (`.olb`)
- PL/SQL Libraries (`.pll`)
- Database packages, procedures, functions, triggers, sequences, and views
- Other Oracle Forms modules
- Other Oracle APEX pages
- Oracle Reports and reporting services
- Shared security and authorization components
- Shared application settings
- Shared localization and user-interface utilities
- External integrations

The individual sample README files document the dependencies relevant to understanding each migration.

## Assessment Scope

These samples are intended to support an initial migration assessment and budgetary estimate.

They provide both the legacy implementation and examples of the modernization approach already used in the target Oracle APEX application.

A detailed implementation estimate for the complete HIS would require review of the full Forms inventory, dependency relationships, shared libraries, database logic, reporting requirements, integrations, and the complexity distribution of the remaining Forms.

The migration should preserve required business behavior, but a direct one-to-one reproduction of every Oracle Forms implementation detail is not expected where a more appropriate Oracle APEX or database-based design is available.
