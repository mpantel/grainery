# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-10-01

### Added
- Database schema dumping functionality for all related databases
- Schema files now generated in each database directory (e.g., `db/grainery/primary/schema.rb`)
- New rake task: `grainery:load_with_schema` - Load schemas and seeds together
- New rake task: `grainery:generate_data_only` - Harvest data without schema dump
- New rake task: `grainery:generate_raw` - Harvest data without anonymization
- Schema loading option in `load_seeds` method with `load_schema` parameter
- **Production environment protection**: Destructive tasks now blocked in production by default
  - Affects: `grainery:load`, `grainery:load_with_schema`, and all `test:db:*` tasks
  - Override with `GRAINERY_ALLOW_PRODUCTION=true` environment variable
  - Includes 5-second safety countdown when override is used
- **Data Anonymization**: Automatic anonymization of sensitive fields using Faker gem
  - **Automatic field detection**: `grainery:init_config` scans database schema and auto-detects anonymizable fields
  - **Scoped anonymization**: Support for table-specific and database-specific field configuration using `table.field` or `database.table.field` notation
  - Automatic scoping when duplicate field names are detected across multiple tables
  - Default anonymization for common fields (email, name, phone, address, SSN, credit cards, passwords, tokens, API keys)
  - Greek-specific document anonymization:
    - `greek_vat` - Greek VAT number (AFM - 9 digits)
    - `greek_amka` - Greek Social Security Number (11 digits: DDMMYY + 5 digits)
    - `greek_personal_number` - Greek Personal Number (12 characters: 2 digits + letter + 9-digit AFM)
    - `greek_ada` - Greek ADA/Diavgeia Decision Number (15 characters: 4 Greek letters + 2 digits + 4 Greek letters + dash + 1 digit + 2 Greek letters, e.g., "ΨΜΦΡ69ΟΤΝΡ-9ΤΟ")
    - `greek_adam` - Greek ADAM/Public Procurement Publicity identifier (14-15 characters: 2 digits + PROC or REQ + 9 digits, e.g., "24REQ187755230" or "23PROC456789012")
    - `iban` - Greek IBAN (27 characters)
  - `date_of_birth` - Anonymizes birth dates while preserving approximate age (±2 years, minimum age 18 to preserve adulthood)
  - Selective anonymization: Use `skip` value to preserve real data for specific non-sensitive fields
  - All fake values automatically respect database column size limits
  - Configurable anonymization via `anonymize_fields` in `config/grainery.yml`

### Changed
- `grainery:generate` and `grainery:generate_all` now dump database schemas by default
- All generation tasks (`generate`, `generate_all`, `generate_data_only`) now anonymize data by default
- `grainery:load` continues to load only seed data (schemas optional)
- Schema dump includes table definitions, columns with attributes, and indexes
- Updated test framework from RSpec to Minitest
- Rails dependency updated to support versions 6.1 through 8.x
- Ruby requirement updated to >= 3.2.0
- Anonymization happens during harvest, not during load
- Generated seed files contain anonymized data safe for version control

### Security
- Added production environment safeguards to prevent accidental data loss
- Destructive operations require explicit opt-in via environment variable in production
- Sensitive data is now anonymized by default during harvest
- Safe to commit anonymized seed files to version control
- Lookup tables are not anonymized (reference data)

### Technical Details
- Schema dumps use `ActiveRecord::Schema.define` format
- Each database connection gets its own schema file
- Schema loading occurs before seed data when enabled
- Automatic detection and skip of internal Rails tables (schema_migrations, ar_internal_metadata)
- Anonymization uses Faker gem for realistic fake data
- Automatic field detection uses pattern matching on column names (email, phone, ssn, afm, amka, ada, adam, etc.)
- Detected anonymizable fields are automatically added to `config/grainery.yml` during initialization
- Scoped field resolution with priority: `database.table.field` > `table.field` > `field`
- When duplicate field names detected, automatically uses scoped configuration
- Type-aware anonymization respects column data types and size limits
- String fields automatically truncated to match column maximum length
- Numeric fields maintain their data type
- Date of birth anonymization preserves age categories while protecting actual birth dates

## [0.1.0] - 2025-10-01

### Added
- Initial release
- Automatic database detection and configuration generation
- Multi-database support (SQL Server, MySQL, PostgreSQL)
- Dependency-aware seed loading with topological sort
- One seed file per table organization
- Configurable per-project via `config/grainery.yml`
- Lookup tables support (harvest all records)
- Test database management tasks
- Preserves custom `db/seeds.rb` (loaded last)
- Clean separation of harvested vs custom seeds
- Rake tasks:
  - `grainery:init_config` - Initialize configuration
  - `grainery:generate` - Harvest with limit (100 records per table)
  - `grainery:generate_all` - Harvest ALL records
  - `grainery:load` - Load seeds in dependency order
  - `grainery:clean` - Clean grainery directory
  - `test:db:setup_for_grainery` - Setup clean test database
  - `test:db:seed_with_grainery` - Seed test database
  - `test:db:reset_with_grainery` - Reset and seed test database
  - `test:db:clean` - Truncate all test tables
  - `test:db:stats` - Show test database statistics

[0.2.0]: https://github.com/mpantel/grainery/releases/tag/v0.2.0
[0.1.0]: https://github.com/mpantel/grainery/releases/tag/v0.1.0