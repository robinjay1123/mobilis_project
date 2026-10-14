# Complete Guide: Building Mobilis iOS (.ipa) and Installing via Sideloadly

This guide explains how to generate the **`Mobilis.ipa`** file using GitHub Actions (free cloud Mac) and install it on any iPhone using **Sideloadly** from a Windows PC.

---

## Prerequisites (Windows PC)

1. **Install Sideloadly (Free):**
   - Download from: [https://sideloadly.io/](https://sideloadly.io/) (64-bit Windows).
2. **Install iTunes (Standalone 64-bit installer):**
   - Download direct from Apple: [iTunes 64-bit](https://www.apple.com/itunes/download/win64).
   - *Note:* Do NOT use the Microsoft Store version of iTunes, as it sandboxes USB drivers.
   - Open iTunes once with your iPhone plugged in to ensure Windows detects your device, then you can close it.
   - *(iCloud is NOT required when using a USB cable).*

---

## Part 1: Generate `Mobilis.ipa` in the Cloud (GitHub Actions)

Since compiling iOS apps requires macOS, we use GitHub's free cloud Mac runner:

1. Open your browser and go to your repository:
   👉 **[https://github.com/robinjay1123/mobilis_project/actions](https://github.com/robinjay1123/mobilis_project/actions)**
2. In the left sidebar, click **Build iOS IPA for Sideloadly**.
3. On the right, click **Run workflow** -> select branch `main` -> click the green **Run workflow** button.
4. Wait for the build to finish (takes about **6 to 10 minutes**; it turns green with a checkmark).
5. Click on the completed workflow run.
6. Scroll down to the bottom **Artifacts** section and click **`Mobilis-iOS-IPA`** to download the zip.
7. Unzip the downloaded file on your computer to get:
   ```text
   Mobilis.ipa
   ```

---

## Part 2: Install `Mobilis.ipa` to Your iPhone via Sideloadly

1. **Connect your iPhone** to your Windows PC with your USB lightning or USB-C cable.
2. **Unlock your iPhone screen** and tap **Trust This Computer** (enter your passcode if asked).
3. Open **Sideloadly** on your PC.
4. Verify that your phone name appears under **iDevice** at the top.
5. **Drag and drop** `Mobilis.ipa` onto the large IPA icon on the left of Sideloadly.
6. In the **Apple account** input box, type your personal **Apple ID email address**.
7. Click **Start**.
8. When prompted:
   - Enter your Apple ID password.
   - A 2-Factor Authentication prompt will pop up on your iPhone screen. Tap **Allow**, note the 6-digit code, and enter it into Sideloadly.
9. Wait until the progress bar reaches **100%** and the log says `Done.`.
10. The **Mobilis** app icon is now installed on your iPhone home screen!

---

## Part 3: First-Time iPhone Permissions (Mandatory)

Before opening the app for the first time, iOS requires you to trust your developer profile:

### 1. Trust Developer Profile
1. On your iPhone, open **Settings**.
2. Go to **General** > **VPN & Device Management**.
3. Under *Developer App*, tap your **Apple ID**.
4. Tap **Trust "[your Apple ID]"** and confirm.

### 2. Turn ON Developer Mode (iOS 16, 17, and 18)
1. On your iPhone, go to **Settings** > **Privacy & Security**.
2. Scroll all the way to the bottom and tap **Developer Mode**.
3. Toggle it **ON** and tap **Restart**.
4. After restarting, unlock your phone and tap **Turn On** on the popup.

---

## Part 4: Sharing with a Friend

If your friend has an iPhone:
- **Free Method (Sideloadly):** Send them the `Mobilis.ipa` file. They plug their iPhone into their own computer, open Sideloadly, type *their* Apple ID, and click Start.
- **Instant Web Testing (No PC required):** Have your friend open your hosted web link in **Safari**, tap **Share** > **Add to Home Screen**. It installs immediately and runs fullscreen.
- **TestFlight (For Over-the-Air Link Distribution):** Requires a paid Apple Developer Account ($99/year), which allows up to 10,000 testers to install via the official TestFlight app.

---

## Useful Tips & Troubleshooting

- **7-Day Expiry:** Apps signed with a free personal Apple ID expire after 7 days. When it stops opening, simply connect your phone to PC, open Sideloadly with the same `.ipa`, and click **Start** again. Your app data will NOT be deleted.
- **Anisette Error:** If Sideloadly shows an Anisette or iCloud error, click **Advanced Options** in Sideloadly and set **Anisette Authentication** to **Remote**.
