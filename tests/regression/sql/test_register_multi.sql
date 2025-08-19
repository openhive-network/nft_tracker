-- Check registering new NFT types using multiactions

-- Given
CALL insert_nft_ops(block_num=>1, auth=>'alice', ops=>ARRAY[
  nft_register_op(symbol=>'alice/A', name=>'test1', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12),
  nft_register_op(symbol=>'alice/B', name=>'test2', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12),
  nft_register_op(symbol=>'alice/C', name=>'test3', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12),
  nft_register_op(symbol=>'alice/A', name=>'test1', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12),
  nft_register_op(symbol=>'alice/B', name=>'test2', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12),
  nft_register_op(symbol=>'alice/C', name=>'test3', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12)
]);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at = created_at FROM types_view;
