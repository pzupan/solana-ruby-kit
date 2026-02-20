# typed: strict
# frozen_string_literal: true

# Parsed RPC response types — mirrors @solana/rpc-parsed-types.
# These structs are populated when using encoding: 'jsonParsed' with
# RPC methods like getAccountInfo / getMultipleAccounts.
require_relative 'rpc_parsed_types/token_account'
require_relative 'rpc_parsed_types/nonce_account'
require_relative 'rpc_parsed_types/stake_account'
require_relative 'rpc_parsed_types/vote_account'
require_relative 'rpc_parsed_types/address_lookup_table'

module Solana::Ruby::Kit
  module RpcParsedTypes
  end
end
