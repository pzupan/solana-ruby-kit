# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Keys do
  let(:key_pair)   { RubyKit::Keys.generate_key_pair }
  let(:message)    { RbNaCl::Random.random_bytes(64) }

  describe '.sign_bytes' do
    it 'returns a SignatureBytes of exactly 64 bytes' do
      sig = described_class.sign_bytes(key_pair.signing_key, message)

      expect(sig).to be_a(RubyKit::Keys::SignatureBytes)
      expect(sig.bytesize).to eq(64)
    end

    it 'produces different signatures for different messages' do
      s1 = described_class.sign_bytes(key_pair.signing_key, 'message_a')
      s2 = described_class.sign_bytes(key_pair.signing_key, 'message_b')

      expect(s1.value).not_to eq(s2.value)
    end
  end

  describe '.verify_signature' do
    it 'returns true for a valid signature' do
      sig = described_class.sign_bytes(key_pair.signing_key, message)
      expect(described_class.verify_signature(key_pair.verify_key, sig, message)).to be true
    end

    it 'returns false when the message has been tampered with' do
      sig     = described_class.sign_bytes(key_pair.signing_key, message)
      tampered = message[0..-2] + (message[-1].ord ^ 0xff).chr

      expect(described_class.verify_signature(key_pair.verify_key, sig, tampered)).to be false
    end

    it 'returns false when verified against the wrong public key' do
      sig      = described_class.sign_bytes(key_pair.signing_key, message)
      other_kp = RubyKit::Keys.generate_key_pair

      expect(described_class.verify_signature(other_kp.verify_key, sig, message)).to be false
    end
  end

  describe '.signature? / .assert_signature! / .signature' do
    let(:valid_sig_bytes) { described_class.sign_bytes(key_pair.signing_key, message) }
    let(:valid_sig_str)   { described_class.encode_signature(valid_sig_bytes).value }

    it 'signature? returns true for a valid base58-encoded signature string' do
      expect(described_class.signature?(valid_sig_str)).to be true
    end

    it 'signature? returns false for a string that is too short' do
      expect(described_class.signature?('abc')).to be false
    end

    it 'assert_signature! does not raise for a valid signature string' do
      expect { described_class.assert_signature!(valid_sig_str) }.not_to raise_error
    end

    it 'assert_signature! raises SolanaError for an invalid string' do
      expect { described_class.assert_signature!('too_short') }
        .to raise_error(RubyKit::SolanaError)
    end

    it 'signature() returns a Signature value object' do
      sig = described_class.signature(valid_sig_str)
      expect(sig).to be_a(RubyKit::Keys::Signature)
      expect(sig.value).to eq(valid_sig_str)
    end
  end

  describe '.signature_bytes? / .assert_signature_bytes! / .signature_bytes' do
    let(:raw_64) { described_class.sign_bytes(key_pair.signing_key, message).value }

    it 'signature_bytes? returns true for exactly 64 bytes' do
      expect(described_class.signature_bytes?(raw_64)).to be true
    end

    it 'signature_bytes? returns false for 63 bytes' do
      expect(described_class.signature_bytes?(raw_64[0..62])).to be false
    end

    it 'signature_bytes() wraps raw bytes in a SignatureBytes object' do
      sb = described_class.signature_bytes(raw_64)
      expect(sb).to be_a(RubyKit::Keys::SignatureBytes)
    end

    it 'assert_signature_bytes! raises for wrong length' do
      expect { described_class.assert_signature_bytes!('short') }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe 'encode / decode round-trip' do
    it 'encodes SignatureBytes to base58 and decodes back to the same bytes' do
      sig_bytes = described_class.sign_bytes(key_pair.signing_key, message)
      encoded   = described_class.encode_signature(sig_bytes)
      decoded   = described_class.decode_signature(encoded)

      expect(decoded.value).to eq(sig_bytes.value)
    end
  end
end
