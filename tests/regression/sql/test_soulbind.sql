-- Check that soulbinding an NFT instance works correctly and is idempotent

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', name=>'test', symbol=>'ABC', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'ABC', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, souldbound=>FALSE);
CALL insert_nft_soulbind_op(block_num=>3, auth=>'alice', symbol=>'ABC', id=>1, soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>4, auth=>'alice', symbol=>'ABC', id=>1, soulbound=>TRUE);

-- When
CALL nfttracker_app.main('nfttracker_app', 4);

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT ALL(updated_at > created_at) FROM instances_view;
