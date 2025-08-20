-- Check modifying max_count respect constraints

-- Given
CALL insert_nft_ops(block_num=>1, auth=>'alice', ops=>ARRAY[
  nft_register_op(symbol=>'alice/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>1),
  nft_register_op(symbol=>'alice/B', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>2),
  nft_register_op(symbol=>'alice/C', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>3),
  nft_register_op(symbol=>'alice/D', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>4)
]);
CALL insert_nft_ops(block_num=>2, auth=>'alice', ops=>ARRAY[
  nft_issue_op(symbol=>'alice/D', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/D', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE)
]);
CALL insert_nft_ops(block_num=>3, auth=>'alice', ops=>ARRAY[
  nft_modify_op(symbol=>'alice/A', max_count=>0),
  nft_modify_op(symbol=>'alice/B', max_count=>-1),
  nft_modify_op(symbol=>'alice/C', max_count=>NULL),
  nft_modify_op(symbol=>'alice/D', max_count=>1)
]);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
