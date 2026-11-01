# pl8(math) — App Store Connect answers

What to type in App Store Connect, from `DATA-AND-SERVICES.md` §5 and how the app is built today.

## App information
- **Name:** pl8(math)
- **Bundle ID:** com.williansertorio.pl8
- **Category:** Health & Fitness
- **Privacy Policy URL:** https://willsertorio.github.io/pl8-math/privacy.html
- **Price:** Free. No in-app purchases.
- **Devices:** iPhone only.

## App Privacy (the "nutrition label")

**Do you or your third-party partners collect data from this app?** Yes.

| Data type | Collected | Linked to the user | Used for tracking | Purposes |
|---|---|---|---|---|
| Usage Data → Product Interaction | Yes | No | No | Analytics |
| Diagnostics → Crash Data | Yes | No | No | App Functionality, Analytics |
| Diagnostics → Performance Data | Yes | No | No | App Functionality, Analytics |
| User Content → Photos or Videos | Yes* | No | No | App Functionality |
| User Content → Other User Content | Yes* | No | No | App Functionality |

Everything else (Contact Info, Health & Fitness, Location, Identifiers, Purchases, Financial Info, Contacts, Browsing
and Search History, Sensitive Info, Other Data): **Not collected.**

\* Only once the read server is live (`PL8ReadServer` set in `Info.plist`). If you release without it, answer **No**
for both User Content rows, and change them when the cloud reading goes on.

Why the answers are what they are:
- **Not linked:** no accounts, no sign-in; analytics use a random id made by the app.
- **No tracking:** no ads, no data shared with data brokers, nothing combined with other companies' data.
- **Workouts and PRs aren't "collected":** they stay on the phone and in the user's own iCloud, which we can't read.
- **Photos:** sent only when the phone can't read one, only after the user says yes, never kept.

## Other questions
- **Encryption (export compliance):** No, the app uses no non-exempt encryption (`ITSAppUsesNonExemptEncryption = NO`
  is already set, so App Store Connect won't ask on every build).
- **Age rating:** answer "None" to every content question; the result is 4+.
- **Sign-in required for review:** No.
- **Review notes** (suggested): "pl8(math) turns a CrossFit workout screenshot into the plates to load on the bar.
  Tap the title to start. Upload any workout screenshot from Photos on the whiteboard step; a photo the phone can't
  read shows question marks. No account is needed."
