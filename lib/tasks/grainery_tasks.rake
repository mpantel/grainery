namespace :grainery do
  desc "Initialize grainery.yml configuration file"
  task init_config: :environment do
    config_path = Rails.root.join('config/grainery.yml')

    if File.exist?(config_path)
      puts "Configuration file already exists at config/grainery.yml"
      exit
    end

    puts "Initializing grainery configuration..."
    grainery = Grainery::Grainer.new

    puts "\n✓ Configuration file created successfully!"
    puts "\nNext steps:"
    puts "1. Review config/grainery.yml"
    puts "2. Run 'rake grainery:generate' to harvest data"
  end

  desc "Harvest data from all tables (respecting dependencies)"
  task generate: :environment do
    puts "Harvesting data from all tables..."

    grainery = Grainery::Grainer.new
    grainery.harvest_all(limit: 100, dump_schema: true, anonymize: true) # Default limit of 100 records per table

    puts "\n✓ Data harvested to db/grainery/"
  end

  desc "Harvest all records from all tables (no limit)"
  task generate_all: :environment do
    puts "⚠  WARNING: This will harvest ALL records from ALL tables"
    puts "   This may take a while and create large files\n\n"

    grainery = Grainery::Grainer.new
    grainery.harvest_all(limit: nil, dump_schema: true, anonymize: true)

    puts "\n✓ All data harvested to db/grainery/"
  end

  desc "Harvest data without schema dump"
  task generate_data_only: :environment do
    puts "Harvesting data from all tables (no schema dump)..."

    grainery = Grainery::Grainer.new
    grainery.harvest_all(limit: 100, dump_schema: false, anonymize: true)

    puts "\n✓ Data harvested to db/grainery/"
  end

  desc "Harvest data without anonymization (raw production data)"
  task generate_raw: :environment do
    puts "⚠  WARNING: Harvesting RAW production data without anonymization!"
    puts "   This will include sensitive information (emails, names, etc.)"
    puts "   DO NOT commit these files to version control\n\n"

    grainery = Grainery::Grainer.new
    grainery.harvest_all(limit: 100, dump_schema: true, anonymize: false)

    puts "\n✓ Raw data harvested to db/grainery/"
    puts "⚠  Remember: This data contains sensitive information!"
  end

  desc "Load harvested seeds into database (in dependency order)"
  task load: :environment do
    if Rails.env.production?
      puts "❌ ERROR: Cannot load seeds in production environment!"
      puts "   This is a destructive operation that could overwrite production data."
      puts "\n   If you absolutely must load seeds in production:"
      puts "   Set GRAINERY_ALLOW_PRODUCTION=true environment variable"
      puts "\n   Example: GRAINERY_ALLOW_PRODUCTION=true rake grainery:load"
      exit 1 unless ENV['GRAINERY_ALLOW_PRODUCTION'] == 'true'

      puts "⚠️  WARNING: Loading seeds in PRODUCTION environment!"
      puts "   Proceeding because GRAINERY_ALLOW_PRODUCTION=true"
      puts "   Press Ctrl+C within 5 seconds to cancel..."
      sleep 5
    end

    grainery = Grainery::Grainer.new
    grainery.load_seeds(load_schema: false)
  end

  desc "Load schemas and seeds into database"
  task load_with_schema: :environment do
    if Rails.env.production?
      puts "❌ ERROR: Cannot load schemas in production environment!"
      puts "   This is a destructive operation that could overwrite production data."
      puts "\n   If you absolutely must load schemas in production:"
      puts "   Set GRAINERY_ALLOW_PRODUCTION=true environment variable"
      puts "\n   Example: GRAINERY_ALLOW_PRODUCTION=true rake grainery:load_with_schema"
      exit 1 unless ENV['GRAINERY_ALLOW_PRODUCTION'] == 'true'

      puts "⚠️  WARNING: Loading schemas and seeds in PRODUCTION environment!"
      puts "   Proceeding because GRAINERY_ALLOW_PRODUCTION=true"
      puts "   Press Ctrl+C within 5 seconds to cancel..."
      sleep 5
    end

    grainery = Grainery::Grainer.new
    grainery.load_seeds(load_schema: true)
  end

  desc "Clean grainery directory"
  task clean: :environment do
    grainery = Grainery::Grainer.new
    grainery_path = Rails.root.join(grainery.instance_variable_get(:@grainery_path))

    if Dir.exist?(grainery_path)
      FileUtils.rm_rf(grainery_path)
      puts "✓ Cleaned #{grainery_path}"
    else
      puts "  Nothing to clean"
    end
  end
end