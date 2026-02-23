/** openapi:components:schemas
nfttracker_endpoints.nft_instance_with_type:
  type: object
  properties:
    id:
      type: string
      description: id of NFT instance
    creator:
      type: string
      description: account that registered the NFT type
    symbol:
      type: string
      description: symbol name of the NFT type
    holder:
      type: string
      description: account currently owning this instance
    data:
      type: string
      description: extra data as JSON
    tags:
      type: array
      items:
        type: string
      description: extra tags associated with this instance
    soulbound:
      type: boolean
      description: whether this instance is soulbound (cannot be
        transferred to other account)
    created_at:
      type: string
      format: date-time
      description: the timestamp when this instance was created
    updated_at:
      type: string
      format: date-time
      description: the timestamp this instance was last modified
*/
-- openapi-generated-code-begin
DROP TYPE IF EXISTS nfttracker_endpoints.nft_instance_with_type CASCADE;
CREATE TYPE nfttracker_endpoints.nft_instance_with_type AS (
    "id" TEXT,
    "creator" TEXT,
    "symbol" TEXT,
    "holder" TEXT,
    "data" TEXT,
    "tags" TEXT[],
    "soulbound" BOOLEAN,
    "created_at" TIMESTAMP,
    "updated_at" TIMESTAMP
);
-- openapi-generated-code-end
