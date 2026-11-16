ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "support/factories"
require_relative "support/stubbing"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Las fixtures del scaffold inicial quedaron como stubs inválidos cuando
    # cambió el schema económico v0.2. Usamos factories explícitas en
    # test/support/factories.rb — más legible para relaciones ricas
    # (Interaction → Post → Category → User × N).
    include Factories
    include Stubbing
  end
end
