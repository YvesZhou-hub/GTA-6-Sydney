# v0.1.5 evidence

`build.json`, `opera-access-*` and `precinct-*` refer to the final exported App whose SHA256 is in the build manifest. Logs have local paths normalized to `${PROJECT}`, `${APP}`, `${USER_DATA}` and `${HOME}`; numerical results and hashes are unchanged. The three PNG files are direct native GPU captures without editing.

`stair-baseline.json` is a synthetic local reproduction using the v0.1.4 Opera source: destroying `opera/steps/7` drops support from about 15.14m to 4.5m at the sampled point. `opera-exterior-source.*` and `map-migration-source.*` are isolated source fixtures, not additional native exported-App checks. No real player save or screenshot is redistributed. All QA worlds and recovery backups are retained.
