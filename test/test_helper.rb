ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module SingletonStub
  # Minitest 6 split mock/stub into a separate gem; this is a tiny
  # replacement for `Module.stub(:method, value_or_proc) { ... }`
  # that we use in scraper tests.
  def stub_method(target, method_name, replacement)
    original = target.singleton_method(method_name) rescue nil
    target.define_singleton_method(method_name) do |*args, **kwargs, &blk|
      replacement.respond_to?(:call) ? replacement.call(*args, **kwargs, &blk) : replacement
    end
    yield
  ensure
    if original
      target.define_singleton_method(method_name, original)
    else
      target.singleton_class.send(:remove_method, method_name)
    end
  end
end

ActiveSupport::TestCase.include SingletonStub

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
