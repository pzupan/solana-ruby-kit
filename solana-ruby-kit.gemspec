# frozen_string_literal: true

require_relative 'lib/solana/ruby/kit/version'

Gem::Specification.new do |spec|
  spec.name                  = 'solana-ruby-kit'
  spec.version               = Solana::Ruby::Kit::VERSION
  spec.authors               = ['Paul Zupan']
  spec.summary               = 'Ruby port of the Anza TypeScript SDK (@anza-xyz/kit)'
  spec.license               = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'
  spec.require_paths         = ['lib']

  spec.files = Dir['lib/**/*.rb', 'lib/**/*.tt', 'solana-ruby-kit.gemspec']

  spec.add_dependency 'openssl',                 '~> 3.3'
  spec.add_dependency 'sorbet-runtime'
  spec.add_dependency 'rbnacl'
  spec.add_dependency 'websocket-client-simple'

  spec.add_development_dependency 'sorbet'
  spec.add_development_dependency 'tapioca'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock'
end
