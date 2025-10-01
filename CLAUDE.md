# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Grainery is a Ruby gem for Rails applications that extracts database records and generates seed files organized by database with automatic dependency resolution. It supports multi-database Rails applications (SQL Server, MySQL, PostgreSQL) and handles dependency ordering via topological sort.

## Development Commands

### Building and Publishing

```bash
# Build the gem
gem build grainery.gemspec

# Push to RubyGems (requires API key and OTP)
GEM_HOST_API_KEY=<api_key> gem push grainery-<version>.gem --otp <otp_code>
```

### Testing

```bash
# Run tests (Minitest)
rake test

# Or run tests directly
ruby test/*_test.rb
```

Note: Test suite uses Minitest (migrated from RSpec in v0.2.0).

## Architecture

### Core Components

**`lib/grainery/grainer.rb`** - Main orchestration class that:
- Loads configuration from `config/grainery.yml`
- Detects databases and model base classes automatically
- Builds dependency graphs via `belongs_to` associations
- Performs topological sort for load order
- Harvests data from tables into seed files
- Dumps database schemas (optional)
- Loads seeds in dependency order

**`lib/grainery/railtie.rb`** - Rails integration that loads rake tasks

**`lib/tasks/grainery_tasks.rake`** - Primary rake tasks for harvesting and loading
**`lib/tasks/test_db_tasks.rake`** - Test database management tasks

### Multi-Database Architecture

The gem is designed for Rails applications with multiple databases:

1. **Database Detection**: Inspects `ObjectSpace` for ActiveRecord model base classes (e.g., `ApplicationRecord`, `OtherDB`, `BankingDB`)
2. **Configuration Mapping**: Maps logical database names to connection names, adapters, and model base classes in `config/grainery.yml`
3. **Per-Database Organization**: Creates separate directories for each database under `db/grainery/`
4. **Schema Isolation**: Each database gets its own `schema.rb` dump

### Dependency Resolution

The harvester uses topological sort to determine load order:

1. Analyzes all `belongs_to` associations across models
2. Builds dependency graph (edges = foreign key dependencies)
3. Performs depth-first topological sort
4. Generates `db/grainery/load_order.txt` with correct loading sequence
5. Groups by database while preserving dependencies

### Security Features

**Production Environment Protection**:
- All destructive tasks (`load`, `load_with_schema`, `test:db:*`) check `Rails.env.production?`
- Requires `GRAINERY_ALLOW_PRODUCTION=true` environment variable to override
- Includes 5-second countdown when override is enabled

**Safe Constant Resolution**:
- Whitelisted patterns for model base classes (see `ALLOWED_BASE_CLASS_PATTERN`)
- Prevents arbitrary code execution via constant lookups

**Path Traversal Protection**:
- Validates `grainery_path` is within `Rails.root`

## Key Implementation Details

### Schema Dumping (v0.2.0+)

When `dump_schema: true`:
- Connects to each database via its model base class
- Extracts table definitions using `connection.tables` and `connection.columns`
- Generates `ActiveRecord::Schema.define` format
- Includes column types, attributes (limit, precision, scale, null, default)
- Includes indexes with names and uniqueness constraints
- Skips internal Rails tables (`schema_migrations`, `ar_internal_metadata`)

### Configuration Auto-Detection

`detect_databases_and_models` method:
1. Calls `Rails.application.eager_load!`
2. Scans `ObjectSpace` for classes inheriting from `ActiveRecord::Base`
3. Filters for non-abstract classes with descendants (base classes)
4. Extracts connection config via `connection_db_config`
5. Infers logical names from class names and connection names
6. Writes formatted YAML with comments to `config/grainery.yml`

### Seed File Generation

Format:
- Header comments with database, record count, timestamp
- Single `Model.create!()` call with array of hashes
- Excludes `id`, `created_at`, `updated_at` columns
- Type-aware value formatting (strings, integers, dates, JSON, etc.)

## Version History

- **v0.1.0**: Initial release with multi-database support, dependency resolution
- **v0.2.0**: Added schema dumping, Minitest migration, Rails 6.1-8.x support, production safeguards

## Testing Strategy

The gem includes test database tasks for Rails applications:
- `test:db:setup_for_grainery` - Drops, creates, loads schema
- `test:db:clean` - Truncates all tables (respects foreign keys)
- `test:db:stats` - Shows row counts per table
- `test:db:reset_with_grainery` - Complete reset + seed workflow

Note: Test tasks force `Rails.env = 'test'` and explicitly connect to test database.

## Common Pitfalls

1. **Circular Dependencies**: Topological sort will raise "Circular dependency detected". Check for self-referential or circular foreign keys.
2. **SQL Server Foreign Keys**: Test cleanup uses SQL Server-specific `sp_MSforeachtable` to disable/enable constraints.
3. **Lookup Tables**: Use `lookup_tables` config to harvest ALL records from reference tables instead of limited samples.
4. **Production Override**: When overriding production protection, the 5-second countdown cannot be skipped (intentional safety delay).
