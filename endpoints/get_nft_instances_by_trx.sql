SET ROLE nfttracker_owner;

/** openapi:paths
/nfts/by-trx/{trx_id}:
  get:
    tags:
      - NFT
    summary: NFT instances by transaction
    description: |
      Returns NFT instances created by a given transaction.

      SQL example
      * `SELECT * FROM nfttracker_endpoints.get_nft_instances_by_trx(''abc123...'');`

      REST call example
      * `GET ''https://%1$s/nft-tracker-api/nfts/by-trx/abc123...''`
    operationId: nfttracker_endpoints.get_nft_instances_by_trx
    parameters:
      - in: path
        name: trx_id
        required: true
        schema:
          type: string
        description: hex-encoded transaction hash
      - in: query
        name: count
        required: false
        schema:
          type: integer
          default: NULL
        description: |
          Maximum number of instances to return. The value is capped at 1000, which is also the default.
      - in: query
        name: last_id
        required: false
        schema:
          type: string
          default: NULL
        description: |
          Return instances with IDs greater than this value.
    responses:
      '200':
        description: |
          NFT instances created by the given transaction

          * Returns `nfttracker_endpoints.nft_instance_with_type`
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/nfttracker_endpoints.nft_instance_with_type'
            example: [{
              "id": "123456789012345678",
              "creator": "alice",
              "symbol": "TEST",
              "holder": "bob",
              "data": "{\"key\": \"value\"}",
              "tags": ["item", "collectible"],
              "soulbound": false,
              "created_at": "2025-08-22T12:00:00",
              "updated_at": "2025-08-22T12:00:00"
            }]
 */
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS nfttracker_endpoints.get_nft_instances_by_trx;
CREATE OR REPLACE FUNCTION nfttracker_endpoints.get_nft_instances_by_trx(
    "trx_id" TEXT,
    "count" INT = NULL,
    "last_id" TEXT = NULL
)
RETURNS nfttracker_endpoints.nft_instance_with_type[]
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN nfttracker_backend.get_nft_instances_by_trx(trx_id, "count", last_id::NUMERIC);
END
$$;

RESET ROLE;
