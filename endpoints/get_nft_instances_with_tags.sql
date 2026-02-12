SET ROLE nfttracker_owner;

/** openapi:paths
/nfts/{creator}/{symbol}/{tags}:
  get:
    tags:
      - NFT
    summary: NFT instances
    description: |
      Returns issued instances of given NFT symbol.

      SQL example
      * `SELECT * FROM nfttracker_endpoints.get_nft_instances(''alice'', ''TEST'');`

      REST call example
      * `GET ''https://%1$s/nft-tracker-api/nfts/alice/TEST''`
    operationId: nfttracker_endpoints.get_nft_instances_with_tags
    parameters:
      - in: path
        name: creator
        required: true
        schema:
          type: string
        description: name of the account that created the NFT type
      - in: path
        name: symbol
        required: true
        schema:
          type: string
        description: NFT symbol
      - in: path
        name: tags
        required: true
        schema:
          type: string
        description: |
          Only return instances with tags matching pattern.
          Pattern is a pipe-separated list of comma-separated tags.
          Example: `a,b|x,y|z` will match instances with tags ''a'' and ''b'', ''x'' and ''y'', or ''z''.
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
          Issued NFT instances of given symbol

          * Returns `nfttracker_endpoints.nft_instance`
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/nfttracker_endpoints.nft_instance'
            example: [{
              "id": "123456789012345678",
              "holder": "alice",
              "data": "{\"key\": \"value\"}",
              "tags": ["item", "collectible"],
              "soulbound": false,
              "created_at": "2025-08-22T12:00:00",
              "updated_at": "2025-08-22T12:00:00"
            }]
      '404':
        description: |
          creator/symbol combination does not exist
*/
-- openapi-generated-code-begin
DROP FUNCTION IF EXISTS nfttracker_endpoints.get_nft_instances_with_tags;
CREATE OR REPLACE FUNCTION nfttracker_endpoints.get_nft_instances_with_tags(
    "creator" TEXT,
    "symbol" TEXT,
    "tags" TEXT,
    "count" INT = NULL,
    "last_id" NUMERIC = NULL
)
RETURNS nfttracker_endpoints.nft_instance[] 
-- openapi-generated-code-end
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  PERFORM set_config('response.headers', '[{"Cache-Control": "public, max-age=2"}]', true);

  RETURN nfttracker_backend.get_nft_instances(creator, symbol, tags, "count", last_id);
END
$$;

RESET ROLE;
