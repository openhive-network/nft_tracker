-- Check modifying an NFT type with nonexistent creator/owner/issuer

-- Given
CALL insert_nft_register_op(block_num=>1, pos=>1, auth=>'alice', symbol=>'alice/A', name=>'test', owner=>'alice', issuers=>ARRAY['alice'], max_count=>10);
CALL insert_nft_modify_op(block_num=>2, pos=>1, auth=>'nonexistent1', symbol=>'alice/A', name=>'first', owner=>'alice', issuers=>ARRAY['nonexistent1'], max_count=>10);
CALL insert_nft_modify_op(block_num=>2, pos=>2, auth=>'alice', symbol=>'alice/A', name=>'second', owner=>'nonexistent2', issuers=>ARRAY['nonexistent2'], max_count=>10);
CALL insert_nft_modify_op(block_num=>2, pos=>3, auth=>'alice', symbol=>'alice/A', name=>'third', owner=>'charlie', issuers=>ARRAY['nonexistent3'], max_count=>10);

-- When
CALL nfttracker_sync_blocks();

-- Then
SELECT creator, owner, symbol, name, max_count, issuers FROM types_view;
SELECT updated_at = created_at FROM types_view;
