# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'RubyKit::OffchainMessages.assert_offchain_message_v1_equal' do
  # Base58 alphabet excludes 0, I, O and l, so the padding character is 'A'.
  SIGNER_A = 'signerAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
  SIGNER_B = 'signerBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
  SIGNER_C = 'signerCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'

  def message(content, signatory_addresses)
    RubyKit::OffchainMessages::MessageV1.new(
      content:             content,
      required_signatories: signatory_addresses.map { |a|
        RubyKit::OffchainMessages::Signatory.new(address: RubyKit::Addresses::Address.new(a))
      }
    )
  end

  def assert_equal_messages(received, expected)
    RubyKit::OffchainMessages.assert_offchain_message_v1_equal(received, expected)
  end

  it 'does not raise when the messages are identical' do
    expect {
      assert_equal_messages(message('gm', [SIGNER_A, SIGNER_B]), message('gm', [SIGNER_A, SIGNER_B]))
    }.not_to raise_error
  end

  it 'does not raise when the required signatories are listed in a different order' do
    # A decoded message lists its signatories in the order the spec mandates, whereas the
    # expected message lists them in whatever order the caller built it with.
    expect {
      assert_equal_messages(message('gm', [SIGNER_A, SIGNER_B]), message('gm', [SIGNER_B, SIGNER_A]))
    }.not_to raise_error
  end

  it 'reports the version as 1' do
    expect(message('gm', []).version).to eq(1)
  end

  describe 'content mismatches' do
    it 'raises when the contents differ' do
      expect { assert_equal_messages(message('drain my wallet', [SIGNER_A]), message('gm', [SIGNER_A])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.code).to eq(RubyKit::SolanaError::OFFCHAIN_MESSAGES__CONTENT_DOES_NOT_MATCH_EXPECTED)
          expect(error.context).to eq({ actual_bytes: 15, expected_bytes: 2 })
        }
    end

    it 'raises when the contents differ only in case' do
      # Two messages of the same length must still be compared by value.
      expect { assert_equal_messages(message('GM', [SIGNER_A]), message('gm', [SIGNER_A])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.context).to eq({ actual_bytes: 2, expected_bytes: 2 })
        }
    end

    it 'reports content lengths in UTF-8 bytes rather than in characters' do
      # Version 1 content is serialized as UTF-8, so '🤝' is four bytes rather than the
      # single character that String#length would report.
      expect { assert_equal_messages(message('gm', [SIGNER_A]), message('🤝', [SIGNER_A])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.context).to eq({ actual_bytes: 2, expected_bytes: 4 })
        }
    end

    it 'counts UTF-8 bytes for content that arrived in another encoding' do
      received = message('gm', [SIGNER_A])
      expected = message('é'.encode('ISO-8859-1'), [SIGNER_A])
      expect { assert_equal_messages(received, expected) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.context).to eq({ actual_bytes: 2, expected_bytes: 2 })
        }
    end

    it 'never puts the message content in the error' do
      expect { assert_equal_messages(message('hunter2', [SIGNER_A]), message('gm', [SIGNER_A])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.context.values).not_to include('hunter2')
          expect(error.message).not_to include('hunter2')
        }
    end
  end

  describe 'required signatory mismatches' do
    it 'raises when the received message is missing a required signatory' do
      expect { assert_equal_messages(message('gm', [SIGNER_A]), message('gm', [SIGNER_A, SIGNER_B])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.code)
            .to eq(RubyKit::SolanaError::OFFCHAIN_MESSAGES__REQUIRED_SIGNATORIES_DO_NOT_MATCH_EXPECTED)
          expect(error.context).to eq({
            actual_addresses:   [SIGNER_A],
            expected_addresses: [SIGNER_A, SIGNER_B]
          })
        }
    end

    it 'raises when the received message has an extra required signatory' do
      expect { assert_equal_messages(message('gm', [SIGNER_A, SIGNER_B]), message('gm', [SIGNER_A])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.context).to eq({
            actual_addresses:   [SIGNER_A, SIGNER_B],
            expected_addresses: [SIGNER_A]
          })
        }
    end

    it 'reports both sets of signatories sorted when one is substituted for another' do
      expect { assert_equal_messages(message('gm', [SIGNER_C, SIGNER_A]), message('gm', [SIGNER_B, SIGNER_A])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.context).to eq({
            actual_addresses:   [SIGNER_A, SIGNER_C],
            expected_addresses: [SIGNER_A, SIGNER_B]
          })
        }
    end

    it 'raises when a signatory is duplicated in one message but not the other' do
      # Signatories are compared as sorted lists rather than as sets, so a duplicate is a
      # difference rather than a no-op.
      expect { assert_equal_messages(message('gm', [SIGNER_A]), message('gm', [SIGNER_A, SIGNER_A])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.context).to eq({
            actual_addresses:   [SIGNER_A],
            expected_addresses: [SIGNER_A, SIGNER_A]
          })
        }
    end

    it 'renders the address lists readably in the error message' do
      expect { assert_equal_messages(message('gm', [SIGNER_A]), message('gm', [SIGNER_A, SIGNER_B])) }
        .to raise_error(RubyKit::SolanaError) { |error|
          expect(error.message).to include("Expected [#{SIGNER_A}, #{SIGNER_B}]")
          expect(error.message).to include("Got [#{SIGNER_A}]")
        }
    end
  end

  it 'reports a content mismatch rather than a signatory mismatch when both differ' do
    expect { assert_equal_messages(message('drain my wallet', [SIGNER_B]), message('gm', [SIGNER_A])) }
      .to raise_error(RubyKit::SolanaError) { |error|
        expect(error.code).to eq(RubyKit::SolanaError::OFFCHAIN_MESSAGES__CONTENT_DOES_NOT_MATCH_EXPECTED)
      }
  end
end
