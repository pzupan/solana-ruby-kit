# typed: ignore
# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'base64'

RSpec.describe RubyKit::Rpc::Client do
  ENDPOINT = 'https://api.devnet.solana.com'

  let(:client) { described_class.new(ENDPOINT) }

  # ---------------------------------------------------------------------------
  # Helper: stub a successful JSON-RPC response
  # ---------------------------------------------------------------------------
  def stub_rpc(method, result:)
    stub_request(:post, ENDPOINT)
      .with(
        body: hash_including('method' => method),
        headers: { 'Content-Type' => /application\/json/ }
      )
      .to_return(
        status:  200,
        body:    JSON.generate({ 'jsonrpc' => '2.0', 'id' => 1, 'result' => result }),
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # ---------------------------------------------------------------------------
  # Helper: stub a JSON-RPC error response
  # ---------------------------------------------------------------------------
  def stub_rpc_error(method, code:, message:)
    stub_request(:post, ENDPOINT)
      .with(body: hash_including('method' => method))
      .to_return(
        status:  200,
        body:    JSON.generate({
          'jsonrpc' => '2.0', 'id' => 1,
          'error'   => { 'code' => code, 'message' => message }
        }),
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  # ---------------------------------------------------------------------------
  # Transport errors
  # ---------------------------------------------------------------------------
  describe 'transport error handling' do
    it 'raises RpcError on a JSON-RPC error payload' do
      stub_rpc_error('getSlot', code: -32600, message: 'Invalid request')

      expect { client.get_slot }
        .to raise_error(RubyKit::Rpc::RpcError, /Invalid request/)
    end

    it 'raises HttpTransportError on a non-2xx HTTP status' do
      stub_request(:post, ENDPOINT).to_return(status: 503, body: 'Service Unavailable')

      expect { client.get_slot }
        .to raise_error(RubyKit::Rpc::HttpTransportError, /503/)
    end
  end

  # ---------------------------------------------------------------------------
  # get_slot
  # ---------------------------------------------------------------------------
  describe '#get_slot' do
    it 'returns the current slot as an Integer' do
      stub_rpc('getSlot', result: 123_456_789)

      slot = client.get_slot
      expect(slot).to be_a(Integer)
      expect(slot).to eq(123_456_789)
    end

    it 'accepts a commitment keyword argument' do
      stub_rpc('getSlot', result: 1)
      expect { client.get_slot(commitment: :finalized) }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # get_balance
  # ---------------------------------------------------------------------------
  describe '#get_balance' do
    let(:address) { 'So11111111111111111111111111111111111111112' }

    it 'returns an RpcContextualValue with slot and value (lamports)' do
      stub_rpc('getBalance', result: { 'context' => { 'slot' => 42 }, 'value' => 1_000_000 })

      res = client.get_balance(address)
      expect(res).to be_a(RubyKit::RpcTypes::RpcContextualValue)
      expect(res.slot).to  eq(42)
      expect(res.value).to eq(1_000_000)
    end
  end

  # ---------------------------------------------------------------------------
  # get_latest_blockhash
  # ---------------------------------------------------------------------------
  describe '#get_latest_blockhash' do
    it 'returns an RpcContextualValue whose value has blockhash and last_valid_block_height' do
      stub_rpc('getLatestBlockhash', result: {
        'context' => { 'slot' => 99 },
        'value'   => {
          'blockhash'            => '4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi',
          'lastValidBlockHeight' => 200
        }
      })

      res = client.get_latest_blockhash
      expect(res.slot).to eq(99)

      bh = res.value
      expect(bh.blockhash).to              eq('4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi')
      expect(bh.last_valid_block_height).to eq(200)
    end
  end

  # ---------------------------------------------------------------------------
  # get_account_info
  # ---------------------------------------------------------------------------
  describe '#get_account_info' do
    let(:address) { 'So11111111111111111111111111111111111111112' }

    it 'returns nil value when the account does not exist' do
      stub_rpc('getAccountInfo', result: { 'context' => { 'slot' => 1 }, 'value' => nil })

      res = client.get_account_info(address)
      expect(res.slot).to  eq(1)
      expect(res.value).to be_nil
    end

    it 'returns an AccountInfoWithBase64Data when the account exists' do
      stub_rpc('getAccountInfo', result: {
        'context' => { 'slot' => 2 },
        'value'   => {
          'lamports'   => 5_000,
          'owner'      => '11111111111111111111111111111111',
          'data'       => ['AAAA', 'base64'],
          'executable' => false,
          'rentEpoch'  => 0
        }
      })

      res  = client.get_account_info(address)
      info = res.value
      expect(info).to be_a(RubyKit::RpcTypes::AccountInfoWithBase64Data)
      expect(info.lamports).to    eq(5_000)
      expect(info.owner).to       eq('11111111111111111111111111111111')
      expect(info.executable).to  be false
      expect(info.rent_epoch).to  eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # get_block_height
  # ---------------------------------------------------------------------------
  describe '#get_block_height' do
    it 'returns the block height as an Integer' do
      stub_rpc('getBlockHeight', result: 99_000)

      expect(client.get_block_height).to eq(99_000)
    end
  end

  # ---------------------------------------------------------------------------
  # get_signature_statuses
  # ---------------------------------------------------------------------------
  describe '#get_signature_statuses' do
    let(:sig) { 'Fake1111111111111111111111111111111111111111111111111111111111111111111111111111111111' }

    it 'returns an RpcContextualValue whose value is an array of statuses' do
      stub_rpc('getSignatureStatuses', result: {
        'context' => { 'slot' => 55 },
        'value'   => [
          {
            'slot'               => 50,
            'confirmations'      => 3,
            'err'                => nil,
            'confirmationStatus' => 'confirmed'
          }
        ]
      })

      res = client.get_signature_statuses([sig])
      expect(res.slot).to   eq(55)
      expect(res.value).to  be_an(Array)

      status = res.value.first
      expect(status).to                    be_a(RubyKit::Rpc::Api::SignatureStatus)
      expect(status.slot).to               eq(50)
      expect(status.confirmations).to      eq(3)
      expect(status.err).to                be_nil
      expect(status.confirmation_status).to eq(:confirmed)
    end

    it 'includes nil entries for unknown signatures' do
      stub_rpc('getSignatureStatuses', result: {
        'context' => { 'slot' => 55 },
        'value'   => [nil]
      })

      res = client.get_signature_statuses([sig])
      expect(res.value).to eq([nil])
    end
  end

  # ---------------------------------------------------------------------------
  # send_transaction
  # ---------------------------------------------------------------------------
  describe '#send_transaction' do
    it 'returns a Signature wrapping the transaction signature string' do
      tx_b64 = Base64.strict_encode64('fake_tx_bytes')
      stub_rpc('sendTransaction', result: '5KtPn3DXXzHkb7VAVHZGwXJQqww39ASnkLqcZ5einu8D')

      sig = client.send_transaction(tx_b64)
      expect(sig).to be_a(RubyKit::Keys::Signature)
      expect(sig.value).to eq('5KtPn3DXXzHkb7VAVHZGwXJQqww39ASnkLqcZ5einu8D')
    end
  end

  # ---------------------------------------------------------------------------
  # request_airdrop
  # ---------------------------------------------------------------------------
  describe '#request_airdrop' do
    let(:address) { 'So11111111111111111111111111111111111111112' }

    it 'returns a Signature for the airdrop transaction' do
      stub_rpc('requestAirdrop', result: '3kSzMbn5WtX7rMF8qRU4JNAqcb7E5k1BcGiQh8ZhHGJ')

      sig = client.request_airdrop(address, 1_000_000_000)
      expect(sig).to be_a(RubyKit::Keys::Signature)
      expect(sig.value).to eq('3kSzMbn5WtX7rMF8qRU4JNAqcb7E5k1BcGiQh8ZhHGJ')
    end
  end

  # ---------------------------------------------------------------------------
  # is_blockhash_valid
  # ---------------------------------------------------------------------------
  describe '#is_blockhash_valid' do
    let(:blockhash) { '4vJ9JU1bJJE96FWSJKvHsmmFADCg4gpZQff4P3bkLKi' }

    it 'returns true when the blockhash is still valid' do
      stub_rpc('isBlockhashValid', result: { 'context' => { 'slot' => 10 }, 'value' => true })

      res = client.is_blockhash_valid(blockhash)
      expect(res.slot).to    eq(10)
      expect(res.value).to   be true
    end

    it 'returns false when the blockhash has expired' do
      stub_rpc('isBlockhashValid', result: { 'context' => { 'slot' => 11 }, 'value' => false })

      res = client.is_blockhash_valid(blockhash)
      expect(res.value).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # get_minimum_balance_for_rent_exemption
  # ---------------------------------------------------------------------------
  describe '#get_minimum_balance_for_rent_exemption' do
    it 'returns the minimum lamport balance as an Integer' do
      stub_rpc('getMinimumBalanceForRentExemption', result: 2_039_280)

      lamports = client.get_minimum_balance_for_rent_exemption(165)
      expect(lamports).to be_a(Integer)
      expect(lamports).to eq(2_039_280)
    end
  end

  # ---------------------------------------------------------------------------
  # ClusterUrl convenience constructors
  # ---------------------------------------------------------------------------
  describe 'ClusterUrl convenience constructors' do
    it 'creates a devnet client from RubyKit::RpcTypes.devnet' do
      cluster = RubyKit::RpcTypes.devnet
      c = described_class.new(cluster)
      expect(c.transport.url).to eq('https://api.devnet.solana.com')
    end

    it 'creates a testnet client from RubyKit::RpcTypes.testnet' do
      cluster = RubyKit::RpcTypes.testnet
      c = described_class.new(cluster)
      expect(c.transport.url).to eq('https://api.testnet.solana.com')
    end

    it 'creates a mainnet client from RubyKit::RpcTypes.mainnet' do
      cluster = RubyKit::RpcTypes.mainnet
      c = described_class.new(cluster)
      expect(c.transport.url).to eq('https://api.mainnet-beta.solana.com')
    end
  end
end
