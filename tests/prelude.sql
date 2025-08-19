CREATE OR REPLACE FUNCTION format_custom_json_operation(block_num INT, pos INT, auth hive.account_name_type, id TEXT, data jsonb)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format('{"type":"custom_json_operation","value":{"id":"%s", "json":%s, "required_auths":[], "required_posting_auths":[%s]}}'::text, id, to_jsonb(data::text)::text, to_jsonb(auth)::text);
END;
$$;

CREATE OR REPLACE FUNCTION format_nft_operation(block_num INT, pos INT, auth hive.account_name_type, data jsonb)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format_custom_json_operation(block_num, pos, auth, 'NFT', data);
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_operation(block_num INT, pos INT, auth hive.account_name_type, data jsonb)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO hafd.operations VALUES (hafd.operation_id(block_num,18,pos), 0, 0, format_nft_operation(block_num, pos, auth, data)::jsonb::hafd.operation);
END;
$$;

CREATE OR REPLACE FUNCTION nft_register_op(symbol TEXT DEFAULT NULL, name TEXT DEFAULT NULL, owner hive.account_name_type DEFAULT NULL, issuers hive.account_name_type[] DEFAULT NULL, max_count INT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format('{"action": "register"%s%s%s%s%s}',
        ', "name": ' || to_jsonb(name)::text,
        ', "symbol": ' || to_jsonb(symbol)::text,
        ', "owner": ' || to_jsonb(owner)::text,
        ', "issuers": ' || to_jsonb(issuers)::text,
        ', "max_count": ' || to_jsonb(max_count)::text
    );
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_register_op(block_num INT, auth hive.account_name_type, symbol TEXT DEFAULT NULL, name TEXT DEFAULT NULL, owner hive.account_name_type DEFAULT NULL, issuers hive.account_name_type[] DEFAULT NULL, max_count INT DEFAULT NULL, pos INT DEFAULT 0)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_nft_operation(block_num, pos, auth, nft_register_op(symbol, name, owner, issuers, max_count)::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION nft_modify_op(symbol TEXT DEFAULT NULL, name TEXT DEFAULT NULL, owner hive.account_name_type DEFAULT NULL, issuers hive.account_name_type[] DEFAULT NULL, max_count INT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format('{"action": "modify"%s%s%s%s%s}',
        ', "symbol": ' || to_jsonb(symbol)::text,
        ', "name": ' || to_jsonb(name)::text,
        ', "owner": ' || to_jsonb(owner)::text,
        ', "issuers": ' || to_jsonb(issuers)::text,
        ', "max_count": ' || to_jsonb(max_count)::text
    );
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_modify_op(block_num INT, auth hive.account_name_type, symbol TEXT DEFAULT NULL, name TEXT DEFAULT NULL, owner hive.account_name_type DEFAULT NULL, issuers hive.account_name_type[] DEFAULT NULL, max_count INT DEFAULT NULL, pos INT DEFAULT 0)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_nft_operation(block_num, pos, auth, nft_modify_op(symbol, name, owner, issuers, max_count)::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION nft_issue_op(symbol TEXT, holder hive.account_name_type, data jsonb, tags nfttracker_app.tags, soulbound bool)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format('{"action": "issue", "symbol": %s, "holder": %s, "data": %s, "soulbound": %s, "tags": %s}',
        to_jsonb(symbol)::text,
        to_jsonb(holder)::text,
        to_jsonb(data)::text,
        to_jsonb(soulbound)::text,
        to_jsonb(tags)::text
    );
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_issue_op(block_num INT, auth hive.account_name_type, symbol TEXT, holder hive.account_name_type, data jsonb, tags nfttracker_app.tags, soulbound bool, pos INT DEFAULT 0)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_nft_operation(block_num, pos, auth, nft_issue_op(symbol, holder, data, tags, soulbound)::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION nft_soulbind_op(symbol TEXT, id INT, soulbound bool)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format('{"action": "soulbind", "symbol": %s, "id": %s, "soulbound": %s}',
        to_jsonb(symbol)::text,
        to_jsonb(id)::text,
        to_jsonb(soulbound)::text
    );
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_soulbind_op(block_num INT, auth hive.account_name_type, symbol TEXT, id INT, soulbound bool, pos INT DEFAULT 0)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_nft_operation(block_num, pos, auth, nft_soulbind_op(symbol, id, soulbound)::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION nft_set_data_op(symbol TEXT, id INT, data jsonb)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format('{"action": "set_data", "symbol": %s, "id": %s, "data": %s}',
        to_jsonb(symbol)::text,
        to_jsonb(id)::text,
        to_jsonb(data)::text
    );
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_set_data_op(block_num INT, auth hive.account_name_type, symbol TEXT, id INT, data jsonb, pos INT DEFAULT 0)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_nft_operation(block_num, pos, auth, nft_set_data_op(symbol, id, data)::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION nft_transfer_op(symbol TEXT, id INT, to_account hive.account_name_type)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN format('{"action": "transfer", "symbol": %s, "id": %s, "to": %s}',
        to_jsonb(symbol)::text,
        to_jsonb(id)::text,
        to_jsonb(to_account)::text
    );
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_transfer_op(block_num INT, auth hive.account_name_type, symbol TEXT, id INT, to_account hive.account_name_type, pos INT DEFAULT 0)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL insert_nft_operation(block_num, pos, auth, nft_transfer_op(symbol, id, to_account)::jsonb);
END;
$$;

CREATE OR REPLACE PROCEDURE insert_nft_ops(block_num INT, auth hive.account_name_type, ops TEXT[], pos INT DEFAULT 0)
LANGUAGE plpgsql
AS $$
DECLARE
    data JSONB;
BEGIN
    data := '[' || array_to_string(ops, ',') || ']';
    CALL insert_nft_operation(block_num, pos, auth, data);
END;
$$;

CREATE OR REPLACE PROCEDURE nfttracker_sync_blocks()
LANGUAGE plpgsql
AS $$
DECLARE
    block_count INT;
BEGIN
    SELECT COALESCE(MAX(hafd.operation_id_to_block_num(id)), 1) INTO block_count FROM hafd.operations;
    CALL nfttracker_app.main('nfttracker_app', block_count);
END;
$$;

CREATE OR REPLACE VIEW types_view AS
SELECT
    t.id,
    c.name AS creator,
    o.name AS owner,
    t.symbol,
    t.name,
    t.max_count,
    t.created_at,
    t.updated_at,
    ARRAY_AGG(DISTINCT a.name) FILTER (WHERE a.name IS NOT NULL) AS issuers
FROM nfttracker_app.types AS t
LEFT JOIN nfttracker_app.authorized_issuers AS ai ON t.id = ai.type_id
LEFT JOIN hafd.accounts AS a ON ai.account_id = a.id
LEFT JOIN hafd.accounts AS c ON t.creator = c.id
LEFT JOIN hafd.accounts AS o ON t.owner = o.id
GROUP BY t.id, c.name, o.name, t.symbol, t.name, t.max_count, t.created_at, t.updated_at
ORDER BY id;

CREATE OR REPLACE VIEW instances_view AS
SELECT
    i.id,
    h.name AS holder,
    i.data,
    i.tags,
    i.soulbound,
    i.created_at,
    i.updated_at,
    c.name AS creator,
    o.name AS owner,
    t.symbol,
    t.name,
    t.max_count
FROM nfttracker_app.instances AS i
INNER JOIN nfttracker_app.types AS t ON i.type_id = t.id
LEFT JOIN hafd.accounts AS h ON i.holder = h.id
LEFT JOIN hafd.accounts AS c ON t.creator = c.id
LEFT JOIN hafd.accounts AS o ON t.owner = o.id
ORDER BY id;
