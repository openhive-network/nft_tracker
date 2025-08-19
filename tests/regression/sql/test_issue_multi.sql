-- Check issuing instances using multiactions

-- Given
CALL insert_nft_ops(block_num=>1, auth=>'alice', ops=>ARRAY[
  nft_register_op(symbol=>'alice/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>1),
  nft_register_op(symbol=>'alice/B', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>2),
  nft_issue_op(symbol=>'alice/B', holder=>'alice', data=>'{"for": "alice"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/A', holder=>'bob', data=>'{"for": "bob"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/B', holder=>'bob', data=>'{"for": "bob"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/A', holder=>'alice', data=>'{"for": "alice"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE),
  nft_issue_op(symbol=>'alice/B', holder=>'charlie', data=>'{"for": "charlie"}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE)
]);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, holder, data, tags, soulbound FROM instances_view;
SELECT ALL(updated_at = created_at) FROM instances_view;
