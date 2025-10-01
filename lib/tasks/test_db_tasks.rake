namespace :test do
  namespace :db do
    desc "Setup clean test database for grainery-based testing"
    task setup_for_grainery: :environment do
      puts "Setting up clean test database for grainery-based testing..."

      # Switch to test environment
      Rails.env = 'test'
      ActiveRecord::Base.establish_connection(:test)

      begin
        # Drop existing test database (optional - remove if you want to preserve structure)
        puts "  → Dropping test database..."
        ActiveRecord::Tasks::DatabaseTasks.drop_current('test')
      rescue => e
        puts "    ⚠ Could not drop database: #{e.message}"
      end

      # Create test database
      puts "  → Creating test database..."
      ActiveRecord::Tasks::DatabaseTasks.create_current('test')

      # Load schema
      puts "  → Loading schema..."
      ActiveRecord::Base.establish_connection(:test)
      ActiveRecord::Tasks::DatabaseTasks.load_schema_for 'test', :ruby

      # Reconnect
      ActiveRecord::Base.establish_connection(:test)

      puts "\n✓ Test database is ready for grainery-based testing!"
      puts "\nNext steps:"
      puts "  1. Load seeds: RAILS_ENV=test rake grainery:load"
      puts "  2. Run tests:  bundle exec rspec"
      puts "\nOr use the combined task:"
      puts "  rake test:db:reset_with_grainery"
    end

    desc "Seed test database with grainery data"
    task seed_with_grainery: :environment do
      Rails.env = 'test'
      ActiveRecord::Base.establish_connection(:test)

      puts "Seeding test database with grainery data..."

      begin
        # Check if grainery seeds exist
        grainery_path = Rails.root.join('db/grainery')
        load_order_file = grainery_path.join('load_order.txt')

        unless File.exist?(load_order_file)
          puts "\n⚠ No grainery seeds found!"
          puts "\nTo generate seeds:"
          puts "  1. Harvest from another environment:"
          puts "     RAILS_ENV=development rake grainery:generate"
          puts "\n  2. Then load into test:"
          puts "     RAILS_ENV=test rake grainery:load"
          puts "\nOr run this task which does both:"
          puts "  rake test:db:reset_with_grainery"
          exit 1
        end

        # Load grainery seeds
        puts "  → Loading grainery seeds..."
        Rake::Task['grainery:load'].invoke

        puts "\n✓ Test database seeded successfully with grainery data!"
      rescue => e
        puts "Error seeding database: #{e.message}"
        puts e.backtrace.first(5).join("\n")
      end
    end

    desc "Reset test database and seed with grainery"
    task reset_with_grainery: [:setup_for_grainery, :seed_with_grainery]

    desc "Clean test database (truncate all tables)"
    task clean: :environment do
      Rails.env = 'test'
      ActiveRecord::Base.establish_connection(:test)

      puts "Cleaning test database..."

      # Get all table names
      tables = ActiveRecord::Base.connection.tables.reject do |table|
        table == 'schema_migrations' || table == 'ar_internal_metadata'
      end

      puts "  → Truncating #{tables.size} tables..."

      # Disable foreign key checks temporarily (SQL Server specific)
      ActiveRecord::Base.connection.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'")

      tables.each do |table|
        begin
          quoted_table = ActiveRecord::Base.connection.quote_table_name(table)
          ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{quoted_table}")
        rescue => e
          puts "    ⚠ Could not truncate #{table}: #{e.message}"
        end
      end

      # Re-enable foreign key checks
      ActiveRecord::Base.connection.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? CHECK CONSTRAINT ALL'")

      puts "\n✓ Test database cleaned!"
    end

    desc "Show test database statistics"
    task stats: :environment do
      Rails.env = 'test'
      ActiveRecord::Base.establish_connection(:test)

      puts "Test Database Statistics"
      puts "=" * 80

      # Get all tables and their row counts
      tables = ActiveRecord::Base.connection.tables.reject do |table|
        table == 'schema_migrations' || table == 'ar_internal_metadata'
      end

      total_rows = 0
      table_data = []

      tables.each do |table|
        begin
          quoted_table = ActiveRecord::Base.connection.quote_table_name(table)
          count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{quoted_table}")
          total_rows += count
          table_data << [table, count] if count > 0
        rescue => e
          # Skip tables we can't query
        end
      end

      # Sort by row count descending
      table_data.sort_by! { |_, count| -count }

      if table_data.empty?
        puts "\n  Database is empty ✓"
        puts "\n  Run 'rake test:db:setup_for_grainery' to initialize"
      else
        puts "\n  Total tables with data: #{table_data.size}"
        puts "  Total rows: #{total_rows.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
        puts "\n  Top 20 tables by row count:"
        puts "  " + "-" * 76

        table_data.first(20).each do |table, count|
          formatted_count = count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
          puts "  #{table.ljust(50)} #{formatted_count.rjust(10)} rows"
        end
      end

      puts "=" * 80
    end
  end
end

# Aliases for convenience
namespace :db do
  namespace :test do
    desc "Alias for test:db:setup_for_grainery"
    task setup_for_grainery: 'test:db:setup_for_grainery'

    desc "Alias for test:db:clean"
    task clean: 'test:db:clean'

    desc "Alias for test:db:stats"
    task stats: 'test:db:stats'

    desc "Alias for test:db:reset_with_grainery"
    task reset_with_grainery: 'test:db:reset_with_grainery'
  end
end