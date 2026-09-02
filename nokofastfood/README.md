# nokofastfood

Customer Flutter app for Noko fast food ordering.

## Authentication

Email/password, Google, Facebook, and Apple authentication are wired through
Firebase Auth. Apple sign-in is available on both the sign-in and registration
screens. Enable the Apple provider in Firebase Auth and configure the iOS
bundle identifier, Android redirect/service details, and Apple developer keys
before release.

Facebook and Apple still need real production provider values in Firebase and
the native app configuration. The current Android Facebook strings are
placeholders until your Facebook app ID/client token are supplied.

## Peach Payments

Payment secrets stay in Firebase Functions. The app currently supports the
official Peach embedded Flutter checkout flow through a hosted Functions page,
plus Functions callables for the Peach mobile SDK prepare/status flow:

- `createPeachCheckout`
- `verifyPeachPayment`
- `preparePeachMobileCheckout`
- `verifyPeachMobilePayment`

Required Functions config:

```bash
firebase functions:config:set \
  peach.entity_id="..." \
  peach.client_id="..." \
  peach.client_secret="..." \
  peach.merchant_id="..." \
  peach.mobile_token="..." \
  peach.currency="ZAR"
```

Optional config:

```bash
firebase functions:config:set \
  peach.mobile_base_url="https://sandbox-card.peachpayments.com" \
  peach.auth_url="https://sandbox-dashboard.peachpayments.com" \
  peach.checkout_url="https://testsecure.peachpayments.com" \
  peach.checkout_script_url="https://sandbox-checkout.peachpayments.com/js/checkout.js" \
  peach.referer="https://your-domain.example"
```

The public Peach Flutter packages currently available on pub.dev do not expose a
usable modern checkout API. Peach's current Flutter documentation uses Embedded
Checkout in a WebView and requires the backend to serve the checkout page over
HTTPS, so the app keeps that working path while the server-side mobile SDK
handlers remain ready for a real native SDK package.

## Delivery and Chat Setup

Restaurant documents should include `latitude` and `longitude`, or a Firestore
`geoPoint`/`locationPoint`, for accurate map tracking. Driver apps can update
orders with `driverLatitude`/`driverLongitude` or `driverLocation` for live
customer tracking.

Deploy both `firestore.rules` and `storage.rules`. Chat image attachments are
stored under `chat_attachments/{uid}/...`.

## Manual Refunds

Customer cancellation of a paid Peach order creates a
`manualRefundRequests/{orderId}` document. The restaurant/admin must manually
send the money back and close that request; the app does not automatically void
or refund the Peach transaction.
