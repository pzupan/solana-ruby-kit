# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  class Configuration
    extend T::Sig

    sig { returns(String) }
    attr_reader :rpc_url

    sig { returns(T.nilable(String)) }
    attr_reader :ws_url

    sig { returns(Symbol) }
    attr_reader :commitment

    sig { returns(Integer) }
    attr_reader :timeout

    sig { void }
    def initialize
      @rpc_url    = T.let('https://api.mainnet-beta.solana.com', String)
      @ws_url     = T.let(nil, T.nilable(String))
      @commitment  = T.let(:confirmed, Symbol)
      @timeout    = T.let(30, Integer)
    end

    sig { params(value: String).void }
    def rpc_url=(value)
      @rpc_url = value
    end

    sig { params(value: T.nilable(String)).void }
    def ws_url=(value)
      @ws_url = value
    end

    sig { params(value: Symbol).void }
    def commitment=(value)
      @commitment = value
    end

    sig { params(value: Integer).void }
    def timeout=(value)
      @timeout = value
    end
  end
end
