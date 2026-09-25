-- No version recorded yet: falls back to 'unspecified'
SELECT nfttracker_endpoints.get_version();

-- After install records the build's git hash, /version serves it
SELECT nfttracker_app.set_version('c2fed8958584511ef1a66dab3dbac8c40f3518f0');
SELECT nfttracker_endpoints.get_version();

-- A reinstall replaces the previous hash rather than adding a row
SELECT nfttracker_app.set_version('136fe35c62cdc0fd7d6ff41cf6c946cadc2a4cd5');
SELECT nfttracker_endpoints.get_version();
SELECT count(*) FROM nfttracker_app.version;
