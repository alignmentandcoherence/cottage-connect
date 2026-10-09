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
7. **Resources** is a free library of recipes, building plans, canning instructions and how-tos, with attachments. Rosa already commented on Sam's raised bed plan, so she's locked until Sam replies.
8. **Invites and review.** Sign out, tap Join with an invite code, enter `HARVEST`, and fill in a profile. The new member waits for review. Sign in as Rosa to approve them (and Maya, who's already waiting) from the Inbox.

## What's in v1
- Barter: spare items in categories (veggies, fruit, meat, dairy, eggs, wood, time + skill), trade flow with ask, accept, decline and counteroffer, and full history.
- Free Resources: recipes, building plans, canning instructions and how-tos anyone can read, with photo or drawing attachments and the same one-comment rule.
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
Photos are from the [USDA Agricultural Research Service Image Gallery](https://www.ars.usda.gov/oc/images/) and [Openverse](https://openverse.org), and are all CC0 or public domain. Each one shows a blurred [BlurHash](https://blurha.sh) placeholder while it loads. Spare items use them, and each free resource gets a cover photo.

- Vegetables: [Fresh beets and leafy greens](https://www.ars.usda.gov/oc/images/photos/featuredphoto/aug20/produce/). Photo by Peggy Greb, USDA-ARS (public domain).
- Fruit: [Baskets of strawberries, blackberries and blueberries](https://www.ars.usda.gov/oc/images/photos/k7229-19). Photo by Scott Bauer, USDA-ARS (public domain).
- Eggs: [Basket of fresh eggs](https://www.flickr.com/photos/136594255@N06/25921784211). Photo by lisafree54 via Flickr (CC0 1.0 (public domain dedication)).
- Dairy: [Cheese board with wedges of cheese](https://www.flickr.com/photos/96218136@N08/51421814670). Photo by richardhe51067 via Flickr (CC0 1.0 (public domain dedication)).
- Meat: [Sheep grazing in a mountain meadow](https://www.ars.usda.gov/oc/images/photos/k5629-2). Photo by Scott Bauer, USDA-ARS (public domain).
- Honey: [Jar of honey with honeycomb](https://www.flickr.com/photos/184594136@N08/51331363379). Photo by Alabama Extension via Flickr (CC0 1.0 (public domain dedication)).
- Bread: [Slices of assorted breads](https://www.ars.usda.gov/oc/images/photos/k7251-46/). Photo by Scott Bauer, USDA-ARS (public domain).
- Herbs: [Peppermint and Corsican mint](https://www.ars.usda.gov/oc/images/photos/k4424-2). Photo by Michael Thompson, USDA-ARS (public domain).
- Seeds: [Dry bean seed varieties spilling from a seed packet](https://www.ars.usda.gov/oc/images/photos/featuredphoto/mar24/drybeans/). Photo by Steve Ausmus, USDA-ARS (public domain).
- Canning: [Jars of home-canned vegetables and preserves](https://www.flickr.com/photos/93936679@N05/51386017045). Photo by Nutrition, Food Safety & Health via Flickr (CC0 1.0 (public domain dedication)).
- Firewood: [Stacked split firewood](https://www.flickr.com/photos/40882383@N03/51881680612). Photo by Forest Service - Northern Region via Flickr (Public Domain Mark 1.0).
- Tools: [Tractor cultivating rows](https://www.ars.usda.gov/oc/images/photos/k5197-3). Photo by Keith Weller, USDA-ARS (public domain).
- Livestock: [Goat browsing in brush](https://www.ars.usda.gov/oc/images/photos/oct99/k8595-9/). Photo by Scott Bauer, USDA-ARS (public domain).
- Bees: [Honey bee on a pink cosmos flower](https://www.ars.usda.gov/oc/images/photos/featuredphoto/jun19/honeybees/). Photo by Peggy Greb, USDA-ARS (public domain).
- Garden: [Gardener walking between raised garden beds](https://www.flickr.com/photos/41284017@N08/52265246749). Photo by USDAgov via Flickr (Public Domain Mark 1.0).

Fallback illustrations are from [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) by Microsoft, MIT license. In the browser version, members can also add their own photo when listing an item.
