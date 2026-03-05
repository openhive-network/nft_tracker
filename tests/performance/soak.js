// Soak test: extended duration to detect memory leaks and degradation
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';
import { BASE_URL, CREATOR_SYMBOL_PAIRS, DEFAULT_THRESHOLDS } from './config.js';

const VUS = parseInt(__ENV.VUS || '5');
const DURATION = __ENV.DURATION || '15m';

const typesLatency = new Trend('nft_types_duration');
const instancesLatency = new Trend('nft_instances_duration');

export const options = {
  stages: [
    { duration: '1m', target: VUS },
    { duration: DURATION, target: VUS },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    ...DEFAULT_THRESHOLDS,
    nft_types_duration: ['p(95)<500'],
    nft_instances_duration: ['p(95)<500'],
  },
};

function randomItem(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export default function () {
  // NFT Types
  let res = http.get(`${BASE_URL}/nfts`);
  check(res, { 'types ok': (r) => r.status === 200 });
  typesLatency.add(res.timings.duration);

  // NFT Instances
  const pair = randomItem(CREATOR_SYMBOL_PAIRS);
  res = http.get(`${BASE_URL}/nfts/${pair.creator}/${pair.symbol}`);
  check(res, { 'instances ok': (r) => r.status === 200 });
  instancesLatency.add(res.timings.duration);

  sleep(1 + Math.random());
}
