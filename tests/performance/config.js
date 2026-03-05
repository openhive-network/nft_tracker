// Shared configuration for k6 performance tests

// Base URL for the NFT Tracker API
export const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080/nft-tracker-api';

// Sample data for parameterized requests
export const SAMPLE_CREATORS = (__ENV.CREATORS || 'alice,bob,charlie').split(',');
export const SAMPLE_SYMBOLS = (__ENV.SYMBOLS || 'CARD,ART,BADGE').split(',');
export const SAMPLE_TAGS = (__ENV.TAGS || 'item,collectible|rare').split('|');
export const SAMPLE_TRX_IDS = (__ENV.TRX_IDS || 'abc123def456,789012345678').split(',');

// Thresholds applied to all scenarios
export const DEFAULT_THRESHOLDS = {
  http_req_duration: ['p(95)<500', 'p(99)<1000'],
  http_req_failed: ['rate<0.01'],
};
