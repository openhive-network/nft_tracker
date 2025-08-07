-- Check that registering a duplicate NFT type fails

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/A', name=>'first', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/B', name=>'second', owner=>'bob', issuers=>ARRAY['bob'], max_count=>10);
CALL insert_nft_register_op(block_num=>3, pos=>1, auth=>'alice', symbol=>'alice/B', name=>'duplicate', owner=>'dan', issuers=>ARRAY['dan'], max_count=>1);
CALL insert_nft_register_op(block_num=>4, pos=>1, auth=>'alice', symbol=>'alice/C', name=>'third', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>10);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at = created_at FROM types_view;
