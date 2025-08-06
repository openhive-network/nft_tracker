-- Check that accounts that are not issuers cannot set instance data

-- Given
CALL insert_nft_register_op(block_num=>1, auth=>'alice', symbol=>'alice/XYZ', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'alice/XYZ', holder=>'alice', data=>'{}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_modify_op(block_num=>3, auth=>'alice', symbol=>'alice/XYZ', name=>'test', owner=>'alice', issuers=>ARRAY[]::hive.account_name_type[], max_count=>12);
CALL insert_nft_set_data_op(block_num=>4, pos=>1, auth=>'alice', symbol=>'alice/XYZ', id=>1, data=>'{"by": "alice"}'::jsonb);
CALL insert_nft_set_data_op(block_num=>4, pos=>2, auth=>'bob', symbol=>'alice/XYZ', id=>1, data=>'{"by": "bob"}'::jsonb);
CALL insert_nft_set_data_op(block_num=>4, pos=>3, auth=>'charlie', symbol=>'alice/XYZ', id=>1, data=>'{"by": "charlie"}'::jsonb);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT name, issuers FROM types_view;
SELECT creator, owner, symbol::TEXT, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at = created_at FROM instances_view;
