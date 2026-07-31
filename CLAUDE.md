# ZoneClock

Offline iOS world-clock planner: pick a time in the home city, see local time
and day offset in every saved city. See README.md for features and layout.

## Stack

- Swift / SwiftUI, iOS 17+
- XcodeGen: project generated from `project.yml`; the `.xcodeproj` is not
  committed. Regenerate after editing `project.yml`.
- No dependencies, no network. City data is a bundled GeoNames extract.

## Commands

- Generate project: `xcodegen generate`
- Build (device): `xcodebuild -project ZoneClock.xcodeproj -scheme ZoneClock -destination 'generic/platform=iOS' -allowProvisioningUpdates build`
- Test: `xcodebuild -project ZoneClock.xcodeproj -scheme ZoneClock -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test`
- Deploy: `xcrun devicectl device install app --device <udid> <path to ZoneClock.app>` then `xcrun devicectl device process launch --device <udid> com.riverray.ZoneClock`
- Rebuild city DB: put GeoNames dumps in `data/` (see README), run `python3 scripts/build_city_db.py`

## Standing rules

- All time math goes through `TimeUtil`; keep it pure and covered by
  `Tests/TimeUtilTests.swift`.
- `Resources/cities.tsv` is generated; edit `scripts/build_city_db.py`
  instead of the file.
