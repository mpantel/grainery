# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/mpantel/grainery/releases/tag/v0.1.0