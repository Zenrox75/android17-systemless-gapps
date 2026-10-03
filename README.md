# Systemless GApps on Android 17 custom ROMs (when the GApps zip flashes "successfully" but nothing installs)

A guide for custom ROMs where a GApps zip reports `Install completed with status 0`
but no Play Store, Play services or GSF ever appears.

**Tested on:** Redmi 9 (`lancelot`), Evolution X 17.0 unofficial **vanilla** build
(Android 17, built-in recovery, Magisk root).
**Not tested on anything else.** It may work on other devices and ROMs with the same
symptom, but that is unverified. Reports are welcome via Issues.

---

## The symptom

- You flash a GApps zip (e.g. MindTheGapps 17) and the recovery prints "Done / status 0".
- After boot, `adb shell pm list packages | findstr /i "gms vending gsf"` prints nothing.
- Apps that need Google services hang (the game in the original report stalled at ~90% loading
  with `AssetPackException: -11 ... Play Store app is either not installed`).

## What was actually wrong

1. **The installer could not write to `/product`.** The recovery log showed
   `cp: /product/priv-app/...: Permission denied`, but the installer script does not check
   its copies, so it still printed status 0. Flashing again (clean or dirty) gives the same result.
2. **The Android 17 MindTheGapps zip tested here contained no Play services (GmsCore).**
   Only Play Store (Phonesky) and GSF were inside.
3. **Installing Play services/GSF/Play Store as normal user apps does not work.** The Play Store
   crashes with `Failed to find provider com.google.android.gsf.gservices`. Android 17 GSF builds
   declare that provider as `...gms.gservices.provider.do.not.use`, and user-installed Play services
   does not provide the real one.
4. **What worked:** the **MindTheGapps Android 16** zip *does* include GmsCore. Turning its
   `system` folder into a **Magisk module** avoids the blocked write (Magisk overlays files at boot).
   With the matched set from one package, Play services declares
   `com.google.android.gsf.gservices` and the Play Store opens.

> How to tell if you have the same problem: look at the recovery log for `Permission denied`
> on `/product/priv-app`, and run the checks in step 1 below.

---

## Requirements

