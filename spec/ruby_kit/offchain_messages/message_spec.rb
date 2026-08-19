# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::OffchainMessages do
  include RubyKit::OffchainMessages::Codec

  let(:v0_message) do
    RubyKit::OffchainMessages::Message.new(
      version: 0,
      domain:  'localhost',
      message: 'Hello, Solana!'
    )
  end

  let(:v1_message) do
    RubyKit::OffchainMessages::Message.new(
      version:            1,
      domain:             'localhost',
      message:            'Sign this',
      application_domain: 'myapp.com'
    )
  end

  describe '#encode_offchain_message / #decode_offchain_message' do
    it 'starts with the 0xFF 0xFF magic bytes' do
      encoded = encode_offchain_message(v0_message)
      expect(encoded.bytes.first(2)).to eq([0xFF, 0xFF])
    end

    it 'round-trips a v0 message' do
      encoded = encode_offchain_message(v0_message)
      decoded = decode_offchain_message(encoded)
      expect(decoded.version).to eq(0)
      expect(decoded.domain).to  eq('localhost')
      expect(decoded.message).to eq('Hello, Solana!')
    end

    it 'round-trips a v1 message with application_domain' do
      encoded = encode_offchain_message(v1_message)
      decoded = decode_offchain_message(encoded)
      expect(decoded.version).to            eq(1)
      expect(decoded.application_domain).to eq('myapp.com')
      expect(decoded.message).to            eq('Sign this')
    end

    it 'round-trips a v1 message without an application_domain' do
      # Regression: encode used to omit the application-domain block entirely when there
      # was no application domain, while decode always read a length for v1. The decoder
      # then consumed the message length as an application-domain length and every
      # subsequent field was misread, silently yielding an empty message.
      message = RubyKit::OffchainMessages::Message.new(
        version: 1,
        domain:  'localhost',
        message: 'Sign this'
      )
      decoded = decode_offchain_message(encode_offchain_message(message))

      expect(decoded.version).to            eq(1)
      expect(decoded.message).to            eq('Sign this')
      expect(decoded.domain).to             eq('localhost')
      expect(decoded.application_domain).to be_nil
    end

    it 'raises on invalid header' do
      expect { decode_offchain_message("\x00\x00hello".b) }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe '#sign_offchain_message / #verify_offchain_message_signature' do
    let(:signer) { RubyKit::Signers.generate_key_pair_signer }
    let(:verify_key) { signer.key_pair.signing_key.verify_key.to_bytes }

    # Regression: the verifier used to hand RbNaCl the base58 signature text (via
    # `pack('H*')` over it, no less) rather than the 64 raw bytes it decodes to, so
    # verification could never succeed.
    it 'verifies a signature it just produced' do
      signature = sign_offchain_message(signer, v1_message)
      expect(verify_offchain_message_signature(verify_key, signature, v1_message)).to be(true)
    end

    it 'rejects a signature over different content' do
      signature = sign_offchain_message(signer, v1_message)
      expect(verify_offchain_message_signature(verify_key, signature, v0_message)).to be(false)
    end

    it 'rejects a signature checked against the wrong key' do
      signature  = sign_offchain_message(signer, v1_message)
      other_key  = RubyKit::Signers.generate_key_pair_signer.key_pair.signing_key.verify_key.to_bytes
      expect(verify_offchain_message_signature(other_key, signature, v1_message)).to be(false)
    end
  end
end
