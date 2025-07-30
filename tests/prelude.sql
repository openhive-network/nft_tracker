CREATE OR REPLACE PROCEDURE insert_custom_json_operation(block_num INT, auth hive.account_name_type, id TEXT, data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO hafd.operations VALUES (hafd.operation_id(block_num,18,0), 0, 0, format('{"type":"custom_json_operation","value":{"id":"%s", "json":%s, "required_auths":[], "required_posting_auths":[%s]}}'::text, id, to_jsonb(data::text)::text, to_jsonb(auth)::text)::jsonb::hafd.operation);
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_register_op(block_num INT, auth hive.account_name_type, name TEXT, symbol nfttracker_app.symbol, owner TEXT, issuers hive.account_name_type[], max_count INT)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_custom_json_operation(block_num, auth, 'NFT', format('{"action": "register", "name": %s, "symbol": %s, "owner": %s, "issuers": %s, "max_count": %s}',
        to_jsonb(name)::text,
        to_jsonb(symbol)::text,
        to_jsonb(owner)::text,
        to_jsonb(issuers)::text,
        to_jsonb(max_count)::text
    )::jsonb);
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_modify_op(block_num INT, auth hive.account_name_type, name TEXT, symbol nfttracker_app.symbol, owner TEXT, issuers hive.account_name_type[], max_count INT)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_custom_json_operation(block_num, auth, 'NFT', format('{"action": "modify", "name": %s, "symbol": %s, "owner": %s, "issuers": %s, "max_count": %s}',
        to_jsonb(name)::text,
        to_jsonb(symbol)::text,
        to_jsonb(owner)::text,
        to_jsonb(issuers)::text,
        to_jsonb(max_count)::text
    )::jsonb);
END;
$$;

CREATE OR REPLACE VIEW types_view AS
SELECT
    t.id,
    t.creator,
    t.owner,
    t.symbol,
    t.name,
    t.max_count,
    t.created_at,
    t.updated_at,
    ARRAY_AGG(DISTINCT a.name) FILTER (WHERE a.name IS NOT NULL) AS issuers
FROM nfttracker_app.types AS t
LEFT JOIN nfttracker_app.authorized_issuers AS ai ON t.id = ai.type_id
LEFT JOIN hafd.accounts AS a ON ai.account_id = a.id
GROUP BY t.id, t.creator, t.owner, t.symbol, t.name, t.max_count, t.created_at, t.updated_at;

