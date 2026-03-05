// Shared configuration for k6 performance tests

// Base URL for the NFT Tracker API
export const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080/nft-tracker-api';

// Sample data for parameterized requests (defaults reference real production data)
export const SAMPLE_CREATORS = (__ENV.CREATORS || 'zingtoken,omgomg').split(',');
export const SAMPLE_SYMBOLS = (__ENV.SYMBOLS || 'ZING,HERO').split(',');
export const SAMPLE_TAGS = (__ENV.TAGS || 'Creature|wolf,hero|Item').split('|');
// Real 40-char hex transaction hashes (issue operations on production)
export const SAMPLE_TRX_IDS = (__ENV.TRX_IDS || '62e5752db1bca81663c57422710616baee4807a7,05e1972da71d7a65672bb161127261d177a3ec9d').split(',');

// Creator-symbol pairs for parameterized instance lookups
export const CREATOR_SYMBOL_PAIRS = [
  { creator: 'zingtoken', symbol: 'ZING' },
  { creator: 'omgomg', symbol: 'HERO' },
];

// Thresholds applied to all scenarios
export const DEFAULT_THRESHOLDS = {
  http_req_duration: ['p(95)<500', 'p(99)<1000'],
  http_req_failed: ['rate<0.01'],
};
