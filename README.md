# Grainery

Database seed storage system for Rails applications. Extract database records and generate seed files organized by database with automatic dependency resolution. Like a grainery stores grain, this gem stores and organizes your database seeds.

## Features

- ✅ Automatic database detection
- ✅ Dependency-aware loading (topological sort)
- ✅ Multi-database support
- ✅ Configurable per project
- ✅ Preserves custom seeds
- ✅ One seed file per table
- ✅ Clean separation of concerns
- ✅ Supports SQL Server, MySQL, PostgreSQL
- ✅ Test database management tasks

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

This auto-detects all databases and creates `config/grainery.yml`.

### 2. Harvest Data

```bash
# Harvest with limit (100 records per table)
rake grainery:generate

# Harvest ALL records (use with caution)
rake grainery:generate_all
```

### 3. Load Seeds

```bash
rake grainery:load
```

This loads:
1. Harvested seeds (in dependency order)
2. Custom seeds from `db/seeds.rb` (last)

## Directory Structure

```
db/
├── grainery/                   # Harvested seeds (auto-generated)
│   ├── load_order.txt         # Load order respecting dependencies
│   ├── primary/               # Primary database
│   │   ├── users.rb
│   │   ├── posts.rb
│   │   └── comments.rb
│   ├── other/                 # Other database
│   │   └── projects.rb
│   └── banking/               # Banking database
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
```

## Available Rake Tasks

### Grainery Tasks

```bash
# Initialize configuration
rake grainery:init_config

# Harvest data (with limit)
rake grainery:generate

# Harvest ALL records
rake grainery:generate_all

# Load harvested + custom seeds
rake grainery:load

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

## Seed File Format

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
# Harvest production-like data for development
rake grainery:generate
rake grainery:load
```

### Testing
```bash
# Create test fixtures
rake grainery:generate
# In test setup, load specific seeds as needed
```

### Staging
```bash
# Harvest production data (anonymized)
rake grainery:generate_all
# Deploy to staging
# Load on staging server
rake grainery:load
```

## Safety Features

1. **Separate Directories**: Harvested seeds never touch `db/seeds.rb`
2. **Dependency Order**: Foreign keys respected automatically
3. **Custom Preservation**: Your `db/seeds.rb` always loads last
4. **Clean Command**: `rake grainery:clean` removes only harvested files

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