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
  # ---------------------------------------------------------------------------
  # get_block_time
  # ---------------------------------------------------------------------------
  describe '#get_block_time' do
    it 'returns the block production time as a Unix timestamp' do
      stub_rpc('getBlockTime', result: 1_700_000_000)

      ts = client.get_block_time(200_000_000)
      expect(ts).to eq(1_700_000_000)
    end

    it 'returns nil when the block time is not available' do
      stub_rpc('getBlockTime', result: nil)

      expect(client.get_block_time(0)).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # get_epoch_schedule
  # ---------------------------------------------------------------------------
  describe '#get_epoch_schedule' do
    it 'returns an EpochSchedule struct with all fields' do
      stub_rpc('getEpochSchedule', result: {
        'firstNormalEpoch'          => 14,
        'firstNormalSlot'           => 524_256,
        'leaderScheduleSlotOffset'  => 432_000,
        'slotsPerEpoch'             => 432_000,
        'warmup'                    => true
      })

      sched = client.get_epoch_schedule
      expect(sched.first_normal_epoch).to           eq(14)
      expect(sched.first_normal_slot).to            eq(524_256)
      expect(sched.leader_schedule_slot_offset).to  eq(432_000)
      expect(sched.slots_per_epoch).to              eq(432_000)
      expect(sched.warmup).to                       eq(true)
    end
  end

  # ---------------------------------------------------------------------------
  # get_inflation_reward
  # ---------------------------------------------------------------------------
  describe '#get_inflation_reward' do
    let(:address) { 'Vote111111111111111111111111111111111111111' }

    it 'returns an array of InflationReward structs' do
      stub_rpc('getInflationReward', result: [{
        'amount'        => 2_500,
        'commission'    => 10,
        'effectiveSlot' => 432_000,
        'epoch'         => 2,
        'postBalance'   => 1_000_002_500
      }])

      rewards = client.get_inflation_reward([address])
      expect(rewards.size).to eq(1)

      r = rewards.first
      expect(r.amount).to          eq(2_500)
      expect(r.commission).to      eq(10)
      expect(r.effective_slot).to  eq(432_000)
      expect(r.epoch).to           eq(2)
      expect(r.post_balance).to    eq(1_000_002_500)
    end

    it 'returns nil entries for addresses with no reward' do
      stub_rpc('getInflationReward', result: [nil])

      rewards = client.get_inflation_reward([address])
      expect(rewards).to eq([nil])
    end

    # Vote accounts that report commission through getVoteAccounts'
    # inflationRewardsCommissionBps get a null commission here.
    it 'parses an entry whose commission is null' do
      stub_rpc('getInflationReward', result: [{
        'amount'        => 0,
        'commission'    => nil,
        'effectiveSlot' => 436_320_000,
        'epoch'         => 1_009,
        'postBalance'   => 445_971_718
      }])

      r = client.get_inflation_reward([address]).first
      expect(r.commission).to     be_nil
      expect(r.amount).to         eq(0)
      expect(r.effective_slot).to eq(436_320_000)
      expect(r.epoch).to          eq(1_009)
      expect(r.post_balance).to   eq(445_971_718)
    end

    it 'accepts commitment, epoch, and min_context_slot options' do
      stub_rpc('getInflationReward', result: [nil])
      expect {
        client.get_inflation_reward([address], commitment: :finalized, epoch: 5, min_context_slot: 100)
      }.not_to raise_error
    end
  end

  # ---------------------------------------------------------------------------
  # get_signatures_for_address
  # ---------------------------------------------------------------------------
  describe '#get_signatures_for_address' do
    let(:address) { 'Vote111111111111111111111111111111111111111' }
    let(:sig)     { '5KtPn3DXXzHkb7VAVHZGwXJQqww39ASnkLqcZ5einu8D' }

    it 'returns an array of SignatureInfo structs' do
      stub_rpc('getSignaturesForAddress', result: [
        {
          'blockTime'          => 1_700_000_000,
          'confirmationStatus' => 'finalized',
          'err'                => nil,
          'memo'               => nil,
          'signature'          => sig,
          'slot'               => 100
        }
      ])

      results = client.get_signatures_for_address(address)
      expect(results).to be_an(Array)
      expect(results.size).to eq(1)

      info = results.first
      expect(info).to be_a(RubyKit::Rpc::Api::SignatureInfo)
      expect(info.signature).to           eq(sig)
      expect(info.slot).to                eq(100)
      expect(info.block_time).to          eq(1_700_000_000)
      expect(info.confirmation_status).to eq(:finalized)
      expect(info.err).to                 be_nil
      expect(info.memo).to                be_nil
      expect(info.transaction_index).to   be_nil
    end

    it 'exposes transactionIndex when the RPC returns it (Agave 4.0+)' do
      stub_rpc('getSignaturesForAddress', result: [
        {
          'blockTime'         => nil,
          'confirmationStatus' => 'confirmed',
          'err'               => nil,
          'memo'              => nil,
          'signature'         => sig,
          'slot'              => 200,
          'transactionIndex'  => 3
        }
      ])

      info = client.get_signatures_for_address(address).first
      expect(info.transaction_index).to eq(3)
    end

    it 'accepts optional filter keyword arguments' do
      stub_rpc('getSignaturesForAddress', result: [])
      expect do
        client.get_signatures_for_address(
          address,
          limit:            10,
          commitment:       :finalized,
          min_context_slot: 50
        )
      end.not_to raise_error
    end

    it 'returns an empty array when no signatures exist' do
      stub_rpc('getSignaturesForAddress', result: [])
      expect(client.get_signatures_for_address(address)).to eq([])
    end
  end

  describe '#get_transactions_for_address' do
    let(:address) { 'Vote111111111111111111111111111111111111111' }

    def last_config
      body = JSON.parse(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last.body)
      body['params'][1]
    end

    it 'parses a signatures page and its pagination token' do
      stub_rpc('getTransactionsForAddress', result: {
        'data' => [{
          'blockTime'          => 1_700_000_000,
          'confirmationStatus' => 'finalized',
          'err'                => nil,
          'memo'               => 'hello',
          'signature'          => '5xY',
          'slot'               => 436_320_000,
          'transactionIndex'   => 3
        }],
        'paginationToken' => '436320000:4'
      })

      page = client.get_transactions_for_address(address)
      expect(page.pagination_token).to eq('436320000:4')

      entry = page.data.first
      expect(entry.block_time).to          eq(1_700_000_000)
      expect(entry.confirmation_status).to eq(:finalized)
      expect(entry.err).to                 be_nil
      expect(entry.memo).to                eq('hello')
      expect(entry.signature).to           eq('5xY')
      expect(entry.slot).to                eq(436_320_000)
      expect(entry.transaction_index).to   eq(3)
    end

    it 'defaults to signatures details' do
      stub_rpc('getTransactionsForAddress', result: { 'data' => [], 'paginationToken' => nil })
      client.get_transactions_for_address(address)
      expect(last_config['transactionDetails']).to eq('signatures')
    end

    it 'returns full results verbatim so they can be decoded by TransactionIntrospection' do
      full = {
        'blockTime'        => nil,
        'meta'             => { 'loadedAddresses' => { 'readonly' => [], 'writable' => [] } },
        'slot'             => 100,
        'transaction'      => %w[AQID base64],
        'transactionIndex' => 0,
        'version'          => 0
      }
      stub_rpc('getTransactionsForAddress', result: { 'data' => [full], 'paginationToken' => nil })

      page = client.get_transactions_for_address(
        address, transaction_details: :full, encoding: 'base64', max_supported_transaction_version: 0
      )
      expect(page.data).to eq([full])
      expect(page.pagination_token).to be_nil
    end

    it 'serializes filters, sort order, and pagination options into the wire config' do
      stub_rpc('getTransactionsForAddress', result: { 'data' => [], 'paginationToken' => nil })

      client.get_transactions_for_address(
        address,
        commitment:       :confirmed,
        limit:            50,
        min_context_slot: 400,
        pagination_token: '100:2',
        sort_order:       :asc,
        filters:          {
          block_time:     { gte: 1_700_000_000, lt: 1_800_000_000 },
          slot:           { gt: 400 },
          signature:      { lte: '5xY' },
          status:         :succeeded,
          token_accounts: :balance_changed
        }
      )

      config = last_config
      expect(config['commitment']).to      eq('confirmed')
      expect(config['limit']).to           eq(50)
      expect(config['minContextSlot']).to  eq(400)
      expect(config['paginationToken']).to eq('100:2')
      expect(config['sortOrder']).to       eq('asc')
      expect(config['filters']).to eq(
        'blockTime'     => { 'gte' => 1_700_000_000, 'lt' => 1_800_000_000 },
        'slot'          => { 'gt' => 400 },
        'signature'     => { 'lte' => '5xY' },
        'status'        => 'succeeded',
        'tokenAccounts' => 'balanceChanged'
      )
    end

    it 'rejects the processed commitment, which this method does not support' do
      expect { client.get_transactions_for_address(address, commitment: :processed) }
        .to raise_error(ArgumentError, /processed/)
    end

    it 'rejects encoding without full transaction details' do
      expect { client.get_transactions_for_address(address, encoding: 'base64') }
        .to raise_error(ArgumentError, /only valid with transaction_details: :full/)
    end

    it 'rejects an unknown filter key' do
      expect { client.get_transactions_for_address(address, filters: { nope: 1 }) }
        .to raise_error(ArgumentError, /unknown filter/)
    end

    it 'rejects an unknown comparison operator' do
      expect { client.get_transactions_for_address(address, filters: { slot: { between: 1 } }) }
        .to raise_error(ArgumentError, /unknown comparison/)
    end

    it 'returns an empty page when nothing matches' do
      stub_rpc('getTransactionsForAddress', result: { 'data' => [], 'paginationToken' => nil })
      page = client.get_transactions_for_address(address)
      expect(page.data).to eq([])
      expect(page.pagination_token).to be_nil
    end
  end

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
