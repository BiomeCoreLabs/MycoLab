# App Store Connect • App Privacy Questionnaire Cheatsheet
**App:** MycoLabs  
**Bundle ID:** `com.mycolab.app`  

---

## Purpose of this Cheatsheet
In App Store Connect, completing the **App Privacy** questionnaire is required before submitting your app for App Store Review. Selecting incorrect options (such as accidentally declaring "Tracking") can cause rejection or require unnecessary App Tracking Transparency (ATT) dialogs.

Use this guide to complete the Apple Privacy Questionnaire accurately in 2 minutes.

---

## Question 1: Do you or your third-party partners collect data from this app?

👉 **Select:** **YES**  
*(Accounts for optional, privacy-preserving local diagnostics).*

---

## Question 2: Select the data types you collect

Apple presents a categorized list of data types.

👉 **Select ONLY:**
* 📁 **Diagnostics**
  * ✅ **Crash Data**
  * ✅ **Performance Data**
* ❌ *Leave all other categories (Contact Info, Location, Photos/Videos, Browsing History, User IDs) UNCHECKED.*

> [!NOTE]
> **Why Photos/Videos is unchecked**: Chamber images and video streams remain 100% local on the user's device. Under Apple guidelines, on-device local processing does **not** constitute developer data collection.

---

## Question 3: How is Diagnostic Data used?
*For both Crash Data and Performance Data, answer the following:*

### 1. Purpose
* 👉 Check: **App Functionality**
* 👉 Check: **Analytics**
* ❌ Do not check Advertising or Third-Party Marketing.

### 2. Are these data linked to the user's identity?
* 👉 **Select:** **NO**  
*(All crash diagnostics are completely anonymized and contain no user identity or Apple ID).*

### 3. Are these data used for tracking?
* 👉 **Select:** **NO**  
*(Zero integration with advertising trackers or third-party brokers).*

---

## Question 4: Privacy Policy URL
* 👉 Enter: `https://biomecorelabs.github.io/MycoLabs/privacy_policy.html`
