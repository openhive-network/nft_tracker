/** openapi:components:schemas
nfttracker_backend.nft_type:
  type: object
  properties:
    id:
      type: integer
      description: id of NFT type
    creator:
      type: string
      description: account name that registered NFT type
    owner:
      type: string
      description: current owner of NFT type
    symbol:
      type: string
      description: symbol name of registered NFT type
    name:
      type: string
      description: name of registered NFT type
    max_count:
      type: integer
      description: max number of possible issued instances of this NFT type
    created_at:
      type: string
      format: date-time
      description: the timestamp when the NFT type was registered
    updated_at:
      type: string
      format: date-time
      description: the timestamp when the NFT type was last modified
    authorized_issuers:
      type: array
      items:
        type: string
      description: list of accounts that can issue instance of this NFT type
*/
-- openapi-generated-code-begin
DROP TYPE IF EXISTS nfttracker_backend.nft_type CASCADE;
CREATE TYPE nfttracker_backend.nft_type AS (
    "id" INT,
    "creator" TEXT,
    "owner" TEXT,
    "symbol" TEXT,
    "name" TEXT,
    "max_count" INT,
    "created_at" TIMESTAMP,
    "updated_at" TIMESTAMP,
    "authorized_issuers" TEXT[]
);
-- openapi-generated-code-end
