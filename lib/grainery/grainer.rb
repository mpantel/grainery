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
      @anonymize_fields = load_anonymize_fields
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

      # Detect anonymizable fields from actual database schema
      detected_fields = detect_anonymizable_fields(detected_databases)

      # Build default anonymize_fields hash
      default_anonymize_fields = {
          'email' => 'email',
          'first_name' => 'first_name',
          'last_name' => 'last_name',
          'name' => 'name',
          'phone' => 'phone_number',
          'phone_number' => 'phone_number',
          'address' => 'address',
          'street_address' => 'street_address',
          'city' => 'city',
          'state' => 'state',
          'zip' => 'zip_code',
          'zip_code' => 'zip_code',
          'postal_code' => 'zip_code',
          'ssn' => 'ssn',
          'credit_card' => 'credit_card_number',
          'password' => 'password',
          'token' => 'token',
          'api_key' => 'api_key',
          'secret' => 'secret',
          'iban' => 'iban',
          'vat_number' => 'greek_vat',
          'afm' => 'greek_vat',
          'identity_number' => 'identity_number',
          'id_number' => 'identity_number',
          'national_id' => 'identity_number',
          'amka' => 'greek_amka',
          'social_security_number' => 'greek_amka',
          'ssn_greek' => 'greek_amka',
          'personal_number' => 'greek_personal_number',
          'personal_id' => 'greek_personal_number',
          'afm_extended' => 'greek_personal_number',
          'ada' => 'greek_ada',
          'diavgeia_id' => 'greek_ada',
          'decision_number' => 'greek_ada',
          'adam' => 'greek_adam',
          'adam_number' => 'greek_adam',
          'procurement_id' => 'greek_adam',
          'date_of_birth' => 'date_of_birth',
          'birth_date' => 'date_of_birth',
          'dob' => 'date_of_birth',
          'birthdate' => 'date_of_birth'
      }

      # Merge detected fields with defaults (detected fields take precedence)
      anonymize_fields = default_anonymize_fields.merge(detected_fields)

      # Build configuration hash
      config = {
        'database_connections' => detected_databases,
        'grainery_path' => 'db/grainery',
        'lookup_tables' => [],
        'anonymize_fields' => anonymize_fields,
        'last_updated' => Time.now.to_s
      }

      # Write with custom formatting for better readability
      write_config_file(config_path, config)

      puts "  ✓ Created config/grainery.yml with #{detected_databases.size} detected databases"
      puts "  ✓ Detected #{detected_fields.size} anonymizable fields in database schema"
    end

    def detect_anonymizable_fields(detected_databases)
      puts "  → Detecting anonymizable fields from database schema..."

      # Field name patterns mapped to anonymization methods
      field_patterns = {
        /email/i => 'email',
        /first_name/i => 'first_name',
        /last_name/i => 'last_name',
        /^name$/i => 'name',
        /phone/i => 'phone_number',
        /mobile/i => 'phone_number',
        /address/i => 'address',
        /street/i => 'street_address',
        /city/i => 'city',
        /state/i => 'state',
        /zip/i => 'zip_code',
        /postal/i => 'zip_code',
        /ssn/i => 'ssn',
        /credit_card/i => 'credit_card_number',
        /password/i => 'password',
        /token/i => 'token',
        /api_key/i => 'api_key',
        /secret/i => 'secret',
        /iban/i => 'iban',
        /vat_number/i => 'greek_vat',
        /afm/i => 'greek_vat',
        /amka/i => 'greek_amka',
        /social_security_number/i => 'greek_amka',
        /personal_number/i => 'greek_personal_number',
        /personal_id/i => 'greek_personal_number',
        /ada$/i => 'greek_ada',
        /diavgeia/i => 'greek_ada',
        /adam/i => 'greek_adam',
        /procurement_id/i => 'greek_adam',
        /(date_of_)?birth/i => 'date_of_birth',
        /dob$/i => 'date_of_birth',
        /identity_number/i => 'identity_number',
        /national_id/i => 'identity_number'
      }

      detected_fields = {}
      field_locations = Hash.new { |h, k| h[k] = [] } # Track where each field appears

      detected_databases.each do |db_name, db_config|
        begin
          # Get the model base class
          base_class = db_config['model_base_class'].constantize

          # Find all models that inherit from this base class
          models = ObjectSpace.each_object(Class).select do |klass|
            klass < base_class && !klass.abstract_class?
          rescue
            false
          end

          models.each do |model|
            begin
              table_name = model.table_name

              # Get column information
              model.columns.each do |column|
                column_name = column.name

                # Skip internal Rails columns
                next if %w[id created_at updated_at].include?(column_name)

                # Match against patterns
                field_patterns.each do |pattern, method|
                  if column_name.match?(pattern)
                    # Track location for duplicate detection
                    field_locations[column_name] << { db: db_name, table: table_name, model: model.name, method: method }
                    puts "    ✓ Found: #{model.name}.#{column_name} → #{method}"
                    break # Use first matching pattern
                  end
                end
              end
            rescue => e
              # Skip models that can't be analyzed
              next
            end
          end
        rescue => e
          puts "    ⚠ Warning: Could not analyze #{db_name}: #{e.message}"
        end
      end

      # Build detected_fields with scoping when duplicates exist
      field_locations.each do |field_name, locations|
        if locations.size == 1
          # Single occurrence - use simple field name
          detected_fields[field_name] = locations.first[:method]
        else
          # Multiple occurrences - use scoped names
          puts "    ℹ Field '#{field_name}' appears in multiple tables - using scoped configuration"
          locations.each do |loc|
            if locations.count { |l| l[:db] == loc[:db] } > 1
              # Multiple tables in same database - use db.table.field
              scoped_key = "#{loc[:db]}.#{loc[:table]}.#{field_name}"
              detected_fields[scoped_key] = loc[:method]
              puts "      → #{scoped_key}"
            else
              # Single table per database - use table.field
              scoped_key = "#{loc[:table]}.#{field_name}"
              detected_fields[scoped_key] = loc[:method]
              puts "      → #{scoped_key}"
            end
          end
        end
      end

      detected_fields
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
      content << "# Field anonymization (column_name => faker_method)"
      content << "# Set to empty hash {} to disable anonymization"
      content << "# Faker methods: email, first_name, last_name, name, phone_number, address,"
      content << "#                street_address, city, state, zip_code, ssn, credit_card_number,"
      content << "#                password, token, api_key, secret, iban, greek_vat, greek_amka,"
      content << "#                greek_personal_number, greek_ada, identity_number"
      content << "anonymize_fields:"
      if config['anonymize_fields']&.any?
        config['anonymize_fields'].each do |field, faker_method|
          content << "  #{field}: #{faker_method}"
        end
      else
        content << "  {}"
      end
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

    def load_anonymize_fields
      fields = @config['anonymize_fields'] || {}
      fields.is_a?(Hash) ? fields : {}
    rescue => e
      puts "  Warning: Could not load anonymize_fields: #{e.message}"
      {}
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

    def harvest_all(limit: nil, dump_schema: false, anonymize: true)
      all_models = get_all_models

      models_to_harvest = all_models.reject do |model|
        model.abstract_class? ||
        model.name.start_with?('HABTM_', 'ActiveRecord::') ||
        model.table_name.nil?
      end

      harvest_models(models_to_harvest, limit: limit, dump_schema: dump_schema, anonymize: anonymize)
    end

    def harvest_models(models, limit: nil, dump_schema: false, anonymize: true)
      models = Array(models)
      return if models.empty?

      # Require faker if anonymization is enabled
      if anonymize && @anonymize_fields.any?
        begin
          require 'faker'
        rescue LoadError
          puts "  ⚠ Warning: Faker gem not found. Anonymization disabled."
          puts "    Install with: gem install faker"
          anonymize = false
        end
      end

      puts "\n" + "="*80
      puts "Grainer - Extracting Database Seeds"
      puts "="*80
      puts "Total models: #{models.size}"
      puts "Limit per table: #{limit || 'ALL RECORDS'}"
      puts "Schema dump: #{dump_schema ? 'YES' : 'NO'}"
      puts "Anonymization: #{anonymize && @anonymize_fields.any? ? "YES (#{@anonymize_fields.size} fields)" : 'NO'}"
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

      # Dump schemas if requested
      if dump_schema
        puts "\n" + "-"*80
        puts "Dumping Database Schemas"
        puts "-"*80
        grouped_models.each do |db_name, _|
          dump_database_schema(db_name)
        end
      end

      # Harvest in dependency order
      load_order.each do |model|
        next unless models.include?(model)

        begin
          db_name = detect_database(model)
          harvest_table(model, db_name, limit: limit, anonymize: anonymize)
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

    def harvest_table(model, db_name, limit: nil, anonymize: true)
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
      seed_content = generate_seed_content(model, records, db_name, anonymize: anonymize)
      seed_path = get_seed_path(model, db_name)

      File.write(seed_path, seed_content)

      anonymize_suffix = anonymize && @anonymize_fields.any? ? " [anonymized]" : ""
      record_info = is_lookup ? " (lookup: #{records.size} records)" : " (#{records.size} records)"
      puts "  ✓ #{model.name.ljust(50)} → #{table_name}.rb#{record_info}#{anonymize_suffix}"
    end

    def get_seed_path(model, db_name)
      db_dir = File.join(@grainery_path, db_name.to_s)
      FileUtils.mkdir_p(Rails.root.join(db_dir))
      Rails.root.join(db_dir, "#{model.table_name}.rb")
    end

    def generate_seed_content(model, records, db_name, anonymize: true)
      table_name = model.table_name

      # Get columns to export (exclude id, timestamps)
      columns = model.columns.reject do |col|
        %w[id created_at updated_at].include?(col.name)
      end

      content = []
      content << "# Harvested from #{db_name} database: #{table_name}"
      content << "# Records: #{records.size}"
      content << "# Generated: #{Time.now}"
      content << "# Anonymized: #{anonymize && @anonymize_fields.any? ? 'YES' : 'NO'}"
      content << ""
      content << "#{model.name}.create!("

      records.each_with_index do |record, idx|
        content << "  {" if idx == 0
        content << "  }," if idx > 0
        content << "  {" if idx > 0

        columns.each_with_index do |col, col_idx|
          value = record.send(col.name)

          # Anonymize if enabled and field is configured
          if anonymize
            faker_method = get_anonymization_method(col.name, table_name, db_name)
            if faker_method
              # Skip anonymization if explicitly set to "skip"
              unless faker_method.to_s == 'skip'
                value = anonymize_value(col.name, faker_method, col, value)
              end
            end
          end

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

    def get_anonymization_method(field_name, table_name, db_name)
      # Priority order:
      # 1. database.table.field (most specific)
      # 2. table.field (table-specific)
      # 3. field (global)

      scoped_key_db_table = "#{db_name}.#{table_name}.#{field_name}"
      scoped_key_table = "#{table_name}.#{field_name}"

      @anonymize_fields[scoped_key_db_table] ||
        @anonymize_fields[scoped_key_table] ||
        @anonymize_fields[field_name]
    end

    def anonymize_value(field_name, faker_method, column, original_value = nil)
      return nil if faker_method.nil?

      begin
        # Generate fake value based on method
        fake_value = case faker_method.to_s
        when 'email'
          Faker::Internet.email
        when 'first_name'
          Faker::Name.first_name
        when 'last_name'
          Faker::Name.last_name
        when 'name'
          Faker::Name.name
        when 'phone_number'
          Faker::PhoneNumber.phone_number
        when 'address'
          Faker::Address.full_address
        when 'street_address'
          Faker::Address.street_address
        when 'city'
          Faker::Address.city
        when 'state'
          Faker::Address.state
        when 'zip_code'
          Faker::Address.zip_code
        when 'ssn'
          Faker::IDNumber.valid
        when 'credit_card_number'
          Faker::Finance.credit_card
        when 'password'
          Faker::Internet.password
        when 'token'
          generate_token(column)
        when 'api_key'
          generate_api_key(column)
        when 'secret'
          generate_secret(column)
        when 'iban'
          generate_fake_iban(column)
        when 'greek_vat'
          generate_fake_greek_vat(column)
        when 'greek_amka'
          generate_fake_greek_amka(column)
        when 'greek_personal_number'
          generate_fake_greek_personal_number(column)
        when 'greek_ada'
          generate_fake_greek_ada(column)
        when 'greek_adam'
          generate_fake_greek_adam(column)
        when 'date_of_birth'
          generate_fake_date_of_birth(original_value, column)
        when 'identity_number'
          generate_fake_identity_number(column)
        else
          # Try to call the method dynamically if it exists
          if Faker.respond_to?(faker_method)
            Faker.send(faker_method)
          else
            nil
          end
        end

        # Truncate to column limit if necessary
        if fake_value.is_a?(String) && column.limit
          fake_value = fake_value[0...column.limit]
        end

        fake_value
      rescue => e
        # If faker fails, return nil or a safe default
        puts "  ⚠ Warning: Could not anonymize #{field_name} with #{faker_method}: #{e.message}"
        nil
      end
    end

    def generate_token(column)
      # Generate token respecting column size
      length = column.limit ? [column.limit, 32].min : 32
      Faker::Alphanumeric.alphanumeric(number: length)
    end

    def generate_api_key(column)
      # Generate API key respecting column size
      length = column.limit ? [column.limit, 40].min : 40
      Faker::Alphanumeric.alphanumeric(number: length)
    end

    def generate_secret(column)
      # Generate secret respecting column size
      length = column.limit ? [column.limit, 64].min : 64
      Faker::Alphanumeric.alphanumeric(number: length)
    end

    def generate_fake_iban(column)
      # Generate a fake Greek IBAN (27 characters)
      # Format: GR + 2 check digits + 7 bank code + 16 account number
      country_code = 'GR'
      check_digits = rand(10..99).to_s
      bank_code = rand(1000000..9999999).to_s
      account_number = rand(1000000000000000..9999999999999999).to_s
      iban = "#{country_code}#{check_digits}#{bank_code}#{account_number}"

      # Truncate if column has a limit
      if column.limit && iban.length > column.limit
        # Keep the country code prefix if possible
        if column.limit >= 4
          iban = iban[0...column.limit]
        else
          iban = iban[0...column.limit]
        end
      end

      iban
    end

    def generate_fake_greek_vat(column)
      # Generate a fake Greek VAT number (AFM - 9 digits)
      # Format: 9 digits
      vat = rand(100000000..999999999).to_s

      # Adjust length if column has a limit
      if column.limit
        if column.limit >= 9
          vat
        elsif column.limit > 0
          # Generate shorter number
          max_val = (10 ** column.limit) - 1
          min_val = 10 ** (column.limit - 1)
          rand(min_val..max_val).to_s
        else
          vat[0...column.limit]
        end
      else
        vat
      end
    end

    def generate_fake_greek_amka(column)
      # Generate a fake Greek AMKA (Social Security Number - 11 digits)
      # Format: DDMMYY followed by 5 digits
      # Example: 01011990001 (1st January 1990, sequence 001)

      # Generate random date (between 1950 and 2005 for realistic working age)
      day = rand(1..28).to_s.rjust(2, '0')
      month = rand(1..12).to_s.rjust(2, '0')
      year = rand(50..105).to_s.rjust(2, '0')  # Last 2 digits of year
      sequence = rand(0..99999).to_s.rjust(5, '0')

      amka = "#{day}#{month}#{year}#{sequence}"

      # Adjust length if column has a limit
      if column.limit
        if column.limit >= 11
          amka
        elsif column.limit > 0
          # Truncate if needed
          amka[0...column.limit]
        else
          amka[0...column.limit]
        end
      else
        amka
      end
    end

    def generate_fake_greek_personal_number(column)
      # Generate a fake Greek Personal Number (12 characters)
      # Format: 2 digits + 1 letter + 9-digit AFM
      # Example: 12A123456789 (prefix: 12A, AFM: 123456789)

      # Generate 2-digit prefix
      prefix_digits = rand(10..99).to_s

      # Generate random letter
      letters = ('A'..'Z').to_a
      prefix_letter = letters.sample

      # Generate AFM (9 digits)
      afm = rand(100000000..999999999).to_s

      personal_number = "#{prefix_digits}#{prefix_letter}#{afm}"

      # Adjust length if column has a limit
      if column.limit
        if column.limit >= 12
          personal_number
        elsif column.limit >= 10
          # Try to keep prefix + partial AFM
          personal_number[0...column.limit]
        elsif column.limit >= 3
          # Keep at least the prefix
          personal_number[0...column.limit]
        elsif column.limit > 0
          # Very short, just use digits
          rand(10 ** (column.limit - 1)...10 ** column.limit).to_s
        else
          personal_number[0...column.limit]
        end
      else
        personal_number
      end
    end

    def generate_fake_greek_ada(column)
      # Generate a fake Greek ADA (Diavgeia Decision Number)
      # Format: 4 Greek uppercase letters + 2 digits + 4 Greek uppercase letters + dash + 1 digit + 2 Greek uppercase letters
      # Example: ΨΚΕΘ46ΜΤΛΠ-7ΗΠ

      greek_letters = ['Α', 'Β', 'Γ', 'Δ', 'Ε', 'Ζ', 'Η', 'Θ', 'Ι', 'Κ', 'Λ', 'Μ', 'Ν', 'Ξ', 'Ο', 'Π', 'Ρ', 'Σ', 'Τ', 'Υ', 'Φ', 'Χ', 'Ψ', 'Ω']

      # First part: 4 Greek uppercase letters
      part1 = 4.times.map { greek_letters.sample }.join

      # 2 digits
      digits1 = 2.times.map { rand(0..9) }.join

      # Second part: 4 Greek uppercase letters
      part2 = 4.times.map { greek_letters.sample }.join

      # After dash: 1 digit
      digit2 = rand(0..9).to_s

      # Final part: 2 Greek uppercase letters
      part3 = 2.times.map { greek_letters.sample }.join

      ada = "#{part1}#{digits1}#{part2}-#{digit2}#{part3}"

      # Adjust length if column has a limit
      if column.limit && column.limit < 15
        ada[0...column.limit]
      else
        ada
      end
    end

    def generate_fake_greek_adam(column)
      # Generate a fake Greek ADAM number (Public Procurement Publicity identifier)
      # Format: 2 digits + PROC or REQ + 9 digits
      # Examples: 21PROC009041696, 21REQ008902853

      # First 2 digits (year)
      year_part = 2.times.map { rand(0..9) }.join

      # Category type (always PROC or REQ)
      category = ['PROC', 'REQ'].sample

      # 9 digits (sequential number)
      sequence = 9.times.map { rand(0..9) }.join

      adam = "#{year_part}#{category}#{sequence}"

      # Adjust length if column has a limit
      if column.limit && column.limit < adam.length
        adam[0...column.limit]
      else
        adam
      end
    end

    def generate_fake_date_of_birth(original_value, column)
      # Generate a fake date of birth preserving approximate age (adulthood)
      # Strategy: Keep the year roughly the same (within +/- 2 years) to preserve age category

      return Faker::Date.birthday(min_age: 18, max_age: 80) if original_value.nil?

      begin
        # Parse the original date
        original_date = case original_value
        when Date
          original_value
        when Time, DateTime
          original_value.to_date
        when String
          Date.parse(original_value)
        else
          return Faker::Date.birthday(min_age: 18, max_age: 80)
        end

        # Calculate age
        today = Date.today
        age = today.year - original_date.year
        age -= 1 if today < original_date + age.years

        # Generate a new birth date with similar age (+/- 2 years)
        min_age = [age - 2, 18].max  # Preserve adulthood (minimum 18)
        max_age = age + 2

        Faker::Date.birthday(min_age: min_age, max_age: max_age)
      rescue
        # Fallback if parsing fails
        Faker::Date.birthday(min_age: 18, max_age: 80)
      end
    end

    def generate_fake_identity_number(column)
      # Generate a fake identity number (generic format)
      # Using alphanumeric format similar to national ID cards
      letters = ('A'..'Z').to_a

      if column.limit
        if column.limit >= 8
          # Full format: 2 letters + 6 digits
          "#{letters.sample}#{letters.sample}#{rand(100000..999999)}"
        elsif column.limit >= 2
          # Adjust format to fit column size
          num_letters = [2, column.limit / 2].min
          num_digits = column.limit - num_letters
          letter_part = num_letters.times.map { letters.sample }.join
          digit_part = num_digits > 0 ? rand(10 ** (num_digits - 1)...10 ** num_digits).to_s : ''
          "#{letter_part}#{digit_part}"
        else
          # Very small limit, just use letters
          column.limit.times.map { letters.sample }.join
        end
      else
        # No limit, use default format
        "#{letters.sample}#{letters.sample}#{rand(100000..999999)}"
      end
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

    def dump_database_schema(db_name)
      db_config = @database_configs[db_name]
      return unless db_config

      schema_path = Rails.root.join(@grainery_path, db_name.to_s, 'schema.rb')

      begin
        base_class = safe_const_get(db_config[:model_base_class])
        connection = base_class.connection

        # Generate schema dump
        schema_content = []
        schema_content << "# Schema dump for #{db_name} database"
        schema_content << "# Generated: #{Time.now}"
        schema_content << "# Adapter: #{db_config[:adapter]}"
        schema_content << ""
        schema_content << "ActiveRecord::Schema.define do"
        schema_content << ""

        # Get all tables for this connection
        tables = connection.tables.sort

        tables.each do |table_name|
          # Skip internal Rails tables
          next if ['schema_migrations', 'ar_internal_metadata'].include?(table_name)

          schema_content << "  create_table \"#{table_name}\", force: :cascade do |t|"

          # Get columns
          connection.columns(table_name).each do |column|
            next if column.name == 'id' # Primary key is handled by create_table

            type = column.type
            attrs = []
            attrs << "limit: #{column.limit}" if column.limit
            attrs << "precision: #{column.precision}" if column.precision
            attrs << "scale: #{column.scale}" if column.scale
            attrs << "null: false" unless column.null
            attrs << "default: #{column.default.inspect}" if column.default

            attrs_str = attrs.any? ? ", #{attrs.join(', ')}" : ""
            schema_content << "    t.#{type} \"#{column.name}\"#{attrs_str}"
          end

          schema_content << "  end"
          schema_content << ""

          # Get indexes
          connection.indexes(table_name).each do |index|
            columns = index.columns.is_a?(Array) ? index.columns : [index.columns]
            options = []
            options << "name: \"#{index.name}\"" if index.name
            options << "unique: true" if index.unique

            columns_str = columns.size == 1 ? "\"#{columns.first}\"" : "[#{columns.map { |c| "\"#{c}\"" }.join(', ')}]"
            options_str = options.any? ? ", #{options.join(', ')}" : ""

            schema_content << "  add_index \"#{table_name}\", #{columns_str}#{options_str}"
          end

          schema_content << "" if connection.indexes(table_name).any?
        end

        schema_content << "end"
        schema_content << ""

        File.write(schema_path, schema_content.join("\n"))
        puts "  ✓ Schema dumped for #{db_name} → schema.rb"
      rescue => e
        puts "  ✗ Error dumping schema for #{db_name}: #{e.message}"
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

    def load_seeds(load_schema: false)
      order_file = Rails.root.join(@grainery_path, 'load_order.txt')

      unless File.exist?(order_file)
        puts "  ✗ Load order file not found. Run 'rake grainery:generate' first."
        return
      end

      puts "\n" + "="*80
      puts "Loading Harvested Seeds"
      puts "="*80
      puts "Load schema: #{load_schema ? 'YES' : 'NO'}"
      puts "="*80

      # Load schemas first if requested
      if load_schema
        puts "\n" + "-"*80
        puts "Loading Database Schemas"
        puts "-"*80

        @database_configs.each do |db_name, _|
          schema_file = Rails.root.join(@grainery_path, db_name.to_s, 'schema.rb')
          if File.exist?(schema_file)
            puts "  → Loading schema for #{db_name}..."
            begin
              load schema_file
            rescue => e
              puts "  ✗ Error loading schema for #{db_name}: #{e.message}"
            end
          else
            puts "  ⚠ No schema file found for #{db_name}"
          end
        end
      end

      # Load harvested seeds in dependency order
      puts "\n" + "-"*80
      puts "Loading Seed Data"
      puts "-"*80

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