SET ROLE nfttracker_owner;

/** openapi:paths
/nfts:
  get:
    tags:
      - NFT
    summary: NFT types
    description: |
      Returns registered NFT types.

      SQL example
      * `SELECT * FROM nfttracker_endpoints.get_nft_types();`

      REST call example
      * `GET ''https://%1$s/nfts-api/nfts''`
    operationId: nfttracker_endpoints.get_nft_types
    responses:
      '200':
        description: |
          Registered NFT types

          * Returns `nfttracker_backend.nft_type`
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/nfttracker_backend.nft_type'
            example: {
              "id": 1,
              "creator": "alice",
              "owner": "bob",
              "symbol": "TEST",
              "name": "Test symbol",
              "max_count": 10,
              "created_at": "2025-08-22T12:00:00",
              "updated_at": "2025-08-22T12:00:00"
            }
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS nfttracker_endpoints.get_nft_types;
CREATE OR REPLACE FUNCTION nfttracker_endpoints.get_nft_types()
RETURNS nfttracker_backend.nft_type 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN (
    SELECT ROW(
      t.id,
      c.name,
      o.name,
      t.symbol,
      t.name,
      t.max_count,
      t.created_at,
      t.updated_at,
      ARRAY_AGG(DISTINCT a.name) FILTER (WHERE a.name IS NOT NULL)
    )::nfttracker_backend.nft_type
    FROM nfttracker_app.types AS t
    LEFT JOIN nfttracker_app.authorized_issuers AS ai ON t.id = ai.type_id
    LEFT JOIN hafd.accounts AS a ON ai.account_id = a.id
    LEFT JOIN hafd.accounts AS c ON t.creator = c.id
    LEFT JOIN hafd.accounts AS o ON t.owner = o.id
    GROUP BY t.id, c.name, o.name, t.symbol, t.name, t.max_count, t.created_at, t.updated_at
    ORDER BY t.id
    LIMIT 1
  );
END
$$;

RESET ROLE;
