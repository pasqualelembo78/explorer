//
// Created by mwo on 5/11/15.
// Patched for Mevacoin compatibility (private Blockchain/tx_memory_pool constructors)
//

#pragma once

#include "monero_headers.h"
#include "cryptonote_core/blockchain_and_pool.h"

#include <iostream>
#include <memory>

namespace xmreg
{

using namespace cryptonote;
using namespace crypto;
using namespace std;


/**
 * Micro version of cryptonote::core class.
 *
 * Patched to work with Mevacoin where Blockchain and tx_memory_pool
 * constructors are private (only accessible via friend struct BlockchainAndPool).
 *
 * We hold a cryptonote::BlockchainAndPool member (m_bap) which is the
 * only valid way to construct Blockchain and tx_memory_pool together.
 * m_blockchain_storage and m_mempool are references into m_bap.
 *
 * IMPORTANT: m_bap must be declared BEFORE m_blockchain_storage and
 * m_mempool so that it is constructed first (C++ initialises members
 * in declaration order).
 */
class MicroCore
{

public:

    MicroCore();

    ~MicroCore();

    bool
    init(const string& _blockchain_path, network_type nt);

    Blockchain&
    get_core();

    tx_memory_pool&
    get_mempool();

    bool
    get_block_by_height(const uint64_t& height, block& blk);

    bool
    get_tx(const crypto::hash& tx_hash, transaction& tx);

    bool
    get_tx(const string& tx_hash_str, transaction& tx);

    bool
    find_output_in_tx(const transaction& tx,
                      const public_key& output_pubkey,
                      tx_out& out,
                      size_t& output_index);

    uint64_t
    get_blk_timestamp(uint64_t blk_height);

    bool
    get_block_complete_entry(block const& b, block_complete_entry& bce);

    string
    get_blkchain_path();

    hw::device* const
    get_device() const;

private:

    string blockchain_path;

    network_type nettype;

    hw::device* m_device {nullptr};

    // BlockchainAndPool MUST be declared first: it owns the actual objects.
    // m_blockchain_storage and m_mempool are references into it and must be
    // initialised after m_bap in the constructor initialiser list.
    cryptonote::BlockchainAndPool m_bap;

    Blockchain&       m_blockchain_storage;
    tx_memory_pool&   m_mempool;
};


bool
init_blockchain(const string& path,
                MicroCore& mcore,
                Blockchain*& core_storage,
                network_type nt);

} // namespace xmreg
