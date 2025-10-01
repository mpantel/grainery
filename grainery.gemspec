require_relative "lib/grainery/version"

Gem::Specification.new do |spec|
  spec.name        = "grainery"
  spec.version     = Grainery::VERSION
  spec.authors     = ["Michail Pantelelis"]
  spec.email       = ["mpantel@aegean.gr"]
  spec.homepage    = "https://github.com/mpantel/grainery"
  spec.summary     = "Database seed storage system for Rails applications"
  spec.description = "Extract database records and generate seed files organized by database with automatic dependency resolution. Like a grainery stores grain, this gem stores and organizes your database seeds."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{lib}/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 6.1", "< 9"
  spec.add_dependency "faker", "~> 3.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "sqlite3", "~> 1.4"
end