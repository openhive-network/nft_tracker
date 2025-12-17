# NFT Tracker

A PostgreSQL-based API for managing and tracking NFTs (Non-Fungible Tokens) on the Hive blockchain. Built on top of the Hive Application Framework (HAF), NFT Tracker provides a robust REST API for creating, managing, and querying NFT types and instances.

## Overview

NFT Tracker is a HAF-based application that processes Hive blockchain operations to track NFT creation, issuance, transfers, and modifications. It exposes a RESTful API through PostgREST, allowing applications to easily query and interact with NFT data.

### Key Concepts

- **NFT Type**: A template or class of NFTs with a unique symbol (e.g., `alice/BADGE`)
- **NFT Instance**: Individual NFTs issued from a type
- **Symbol Format**: `namespace/SYMBOL` where namespace is the creator's account name
- **Authorized Issuers**: Accounts permitted to issue instances of an NFT type
- **Soulbound NFTs**: NFTs that cannot be transferred once marked as soulbound

## Features

- ✅ **NFT Type Registration**: Create new NFT types with customizable properties
- ✅ **NFT Issuance**: Mint individual NFT instances with custom data and tags
- ✅ **Transfer Management**: Transfer NFTs between accounts
- ✅ **Soulbound Support**: Mark NFTs as non-transferable
- ✅ **Flexible Querying**: Query NFTs by type, holder, tags, and more
- ✅ **Authorization Control**: Manage who can issue NFTs for each type
- ✅ **REST API**: Easy-to-use HTTP endpoints via PostgREST
- ✅ **OpenAPI Documentation**: Auto-generated API documentation

## Getting Started

### Prerequisites

- Docker and Docker Compose
- PostgreSQL 14+ with HAF installed
- PostgREST
- Access to a Hive blockchain node (for live data)

### Installation

1. **Clone the repository**:
   ```sh
   git clone https://gitlab.syncad.com/hive/nft_tracker.git
   cd nft_tracker
   ```

2. **Initialize HAF submodule**:
   ```sh
   git submodule update --init --recursive
   ```

3. **Build the Docker image**:
   ```sh
   docker build -t nft_tracker:latest .
   ```

### Running the Application

1. **Install the NFT Tracker application**:
   ```sh
   ./scripts/install_app.sh
   ```

2. **Start block processing**:
   ```sh
   ./scripts/process_blocks.sh
   ```

3. **Start PostgREST API server**:
   ```sh
   ./scripts/start_postgrest.sh
   ```

The API will be available at `http://localhost:3000/nft-tracker-api`

## API Documentation

### Endpoints

#### Get API Version
```
GET /nft-tracker-api/version
```
Returns the current version (git commit hash) of the NFT Tracker application.

**Response Example**:
```json
"c2fed8958584511ef1a66dab3dbac8c40f3518f0"
```

#### Get NFT Types
```
GET /nft-tracker-api/nfts?count=<limit>&last_id=<id>
```
Returns a list of registered NFT types.

**Query Parameters**:
- `count` (optional): Maximum number of results (default: 1000, max: 1000)
- `last_id` (optional): Return types with IDs greater than this value (for pagination)

**Response Example**:
```json
[
  {
    "id": 1,
    "creator": "alice",
    "owner": "bob",
    "symbol": "TEST",
    "name": "Test NFT Collection",
    "max_count": 100,
    "created_at": "2025-08-22T12:00:00",
    "updated_at": "2025-08-22T12:00:00",
    "authorized_issuers": ["alice", "bob"]
  }
]
```

#### Get NFT Instances
```
GET /nft-tracker-api/nfts/{creator}/{symbol}?count=<limit>&last_id=<id>
```
Returns instances of a specific NFT type.

**Path Parameters**:
- `creator`: Account name that created the NFT type
- `symbol`: NFT symbol name

**Query Parameters**:
- `count` (optional): Maximum number of results (default: 1000, max: 1000)
- `last_id` (optional): Return instances with IDs greater than this value

**Response Example**:
```json
[
  {
    "id": 1,
    "holder": "alice",
    "data": "{\"image\": \"https://example.com/nft1.png\", \"rarity\": \"rare\"}",
    "tags": ["collectible", "rare"],
    "soulbound": false,
    "created_at": "2025-08-22T12:00:00",
    "updated_at": "2025-08-22T12:00:00"
  }
]
```

#### Get NFT Instances by Tags
```
GET /nft-tracker-api/nfts/{creator}/{symbol}/{tags}?count=<limit>&last_id=<id>
```
Returns instances matching specific tag patterns.

**Path Parameters**:
- `creator`: Account name that created the NFT type
- `symbol`: NFT symbol name
- `tags`: Tag pattern (e.g., `rare,collectible|common` matches instances with tags `rare` AND `collectible`, OR `common`)

**Tag Pattern Format**:
- Comma (`,`) = AND operator
- Pipe (`|`) = OR operator
- Example: `a,b|x,y|z` matches instances with tags (`a` AND `b`) OR (`x` AND `y`) OR `z`

## Usage

### Registering an NFT Type

To register a new NFT type, broadcast a `custom_json` operation on the Hive blockchain:

```json
{
  "required_auths": ["alice"],
  "required_posting_auths": [],
  "id": "NFT",
  "json": {
    "action": "register",
    "symbol": "alice/BADGE",
    "name": "Achievement Badges",
    "owner": "alice",
    "max_count": 1000,
    "issuers": ["alice", "bob"]
  }
}
```

