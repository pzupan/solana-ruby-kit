# typed: ignore
# frozen_string_literal: true

module Solana::Ruby::Kit
  class Railtie < Rails::Railtie
    config.solana_ruby_kit = ActiveSupport::OrderedOptions.new

    initializer 'solana_ruby_kit.configure' do |app|
      opts = app.config.solana_ruby_kit
      Solana::Ruby::Kit.configure do |c|
        c.rpc_url    = opts.rpc_url    if opts.rpc_url
        c.ws_url     = opts.ws_url     if opts.ws_url
        c.commitment = opts.commitment if opts.commitment
        c.timeout    = opts.timeout    if opts.timeout
      end
    end
  end
end
