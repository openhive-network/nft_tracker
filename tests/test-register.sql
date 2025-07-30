CREATE OR REPLACE PROCEDURE test_given()
AS $$
BEGIN
    CALL insert_nft_register_op(block_num=>1, auth=>'alice', name=>'test', symbol=>'ABC', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE test_when()
AS $$
BEGIN
    CALL nfttracker_app.main('nfttracker_app', 1);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE test_then()
AS $$
BEGIN
    ASSERT (SELECT (creator, owner, symbol::text, name::text, max_count) FROM nfttracker_app.types) = (SELECT (6, 6, 'ABC'::text, 'test'::text, 12));
END;
$$ LANGUAGE plpgsql;
