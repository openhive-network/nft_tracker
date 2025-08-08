-- Check that registering a new NFT type works correctly

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/B', name=>'diff', owner=>'bob', issuers=>ARRAY['bob'], max_count=>10);
CALL insert_nft_register_op(block_num=>2, pos=>1, auth=>'bob', symbol=>'bob/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>2, pos=>2, auth=>'bob', symbol=>'bob/B', name=>'diff', owner=>'bob', issuers=>ARRAY['bob'], max_count=>10);
CALL insert_nft_register_op(block_num=>3, pos=>1, auth=>'charlie', symbol=>'charlie/X', name=>'', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>10);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at = created_at FROM types_view;
