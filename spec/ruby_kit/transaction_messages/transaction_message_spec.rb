# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::TransactionMessages do
  let(:system_program) { RubyKit::Addresses.address('11111111111111111111111111111111') }
  let(:fee_payer_kp)   { RubyKit::Keys.generate_key_pair }
  let(:fee_payer_addr) do
    RubyKit::Addresses.get_address_from_public_key(fee_payer_kp.verify_key)
  end

  describe '.create_transaction_message' do
    it 'creates an empty V0 transaction message' do
      msg = described_class.create_transaction_message(version: 0)

      expect(msg).to be_a(RubyKit::TransactionMessages::TransactionMessage)
      expect(msg.version).to eq(0)
      expect(msg.instructions).to be_empty
      expect(msg.fee_payer).to be_nil
      expect(msg.lifetime_constraint).to be_nil
    end

    it 'creates an empty legacy transaction message' do
      msg = described_class.create_transaction_message(version: :legacy)
      expect(msg.version).to eq(:legacy)
    end
  end

  describe '.set_fee_payer' do
    it 'returns a new message with the fee payer set' do
      msg  = described_class.create_transaction_message(version: 0)
      msg2 = described_class.set_fee_payer(fee_payer_addr, msg)

      expect(msg2.fee_payer).to eq(fee_payer_addr)
      expect(msg.fee_payer).to be_nil  # original unchanged
    end

    it 'is idempotent when the same fee payer is set again' do
      msg  = described_class.create_transaction_message(version: 0)
      msg2 = described_class.set_fee_payer(fee_payer_addr, msg)
      msg3 = described_class.set_fee_payer(fee_payer_addr, msg2)

      expect(msg3).to eq(msg2)
    end
  end

  describe '.set_blockhash_lifetime' do
    let(:blockhash_constraint) do
      RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
        blockhash:               '4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi',
        last_valid_block_height: 100_000
      )
    end

    it 'attaches a blockhash lifetime to the message' do
      msg  = described_class.create_transaction_message(version: 0)
      msg2 = described_class.set_blockhash_lifetime(blockhash_constraint, msg)

      expect(described_class.blockhash_lifetime?(msg2)).to be true
      expect(msg2.lifetime_constraint.blockhash).to eq(blockhash_constraint.blockhash)
    end
  end

  describe '.append_instructions / .prepend_instructions' do
    let(:instr) do
      RubyKit::Instructions::Instruction.new(
        program_address: system_program,
        accounts:        nil,
        data:            nil
      )
    end

    it 'appends instructions' do
      msg  = described_class.create_transaction_message(version: 0)
      msg2 = described_class.append_instructions(msg, [instr])

      expect(msg2.instructions.length).to eq(1)
    end

    it 'prepends instructions' do
      msg   = described_class.create_transaction_message(version: 0)
      msg2  = described_class.append_instructions(msg, [instr])
      instr2 = RubyKit::Instructions::Instruction.new(
        program_address: system_program,
        accounts:        nil,
        data:            "\x01"
      )
      msg3  = described_class.prepend_instructions(msg2, [instr2])

      expect(msg3.instructions.first.data).to eq("\x01")
    end
  end

  describe 'composing with pipe' do
    it 'builds a complete message using Functional.pipe' do
      blockhash_constraint = RubyKit::TransactionMessages::BlockhashLifetimeConstraint.new(
        blockhash:               '4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi',
        last_valid_block_height: 200_000
      )

      msg = RubyKit::Functional.pipe(
        described_class.create_transaction_message(version: 0),
        ->(tx) { described_class.set_fee_payer(fee_payer_addr, tx) },
        ->(tx) { described_class.set_blockhash_lifetime(blockhash_constraint, tx) }
      )

      expect(msg.fee_payer).to eq(fee_payer_addr)
      expect(described_class.blockhash_lifetime?(msg)).to be true
    end
  end
end
