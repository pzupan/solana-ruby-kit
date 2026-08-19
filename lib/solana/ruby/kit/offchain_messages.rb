# typed: strict
# frozen_string_literal: true

require 'rbnacl'

# Mirrors @solana/signers off-chain message signing, plus the version 1 message
# comparison helper from @solana/offchain-messages.
require_relative 'offchain_messages/message'
require_relative 'offchain_messages/message_v1'
require_relative 'offchain_messages/codec'

module Solana::Ruby::Kit
  module OffchainMessages
    extend T::Sig

    # Re-export codec helpers at module level for convenience.
    #
    # NOTE: `extend Codec` does not work here. Codec declares its helpers with
    # `module_function`, which makes the instance-method copies private, and `extend`
    # only imports public instance methods — so it would silently import nothing.
    # Delegate to Codec's module methods explicitly instead.

    sig { params(msg: Message).returns(String) }
    def self.encode_offchain_message(msg) = Codec.encode_offchain_message(msg)

    sig { params(bytes: String).returns(Message) }
    def self.decode_offchain_message(bytes) = Codec.decode_offchain_message(bytes)

    sig { params(signer: Signers::KeyPairSigner, msg: Message).returns(Keys::Signature) }
    def self.sign_offchain_message(signer, msg) = Codec.sign_offchain_message(signer, msg)

    sig do
      params(
        verify_key: String,
        signature:  Keys::Signature,
        msg:        Message
      ).returns(T::Boolean)
    end
    def self.verify_offchain_message_signature(verify_key, signature, msg)
      Codec.verify_offchain_message_signature(verify_key, signature, msg)
    end
  end
end
