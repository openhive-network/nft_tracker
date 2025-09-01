-- Check that soulbinding an NFT instance works correctly and is idempotent

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_soulbind_op(block_num=>3, auth=>'alice', symbol=>'alice/ABC', ids=>ARRAY[1], soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>4, auth=>'alice', symbol=>'alice/ABC', ids=>ARRAY[1], soulbound=>TRUE);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT ALL(updated_at > created_at) FROM instances_view;
