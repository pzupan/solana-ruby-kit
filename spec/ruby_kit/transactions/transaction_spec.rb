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

  # Helpers to build a real compiled transaction for size/sendable tests.
  let(:fee_payer_kp) { RbNaCl::SigningKey.generate }
  let(:fee_payer_addr) { RubyKit::Addresses.get_address_from_public_key(fee_payer_kp.verify_key) }
  let(:blockhash_constraint) do
    RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
      blockhash:              '4PZNQ5MjgFMRSAEKFbMrgCkKAJAV2VEDiJFy1JoqyN3f',
      last_valid_block_height: 9999
    )
  end
  let(:compiled_tx) do
    msg = RubyKit::TransactionMessages.create_transaction_message(version: :legacy)
    msg = RubyKit::TransactionMessages.set_fee_payer(fee_payer_addr, msg)
    msg = RubyKit::TransactionMessages.set_blockhash_lifetime(blockhash_constraint, msg)
    RubyKit::Transactions.compile_transaction_message(msg)
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

  # ── compile_transaction_message without lifetime (#581) ────────────────────

  describe '.compile_transaction_message' do
    it 'compiles without a lifetime constraint (uses 32 zero bytes as blockhash)' do
      msg = RubyKit::TransactionMessages.create_transaction_message(version: :legacy)
      msg = RubyKit::TransactionMessages.set_fee_payer(fee_payer_addr, msg)
      # no lifetime set
      tx = described_class.compile_transaction_message(msg)
      expect(tx).to be_a(RubyKit::Transactions::Transaction)
      # The 32-byte blockhash field starts at byte 3 (header) + account section;
      # just verify compilation succeeds and message_bytes is non-empty.
      expect(tx.message_bytes.bytesize).to be > 32
    end

    it 'compiles with a blockhash lifetime as before' do
      expect(compiled_tx).to be_a(RubyKit::Transactions::Transaction)
    end
  end

  # ── SendableTransaction helpers (#482) ────────────────────────────────────

  describe '.within_size_limit?' do
    it 'returns true for a small compiled transaction' do
      expect(described_class.within_size_limit?(compiled_tx)).to be true
    end
  end

  describe '.assert_within_size_limit!' do
    it 'does not raise for a small transaction' do
      expect { described_class.assert_within_size_limit!(compiled_tx) }.not_to raise_error
    end
  end

  describe '.sendable_transaction?' do
    it 'returns false when unsigned' do
      expect(described_class.sendable_transaction?(compiled_tx)).to be false
    end

    it 'returns true when fully signed and within size' do
      signed = described_class.partially_sign_transaction([fee_payer_kp], compiled_tx)
      expect(described_class.sendable_transaction?(signed)).to be true
    end
  end

  describe '.assert_sendable_transaction!' do
    it 'raises when unsigned' do
      expect { described_class.assert_sendable_transaction!(compiled_tx) }
        .to raise_error(RubyKit::SolanaError)
    end

    it 'does not raise when fully signed and within size' do
      signed = described_class.partially_sign_transaction([fee_payer_kp], compiled_tx)
      expect { described_class.assert_sendable_transaction!(signed) }.not_to raise_error
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
