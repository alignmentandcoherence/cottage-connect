# Cottage Connect (iOS + macOS)

A SwiftUI multiplatform app where cottage skills practitioners and farmers barter, share know-how, and support each other. Strictly barter: no money changes hands.

## Try it in a browser
`web/index.html` is a browser version of the same app with the same demo data. Open it in any browser on a Mac, iPhone, or PC; no install needed. Data is kept in that browser.

## Build and run (native app)
Requires a Mac with Xcode 15 or newer.

```sh
brew install xcodegen
cd cottage-connect-app
xcodegen generate
open CottageConnect.xcodeproj
```

Choose **My Mac** or an iPhone simulator and press Run. To run on your own iPhone, select the CottageConnect target, open Signing & Capabilities, pick your Personal Team (a free Apple ID works), plug in the phone and press Run.

## Demo script
1. **Sign in.** Tap Continue with Apple, Google, or Phone and pick **Rosa** (she's an admin). Sign-in is simulated in this demo.
2. **Inbox** shows a badge. Sam wants Rosa's cheddar: open it, tap **Choose What Seems Fair**, pick from Sam's spare items, add a note and send.
3. **Switch member** (tap your avatar, then Switch member) to Sam. Sam's Inbox shows the ask: Accept, Decline, or **Propose Something New**.
4. **Barter** lists everyone's spare items with approximate distance. Open one and tap **Start a Trade**.
5. **People** has a List/Map toggle and a radius slider. Profiles show limited info (state, distance, products, spare items) until both people request to connect. Eli has asked to connect with Rosa: tap **Connect Back** in the Inbox, then Message.
6. **Community**: Rosa already commented on Eli's cider press post, so she's locked until Eli replies to her. Switch to Eli, tap Reply on her comment, then switch back.
7. **Learn** holds how-to guides. Tap Share Know-How to add one.
8. **Invites and review.** Sign out, tap Join with an invite code, enter `HARVEST`, and fill in a profile. The new member waits for review. Sign in as Rosa to approve them (and Maya, who's already waiting) from the Inbox.

## What's in v1
- Barter: spare items in categories (veggies, fruit, meat, dairy, eggs, wood, time + skill), trade flow with ask, accept, decline and counteroffer, and full history.
- Learn: information sharing through member-written guides.
- Community board: one comment per post per member until the poster replies to them.
- Connections: both members must request to connect before full profiles and direct messages unlock.
- Map with approximate locations (snapped to a ~3 mile grid) and an adjustable radius.
- Invite-only membership with admin review. Invite codes can be shared from your profile.
- Coming soon placeholders: Events & Workshops, Tool Library.

## Not yet
Data lives on the device (SwiftData), so it's one shared demo community per device. Next up:
- Real sign-in (Sign in with Apple, Google, phone OTP) and a shared backend so members on different devices see each other. Firebase or Supabase recommended, since an Android app is planned for v2.
- Push notifications for trades and connection requests.
- Reporting posts and members (basic moderation).
- An AI reviewer agent to assist admins with membership review.

## Credits
Item pictures are from [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) by Microsoft, MIT license. In the browser version, members can also add their own photo when listing an item.
