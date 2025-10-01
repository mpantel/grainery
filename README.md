# Grainery

Database seed storage system for Rails applications. Extract database records and generate seed files organized by database with automatic dependency resolution. Like a grainery stores grain, this gem stores and organizes your database seeds.

> **Note:** This gem was developed with assistance from [Claude](https://claude.ai), Anthropic's AI assistant. Claude helped with code generation, documentation, and testing strategies throughout the development process.

> **⚠️ Development Status:** This gem is in active development and does not yet have a comprehensive test suite. While the core functionality has been tested manually, automated tests are planned for future releases. Use with caution in production environments.

## Features

- ✅ Automatic database detection
- ✅ Dependency-aware loading (topological sort)
- ✅ Multi-database support
- ✅ Database schema dumping for all related databases
- ✅ Configurable per project
- ✅ Preserves custom seeds
- ✅ One seed file per table
- ✅ Clean separation of concerns
- ✅ Supports SQL Server, MySQL, PostgreSQL
- ✅ Test database management tasks
- ✅ Rails 6.1 - 8.x support

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'grainery', path: 'grainery'
```

And then execute:

```bash
bundle install
```

## Usage

### 1. Initialize Configuration

```bash
rake grainery:init_config
```

This auto-detects:
- All databases and model base classes
- Anonymizable fields in your database schema (email, phone, SSN, Greek documents, etc.)
- Creates `config/grainery.yml` with detected configuration

### 2. Harvest Data

```bash
# Harvest with limit (100 records per table) + schema dump + anonymization
rake grainery:generate

# Harvest ALL records + schema dump + anonymization (use with caution)
rake grainery:generate_all

# Harvest data only (no schema dump) + anonymization
rake grainery:generate_data_only

# Harvest without anonymization (raw production data - use with extreme caution!)
rake grainery:generate_raw
```

**Note:** By default, sensitive fields are anonymized using Faker. Configure anonymization in `config/grainery.yml`.

### 3. Load Seeds

```bash
# Load seeds only (blocked in production)
rake grainery:load

# Load schemas + seeds (blocked in production)
rake grainery:load_with_schema

# Override production protection (use with extreme caution!)
GRAINERY_ALLOW_PRODUCTION=true rake grainery:load
```

**Note:** Loading tasks are blocked in production by default to prevent accidental data loss.

This loads:
1. Database schemas (if using `load_with_schema`)
2. Harvested seeds (in dependency order)
3. Custom seeds from `db/seeds.rb` (last)

## Directory Structure

```
db/
├── grainery/                   # Harvested seeds (auto-generated)
│   ├── load_order.txt         # Load order respecting dependencies
│   ├── primary/               # Primary database
│   │   ├── schema.rb          # Database schema dump
│   │   ├── users.rb
│   │   ├── posts.rb
│   │   └── comments.rb
│   ├── other/                 # Other database
│   │   ├── schema.rb          # Database schema dump
│   │   └── projects.rb
│   └── banking/               # Banking database
│       ├── schema.rb          # Database schema dump
│       └── employees.rb
└── seeds.rb                   # Custom seeds (loaded last)
```

## Configuration

`config/grainery.yml`:

```yaml
# Path for harvested seed files
grainery_path: db/grainery

# Database connection mappings
database_connections:
  primary:
    connection: test
    adapter: sqlserver
    model_base_class: ApplicationRecord
  other:
    connection: other
    adapter: sqlserver
    model_base_class: OtherDB
  # ... other databases

# Lookup tables (harvest all records)
lookup_tables: []

# Field anonymization (column_name => faker_method)
# Set to empty hash {} to disable anonymization
anonymize_fields:
  email: email
  first_name: first_name
  last_name: last_name
  name: name
  phone: phone_number
  phone_number: phone_number
  address: address
  street_address: street_address
  city: city
  state: state
  zip: zip_code
  zip_code: zip_code
  postal_code: zip_code
  ssn: ssn
  credit_card: credit_card_number
  password: password
  token: token
  api_key: api_key
  secret: secret
  iban: iban
  vat_number: greek_vat
  afm: greek_vat
  amka: greek_amka
  social_security_number: greek_amka
  ssn_greek: greek_amka
  personal_number: greek_personal_number
  personal_id: greek_personal_number
  afm_extended: greek_personal_number
  ada: greek_ada
  diavgeia_id: greek_ada
  decision_number: greek_ada
  adam: greek_adam
  adam_number: greek_adam
  procurement_id: greek_adam
  date_of_birth: date_of_birth
  birth_date: date_of_birth
  dob: date_of_birth
  birthdate: date_of_birth
  identity_number: identity_number
  id_number: identity_number
  national_id: identity_number
```

## Available Rake Tasks

### Grainery Tasks

```bash
# Initialize configuration
rake grainery:init_config

# Harvest data (with limit) + schema dump + anonymization
rake grainery:generate

# Harvest ALL records + schema dump + anonymization
rake grainery:generate_all

# Harvest data only (no schema dump) + anonymization
rake grainery:generate_data_only

# Harvest without anonymization (raw production data)
rake grainery:generate_raw

# Load harvested + custom seeds
rake grainery:load

# Load schemas + seeds + custom seeds
rake grainery:load_with_schema

# Clean grainery directory
rake grainery:clean
```

### Test Database Tasks

```bash
# Setup clean test database (schema only)
rake test:db:setup_for_grainery
# or: rake db:test:setup_for_grainery

# Seed test database with grainery data
rake test:db:seed_with_grainery

# Reset and seed (one command)
rake test:db:reset_with_grainery
# or: rake db:test:reset_with_grainery

# Clean test database (truncate all tables)
rake test:db:clean
# or: rake db:test:clean

# Show test database statistics
rake test:db:stats
# or: rake db:test:stats
```

## Dependency Resolution

Grainer automatically:
1. Analyzes `belongs_to` associations
2. Builds dependency graph
3. Performs topological sort
4. Generates `load_order.txt`

### Example Load Order

```
# PRIMARY Database
primary/users.rb
primary/categories.rb
primary/posts.rb
primary/comments.rb

# OTHER Database
other/departments.rb
other/projects.rb
```

## Lookup Tables

For small reference tables (statuses, types, categories), grainer can load **all records** instead of samples.

Add to `config/grainery.yml`:
```yaml
lookup_tables:
  - invoice_statuses
  - user_roles
  - categories
```

## File Formats

### Schema File Format

Each database gets a schema dump:

```ruby
# Schema dump for primary database
# Generated: 2025-10-01 10:30:00
# Adapter: postgresql

ActiveRecord::Schema.define do

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "users", ["email"], unique: true

end
```

### Seed File Format

Each table gets its own seed file:

```ruby
# Harvested from primary database: users
# Records: 100
# Generated: 2025-10-01 10:30:00

User.create!(
  {
    email: "user1@example.com",
    name: "John Doe",
    active: true
  },
  {
    email: "user2@example.com",
    name: "Jane Smith",
    active: true
  }
)
```

## Custom Seeds

Your custom seed logic in `db/seeds.rb` is **preserved and loaded last**.

Example `db/seeds.rb`:
```ruby
# Custom seed logic
puts "Creating admin user..."
User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.name = 'Admin'
  user.role = 'admin'
end

puts "Setting up application defaults..."
Setting.create!(key: 'app_name', value: 'My App')
```

## Use Cases

### Development
```bash
# Harvest production-like data for development with schemas
rake grainery:generate
rake grainery:load_with_schema
```

### Testing
```bash
# Create test fixtures with schemas
rake grainery:generate
# In test setup, load schemas and seeds
rake grainery:load_with_schema
```

### Staging
```bash
# Harvest production data (anonymized) with schemas
rake grainery:generate_all
# Deploy to staging
# Load on staging server with full schema
rake grainery:load_with_schema
```

### Cross-Database Migration
```bash
# Export from one database system
rake grainery:generate_all  # Captures schema + data

# Import to another database system
rake grainery:load_with_schema  # Recreates schema + loads data
```

## Safety Features

1. **Production Environment Protection**: Destructive tasks (load, load_with_schema, test:db:*) are blocked in production
   - Requires explicit `GRAINERY_ALLOW_PRODUCTION=true` environment variable to override
   - Includes 5-second countdown when override is used
2. **Separate Directories**: Harvested seeds never touch `db/seeds.rb`
3. **Dependency Order**: Foreign keys respected automatically
4. **Custom Preservation**: Your `db/seeds.rb` always loads last
5. **Clean Command**: `rake grainery:clean` removes only harvested files
6. **Optional Schema Loading**: Schemas only load when explicitly requested
7. **Per-Database Schemas**: Each database gets isolated schema file

### Production Safety Matrix

**Safe Operations (Read-Only):**
- ✅ `rake grainery:generate` - Harvests data, no modifications
- ✅ `rake grainery:generate_all` - Harvests all data, no modifications
- ✅ `rake grainery:generate_data_only` - Harvests data only, no modifications
- ✅ `rake grainery:init_config` - Creates config file only
- ✅ `rake grainery:clean` - Deletes harvested files only (not database data)

**Destructive Operations (Blocked by Default):**
- ❌ `rake grainery:load` - Inserts data into database
- ❌ `rake grainery:load_with_schema` - Modifies schema AND inserts data
- ❌ `rake test:db:*` - All test database operations

**Recommendation:**
- Harvesting in production is safe and useful for creating staging/development fixtures
- Loading in production should be tested thoroughly in staging first due to lack of automated test coverage
- Always review generated files before loading into any environment

## Data Anonymization

✅ **Built-in Anonymization:** Grainery automatically anonymizes sensitive fields using the Faker gem during harvest.

### Automatic Detection

When you run `rake grainery:init_config`, Grainery automatically:
1. Scans all database tables and columns
2. Detects fields that should be anonymized based on naming patterns
3. Adds them to `config/grainery.yml` with appropriate anonymization methods

Detected patterns include: `email`, `phone`, `address`, `ssn`, `password`, `token`, Greek documents (`afm`, `amka`, `ada`, `adam`), dates of birth, and more.

### How It Works

When harvesting, Grainery automatically replaces sensitive field values with fake data:

```ruby
# Original production data:
{ email: "john.doe@company.com", name: "John Doe", phone: "555-1234" }

# Anonymized in seed files:
{ email: "jane_smith@example.org", name: "Sarah Johnson", phone: "555-987-6543" }
```

### Configuration

The `config/grainery.yml` file is automatically populated with detected fields during initialization. You can customize it as needed:

```yaml
anonymize_fields:
  # Global field configuration (applies to all tables)
  email: email                    # Uses Faker::Internet.email
  first_name: first_name          # Uses Faker::Name.first_name
  last_name: last_name            # Uses Faker::Name.last_name
  name: name                      # Uses Faker::Name.name
  phone: phone_number             # Uses Faker::PhoneNumber.phone_number
  ssn: ssn                        # Uses Faker::IDNumber.valid

  # Table-specific configuration (when same field appears in multiple tables)
  users.address: address          # Only anonymize address in users table
  companies.address: skip         # Don't anonymize address in companies table

  # Database.table-specific configuration (most specific)
  primary.users.email: email      # Only for users table in primary database
  other.contacts.email: email     # Only for contacts table in other database
```

**Scoping Priority:**
1. `database.table.field` (highest priority - most specific)
2. `table.field` (medium priority - table-specific)
3. `field` (lowest priority - global)

When a field name appears in multiple tables, Grainery automatically uses scoped names during detection.

### Disabling Anonymization

**Option 1: Disable completely**

```yaml
# Set to empty hash
anonymize_fields: {}
```

**Option 2: Use raw generation task**

```bash
rake grainery:generate_raw  # Harvests without anonymization
```

**Option 3: Skip specific fields**

To keep real values for specific fields while anonymizing others, set them to `skip`:

```yaml
anonymize_fields:
  email: email           # Will be anonymized
  name: name             # Will be anonymized
  company_name: skip     # Will keep real value (not anonymized)
  department: skip       # Will keep real value (not anonymized)
  phone: phone_number    # Will be anonymized
```

This is useful when you need to preserve certain non-sensitive reference data while still protecting personal information.

### Supported Faker Methods

**Personal Information:**
- `email` - Fake email addresses
- `first_name`, `last_name`, `name` - Fake names
- `phone_number` - Fake phone numbers
- `address`, `street_address` - Fake addresses
- `city`, `state`, `zip_code`, `postal_code` - Fake location data
- `date_of_birth` - Fake date of birth preserving approximate age (±2 years, minimum age 18 to preserve adulthood)

**Financial & Identity:**
- `ssn` - Fake social security numbers
- `credit_card_number` - Fake credit card numbers
- `iban` - Fake Greek IBAN (27 characters: GR + check digits + bank code + account number, auto-truncates to column size)
- `greek_vat` - Fake Greek VAT number (AFM - 9 digits, adjusts to column size)
- `greek_amka` - Fake Greek AMKA/Social Security Number (11 digits: DDMMYY + 5 digits, adjusts to column size)
- `greek_personal_number` - Fake Greek Personal Number (12 characters: 2 digits + letter + 9-digit AFM, e.g., "12A123456789", adjusts to column size)
- `greek_ada` - Fake Greek ADA/Diavgeia Decision Number (15 characters: 4 Greek letters + 2 digits + 4 Greek letters + dash + 1 digit + 2 Greek letters, e.g., "ΨΜΦΡ69ΟΤΝΡ-9ΤΟ", adjusts to column size)
- `greek_adam` - Fake Greek ADAM/Public Procurement Publicity identifier (14-15 characters: 2 digits + PROC or REQ + 9 digits, e.g., "24REQ187755230" or "23PROC456789012", adjusts to column size)
- `identity_number` - Fake identity number (alphanumeric format, adjusts to column size)

**Security:**
- `password` - Fake passwords (auto-truncates to column size)
- `token` - Random alphanumeric strings (defaults to 32 characters, adjusts to column size)
- `api_key` - Random alphanumeric strings (defaults to 40 characters, adjusts to column size)
- `secret` - Random alphanumeric strings (defaults to 64 characters, adjusts to column size)

### Custom Field Mapping

Add your own field mappings to anonymize custom columns:

```yaml
anonymize_fields:
  # Global mappings
  employee_id: ssn
  mobile: phone_number
  home_address: address
  work_email: email
  tax_id: ssn
  bank_account: iban
  tin: greek_vat
  social_insurance: greek_amka
  citizen_id: greek_personal_number
  passport_number: identity_number
  diavgeia_decision: greek_ada
  procurement_number: greek_adam
  birth_date: date_of_birth

  # Scoped examples for duplicate fields
  users.status: skip              # Don't anonymize status in users
  orders.status: skip             # Don't anonymize status in orders
  primary.employees.department: skip  # Department in primary.employees
  other.staff.department: skip        # Department in other.staff

  # Skip anonymization for non-sensitive fields
  company_name: skip
  department: skip
  job_title: skip
```

### Important Notes

- Anonymization happens **during harvest**, not during load
- Generated seed files contain anonymized data
- Original production data is never modified
- Safe to commit anonymized seed files to version control
- Lookup tables are not anonymized (reference data)
- Anonymization can be disabled per-harvest using `generate_raw` task
- **Respects database constraints**: Fake values are automatically truncated to match column size limits
- **Type-aware**: String fields respect their maximum length, numeric fields maintain their data type
- **Selective anonymization**: Use `skip` to preserve real values for specific fields while anonymizing others
- **Scoped configuration**: When the same field name appears in multiple tables, use `table.field` or `database.table.field` notation for table-specific or database-specific anonymization

## Best Practices

1. **Use Limits**: Start with `rake grainery:generate` (100 records)
2. **Review Load Order**: Check `db/grainery/load_order.txt`
3. **Test Loading**: Run `rake grainery:load` on clean database first
4. **Commit Selectively**: Consider `.gitignore` for large grainery files
5. **Custom Seeds Last**: Keep application-specific logic in `db/seeds.rb`

## Troubleshooting

### Circular Dependencies
If you see "Circular dependency detected", check for:
- Self-referential associations
- Circular foreign keys

Solution: Temporarily remove `optional: true` or `foreign_key: false`

### Missing Records
If records fail to load:
1. Check `load_order.txt` for correct ordering
2. Verify foreign key constraints
3. Review error messages in console output

### Large Files
If seed files are too large:
```bash
# Use limit parameter
rake grainery:generate  # 100 records per table (default)
```

## Example Workflow

```bash
# 1. Initialize on first use
rake grainery:init_config

# 2. Harvest from production (with VPN/SSH tunnel)
RAILS_ENV=production rake grainery:generate

# 3. Review generated files
ls -la db/grainery/

# 4. Commit grainery files (optional)
git add db/grainery/
git commit -m "Add production seed data"

# 5. On another machine, pull and load
git pull
rake db:reset
rake grainery:load

# 6. Your custom seeds run automatically last
# db/seeds.rb is executed after all harvested seeds
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mpantel/grainery.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).