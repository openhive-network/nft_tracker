// Load test: sustained traffic across all endpoints
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { BASE_URL, CREATOR_SYMBOL_PAIRS, SAMPLE_TAGS, SAMPLE_TRX_IDS, DEFAULT_THRESHOLDS } from './config.js';

const DURATION = __ENV.DURATION || '2m';
const VUS = parseInt(__ENV.VUS || '10');

export const options = {
  stages: [
    { duration: '30s', target: VUS },       // ramp up
    { duration: DURATION, target: VUS },     // sustained load
    { duration: '15s', target: 0 },          // ramp down
  ],
  thresholds: DEFAULT_THRESHOLDS,
};

function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export default function () {
  group('Version', () => {
    const res = http.get(`${BASE_URL}/version`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  group('NFT Types', () => {
    const res = http.get(`${BASE_URL}/nfts`);
    check(res, {
      'status 200': (r) => r.status === 200,
      'returns array': (r) => Array.isArray(r.json()),
    });
  });

  group('NFT Types paginated', () => {
    const count = Math.floor(Math.random() * 50) + 1;
    const res = http.get(`${BASE_URL}/nfts?count=${count}`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  group('NFT Instances', () => {
    const pair = randomItem(CREATOR_SYMBOL_PAIRS);
    const res = http.get(`${BASE_URL}/nfts/${pair.creator}/${pair.symbol}`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  group('NFT Instances paginated', () => {
    const pair = randomItem(CREATOR_SYMBOL_PAIRS);
    const count = Math.floor(Math.random() * 20) + 1;
    const res = http.get(`${BASE_URL}/nfts/${pair.creator}/${pair.symbol}?count=${count}`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  group('NFT Instances with tags', () => {
    const pair = randomItem(CREATOR_SYMBOL_PAIRS);
    const tags = randomItem(SAMPLE_TAGS);
    const res = http.get(`${BASE_URL}/nfts/${pair.creator}/${pair.symbol}/${tags}`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  group('NFT Instances by transaction', () => {
    const trxId = randomItem(SAMPLE_TRX_IDS);
    const res = http.get(`${BASE_URL}/nfts/by-trx/${trxId}`);
    check(res, { 'status 200': (r) => r.status === 200 });
  });

  sleep(0.5);
}
