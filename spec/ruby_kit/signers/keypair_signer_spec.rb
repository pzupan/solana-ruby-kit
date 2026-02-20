# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Signers do
  describe '.generate_key_pair_signer' do
    it 'returns a KeyPairSigner with a valid address' do
      signer = described_class.generate_key_pair_signer

      expect(signer).to be_a(RubyKit::Signers::KeyPairSigner)
      expect(RubyKit::Addresses.address?(signer.address.value)).to be true
    end

    it 'generates unique signers each time' do
      s1 = described_class.generate_key_pair_signer
      s2 = described_class.generate_key_pair_signer

      expect(s1.address.value).not_to eq(s2.address.value)
    end
  end

  describe '.create_signer_from_key_pair' do
    it 'wraps an existing KeyPair in a KeyPairSigner' do
      kp     = RubyKit::Keys.generate_key_pair
      signer = described_class.create_signer_from_key_pair(kp)

      expected_addr = RubyKit::Addresses.encode_address(kp.verify_key.to_bytes)
      expect(signer.address.value).to eq(expected_addr)
    end
  end

  describe '.create_key_pair_signer_from_bytes' do
    it 'reconstructs the correct signer from 64 bytes' do
      original = described_class.generate_key_pair_signer
      priv_raw = original.key_pair.signing_key.to_bytes
      pub_raw  = original.key_pair.verify_key.to_bytes

      recreated = described_class.create_key_pair_signer_from_bytes(priv_raw + pub_raw)
      expect(recreated.address.value).to eq(original.address.value)
    end
  end

  describe 'signing' do
    let(:signer)  { described_class.generate_key_pair_signer }
    let(:data)    { RbNaCl::Random.random_bytes(64) }

    it 'sign produces a 64-byte signature' do
      sig = signer.sign(data)
      expect(sig.bytesize).to eq(64)
    end

    it 'verify returns true for a valid signature' do
      sig = signer.sign(data)
      expect(signer.verify(sig, data)).to be true
    end

    it 'verify returns false when data is tampered' do
      sig     = signer.sign(data)
      tampered = data[0..-2] + (data[-1].ord ^ 0xff).chr
      expect(signer.verify(sig, tampered)).to be false
    end
  end

  describe '.sign_message_bytes_with_signers' do
    it 'returns a map of address → SignatureBytes for each signer' do
      s1 = described_class.generate_key_pair_signer
      s2 = described_class.generate_key_pair_signer
      msg_bytes = RbNaCl::Random.random_bytes(32)

      result = described_class.sign_message_bytes_with_signers([s1, s2], msg_bytes)

      expect(result.keys).to contain_exactly(s1.address.value, s2.address.value)
      expect(result[s1.address.value]).to be_a(RubyKit::Keys::SignatureBytes)
      expect(result[s2.address.value]).to be_a(RubyKit::Keys::SignatureBytes)
    end
  end

  describe '.key_pair_signer? / .assert_key_pair_signer!' do
    let(:signer) { described_class.generate_key_pair_signer }

    it 'key_pair_signer? returns true for a KeyPairSigner' do
      expect(described_class.key_pair_signer?(signer)).to be true
    end

    it 'key_pair_signer? returns false for other objects' do
      expect(described_class.key_pair_signer?('not a signer')).to be false
    end

    it 'assert_key_pair_signer! does not raise for valid signers' do
      expect { described_class.assert_key_pair_signer!(signer) }.not_to raise_error
    end

    it 'assert_key_pair_signer! raises for invalid values' do
      expect { described_class.assert_key_pair_signer!(nil) }
        .to raise_error(RubyKit::SolanaError)
    end
  end
end
