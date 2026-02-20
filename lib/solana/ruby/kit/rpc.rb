# typed: strict
# frozen_string_literal: true

# RPC package — mirrors @solana/rpc + @solana/rpc-transport-http.
# Provides a synchronous JSON-RPC client for the Solana network.
require_relative 'rpc_types'
require_relative 'rpc/transport'
require_relative 'rpc/client'

module Solana::Ruby::Kit
  module Rpc
  end
end
