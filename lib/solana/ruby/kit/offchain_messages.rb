# typed: strict
# frozen_string_literal: true

require 'rbnacl'

# Mirrors @solana/signers off-chain message signing.
require_relative 'offchain_messages/message'
require_relative 'offchain_messages/codec'

module Solana::Ruby::Kit
  module OffchainMessages
    # Re-export codec helpers at module level for convenience.
    extend T::Sig
    extend Codec
  end
end
