require 'grainery/grainer'

module Grainery
  class Railtie < Rails::Railtie
    railtie_name :grainery

    rake_tasks do
      load 'tasks/grainery_tasks.rake'
      load 'tasks/test_db_tasks.rake'
    end
  end
end