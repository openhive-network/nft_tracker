-- Check registering/issuing NFTs respect max_count

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>-1);
CALL insert_nft_register_op(block_num=>1, pos=>2, auth=>'alice', symbol=>'alice/B', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>0);
CALL insert_nft_register_op(block_num=>1, pos=>3, auth=>'alice', symbol=>'alice/C', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>1);
CALL insert_nft_register_op(block_num=>1, pos=>4, auth=>'alice', symbol=>'alice/D', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>3);
CALL insert_nft_register_op(block_num=>1, pos=>5, auth=>'alice', symbol=>'alice/X', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>NULL);
CALL insert_nft_issue_op(block_num=>2, pos=>1, auth=>'alice', symbol=>'alice/A', holder=>'alice', data=>'{"a": 1}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>3, pos=>1, auth=>'alice', symbol=>'alice/B', holder=>'alice', data=>'{"b": 1}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>4, pos=>1, auth=>'alice', symbol=>'alice/C', holder=>'alice', data=>'{"c": 1}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>4, pos=>2, auth=>'alice', symbol=>'alice/C', holder=>'alice', data=>'{"c": 2}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>5, pos=>1, auth=>'alice', symbol=>'alice/D', holder=>'alice', data=>'{"d": 1}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>5, pos=>2, auth=>'alice', symbol=>'alice/D', holder=>'alice', data=>'{"d": 2}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>5, pos=>3, auth=>'alice', symbol=>'alice/D', holder=>'alice', data=>'{"d": 3}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>TRUE);
CALL insert_nft_issue_op(block_num=>5, pos=>4, auth=>'alice', symbol=>'alice/D', holder=>'alice', data=>'{"d": 4}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>6, pos=>1, auth=>'alice', symbol=>'alice/X', holder=>'alice', data=>'{"x": 1}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);

CALL insert_nft_register_op(block_num=>7, pos=>1, auth=>'bob', symbol=>'bob/C', name=>'test2', owner=>'bob', issuers=>ARRAY['bob'], max_count=>2);
CALL insert_nft_register_op(block_num=>7, pos=>2, auth=>'bob', symbol=>'bob/D', name=>'test2', owner=>'bob', issuers=>ARRAY['bob'], max_count=>2);
CALL insert_nft_issue_op(block_num=>8, pos=>1, auth=>'bob', symbol=>'bob/C', holder=>'bob', data=>'{"c": 1}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>8, pos=>2, auth=>'bob', symbol=>'bob/C', holder=>'bob', data=>'{"c": 2}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>8, pos=>3, auth=>'bob', symbol=>'bob/C', holder=>'bob', data=>'{"c": 3}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>9, pos=>1, auth=>'bob', symbol=>'bob/D', holder=>'bob', data=>'{"d": 1}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>9, pos=>2, auth=>'bob', symbol=>'bob/D', holder=>'bob', data=>'{"d": 2}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);
CALL insert_nft_issue_op(block_num=>9, pos=>3, auth=>'bob', symbol=>'bob/D', holder=>'bob', data=>'{"d": 3}', tags=>ARRAY[]::nfttracker_app.tags, soulbound=>FALSE);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at = created_at FROM types_view;
SELECT creator, owner, symbol, holder, data, tags, soulbound FROM instances_view;
SELECT updated_at = created_at FROM instances_view;
