# A4 app shell

The app follows the OS light/dark preference, including changes while it is open.
There is no separate theme toggle to configure.

The initial state says **No forecast yet**, followed by **Search for a city or use
your location to see weather and what to wear.** It makes no automatic network
or GPS request. Existing errors retain actionable messages and a Retry button;
missing outfit advice says **Outfit suggestion unavailable.**

Pull down anywhere on the forecast list, even when it is shorter than the screen,
to repeat the last city request or reacquire GPS. Editing the city field does not
change the refresh target until Get Weather is tapped. Refresh also works after
a failed request. Before a location has been requested, pulling down does nothing.

The sun-and-hanger mark uses teal, white, and gold. Android has legacy and adaptive
icons, a branded pre-Android-12 launch background, and Android-12+ splash resources
with light/dark backgrounds. iOS uses branded icons and a teal launch screen.
Web has branded icons, metadata, and a launch placeholder removed on Flutter's
first frame. Desktop icons use the same mark.

Regenerate raster assets on Windows with `./tooling/Generate-BrandAssets.ps1`.
Android's vector mark lives in `android/app/src/main/res/drawable/brand_mark.xml`.

Automated checks cover system brightness changes, the initial empty state,
pull-to-refresh using the original city despite edited input, GPS refresh, and
recovery from denied GPS. Before release, check a fresh install on Android
before and after API 31 and on iOS for launcher masking and launch appearance.
iOS builds require macOS.
