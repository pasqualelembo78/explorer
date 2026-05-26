//
// Created by mwo on 5/11/15.
// Patched for Mevacoin compatibility (private Blockchain/tx_memory_pool constructors)
//

#include "MicroCore.h"

namespace xmreg
{

/**
 * Initialise m_bap first (it constructs Blockchain + tx_memory_pool via
 * their friend struct), then bind the two references to its members.
 * All other code in this file uses m_blockchain_storage and m_mempool
 * exactly as before — nothing else needs to change.
 */
MicroCore::MicroCore()
    : m_bap(),
      m_blockchain_storage(m_bap.blockchain),
      m_mempool(m_bap.tx_pool)
{}

MicroCore::~MicroCore() {}


/**
 * Initialise the blockchain storage (LMDB) at the given path.
 */
bool
MicroCore::init(const string& _blockchain_path, network_type nt)
{
    blockchain_path = _blockchain_path;
    nettype         = nt;

    BlockchainDB* db = new_db();

    if (db == nullptr)
    {
        cerr << "Error: db is nullptr" << endl;
        return false;
    }

    // Try to open the existing LMDB database (read-only flag = true)
    try
    {
        db->open(blockchain_path, DBF_RDONLY);
    }
    catch (const DB_ERROR& e)
    {
        cerr << "Error opening database: " << e.what() << endl;
        return false;
    }

    m_blockchain_storage.set_user_options(1, false, 0, cryptonote::blockchain_db_sync_mode::db_nosync, false);

    try
    {
        if (!m_blockchain_storage.init(db, nt))
        {
            cerr << "Error initialising blockchain storage" << endl;
            return false;
        }
    }
    catch (const std::exception& e)
    {
        cerr << "Exception during blockchain init: " << e.what() << endl;
        return false;
    }

    m_device = &hw::get_device("default");

    return true;
}


Blockchain&
MicroCore::get_core()
{
    return m_blockchain_storage;
}

tx_memory_pool&
MicroCore::get_mempool()
{
    return m_mempool;
}


bool
MicroCore::get_block_by_height(const uint64_t& height, block& blk)
{
    try
    {
        blk = m_blockchain_storage.get_db().get_block_from_height(height);
        return true;
    }
    catch (const exception& e)
    {
        cerr << "Error getting block by height: " << e.what() << endl;
        return false;
    }
}


bool
MicroCore::get_tx(const crypto::hash& tx_hash, transaction& tx)
{
    try
    {
        return m_blockchain_storage.get_db().get_tx(tx_hash, tx);
    }
    catch (const exception& e)
    {
        cerr << "Error getting tx: " << e.what() << endl;
        return false;
    }
}


bool
MicroCore::get_tx(const string& tx_hash_str, transaction& tx)
{
    crypto::hash tx_hash;

    if (!epee::string_tools::hex_to_pod(tx_hash_str, tx_hash))
    {
        cerr << "Error: invalid tx hash string: " << tx_hash_str << endl;
        return false;
    }

    return get_tx(tx_hash, tx);
}


bool
MicroCore::find_output_in_tx(const transaction& tx,
                              const public_key& output_pubkey,
                              tx_out& out,
                              size_t& output_index)
{
    output_index = 0;

    auto it = find_if(tx.vout.begin(), tx.vout.end(),
        [&output_pubkey](const tx_out& o)
        {
            if (o.target.type() == typeid(txout_to_key))
            {
                return boost::get<txout_to_key>(o.target).key == output_pubkey;
            }
            return false;
        });

    if (it == tx.vout.end())
        return false;

    output_index = static_cast<size_t>(distance(tx.vout.begin(), it));
    out = *it;

    return true;
}


uint64_t
MicroCore::get_blk_timestamp(uint64_t blk_height)
{
    cryptonote::block blk;

    if (!get_block_by_height(blk_height, blk))
        return 0;

    return blk.timestamp;
}


bool
MicroCore::get_block_complete_entry(block const& b, block_complete_entry& bce)
{
    bce.block = cryptonote::block_to_blob(b);

    for (const auto& tx_hash : b.tx_hashes)
    {
        transaction tx;

        if (!get_tx(tx_hash, tx))
            return false;

        bce.txs.push_back(tx_to_blob(tx));
    }

    return true;
}


string
MicroCore::get_blkchain_path()
{
    return blockchain_path;
}


hw::device* const
MicroCore::get_device() const
{
    return m_device;
}


/**
 * Free function used by main.cpp:
 *   init_blockchain(path, mcore, core_storage, nettype)
 */
bool
init_blockchain(const string& path,
                MicroCore& mcore,
                Blockchain*& core_storage,
                network_type nt)
{
    if (!mcore.init(path, nt))
    {
        cerr << "Error: could not init MicroCore" << endl;
        return false;
    }

    core_storage = &mcore.get_core();

    return true;
}

} // namespace xmreg
