CREATE OR REPLACE PROCEDURE test_given()
AS $$
BEGIN
    CALL insert_nft_register_op(block_num=>1, auth=>'alice', name=>'test', symbol=>'ABC', owner=>'alice', issuers=>ARRAY['alice'], max_count=>12);
    CALL insert_nft_issue_op(block_num=>2, auth=>'alice', symbol=>'ABC', holder=>'bob', data=>'{"foo": "bar"}', tags=>array['xyz']::nfttracker_app.tags, souldbound=>FALSE);
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
    ASSERT (SELECT (creator, owner, symbol::TEXT, holder, data, tags, soulbound) FROM instances_view) = (SELECT (6, 6, 'ABC'::TEXT, 7, '{"foo": "bar"}'::JSONB, ARRAY['xyz']::nfttracker_app.tags, FALSE));
    ASSERT (SELECT ALL(updated_at = created_at) FROM instances_view);
END;
$$ LANGUAGE plpgsql;
