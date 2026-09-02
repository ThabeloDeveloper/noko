# Noko Apps

This workspace contains three Flutter apps that share one Firebase backend:

- `nokofastfood`: customer ordering app
- `noko_admin`: admin stock and restaurant status app
- `noko_driver`: driver delivery scanner app

## Required Firebase Setup

1. Deploy Firestore rules from `nokofastfood/firestore.rules`.
2. Deploy Storage rules from `nokofastfood/storage.rules`.
3. Deploy Cloud Functions from `nokofastfood/functions`.
4. Create user documents in Firestore under `users/{uid}` with one of these roles:
   - `customer`
   - `admin`
   - `driver`
5. Register separate Android apps in Firebase for:
   - `com.mecaroid.nokofastfood`
   - `com.mecaroid.noko_admin`
   - `com.mecaroid.noko_driver`
6. Replace each app's `android/app/google-services.json` with the file generated for that package.

## Admin App

The `noko_admin` app now includes:

- restaurant add, edit, delete, open/closed controls, search, and image upload
- menu item add, edit, delete, availability controls, image upload, restaurant filters, category filters, and search
- order dashboard with status, payment status, and driver assignment controls
- customer/user management with search, role updates, password reset, and account deletion
- driver management and driver onboarding
- sales, revenue, order status, and menu category analytics
- notification broadcasts through the `sendAdminNotification` callable function
- admin registration/account creation through the `createManagedUser` callable function

Deploy the updated Cloud Functions before using account creation, role updates,
account deletion, or notification broadcasts from the admin app.

## Customer App

The `nokofastfood` app now includes:

- multiple restaurant browsing with live restaurant images and open/closed state
- live menu categories from Firestore products
- menu search, category filtering, and availability filtering
- saved delivery addresses
- customer profile editing
- password reset from sign-in and account settings
- Facebook sign-in wiring
- restaurant-specific inbox and chat
- cash on delivery and Peach Payments checkout
- customer order cancellation for pending/preparing orders
- delivery progress and ETA display
- favourites and reorder
- product ratings and reviews
- promo code support through `promoCodes`

## Delivery Verification

Customer order QR codes now contain an `orderId` and `verificationCode`. The driver app sends that payload to the callable Cloud Function `settleOrderDelivery`, which verifies:

- the driver is signed in
- the signed-in user has `role: driver`
- the QR verification code matches the order
- the order is not cancelled or already delivered

## Payments

The previous fake payment flow was removed. Orders can use cash on delivery or
Peach Payments:

- `paymentMethod: cash_on_delivery`
- `paymentStatus: pending`
- `paymentMethod: peach_payments`
- `paymentStatus: paid` only after backend verification succeeds

Peach Payments credentials must be configured on Cloud Functions, not in the
Flutter app. Set:

- `peach.entity_id`
- `peach.client_id`
- `peach.client_secret`
- `peach.merchant_id`
- optional `peach.auth_url`, `peach.checkout_url`, `peach.checkout_script_url`,
  `peach.result_url`, `peach.webhook_url`, `peach.currency`, `peach.referer`
