# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Keys do
  describe '.generate_key_pair' do
    it 'returns a KeyPair with a SigningKey and VerifyKey' do
      kp = described_class.generate_key_pair

      expect(kp).to be_a(RubyKit::Keys::KeyPair)
      expect(kp.signing_key).to be_a(RbNaCl::SigningKey)
      expect(kp.verify_key).to be_a(RbNaCl::VerifyKey)
    end

    it 'generates unique key pairs each time' do
      kp1 = described_class.generate_key_pair
      kp2 = described_class.generate_key_pair

      expect(kp1.verify_key.to_bytes).not_to eq(kp2.verify_key.to_bytes)
    end

    it 'produces a key pair where signing and verification are consistent' do
      kp   = described_class.generate_key_pair
      data = RbNaCl::Random.random_bytes(64)
      sig  = RubyKit::Keys.sign_bytes(kp.signing_key, data)

      expect(RubyKit::Keys.verify_signature(kp.verify_key, sig, data)).to be true
    end
  end

  describe '.create_key_pair_from_bytes' do
    let(:kp)       { described_class.generate_key_pair }
    let(:priv_raw) { kp.signing_key.to_bytes }
    let(:pub_raw)  { kp.verify_key.to_bytes }

    it 'reconstructs the same key pair from 64 bytes' do
      reconstructed = described_class.create_key_pair_from_bytes(priv_raw + pub_raw)

      expect(reconstructed.verify_key.to_bytes).to eq(pub_raw)
    end

    it 'raises SolanaError when given fewer than 64 bytes' do
      expect { described_class.create_key_pair_from_bytes(priv_raw) }
        .to raise_error(RubyKit::SolanaError, /64/)
    end

    it 'raises SolanaError when the embedded public key does not match' do
      wrong_pub = described_class.generate_key_pair.verify_key.to_bytes
      expect { described_class.create_key_pair_from_bytes(priv_raw + wrong_pub) }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe '.create_key_pair_from_private_key_bytes' do
    it 'derives the correct public key from a 32-byte private seed' do
      original = described_class.generate_key_pair
      seed     = original.signing_key.to_bytes

      recreated = described_class.create_key_pair_from_private_key_bytes(seed)
      expect(recreated.verify_key.to_bytes).to eq(original.verify_key.to_bytes)
    end
  end
end
