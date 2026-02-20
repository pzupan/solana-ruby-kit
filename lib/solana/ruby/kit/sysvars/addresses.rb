# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Sysvars
    # Well-known on-chain addresses for all Solana sysvar accounts.
    SYSVAR_CLOCK_ADDRESS                 = T.let('SysvarC1ock11111111111111111111111111111111', String)
    SYSVAR_RENT_ADDRESS                  = T.let('SysvarRent111111111111111111111111111111111', String)
    SYSVAR_EPOCH_SCHEDULE_ADDRESS        = T.let('SysvarEpochSchedu1e111111111111111111111111', String)
    SYSVAR_FEES_ADDRESS                  = T.let('SysvarFees111111111111111111111111111111111', String)
    SYSVAR_RECENT_BLOCKHASHES_ADDRESS    = T.let('SysvarRecentB1ockHashes11111111111111111111', String)
    SYSVAR_SLOT_HASHES_ADDRESS           = T.let('SysvarS1otHashes111111111111111111111111111', String)
    SYSVAR_SLOT_HISTORY_ADDRESS          = T.let('SysvarS1otHistory11111111111111111111111111', String)
    SYSVAR_STAKE_HISTORY_ADDRESS         = T.let('SysvarStakeHistory1111111111111111111111111', String)
    SYSVAR_INSTRUCTIONS_ADDRESS          = T.let('Sysvar1nstructions1111111111111111111111111', String)
    SYSVAR_LAST_RESTART_SLOT_ADDRESS     = T.let('SysvarLastRestartS1ot1111111111111111111111', String)
    SYSVAR_EPOCH_REWARDS_ADDRESS         = T.let('SysvarEpochRewards1111111111111111111111111', String)
  end
end
