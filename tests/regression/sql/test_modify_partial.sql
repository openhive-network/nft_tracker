-- Check partial modification of NFT type

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/A', name=>'testA', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/B', name=>'testB', owner=>'alice', issuers=>ARRAY['alice'], max_count=>11);
CALL insert_nft_register_op(block_num=>1, pos=>3, auth=>'alice', symbol=>'alice/C', name=>'testC', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_register_op(block_num=>1, pos=>4, auth=>'alice', symbol=>'alice/D', name=>'testD', owner=>'alice', issuers=>ARRAY['alice'], max_count=>13);
CALL insert_nft_register_op(block_num=>1, pos=>5, auth=>'alice', symbol=>'alice/E', name=>'testE', owner=>'alice', issuers=>ARRAY['alice'], max_count=>14);
CALL insert_nft_modify_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/A', name=>'test-mod');
CALL insert_nft_modify_op(block_num=>2, pos=>2, auth=>'alice', symbol=>'alice/B', owner=>'bob');
CALL insert_nft_modify_op(block_num=>2, pos=>3, auth=>'alice', symbol=>'alice/C', issuers=>ARRAY['charlie']);
CALL insert_nft_modify_op(block_num=>2, pos=>4, auth=>'alice', symbol=>'alice/D', max_count=>8);
CALL insert_nft_modify_op(block_num=>2, pos=>5, auth=>'alice', max_count=>1);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at > created_at FROM types_view WHERE id<5;
SELECT updated_at = created_at FROM types_view WHERE id=5;
