CREATE OR REPLACE PROCEDURE test_given()
AS $$
BEGIN
    CALL insert_nft_register_op(block_num=>1, auth=>'alice', name=>'test', symbol=>'ABC', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
    CALL insert_nft_modify_op(block_num=>2, auth=>'alice', name=>'test-mod', symbol=>'ABC', owner=>'bob', issuers=>ARRAY['bob'], max_count=>11);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE test_when()
AS $$
BEGIN
    CALL nfttracker_app.main('nfttracker_app', 2);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE test_then()
AS $$
BEGIN
    ASSERT (SELECT (creator, owner, symbol::text, name::text, max_count, issuers::TEXT[]) FROM types_view) = (SELECT (6, 7, 'ABC'::text, 'test-mod'::text, 11, ARRAY['bob']));
    ASSERT (SELECT ALL(updated_at > created_at) FROM types_view);
END;
$$ LANGUAGE plpgsql;
