# typed: ignore
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe RubyKit::TransactionConfirmation do
  ENDPOINT2 = 'https://api.devnet.solana.com'
  let(:rpc)  { RubyKit::Rpc::Client.new(ENDPOINT2) }
  let(:sig)  { '5KtPn3DXXzHkb7VAVHZGwXJQqww39ASnkLqcZ5einu8D' }

  def stub_signature_status(status_payload)
    stub_request(:post, ENDPOINT2)
      .with(body: hash_including('method' => 'getSignatureStatuses'))
      .to_return(
        status:  200,
        body:    JSON.generate({
          'jsonrpc' => '2.0', 'id' => 1,
          'result'  => {
            'context' => { 'slot' => 100 },
            'value'   => [status_payload]
          }
        }),
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '.wait_for_confirmation' do
    it 'returns the status when already confirmed' do
      stub_signature_status({
        'slot'               => 50,
        'confirmations'      => 10,
        'err'                => nil,
        'confirmationStatus' => 'confirmed'
      })

      status = described_class.wait_for_confirmation(rpc, sig, commitment: :confirmed, timeout_secs: 5)
      expect(status).not_to be_nil
    end

    it 'raises Timeout::Error if deadline exceeded with nil status' do
      stub_request(:post, ENDPOINT2)
        .with(body: hash_including('method' => 'getSignatureStatuses'))
        .to_return(
          status:  200,
          body:    JSON.generate({ 'jsonrpc' => '2.0', 'id' => 1,
                                   'result'  => { 'context' => { 'slot' => 1 }, 'value' => [nil] } }),
          headers: { 'Content-Type' => 'application/json' }
        )

      expect do
        described_class.wait_for_confirmation(rpc, sig, commitment: :confirmed, timeout_secs: 1, poll_interval: 0.1)
      end.to raise_error(Timeout::Error)
    end

    it 'raises SolanaError when transaction failed' do
      stub_signature_status({
        'slot'               => 50,
        'confirmations'      => 0,
        'err'                => { 'InstructionError' => [0, 'Custom'] },
        'confirmationStatus' => 'confirmed'
      })

      expect do
        described_class.wait_for_confirmation(rpc, sig, commitment: :confirmed, timeout_secs: 5)
      end.to raise_error(RubyKit::SolanaError)
    end
  end
end
