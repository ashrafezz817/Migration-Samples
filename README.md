# Oracle Forms to Oracle APEX Migration Samples

## Overview

This repository contains representative samples from an existing Healthcare Information System (HIS) that is being evaluated for migration from **Oracle Forms to Oracle APEX**.

The complete application contains approximately **500 Oracle Forms**, with business logic distributed between Oracle Forms and the Oracle Database.

## Sample Overview

| Sample                              | Area               | Complexity | Purpose                             |
| ----------------------------------- | ------------------ | ---------- | ----------------------------------- |
| [Cashier Shift Open](./01_Simple/)  | Billing / Cashier  | Simple     | Opens a cashier financial shift     |
| [Nationalities](./02_Simple/)       | Setup              | Simple     | Reference-data maintenance          |
| [Discount Packages](./03_Medium/)   | Billing            | Medium     | Package and discount configuration  |
| [Clinics](./04_Medium/)             | Clinical Setup     | Medium     | Clinic configuration and mapping    |
| [Small Cash Invoice](./05_Complex/) | Billing            | Complex    | Operational invoicing workflow      |
| [Patient](./06_Complex/)            | Patient Management | Complex    | Patient registration and management |

## Technical Profile

The figures below are taken from the Oracle Forms exports and are intended to provide a high-level indication of the technical footprint of each sample.

| Sample             | Blocks | Items | Triggers | Program Units | LOVs | Relations | DB Packages | Reports |
| ------------------ | -----: | ----: | -------: | ------------: | ---: | --------: | ----------: | ------: |
| Cashier Shift Open |    2 |   8 |      6 |           3 |  1 |       0 |         0 |     0 |
| Nationalities      |    1 |   6 |      6 |           5 |  0 |       0 |         0 |     0 |
| Discount Packages  |    TBD |   TBD |      TBD |           TBD |  TBD |       TBD |         TBD |     TBD |
| Clinics            |    TBD |   TBD |      TBD |           TBD |  TBD |       TBD |         TBD |     TBD |
| Small Cash Invoice |    TBD |   TBD |      TBD |           TBD |  TBD |       TBD |         TBD |     TBD |
| Patient            |    TBD |   TBD |      TBD |           TBD |  TBD |       TBD |         TBD |     TBD |

> **Note:** Database package and report counts represent dependencies referenced by the Form and are not intended to represent the complete dependency tree of the underlying database objects.

## Complexity Classification

The classifications used in this repository are intended to describe the expected **Forms-to-APEX migration effort**.

### Simple

Typically contains characteristics such as:

* One primary database block
* Limited number of items and triggers
* Straightforward CRUD or transactional behavior
* Limited embedded PL/SQL
* Few external dependencies
* No significant master-detail workflow

### Medium

Typically contains one or more of the following:

* Multiple blocks or master-detail behavior
* More extensive Forms trigger logic
* Dynamic LOVs or record groups
* Embedded business rules
* Cross-form navigation
* Shared Forms library dependencies
* Database procedure or package calls

### Complex

Typically contains several of the following:

* Multiple interacting data blocks
* Large numbers of items and triggers
* Significant embedded PL/SQL business logic
* Complex validations and calculations
* Multiple database dependencies
* Calls to other Forms, reports, packages, or external services
* Workflow or transaction-state logic
* Significant functionality that must be redesigned rather than directly reproduced in APEX

## Contents of Each Sample

Each sample directory contains:

* **`.fmb`** — Original Oracle Forms module
* **`.xml`** — XML export of the Form for source-code inspection and analysis
* **`screenshot.png`** — Screenshot of the current Oracle Forms user interface
* **`README.md`** — Description of the Form, its functionality, technical characteristics, dependencies, and migration considerations

## Migration Expectations

The objective of the migration is not necessarily to reproduce Oracle Forms behavior one-to-one.

Where appropriate, existing functionality may be redesigned using Oracle APEX capabilities and modern database architecture while preserving the required business behavior.

Examples may include:

* Moving business logic from Forms triggers into reusable database APIs
* Removing obsolete or unused Forms logic
* Improving concurrency and transaction handling where legacy implementations require modernization

## Shared Dependencies

Individual Forms may reference shared application components that are not included with every sample, including:

* Oracle Forms Object Libraries (`.olb`)
* PL/SQL Libraries (`.pll`)
* Database packages, procedures, functions, and triggers
* Other Oracle Forms modules
* Oracle Reports
* Shared security functions
* Shared localization and user-interface utilities

The individual sample README files identify significant dependencies where they are relevant to understanding the migration effort.