- Unlocked bootloader, working ADB/fastboot on a PC (Android platform-tools).
- Ability to root with Magisk (check Magisk's release notes for your Android version).
- A MindTheGapps zip **that contains GmsCore** (see step 3).
- Your data backed up. Flashing a ROM cleanly wipes the phone.

This repo contains **no Google apps**. They are proprietary, so download the GApps zip yourself
from the MindTheGapps project.

---

## Steps

### 1. Confirm the diagnosis

```
adb shell pm list packages | findstr /i "gms vending gsf"
adb shell ls /product/priv-app
adb shell df -h /system_ext /product
```

Nothing Google in the output, and a recovery log with `Permission denied`, means this guide applies.
(Linux/macOS: use `grep -i` instead of `findstr /i`.)

### 2. Root with Magisk

1. Extract `boot.img` from your ROM zip: `tar -xf ROM.zip boot.img`.
   (If the zip has `payload.bin` instead, use a payload dumper.)
2. `adb install magisk.apk`, then `adb push boot.img /sdcard/Download/`.
3. In Magisk: Install, Select and Patch a File, choose `boot.img`.
4. `adb pull /sdcard/Download/magisk_patched-XXXXX.img`
5. ```
   adb reboot bootloader
   fastboot flash boot magisk_patched-XXXXX.img
   fastboot reboot
   ```
6. Keep the original `boot.img`. If the phone bootloops, flash it back.

### 3. Pick a GApps zip and check it is complete

Extract it, then list its APKs:

```
mkdir GApps16
tar -xf MindTheGapps-16-xxxx.zip -C GApps16
dir /s /b GApps16\*.apk | findstr /i "gms phonesky gsf"
```

You need all three:

- `...\priv-app\GmsCore\GmsCore.apk` (Play services)
- `...\priv-app\Phonesky\Phonesky.apk` (Play Store)
- `...\priv-app\GoogleServicesFramework\GoogleServicesFramework.apk`

If `GmsCore` is missing, stop. That package has the same gap as the Android 17 one here.

Check the privileged permission allowlist includes Play services:

```
findstr /s /m /c:"com.google.android.gms\"" GApps16\system\product\etc\permissions\*.xml GApps16\system\system_ext\etc\permissions\*.xml
```

A file name should be printed. If nothing prints, do not continue: a privileged app without an
allowlist entry can bootloop the device.

### 4. Build the module

Put `build_module.bat` and `module.prop` next to your extracted `GApps16` folder and run:

```
build_module.bat GApps16
```

This copies `system\`, removes `addon.d`, adds `module.prop`, and zips everything to
`gapps_module.zip` with `module.prop` at the zip root (required by Magisk). The zip is large
(about 550 MB in the original test), so building it can take a few minutes on a slow drive.

### 5. Install

1. Remove any older GApps module in Magisk first (Modules tab, trash icon).
2. If you installed Play services/Play Store/GSF as normal apps earlier, remove them:
   ```
   adb uninstall com.google.android.gms
   adb uninstall com.android.vending
   adb uninstall com.google.android.gsf
   ```
   (`DELETE_FAILED_INTERNAL_ERROR` can simply mean the package doesn't exist.)
3. `adb push gapps_module.zip /sdcard/Download/`
4. Magisk, Modules, Install from storage, pick the zip, then reboot (first boot can be slow).

### 6. Verify

```
adb shell pm list packages -f | findstr /i "gms vending gsf"
adb shell dumpsys package providers | findstr /i "gservices"
```

Good signs:

- `com.google.android.gms` under `/product/priv-app/GmsCore/`
- a provider entry `[com.google.android.gsf.gservices]` declared by `com.google.android.gms`

Then open the Play Store. Permissions and battery were already correct by default in the
original test. If not, allow all permissions and set battery to Unrestricted for Play services
and Play Store.

---

## Restoring game data on Android 11+ (Android/data)

File managers cannot touch `Android/data`, but ADB can:

```
adb shell am force-stop <package>
adb shell pm clear <package>
adb push "C:\path\to\<package>" /sdcard/Android/data/
```

`rm -rf` on that folder from ADB fails with "Permission denied" because the files belong to the app.
`pm clear` is the fix. Install and open the app once before restoring so the folder exists.

---

## Troubleshooting

| Problem | Cause / fix |
|---|---|
| `adb` is not recognized | You are in a subfolder. Run `cd ..` or use `..\adb`. |
| `adb devices` shows `unauthorized` | Accept the prompt on the phone, or Developer options, Revoke USB debugging authorizations, replug. |
| `pm install /sdcard/...` fails with avc denied | Android 17 cannot install from `/sdcard` via shell. Use `adb install file.apk` from the PC. |
| `adb shell su` says Permission denied | In Magisk, Superuser tab, allow **Shell**. Settings, Superuser access, "Apps and ADB". |
| `adb pull /tmp/recovery.log` fails | Recovery ADB is sideload-only. Read the log on the phone (Advanced, View recovery logs). |
| Play Store crashes: `Failed to find provider com.google.android.gsf.gservices` | Mixed or mismatched Google packages. Use one matched set containing GmsCore (this guide). |
| `.apkm` file won't install | It is a split-APK bundle. Rename to `.zip`, extract, use `adb install-multiple`, or use an installer app. |
| Bootloop after module install | `adb shell magisk --remove-modules`, or boot recovery and back, or flash the original `boot.img`. |

---

## Caveats

- **ROM updates can remove root and the module.** Re-patch the new `boot.img` with Magisk afterwards.
- The device will not be certified. Some apps (banking, etc.) may refuse to run.
- I have not tested other devices, ROMs, or Magisk versions. Treat this as a worked example.
- Use at your own risk. Back up your data first.

## Contributing

If this worked (or didn't) on your device, open an Issue with: device, ROM and version, GApps zip
used, and the output of the step 6 commands.

## Credits

Written by Zenrox75 from a real troubleshooting session on a Redmi 9 (`lancelot`) with Evolution X 17.
Google apps are property of Google. MindTheGapps and Magisk belong to their respective authors.
