# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module OffchainMessages
    # An off-chain message ready for signing.
    # Mirrors the OffchainMessage type from @solana/signers.
    class Message < T::Struct
      # Header version: 0 = legacy ASCII, 1 = extended UTF-8.
      const :version, Integer

      # Application domain (up to 255 bytes).
      const :domain, String

      # UTF-8 message body.
      const :message, String

      # Optional application-specific domain (version ≥ 1 only).
      const :application_domain, T.nilable(String), default: nil
    end
  end
end
