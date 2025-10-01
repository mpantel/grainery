require 'fileutils'
require 'yaml'

module Grainery
  class Grainer
    attr_reader :database_configs, :lookup_tables

    # Security: Whitelist of allowed base class patterns
    ALLOWED_BASE_CLASS_PATTERN = /\A(ApplicationRecord|ActiveRecord::Base|[A-Z][a-zA-Z0-9]*Record|[A-Z][a-zA-Z0-9]*(DB|Database|Connection))\z/

    def initialize
      @config = load_config
      @grainery_path = load_grainery_path
      @database_configs = load_database_connections
      @lookup_tables = load_lookup_tables
    end

    def load_config
      config_path = Rails.root.join('config/grainery.yml')

      unless File.exist?(config_path)
        puts "  Warning: config/grainery.yml not found. Creating default configuration..."
        create_default_config
      end

      YAML.safe_load_file(config_path, permitted_classes: [Symbol, Date, Time], aliases: true) || {}
    rescue => e
      puts "  Warning: Could not load grainery.yml: #{e.message}"
      {}
    end

    def create_default_config
      config_path = Rails.root.join('config/grainery.yml')

      # Detect databases and model base classes dynamically
      detected_databases = detect_databases_and_models

      # Build configuration hash
      config = {
        'database_connections' => detected_databases,
        'grainery_path' => 'db/grainery',
        'lookup_tables' => [],
        'last_updated' => Time.now.to_s
      }

      # Write with custom formatting for better readability
      write_config_file(config_path, config)

      puts "  ✓ Created config/grainery.yml with #{detected_databases.size} detected databases"
    end

    def detect_databases_and_models
      puts "  → Detecting databases and model base classes..."

      Rails.application.eager_load!

      # Find all model base classes
      base_classes = ObjectSpace.each_object(Class).select do |klass|
        klass < ActiveRecord::Base &&
        !klass.abstract_class? &&
        klass != ActiveRecord::Base &&
        klass.descendants.any?
      rescue
        false
      end

      connections_map = {}

      base_classes.each do |base_class|
        begin
          connection_config = base_class.connection_db_config
          connection_name = connection_config.name.to_s
          adapter = connection_config.adapter.to_s

          logical_name = infer_logical_name(connection_name, base_class.name)

          connections_map[logical_name] = {
            'connection' => connection_name,
            'adapter' => adapter,
            'model_base_class' => base_class.name
          }

          puts "    ✓ Detected: #{logical_name} → #{base_class.name} (#{adapter})"
        rescue => e
          puts "    ⚠ Warning: Could not detect connection for #{base_class.name}: #{e.message}"
        end
      end

      # Ensure primary database is included
      unless connections_map.key?('primary')
        begin
          primary_config = ApplicationRecord.connection_db_config
          connections_map['primary'] = {
            'connection' => primary_config.name.to_s,
            'adapter' => primary_config.adapter.to_s,
            'model_base_class' => 'ApplicationRecord'
          }
          puts "    ✓ Detected: primary → ApplicationRecord (#{primary_config.adapter})"
        rescue => e
          puts "    ⚠ Warning: Could not detect primary database: #{e.message}"
        end
      end

      connections_map
    end

    def infer_logical_name(connection_name, class_name)
      logical = class_name.gsub(/DB$|Database$|Connection$/, '')
      logical = logical.gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
                       .gsub(/([a-z\d])([A-Z])/, '\\1_\\2')
                       .downcase

      if connection_name != 'test' && connection_name.length > logical.length
        logical = connection_name.gsub(/_db$|_database$/, '')
      end

      logical
    end

    def write_config_file(path, config)
      content = []

      content << "# Data Harvest Configuration"
      content << "# This file contains configuration for the data harvesting system"
      content << "#"
      content << "# Database Connections:"
      content << "# Map of logical database names to connection name, adapter, and model base class"
      content << "#"
      content << "# Harvest Path:"
      content << "# Where harvested seed files are stored (default: db/grainery)"
      content << "#"
      content << "# Lookup Tables:"
      content << "# Tables to harvest ALL records (not just samples)"
      content << ""
      content << "# Path for harvested seed files"
      content << "grainery_path: #{config['grainery_path'] || 'db/grainery'}"
      content << ""
      content << "# Database connection mappings"
      content << "database_connections:"

      config['database_connections'].each do |db_name, db_config|
        content << "  #{db_name}:"
        content << "    connection: #{db_config['connection']}"
        content << "    adapter: #{db_config['adapter']}"
        content << "    model_base_class: #{db_config['model_base_class']}"
      end

      content << ""
      content << "# Lookup tables (harvest all records)"
      content << "lookup_tables: #{config['lookup_tables'].inspect}"
      content << ""
      content << "# Metadata"
      content << "last_updated: #{config['last_updated']}"
      content << ""

      File.write(path, content.join("\n"))
    end

    def load_database_connections
      connections = @config['database_connections'] || {}
      result = {}

      connections.each do |db_name, config|
        db_key = db_name.to_sym
        if config.is_a?(Hash)
          result[db_key] = {
            connection: config['connection'].to_sym,
            adapter: config['adapter']&.to_sym || :sqlserver,
            model_base_class: config['model_base_class'] || 'ApplicationRecord'
          }
        else
          result[db_key] = {
            connection: config.to_sym,
            adapter: :sqlserver,
            model_base_class: 'ApplicationRecord'
          }
        end
      end
      result
    end

    def load_grainery_path
      path = @config['grainery_path'] || 'db/grainery'
      path = path.sub(/\/$/, '')

      # Security: Validate path is within Rails.root to prevent path traversal
      full_path = Rails.root.join(path).expand_path
      unless full_path.to_s.start_with?(Rails.root.to_s)
        raise SecurityError, "Invalid grainery_path '#{path}': must be within Rails application directory"
      end

      path
    rescue SecurityError => e
      puts "  Error: #{e.message}"
      raise
    rescue => e
      puts "  Warning: Could not load grainery_path: #{e.message}"
      'db/grainery'
    end

    def load_lookup_tables
      (@config['lookup_tables'] || []).to_set
    rescue => e
      puts "  Warning: Could not load lookup tables: #{e.message}"
      Set.new
    end

    # Security: Safe constant resolution with whitelist
    def safe_const_get(class_name)
      unless class_name.match?(ALLOWED_BASE_CLASS_PATTERN)
        raise SecurityError, "Unauthorized base class '#{class_name}'. Only ActiveRecord model base classes are allowed."
      end

      Object.const_get(class_name)
    rescue NameError => e
      raise NameError, "Could not find constant '#{class_name}': #{e.message}"
    end

    def get_all_models
      Rails.application.eager_load!
      models = []

      @database_configs.each do |db_name, db_config|
        base_class_name = db_config[:model_base_class]
        next unless base_class_name

        begin
          base_class = safe_const_get(base_class_name)
          models += base_class.descendants
        rescue => e
          puts "  Warning: Could not load models from '#{base_class_name}': #{e.message}"
        end
      end

      models.uniq.compact
    end

    def detect_database(model)
      @database_configs.each do |db_name, db_config|
        base_class_name = db_config[:model_base_class]
        next unless base_class_name

        begin
          base_class = safe_const_get(base_class_name)
          return db_name if model < base_class
        rescue
          next
        end
      end

      :primary
    end

    def harvest_all(limit: nil)
      all_models = get_all_models

      models_to_harvest = all_models.reject do |model|
        model.abstract_class? ||
        model.name.start_with?('HABTM_', 'ActiveRecord::') ||
        model.table_name.nil?
      end

      harvest_models(models_to_harvest, limit: limit)
    end

    def harvest_models(models, limit: nil)
      models = Array(models)
      return if models.empty?

      puts "\n" + "="*80
      puts "Grainer - Extracting Database Seeds"
      puts "="*80
      puts "Total models: #{models.size}"
      puts "Limit per table: #{limit || 'ALL RECORDS'}"
      puts "="*80 + "\n"

      # Group by database
      grouped_models = models.group_by { |model| detect_database(model) }

      # Calculate dependencies for load order
      dependency_graph = build_dependency_graph(models)
      load_order = topological_sort(dependency_graph)

      # Create harvest directories
      grouped_models.each do |db_name, _|
        db_dir = Rails.root.join(@grainery_path, db_name.to_s)
        FileUtils.mkdir_p(db_dir)
      end

      # Harvest in dependency order
      load_order.each do |model|
        next unless models.include?(model)

        begin
          db_name = detect_database(model)
          harvest_table(model, db_name, limit: limit)
        rescue => e
          puts "  ✗ Error harvesting #{model.name}: #{e.message}"
        end
      end

      # Create load order file
      create_load_order_file(load_order, models)

      puts "\n" + "="*80
      puts "Data harvest complete!"
      puts "Seed files created in #{@grainery_path}/"
      puts "Load with: rake grainery:load"
      puts "="*80
    end

    def build_dependency_graph(models)
      graph = {}

      models.each do |model|
        graph[model] = []

        # Find belongs_to associations (dependencies)
        model.reflect_on_all_associations(:belongs_to).each do |assoc|
          begin
            if assoc.klass && !assoc.polymorphic? && models.include?(assoc.klass)
              graph[model] << assoc.klass
            end
          rescue
            next
          end
        end
      end

      graph
    end

    def topological_sort(graph)
      sorted = []
      visited = Set.new
      visiting = Set.new

      visit = lambda do |node|
        return if visited.include?(node)
        raise "Circular dependency detected" if visiting.include?(node)

        visiting.add(node)

        (graph[node] || []).each do |dependency|
          visit.call(dependency) if graph.key?(dependency)
        end

        visiting.delete(node)
        visited.add(node)
        sorted << node
      end

      graph.keys.each { |node| visit.call(node) }

      sorted
    end

    def harvest_table(model, db_name, limit: nil)
      table_name = model.table_name
      is_lookup = @lookup_tables.include?(table_name)

      # Determine how many records to harvest
      records = if is_lookup
        model.all.to_a
      elsif limit
        model.limit(limit).to_a
      else
        model.all.to_a
      end

      if records.empty?
        puts "  ⚠ #{model.name.ljust(50)} → skipped (no data)"
        return
      end

      # Generate seed file
      seed_content = generate_seed_content(model, records, db_name)
      seed_path = get_seed_path(model, db_name)

      File.write(seed_path, seed_content)

      record_info = is_lookup ? " (lookup: #{records.size} records)" : " (#{records.size} records)"
      puts "  ✓ #{model.name.ljust(50)} → #{table_name}.rb#{record_info}"
    end

    def get_seed_path(model, db_name)
      db_dir = File.join(@grainery_path, db_name.to_s)
      FileUtils.mkdir_p(Rails.root.join(db_dir))
      Rails.root.join(db_dir, "#{model.table_name}.rb")
    end

    def generate_seed_content(model, records, db_name)
      table_name = model.table_name

      # Get columns to export (exclude id, timestamps)
      columns = model.columns.reject do |col|
        %w[id created_at updated_at].include?(col.name)
      end

      content = []
      content << "# Harvested from #{db_name} database: #{table_name}"
      content << "# Records: #{records.size}"
      content << "# Generated: #{Time.now}"
      content << ""
      content << "#{model.name}.create!("

      records.each_with_index do |record, idx|
        content << "  {" if idx == 0
        content << "  }," if idx > 0
        content << "  {" if idx > 0

        columns.each_with_index do |col, col_idx|
          value = record.send(col.name)
          formatted_value = format_seed_value(value, col)
          comma = col_idx < columns.size - 1 ? ',' : ''
          content << "    #{col.name}: #{formatted_value}#{comma}"
        end
      end

      content << "  }"
      content << ")"
      content << ""

      content.join("\n")
    end

    def format_seed_value(value, column)
      return 'nil' if value.nil?

      case column.type
      when :string, :text
        value.to_s.inspect
      when :integer, :bigint
        value.to_i
      when :decimal, :float
        value.to_f
      when :boolean
        value ? 'true' : 'false'
      when :date
        "Date.parse(#{value.to_s.inspect})"
      when :datetime, :timestamp
        "Time.parse(#{value.to_s.inspect})"
      when :json, :jsonb
        value.to_json
      else
        value.inspect
      end
    end

    def create_load_order_file(load_order, models)
      order_path = Rails.root.join(@grainery_path, 'load_order.txt')

      grouped_by_db = load_order.select { |m| models.include?(m) }.group_by { |m| detect_database(m) }

      content = []
      content << "# Load order for harvested seeds"
      content << "# Load files in this order to respect foreign key dependencies"
      content << ""

      grouped_by_db.each do |db_name, db_models|
        content << "# #{db_name.to_s.upcase} Database"
        db_models.each do |model|
          content << "#{db_name}/#{model.table_name}.rb"
        end
        content << ""
      end

      File.write(order_path, content.join("\n"))
      puts "\n  ✓ Load order written to #{@grainery_path}/load_order.txt"
    end

    def load_seeds
      order_file = Rails.root.join(@grainery_path, 'load_order.txt')

      unless File.exist?(order_file)
        puts "  ✗ Load order file not found. Run 'rake grainery:generate' first."
        return
      end

      puts "\n" + "="*80
      puts "Loading Harvested Seeds"
      puts "="*80

      # Load harvested seeds in dependency order
      File.readlines(order_file).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')

        seed_file = Rails.root.join(@grainery_path, line)
        if File.exist?(seed_file)
          puts "  → Loading #{line}..."
          begin
            load seed_file
          rescue => e
            puts "  ✗ Error loading #{line}: #{e.message}"
          end
        end
      end

      # Load custom seeds last (if they exist)
      custom_seeds = Rails.root.join('db/seeds.rb')
      if File.exist?(custom_seeds) && File.read(custom_seeds).strip.present?
        puts "\n" + "-"*80
        puts "Loading Custom Seeds"
        puts "-"*80
        puts "  → Loading db/seeds.rb..."
        begin
          load custom_seeds
        rescue => e
          puts "  ✗ Error loading custom seeds: #{e.message}"
        end
      end

      puts "\n" + "="*80
      puts "Seed loading complete!"
      puts "="*80
    end
  end
end