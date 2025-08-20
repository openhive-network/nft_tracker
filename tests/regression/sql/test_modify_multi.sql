-- Check modifying properties of using multiactions

-- Given
CALL insert_nft_ops(block_num=>1, auth=>'alice', ops=>ARRAY[
  nft_register_op(symbol=>'alice/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>1),
  nft_register_op(symbol=>'alice/B', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>2),
  nft_register_op(symbol=>'alice/C', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>3),
  nft_modify_op(symbol=>'alice/A', name=>'test-mod', owner=>'bob', max_count=>1),
  nft_modify_op(symbol=>'alice/B', OWNER=>'bob', max_count=>4), -- Incrementing max_count should fail
  nft_modify_op(symbol=>'alice/C', issuers=>ARRAY['charlie'], max_count=>1)
]);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at = created_at FROM types_view;
