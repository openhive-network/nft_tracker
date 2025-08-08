-- Check registering NFT type with partial data

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/A', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>3, auth=>'alice', symbol=>'alice/B', name=>'test', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>4, auth=>'alice', symbol=>'alice/C', name=>'test', owner=>'alice', max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>5, auth=>'alice', symbol=>'alice/D', name=>'test', owner=>'alice', issuers=>ARRAY['alice']);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at = created_at FROM types_view;
