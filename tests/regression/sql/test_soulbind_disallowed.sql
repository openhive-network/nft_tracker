-- Check that users not present in issuers cannot soulbind an instance

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY['alice']::hive.account_name_type[], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/ABC', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_modify_op(block_num=>3, auth=>'alice', symbol=>'alice/ABC', name=>'test', owner=>'alice', issuers=>ARRAY[]::hive.account_name_type[], max_count=>12);
CALL insert_nft_soulbind_op(block_num=>4, auth=>'alice', symbol=>'alice/ABC', id=>1, soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>5, auth=>'bob', symbol=>'alice/ABC', id=>1, soulbound=>TRUE);
CALL insert_nft_soulbind_op(block_num=>6, auth=>'charlie', symbol=>'alice/ABC', id=>1, soulbound=>TRUE);

-- When
CALL nfttracker_app.main('nfttracker_app', 6);

-- Then
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at = created_at FROM instances_view;
