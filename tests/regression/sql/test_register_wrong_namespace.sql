-- Check that registering type with incorrect namespace fails.

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'bob/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_register_op(block_num=>2, pos=>1, auth=>'bob', symbol=>'initminer/ABC', name=>'test', owner=>'bob', issuers=>ARRAY['bob'], max_count=>10);
CALL insert_nft_register_op(block_num=>3, pos=>1, auth=>'charlie', symbol=>'/ABC', name=>'test', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>10);
CALL insert_nft_register_op(block_num=>3, pos=>2, auth=>'charlie', symbol=>'ABC', name=>'test', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>10);
CALL insert_nft_register_op(block_num=>3, pos=>3, auth=>'charlie', symbol=>'charlie/charlie/ABC', name=>'test', owner=>'charlie', issuers=>ARRAY['charlie'], max_count=>10);
CALL insert_nft_register_op(block_num=>4, pos=>1, auth=>'dan', symbol=>'-abc/ABC', name=>'test', owner=>'dan', issuers=>ARRAY['dan'], max_count=>10);
CALL insert_nft_register_op(block_num=>4, pos=>2, auth=>'dan', symbol=>'-abc-/ABC', name=>'test', owner=>'dan', issuers=>ARRAY['dan'], max_count=>10);
CALL insert_nft_register_op(block_num=>4, pos=>3, auth=>'dan', symbol=>'*xyz*/ABC', name=>'test', owner=>'dan', issuers=>ARRAY['dan'], max_count=>10);

-- When
CALL nfttracker_app.main('nfttracker_app', 4);

-- Then
SELECT COUNT(*) FROM types_view;
