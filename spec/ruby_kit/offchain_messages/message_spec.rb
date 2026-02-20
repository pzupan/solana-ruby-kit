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

    it 'raises on invalid header' do
      expect { decode_offchain_message("\x00\x00hello".b) }
        .to raise_error(RubyKit::SolanaError)
    end
  end
end