**Parameters**:
- `action`: Must be `"register"`
- `symbol`: Format `namespace/SYMBOL` (namespace must match the account broadcasting)
- `name`: Human-readable name for the NFT type
- `owner`: Account that owns this NFT type
- `max_count`: Maximum number of instances (optional, null = unlimited)
- `issuers`: Array of accounts authorized to issue instances

### Modifying NFT Types

Update properties of an existing NFT type (only the owner can modify):

```json
{
  "required_auths": ["alice"],
  "required_posting_auths": [],
  "id": "NFT",
  "json": {
    "action": "modify",
    "symbol": "alice/BADGE",
    "name": "Updated Achievement Badges",
    "owner": "bob",
    "max_count": 500,
    "issuers": ["alice", "bob", "charlie"]
  }
}
```

**Parameters**:
- `action`: Must be `"modify"`
- `symbol`: The NFT type symbol to modify
- `name` (optional): New display name
- `owner` (optional): Transfer ownership to another account
- `max_count` (optional): Update max instances
- `issuers` (optional): Update the list of authorized issuers

**Restrictions**:
- Only the current owner can modify the type
- Cannot change `creator` or `symbol`
- `max_count` cannot be less than already issued instances

**Note**: Any optional field which is not provided is not modified.

### Issuing NFT Instances

Issue a new NFT instance:

```json
{
  "required_auths": ["alice"],
  "required_posting_auths": [],
  "id": "NFT",
  "json": {
    "action": "issue",
    "symbol": "alice/BADGE",
    "holder": "charlie",
    "data": {
      "achievement": "First Post",
      "image": "https://example.com/badges/first-post.png",
      "earned_date": "2025-01-15"
    },
    "tags": ["bronze", "social"],
    "soulbound": true
  }
}
```

**Parameters**:
- `action`: Must be `"issue"`
- `symbol`: The NFT type symbol
- `holder`: Account that will receive the created NFT instance
- `data`: Custom JSON object
- `tags`: Array of tags (max 4 tags, each max 8 characters)
- `soulbound`: If true, NFT cannot be transferred

### Soulbinding NFTs

Mark NFT instances as soulbound (non-transferable):

```json
{
  "required_auths": ["alice"],
  "required_posting_auths": [],
  "id": "NFT",
  "json": {
    "action": "soulbind",
    "symbol": "alice/BADGE",
    "ids": [1, 2, 3],
    "soulbound": true
  }
}
```

**Parameters**:
- `action`: Must be `"soulbind"`
- `symbol`: The NFT type symbol
- `ids`: Array of instance IDs to soulbind
- `soulbound`: Must be `true` (once soulbound, cannot be reversed)

**Note**: Only authorized issuers can soulbind NFTs. Once an NFT is soulbound, it cannot be unbound.

### Updating NFT Data

Update the custom data field of NFT instances:

```json
{
  "required_auths": ["alice"],
  "required_posting_auths": [],
  "id": "NFT",
  "json": {
    "action": "set_data",
    "symbol": "alice/BADGE",
    "ids": [1, 2],
    "data": {
      "achievement": "First Post",
      "level": 2,
      "upgraded": true,
      "upgrade_date": "2025-02-01"
    }
  }
}
```

**Parameters**:
- `action`: Must be `"set_data"`
- `symbol`: The NFT type symbol
- `ids`: Array of instance IDs to update
- `data`: New JSON object (completely replaces existing data)

**Note**: Only authorized issuers can update NFT data. This operation replaces the entire data field.

### Transferring NFTs

Transfer NFT instances to another account:

```json
{
  "required_auths": ["alice"],
  "required_posting_auths": [],
  "id": "NFT",
  "json": {
    "action": "transfer",
    "symbol": "alice/BADGE",
    "ids": [1, 2, 3],
    "to": "bob"
  }
}
```

**Parameters**:
- `action`: Must be `"transfer"`
- `symbol`: The NFT type symbol
- `ids`: Array of instance IDs to transfer
- `to`: Recipient account

**Note**: Soulbound NFTs cannot be transferred (except to `"null"` account to burn them).

### Querying NFTs

#### Get all NFT types:
```sh
curl http://localhost:3000/nft-tracker-api/nfts
```

#### Get specific NFT type instances:
```sh
curl http://localhost:3000/nft-tracker-api/nfts/alice/BADGE
```

#### Get NFT instances with specific tags:
```sh
# Get instances with "rare" AND "collectible" tags
curl http://localhost:3000/nft-tracker-api/nfts/alice/BADGE/rare,collectible

# Get instances with "rare" OR "epic" tags
curl http://localhost:3000/nft-tracker-api/nfts/alice/BADGE/rare|epic
```

#### Pagination:
```sh
# Get first 10 NFT types
curl http://localhost:3000/nft-tracker-api/nfts?count=10

# Get next 10 NFT types (after ID 10)
curl http://localhost:3000/nft-tracker-api/nfts?count=10&last_id=10
```

## Development

### Database Schema

The NFT Tracker uses three main tables:

1. **`nfttracker_app.types`**: Stores NFT type definitions
2. **`nfttracker_app.instances`**: Stores individual NFT instances
3. **`nfttracker_app.authorized_issuers`**: Maps authorized issuers to types

## Testing

Run the test suite:

```sh
./regress.sh
```

Tests are located in the `tests/` directory and cover:
- NFT type registration
- Instance issuance
- Transfers and soulbinding
- Authorization checks
- Edge cases and error conditions
