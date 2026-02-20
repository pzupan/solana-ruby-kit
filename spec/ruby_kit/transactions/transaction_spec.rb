# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Transactions do
  let(:signer)  { RubyKit::Signers.generate_key_pair_signer }
  let(:addr_str) { signer.address.value }

  # Build a minimal transaction with one reserved signer slot.
  let(:message_bytes) { RbNaCl::Random.random_bytes(64) }
  let(:transaction) do
    RubyKit::Transactions::Transaction.new(
      message_bytes: message_bytes,
      signatures:    { addr_str => nil }   # slot reserved, not yet signed
    )
  end

  describe '.partially_sign_transaction' do
    it 'fills the signer slot with a valid signature' do
      signed = described_class.partially_sign_transaction(
        [signer.key_pair.signing_key],
        transaction
      )

      sig_bytes = signed.signatures[addr_str]
      expect(sig_bytes).not_to be_nil
      expect(sig_bytes.bytesize).to eq(64)
    end

    it 'raises SolanaError when a key is not an expected signer' do
      other_key = RubyKit::Keys.generate_key_pair.signing_key

      expect do
        described_class.partially_sign_transaction([other_key], transaction)
      end.to raise_error(RubyKit::SolanaError)
    end

    it 'returns the same transaction when signing again with an identical key' do
      signed  = described_class.partially_sign_transaction([signer.key_pair.signing_key], transaction)
      signed2 = described_class.partially_sign_transaction([signer.key_pair.signing_key], signed)

      expect(signed2.signatures[addr_str]).to eq(signed.signatures[addr_str])
    end
  end

  describe '.sign_transaction' do
    it 'returns a FullySignedTransaction when all slots are filled' do
      fully_signed = described_class.sign_transaction(
        [signer.key_pair.signing_key],
        transaction
      )

      expect(fully_signed).to be_a(RubyKit::Transactions::FullySignedTransaction)
      expect(described_class.fully_signed_transaction?(fully_signed)).to be true
    end
  end

  describe '.fully_signed_transaction? / .assert_fully_signed_transaction!' do
    it 'returns false when any slot is nil' do
      expect(described_class.fully_signed_transaction?(transaction)).to be false
    end

    it 'assert raises SolanaError for an unsigned transaction' do
      expect { described_class.assert_fully_signed_transaction!(transaction) }
        .to raise_error(RubyKit::SolanaError)
    end
  end

  describe '.get_signature_from_transaction' do
    it 'returns a base58 Signature from the fee payer slot' do
      signed = described_class.partially_sign_transaction(
        [signer.key_pair.signing_key],
        transaction
      )

      result = described_class.get_signature_from_transaction(signed)
      expect(result).to be_a(RubyKit::Keys::Signature)
      expect(RubyKit::Keys.signature?(result.value)).to be true
    end

    it 'raises SolanaError when no signature is present' do
      expect { described_class.get_signature_from_transaction(transaction) }
        .to raise_error(RubyKit::SolanaError)
    end
  end
end
