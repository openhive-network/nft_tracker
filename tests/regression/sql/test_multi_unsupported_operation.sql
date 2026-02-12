-- Invalid action which is part of multiaction operation doesn't stop processing of the actions that follow it.

-- Given
CALL insert_nft_ops(block_num=>1, auth=>'alice', ops=>ARRAY[
  nft_register_op(symbol=>'alice/XYZ', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12),
  nft_issue_op(symbol=>'alice/XYZ', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE),
  '{"action": "nonexistent_action"}',
  nft_transfer_op(symbol=>'alice/XYZ', ids=>ARRAY[expected_instance_id(1,0,1,1)], to_account=>'charlie')
]);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at = created_at FROM instances_view;
