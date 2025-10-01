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
    grainery.harvest_all(limit: 100) # Default limit of 100 records per table

    puts "\n✓ Data harvested to db/grainery/"
  end

  desc "Harvest all records from all tables (no limit)"
  task generate_all: :environment do
    puts "⚠  WARNING: This will harvest ALL records from ALL tables"
    puts "   This may take a while and create large files\n\n"

    grainery = Grainery::Grainer.new
    grainery.harvest_all(limit: nil)

    puts "\n✓ All data harvested to db/grainery/"
  end

  desc "Load harvested seeds into database (in dependency order)"
  task load: :environment do
    grainery = Grainery::Grainer.new
    grainery.load_seeds
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