# typed: ignore
# frozen_string_literal: true

require 'rails/generators'

module Solana::Ruby::Kit
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)
      desc 'Creates a SolanaRubyKit initializer in config/initializers'

      def copy_initializer
        template 'solana_ruby_kit.rb.tt', 'config/initializers/solana_ruby_kit.rb'
      end
    end
  end
end
