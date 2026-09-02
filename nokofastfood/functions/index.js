const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, GeoPoint } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const crypto = require('crypto');
initializeApp();

const firestore = getFirestore;
firestore.FieldValue = FieldValue;
firestore.GeoPoint = GeoPoint;

const admin = {
    auth: getAuth,
    firestore,
    messaging: getMessaging,
};

async function requireAdmin(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Admin sign in is required.'
        );
    }

    const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();

    if (!userDoc.exists || userDoc.data().role !== 'admin') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only admins can perform this action.'
        );
    }
}

async function requireDriver(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Driver sign in is required.'
        );
    }

    const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(context.auth.uid)
        .get();

    if (!userDoc.exists || userDoc.data().role !== 'driver') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only approved drivers can perform this action.'
        );
    }

    return userDoc.data();
}

function requireString(value, label) {
    if (typeof value !== 'string' || !value.trim()) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            `${label} is required.`
        );
    }
    return value.trim();
}

function requireCoordinate(value, label, min, max) {
    if (typeof value !== 'number' || Number.isNaN(value) || value < min || value > max) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            `${label} must be a valid coordinate.`
        );
    }
    return value;
}

function managedUserAuthError(error) {
    const code = error?.code || '';
    const message = error?.message || '';
    if (code === 'auth/email-already-exists') {
        return new functions.https.HttpsError(
            'already-exists',
            'An account with this email already exists.'
        );
    }
    if (code === 'auth/invalid-email') {
        return new functions.https.HttpsError(
            'invalid-argument',
            'Enter a valid email address.'
        );
    }
    if (code === 'auth/invalid-password') {
        return new functions.https.HttpsError(
            'invalid-argument',
            'Temporary password must be at least 6 characters.'
        );
    }
    if (code === 'auth/invalid-phone-number') {
        return new functions.https.HttpsError(
            'invalid-argument',
            'Phone number must include the country code, for example +27796137743.'
        );
    }
    if (code === 'auth/phone-number-already-exists') {
        return new functions.https.HttpsError(
            'already-exists',
            'An account with this phone number already exists.'
        );
    }
    console.error('createManagedUser auth error', { code, message });
    return new functions.https.HttpsError(
        'internal',
        'Account could not be created right now. Please try again.'
    );
}

function routingConfig() {
    const routing = functions.config().routing || {};
    return {
        osrmBaseUrl: (routing.osrm_url || 'https://router.project-osrm.org')
            .replace(/\/+$/, ''),
    };
}

function simplifyRouteCoordinates(coordinates) {
    if (!Array.isArray(coordinates)) {
        return [];
    }
    const maxPoints = 80;
    const step = Math.max(1, Math.ceil(coordinates.length / maxPoints));
    return coordinates
        .filter((_, index) => index % step === 0 || index === coordinates.length - 1)
        .map((point) => ({
            latitude: point[1],
            longitude: point[0],
        }))
        .filter(
            (point) =>
                typeof point.latitude === 'number' &&
                typeof point.longitude === 'number'
        );
}

function degreesToRadians(value) {
    return (value * Math.PI) / 180;
}

function directDistanceMeters(origin, destination) {
    const earthRadiusMeters = 6371000;
    const lat1 = degreesToRadians(origin.latitude);
    const lat2 = degreesToRadians(destination.latitude);
    const deltaLat = degreesToRadians(destination.latitude - origin.latitude);
    const deltaLng = degreesToRadians(destination.longitude - origin.longitude);
    const a =
        Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
        Math.cos(lat1) *
        Math.cos(lat2) *
        Math.sin(deltaLng / 2) *
        Math.sin(deltaLng / 2);
    return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function estimatedRoadRouteBetween(origin, destination) {
    const distanceMeters = Math.round(directDistanceMeters(origin, destination) * 1.3);
    return {
        distanceMeters,
        durationSeconds: Math.max(300, Math.round(distanceMeters / 8.3)),
        provider: 'estimated_road',
        routePolyline: [
            { latitude: origin.latitude, longitude: origin.longitude },
            { latitude: destination.latitude, longitude: destination.longitude },
        ],
    };
}

async function roadRouteBetween(origin, destination) {
    const config = routingConfig();
    const coordinates =
        `${origin.longitude},${origin.latitude};` +
        `${destination.longitude},${destination.latitude}`;
    const url =
        `${config.osrmBaseUrl}/route/v1/driving/${coordinates}` +
        '?overview=simplified&geometries=geojson&steps=false&alternatives=false';
    const response = await fetch(url, {
        headers: {
            'accept': 'application/json',
            'user-agent': 'noko-delivery-functions/1.0',
        },
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok || body.code !== 'Ok' || !body.routes?.length) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            body.message || 'No road route could be calculated for this address.'
        );
    }
    const route = body.routes[0];
    const waypoints = body.waypoints || [];
    return {
        distanceMeters: Math.round(route.distance || 0),
        durationSeconds: Math.round(route.duration || 0),
        provider: 'osrm',
        snappedOrigin:
            waypoints[0]?.location?.length === 2
                ? {
                    latitude: waypoints[0].location[1],
                    longitude: waypoints[0].location[0],
                    roadName: waypoints[0].name || '',
                }
                : null,
        snappedDestination:
            waypoints[1]?.location?.length === 2
                ? {
                    latitude: waypoints[1].location[1],
                    longitude: waypoints[1].location[0],
                    roadName: waypoints[1].name || '',
                }
                : null,
        routePolyline: simplifyRouteCoordinates(route.geometry?.coordinates),
    };
}

function peachConfig() {
    const peach = functions.config().peach || {};
    const entityId = peach.entity_id;
    const clientId = peach.client_id;
    const clientSecret = peach.client_secret;
    const merchantId = peach.merchant_id;
    const authBaseUrl = peach.auth_url || 'https://sandbox-dashboard.peachpayments.com';
    const checkoutBaseUrl = peach.checkout_url || 'https://testsecure.peachpayments.com';
    const checkoutScriptUrl = peach.checkout_script_url ||
        'https://sandbox-checkout.peachpayments.com/js/checkout.js';
    const currency = peach.currency || 'ZAR';
    const referer = peach.referer || `https://${process.env.GCLOUD_PROJECT}.web.app`;

    if (!entityId || !clientId || !clientSecret || !merchantId) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'Peach Payments credentials are not configured.'
        );
    }

    return {
        entityId,
        clientId,
        clientSecret,
        merchantId,
        authBaseUrl,
        checkoutBaseUrl,
        checkoutScriptUrl,
        currency,
        referer,
    };
}

function publicFunctionUrl(name) {
    const region = process.env.FUNCTION_REGION || 'us-central1';
    return `https://${region}-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/${name}`;
}

function merchantTransactionId(orderId) {
    const cleanId = String(orderId).replace(/[^a-zA-Z0-9]/g, '');
    const suffix = cleanId.slice(0, 10).padEnd(10, '0');
    return `NK${suffix}`.slice(0, 16);
}

function isSuccessfulPeachResult(code) {
    if (typeof code !== 'string') {
        return false;
    }
    return /^(000\.000\.|000\.100\.1|000\.[36]|000\.400\.[1][12]0)/.test(code);
}

async function peachAccessToken(config) {
    let response;
    try {
        response = await fetch(`${config.authBaseUrl}/api/oauth/token`, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({
                clientId: config.clientId,
                clientSecret: config.clientSecret,
                merchantId: config.merchantId,
            }),
        });
    } catch (error) {
        console.error('Peach auth request failed', error);
        throw new functions.https.HttpsError(
            'unavailable',
            'Online payment is not available right now. Please choose cash and try again.'
        );
    }
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
        throw new functions.https.HttpsError(
            'internal',
            `Peach auth failed: ${body.message || response.statusText}`
        );
    }
    const token = body.access_token || body.accessToken || body.token;
    if (!token) {
        throw new functions.https.HttpsError(
            'internal',
            'Peach auth response did not include an access token.'
        );
    }
    return token;
}

function rethrowPeachCallableError(error, message) {
    console.error(message, error);
    if (error instanceof functions.https.HttpsError) {
        throw error;
    }
    throw new functions.https.HttpsError('unavailable', message);
}

function peachMobileConfig() {
    const peach = functions.config().peach || {};
    const entityId = peach.mobile_entity_id || peach.entity_id;
    const accessToken = peach.mobile_token || peach.access_token;
    const mobileBaseUrl = peach.mobile_base_url || 'https://sandbox-card.peachpayments.com';
    const currency = peach.currency || 'ZAR';

    if (!entityId || !accessToken) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'Peach mobile SDK credentials are not configured.'
        );
    }

    return {
        entityId,
        accessToken,
        mobileBaseUrl: mobileBaseUrl.replace(/\/+$/, ''),
        currency,
    };
}

function normalizePeachResourcePath(resourcePath) {
    const value = requireString(resourcePath, 'Resource path');
    if (!value.startsWith('/v1/') || value.includes('://')) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Invalid Peach resource path.'
        );
    }
    return value;
}

async function requirePayableOrder(orderId, context) {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Sign in is required before paying.'
        );
    }

    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found.');
    }

    const order = orderDoc.data();
    if (order.customerId !== context.auth.uid) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'You can only pay for your own order.'
        );
    }
    if (order.paymentMethod !== 'peach_payments') {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'This order is not configured for Peach Payments.'
        );
    }

    return { db, orderRef, order };
}

/**
 * Notifies the restaurant when a new order is created.
 * Triggers on onCreate of /orders/{orderId}
 */
exports.notifyRestaurantOnOrderCreate = functions.firestore
    .document('orders/{orderId}')
    .onCreate(async (snapshot, context) => {
        const orderData = snapshot.data();
        const restaurantId = orderData.restaurantId;
        const orderNumber = orderData.orderNumber;

        // Message payload for the restaurant topic
        const message = {
            notification: {
                title: 'New Order Received!',
                body: `Order #${orderNumber} has been placed.`,
            },
            data: {
                orderId: context.params.orderId,
                type: 'NEW_ORDER',
            },
            topic: `restaurant_${restaurantId}`,
        };

        try {
            const response = await admin.messaging().send(message);
            console.log('Successfully sent message to restaurant:', response);
            return response;
        } catch (error) {
            console.error('Error sending message to restaurant:', error);
            return null;
        }
    });

/**
 * Notifies the customer when their order status changes.
 * Triggers on onUpdate of /orders/{orderId}
 */
exports.notifyCustomerOnOrderStatusChange = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
        const beforeData = change.before.data();
        const afterData = change.after.data();

        // Only trigger if status has changed
        if (beforeData.status === afterData.status) {
            return null;
        }

        const customerId = afterData.customerId;
        const newStatus = afterData.status;
        const orderNumber = afterData.orderNumber;

        let statusBody = '';
        switch (newStatus) {
            case 'preparing':
                statusBody = `Your order #${orderNumber} is now being prepared!`;
                break;
            case 'out_for_delivery':
                statusBody = `Your order #${orderNumber} is on its way!`;
                break;
            case 'delivered':
                statusBody = `Your order #${orderNumber} has been delivered. Enjoy!`;
                break;
            case 'cancelled':
                statusBody = `Your order #${orderNumber} has been cancelled.`;
                break;
            default:
                console.log('No notification defined for status:', newStatus);
                return null;
        }

        // Fetch customer FCM token from Firestore
        // Assuming the token is stored in the user's document
        try {
            const userDoc = await admin.firestore().collection('users').doc(customerId).get();

            if (!userDoc.exists) {
                console.error('Customer document not found:', customerId);
                return null;
            }

            const fcmToken = userDoc.data().fcmToken;

            if (!fcmToken) {
                console.warn('No FCM token found for customer:', customerId);
                return null;
            }

            const message = {
                notification: {
                    title: 'Order Update',
                    body: statusBody,
                },
                data: {
                    orderId: context.params.orderId,
                    type: 'ORDER_STATUS_UPDATE',
                    status: newStatus,
                },
                token: fcmToken,
            };

            const response = await admin.messaging().send(message);
            console.log('Successfully sent message to customer:', response);
            return response;
        } catch (error) {
            console.error('Error processing notification:', error);
            return null;
        }
    });

exports.settleOrderDelivery = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Driver sign in is required.'
        );
    }

    const driverId = context.auth.uid;
    const { orderId, verificationCode, driverId: requestedDriverId } = data || {};

    if (!orderId || !verificationCode) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Order ID and verification code are required.'
        );
    }
    if (requestedDriverId && requestedDriverId !== driverId) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Driver identity mismatch.'
        );
    }

    const db = admin.firestore();
    const driverDoc = await db.collection('users').doc(driverId).get();

    if (!driverDoc.exists || driverDoc.data().role !== 'driver') {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only approved drivers can settle deliveries.'
        );
    }

    const orderRef = db.collection('orders').doc(orderId);

    await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Order not found.');
        }

        const order = orderDoc.data();
        if (order.verificationCode !== verificationCode) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'Order verification failed.'
            );
        }
        if (order.status === 'delivered') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Order is already delivered.'
            );
        }
        if (order.status === 'cancelled') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Cancelled orders cannot be delivered.'
            );
        }
        if (order.fulfillmentType === 'collection') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Collection orders do not require driver delivery.'
            );
        }

        transaction.update(orderRef, {
            status: 'delivered',
            paymentStatus: order.paymentStatus === 'paid' ? 'paid' : 'completed',
            driverId,
            deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(db.collection('users').doc(driverId), {
            driverStatus: 'available',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });

    return { success: true };
});

exports.acceptDriverOrder = functions.https.onCall(async (data, context) => {
    await requireDriver(context);
    const driverId = context.auth.uid;
    const orderId = requireString(data?.orderId, 'Order ID');
    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);

    await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Order not found.');
        }

        const order = orderDoc.data();
        if (order.driverId && order.driverId !== driverId) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'This order has already been assigned.'
            );
        }
        if (!['pending', 'preparing'].includes(order.status)) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Only pending or preparing orders can be accepted.'
            );
        }
        if (order.fulfillmentType === 'collection') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Collection orders cannot be accepted by drivers.'
            );
        }

        transaction.update(orderRef, {
            driverId,
            status: order.status === 'pending' ? 'preparing' : order.status,
            driverAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(db.collection('users').doc(driverId), {
            driverStatus: 'on_delivery',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });

    return { success: true };
});

exports.updateDriverOrderStatus = functions.https.onCall(async (data, context) => {
    await requireDriver(context);
    const driverId = context.auth.uid;
    const orderId = requireString(data?.orderId, 'Order ID');
    const status = requireString(data?.status, 'Status');
    const allowed = ['out_for_delivery', 'delivered'];
    if (!allowed.includes(status)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Unsupported driver status update.'
        );
    }

    const orderRef = admin.firestore().collection('orders').doc(orderId);
    await admin.firestore().runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Order not found.');
        }
        const order = orderDoc.data();
        if (order.driverId !== driverId) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'This order is not assigned to you.'
            );
        }
        if (order.status === 'cancelled' || order.status === 'delivered') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'This order can no longer be updated.'
            );
        }
        if (order.fulfillmentType === 'collection') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Collection orders do not have delivery status updates.'
            );
        }
        const update = {
            status,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (status === 'out_for_delivery') {
            update.pickedUpAt = admin.firestore.FieldValue.serverTimestamp();
        }
        if (status === 'delivered') {
            if (order.status !== 'out_for_delivery') {
                throw new functions.https.HttpsError(
                    'failed-precondition',
                    'Only orders that are out for delivery can be marked delivered.'
                );
            }
            update.deliveredAt = admin.firestore.FieldValue.serverTimestamp();
            update.paymentStatus =
                order.paymentStatus === 'paid' ? 'paid' : 'completed';
            transaction.set(admin.firestore().collection('users').doc(driverId), {
                driverStatus: 'available',
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        transaction.update(orderRef, update);
    });

    return { success: true };
});

exports.updateDriverLocation = functions.https.onCall(async (data, context) => {
    await requireDriver(context);
    const driverId = context.auth.uid;
    const orderId = requireString(data?.orderId, 'Order ID');
    const latitude = Number(data?.latitude);
    const longitude = Number(data?.longitude);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Latitude and longitude are required.'
        );
    }

    const orderRef = admin.firestore().collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found.');
    }
    const order = orderDoc.data();
    if (order.driverId !== driverId) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'This order is not assigned to you.'
        );
    }
    if (order.fulfillmentType === 'collection') {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'Collection orders do not share driver locations.'
        );
    }
    if (['delivered', 'cancelled', 'failed_delivery'].includes(order.status)) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'Live location is closed for this order.'
        );
    }

    await orderRef.set({
        driverLatitude: latitude,
        driverLongitude: longitude,
        driverLocation: new admin.firestore.GeoPoint(latitude, longitude),
        driverLocationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { success: true };
});

exports.failDriverDelivery = functions.https.onCall(async (data, context) => {
    await requireDriver(context);
    const driverId = context.auth.uid;
    const orderId = requireString(data?.orderId, 'Order ID');
    const reason = requireString(data?.reason, 'Reason');
    const orderRef = admin.firestore().collection('orders').doc(orderId);

    await admin.firestore().runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Order not found.');
        }
        const order = orderDoc.data();
        if (order.driverId !== driverId) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'This order is not assigned to you.'
            );
        }
        if (order.fulfillmentType === 'collection') {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Collection orders cannot be marked as failed delivery.'
            );
        }
        if (['delivered', 'cancelled'].includes(order.status)) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'This order can no longer be failed.'
            );
        }
        transaction.update(orderRef, {
            status: 'failed_delivery',
            failedDeliveryReason: reason,
            failedDeliveryAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(admin.firestore().collection('users').doc(driverId), {
            driverStatus: 'available',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });

    return { success: true };
});

exports.createManagedUser = functions.https.onCall(async (data, context) => {
    await requireAdmin(context);

    const email = requireString(data?.email, 'Email').toLowerCase();
    const password = requireString(data?.password, 'Password');
    const name = requireString(data?.name, 'Name');
    const role = requireString(data?.role, 'Role');
    const phone = typeof data?.phone === 'string' ? data.phone.trim() : '';
    const allowedRoles = ['admin', 'driver', 'customer'];

    if (!allowedRoles.includes(role)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Role must be admin, driver, or customer.'
        );
    }

    if (password.length < 6) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Temporary password must be at least 6 characters.'
        );
    }
    const phoneNumber = phone.startsWith('+') ? phone : undefined;

    let managedUser;
    let createdNewUser = false;
    const authPayload = {
        email,
        password,
        displayName: name,
    };
    if (phoneNumber) {
        authPayload.phoneNumber = phoneNumber;
    }
    try {
        managedUser = await admin.auth().createUser(authPayload);
        createdNewUser = true;
    } catch (error) {
        throw managedUserAuthError(error);
    }

    try {
        await admin.auth().setCustomUserClaims(managedUser.uid, { role });
        const profile = {
            name,
            phone,
            email,
            role,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (createdNewUser) {
            profile.createdAt = admin.firestore.FieldValue.serverTimestamp();
        }
        await admin.firestore().collection('users').doc(managedUser.uid).set(
            profile,
            { merge: true }
        );

        return { uid: managedUser.uid, created: createdNewUser };
    } catch (error) {
        console.error('createManagedUser profile save failed', error);
        if (createdNewUser) {
            await admin.auth().deleteUser(managedUser.uid).catch((deleteError) => {
                console.error('createManagedUser rollback failed', deleteError);
            });
        }
        throw new functions.https.HttpsError(
            'internal',
            'Account profile could not be saved. Please try again.'
        );
    }
});

exports.setManagedUserRole = functions.https.onCall(async (data, context) => {
    await requireAdmin(context);

    const uid = requireString(data?.uid, 'User ID');
    const role = requireString(data?.role, 'Role');
    const allowedRoles = ['admin', 'driver', 'customer'];

    if (!allowedRoles.includes(role)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Role must be admin, driver, or customer.'
        );
    }

    await admin.auth().setCustomUserClaims(uid, { role });
    await admin.firestore().collection('users').doc(uid).set({
        role,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { success: true };
});

exports.deleteManagedUser = functions.https.onCall(async (data, context) => {
    await requireAdmin(context);

    const uid = requireString(data?.uid, 'User ID');
    if (uid === context.auth.uid) {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'Admins cannot delete their own account.'
        );
    }

    await admin.auth().deleteUser(uid);
    await admin.firestore().collection('users').doc(uid).delete();

    return { success: true };
});

exports.sendAdminNotification = functions.https.onCall(async (data, context) => {
    await requireAdmin(context);

    const title = requireString(data?.title, 'Title');
    const body = requireString(data?.body, 'Message');
    const targetRole = typeof data?.targetRole === 'string'
        ? data.targetRole.trim()
        : 'all';
    const allowedTargets = ['all', 'customer', 'driver', 'admin'];

    if (!allowedTargets.includes(targetRole)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Target must be all, customer, driver, or admin.'
        );
    }

    let query = admin.firestore().collection('users');
    if (targetRole !== 'all') {
        query = query.where('role', '==', targetRole);
    }

    const usersSnapshot = await query.get();
    const tokenUsers = usersSnapshot.docs
        .map((doc) => ({
            uid: doc.id,
            token: doc.data().fcmToken,
        }))
        .filter((item) => typeof item.token === 'string' && item.token.trim())
        .map((item) => ({ ...item, token: item.token.trim() }));

    let successCount = 0;
    let failureCount = 0;

    for (let index = 0; index < tokenUsers.length; index += 500) {
        const batch = tokenUsers.slice(index, index + 500);
        const response = await admin.messaging().sendEachForMulticast({
            notification: { title, body },
            data: {
                type: 'ADMIN_BROADCAST',
                targetRole,
            },
            tokens: batch.map((item) => item.token),
        });
        successCount += response.successCount;
        failureCount += response.failureCount;

        const cleanupWrites = response.responses
            .map((result, resultIndex) => ({ result, user: batch[resultIndex] }))
            .filter(({ result }) =>
                !result.success &&
                [
                    'messaging/invalid-registration-token',
                    'messaging/registration-token-not-registered',
                    'messaging/invalid-argument',
                ].includes(result.error?.code)
            )
            .map(({ user }) =>
                admin.firestore().collection('users').doc(user.uid).set({
                    fcmToken: admin.firestore.FieldValue.delete(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true })
            );

        await Promise.all(cleanupWrites);
    }

    const campaignRef = await admin
        .firestore()
        .collection('notificationCampaigns')
        .add({
            title,
            body,
            targetRole,
            tokenCount: tokenUsers.length,
            successCount,
            failureCount,
            createdBy: context.auth.uid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    return {
        id: campaignRef.id,
        tokenCount: tokenUsers.length,
        successCount,
        failureCount,
    };
});

exports.cancelCustomerOrder = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Sign in is required before cancelling an order.'
        );
    }

    const orderId = requireString(data?.orderId, 'Order ID');
    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);

    let manualRefundRequired = false;
    await db.runTransaction(async (transaction) => {
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Order not found.');
        }

        const order = orderDoc.data();
        if (order.customerId !== context.auth.uid) {
            throw new functions.https.HttpsError(
                'permission-denied',
                'You can only cancel your own order.'
            );
        }
        if (!['pending', 'preparing'].includes(order.status)) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Only pending or preparing orders can be cancelled.'
            );
        }

        manualRefundRequired =
            order.paymentMethod === 'peach_payments' && order.paymentStatus === 'paid';
        transaction.update(orderRef, {
            status: 'cancelled',
            manualRefundRequired,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (manualRefundRequired) {
            const refundRef = db.collection('manualRefundRequests').doc(orderId);
            transaction.set(refundRef, {
                orderId,
                customerId: order.customerId,
                restaurantId: order.restaurantId,
                amount: order.total || 0,
                paymentMethod: order.paymentMethod,
                peachCheckoutId: order.peachCheckoutId || '',
                status: 'restaurant_action_required',
                note: 'Customer cancelled a paid Peach order. Restaurant must manually send back the money.',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
    });

    return { success: true, manualRefundRequired };
});

exports.calculateDeliveryRoute = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Sign in is required before calculating a delivery route.'
        );
    }

    const origin = {
        latitude: requireCoordinate(data?.originLatitude, 'Restaurant latitude', -90, 90),
        longitude: requireCoordinate(data?.originLongitude, 'Restaurant longitude', -180, 180),
    };
    const destination = {
        latitude: requireCoordinate(data?.destinationLatitude, 'Customer latitude', -90, 90),
        longitude: requireCoordinate(data?.destinationLongitude, 'Customer longitude', -180, 180),
    };

    try {
        return await roadRouteBetween(origin, destination);
    } catch (error) {
        console.error('calculateDeliveryRoute road routing failed', error);
        return estimatedRoadRouteBetween(origin, destination);
    }
});

exports.preparePeachMobileCheckout = functions.https.onCall(async (data, context) => {
    const orderId = requireString(data?.orderId, 'Order ID');
    const { db, orderRef, order } = await requirePayableOrder(orderId, context);
    const config = peachMobileConfig();
    const customerDoc = await db.collection('users').doc(context.auth.uid).get();
    const customer = customerDoc.exists ? customerDoc.data() : {};
    const form = new URLSearchParams({
        entityId: config.entityId,
        amount: Number(order.total || 0).toFixed(2),
        currency: config.currency,
        paymentType: 'DB',
        merchantTransactionId: merchantTransactionId(orderId),
        'customParameters[orderId]': orderId,
        'customParameters[customerId]': context.auth.uid,
    });

    if (customer.email || context.auth.token.email) {
        form.set('customer.email', customer.email || context.auth.token.email);
    }

    const checkoutResponse = await fetch(`${config.mobileBaseUrl}/v1/checkouts`, {
        method: 'POST',
        headers: {
            authorization: `Bearer ${config.accessToken}`,
            'content-type': 'application/x-www-form-urlencoded',
        },
        body: form.toString(),
    });

    const checkout = await checkoutResponse.json().catch(() => ({}));
    if (!checkoutResponse.ok) {
        throw new functions.https.HttpsError(
            'internal',
            `Peach mobile checkout failed: ${checkout.message || checkoutResponse.statusText}`
        );
    }

    const checkoutId = checkout.id || checkout.checkoutId;
    if (!checkoutId) {
        throw new functions.https.HttpsError(
            'internal',
            'Peach mobile checkout response did not include a checkout ID.'
        );
    }

    await orderRef.update({
        peachCheckoutId: checkoutId,
        peachMobileCheckoutId: checkoutId,
        paymentStatus: 'pending',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
        checkoutId,
        entityId: config.entityId,
        amount: Number(order.total || 0).toFixed(2),
        currency: config.currency,
    };
});

exports.verifyPeachMobilePayment = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Sign in is required before verifying payment.'
        );
    }

    const orderId = requireString(data?.orderId, 'Order ID');
    const resourcePath = normalizePeachResourcePath(data?.resourcePath);
    const checkoutId = typeof data?.checkoutId === 'string'
        ? data.checkoutId.trim()
        : '';
    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found.');
    }

    const order = orderDoc.data();
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    const isAdminUser = userDoc.exists && userDoc.data().role === 'admin';
    if (order.customerId !== context.auth.uid && !isAdminUser) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'You can only verify your own payment.'
        );
    }
    if (checkoutId && order.peachCheckoutId !== checkoutId) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Checkout ID does not match this order.'
        );
    }

    const config = peachMobileConfig();
    const separator = resourcePath.includes('?') ? '&' : '?';
    const statusResponse = await fetch(
        `${config.mobileBaseUrl}${resourcePath}${separator}entityId=${encodeURIComponent(config.entityId)}`,
        {
            method: 'GET',
            headers: {
                authorization: `Bearer ${config.accessToken}`,
            },
        }
    );

    const status = await statusResponse.json().catch(() => ({}));
    if (!statusResponse.ok) {
        throw new functions.https.HttpsError(
            'internal',
            `Peach mobile status failed: ${status.message || statusResponse.statusText}`
        );
    }

    const resultCode = status['result.code'] || status.result?.code;
    const paid = isSuccessfulPeachResult(resultCode);
    await orderRef.update({
        paymentStatus: paid ? 'paid' : 'failed',
        peachResourcePath: resourcePath,
        peachResultCode: resultCode || '',
        peachResultDescription:
            status['result.description'] || status.result?.description || '',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
        paid,
        resultCode: resultCode || '',
        description:
            status['result.description'] || status.result?.description || '',
    };
});

exports.createPeachCheckout = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Sign in is required before paying.'
        );
    }

    const orderId = requireString(data?.orderId, 'Order ID');
    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found.');
    }

    const order = orderDoc.data();
    if (order.customerId !== context.auth.uid) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'You can only pay for your own order.'
        );
    }
    if (order.paymentMethod !== 'peach_payments') {
        throw new functions.https.HttpsError(
            'failed-precondition',
            'This order is not configured for Peach Payments.'
        );
    }

    const config = peachConfig();
    const token = await peachAccessToken(config);
    const checkoutIdNonce = crypto.randomBytes(16).toString('hex');
    const customerDoc = await db.collection('users').doc(context.auth.uid).get();
    const customer = customerDoc.exists ? customerDoc.data() : {};
    const names = String(customer.name || '').trim().split(/\s+/);
    const givenName = names[0] || 'Noko';
    const surname = names.slice(1).join(' ') || 'Customer';
    const shopperResultUrl = functions.config().peach?.result_url ||
        publicFunctionUrl('peachCheckoutResult');
    const notificationUrl = functions.config().peach?.webhook_url ||
        publicFunctionUrl('peachCheckoutWebhook');

    let checkoutResponse;
    try {
        checkoutResponse = await fetch(`${config.checkoutBaseUrl}/v2/checkout`, {
            method: 'POST',
            headers: {
                accept: 'application/json',
                authorization: `Bearer ${token}`,
                'content-type': 'application/json',
                referer: config.referer,
            },
            body: JSON.stringify({
                authentication: { entityId: config.entityId },
                merchantTransactionId: merchantTransactionId(orderId),
                merchantInvoiceId: order.orderNumber || orderId,
                amount: Number(order.total || 0).toFixed(2),
                currency: config.currency,
                paymentType: 'DB',
                nonce: checkoutIdNonce,
                shopperResultUrl,
                notificationUrl,
                defaultPaymentMethod: 'CARD',
                forceDefaultMethod: false,
                originator: 'Noko Flutter App',
                customer: {
                    givenName,
                    surname,
                    email: customer.email || context.auth.token.email || '',
                    mobile: customer.phone || '',
                },
                shipping: {
                    street1: order.deliveryAddress || 'Collection',
                    country: 'ZA',
                },
                customParameters: {
                    auxData: JSON.stringify({
                        orderId,
                        customerId: context.auth.uid,
                    }),
                },
            }),
        });
    } catch (error) {
        rethrowPeachCallableError(
            error,
            'Online payment could not start right now. Please choose cash and try again.'
        );
    }

    const checkout = await checkoutResponse.json().catch(() => ({}));
    if (!checkoutResponse.ok) {
        throw new functions.https.HttpsError(
            'internal',
            `Peach checkout failed: ${checkout.message || checkoutResponse.statusText}`
        );
    }

    const checkoutId = checkout.checkoutId || checkout.id;
    if (!checkoutId) {
        throw new functions.https.HttpsError(
            'internal',
            'Peach checkout response did not include a checkout ID.'
        );
    }

    await orderRef.update({
        peachCheckoutId: checkoutId,
        paymentStatus: 'pending',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const pageUrl = `${publicFunctionUrl('peachCheckoutPage')}?checkoutId=${encodeURIComponent(checkoutId)}&orderId=${encodeURIComponent(orderId)}`;

    return {
        checkoutId,
        checkoutUrl: pageUrl,
        entityId: config.entityId,
    };
});

exports.verifyPeachPayment = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Sign in is required before verifying payment.'
        );
    }

    const orderId = requireString(data?.orderId, 'Order ID');
    const checkoutId = requireString(data?.checkoutId, 'Checkout ID');
    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found.');
    }

    const order = orderDoc.data();
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    const isAdminUser = userDoc.exists && userDoc.data().role === 'admin';
    if (order.customerId !== context.auth.uid && !isAdminUser) {
        throw new functions.https.HttpsError(
            'permission-denied',
            'You can only verify your own payment.'
        );
    }
    if (order.peachCheckoutId !== checkoutId) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Checkout ID does not match this order.'
        );
    }

    const config = peachConfig();
    const token = await peachAccessToken(config);
    let statusResponse;
    try {
        statusResponse = await fetch(
            `${config.checkoutBaseUrl}/v2/checkout/${encodeURIComponent(checkoutId)}/status`,
            {
                method: 'GET',
                headers: {
                    accept: 'application/json',
                    authorization: `Bearer ${token}`,
                },
            }
        );
    } catch (error) {
        rethrowPeachCallableError(
            error,
            'Online payment status could not be checked right now. Please contact support with your order number.'
        );
    }
    const status = await statusResponse.json().catch(() => ({}));
    if (!statusResponse.ok) {
        throw new functions.https.HttpsError(
            'internal',
            `Peach status failed: ${status.message || statusResponse.statusText}`
        );
    }

    const resultCode = status['result.code'] || status.result?.code;
    const paid = isSuccessfulPeachResult(resultCode);
    await orderRef.update({
        paymentStatus: paid ? 'paid' : 'failed',
        peachResultCode: resultCode || '',
        peachResultDescription:
            status['result.description'] || status.result?.description || '',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
        paid,
        resultCode: resultCode || '',
        description:
            status['result.description'] || status.result?.description || '',
    };
});

exports.peachCheckoutPage = functions.https.onRequest((req, res) => {
    const { checkoutId, orderId } = req.query;
    const config = peachConfig();
    if (!checkoutId || !orderId) {
        res.status(400).send('Missing checkout information.');
        return;
    }

    res.set('content-type', 'text/html');
    res.send(`<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    html, body { margin: 0; padding: 0; min-height: 100%; background: #121212; color: #f5f5f5; font-family: Arial, sans-serif; }
    #payment-form { min-height: 100vh; padding: 16px; box-sizing: border-box; }
  </style>
</head>
<body>
  <div id="payment-form"></div>
  <script src="${config.checkoutScriptUrl}"></script>
  <script>
    const done = (state) => {
      window.location.href = 'noko://peach-payment/' + state +
        '?orderId=${encodeURIComponent(orderId)}&checkoutId=${encodeURIComponent(checkoutId)}';
    };
    const start = () => {
      const checkout = Checkout.initiate({
        key: '${config.entityId}',
        checkoutId: '${String(checkoutId).replace(/'/g, '')}',
        eventHandlers: {
          onCompleted: () => done('completed'),
          onCancelled: () => done('cancelled'),
          onExpired: () => done('expired'),
        },
        options: {
          theme: {
            brand: { primary: '#7A1F2B' },
          },
        },
      });
      checkout.render('#payment-form');
    };
    if (window.Checkout) {
      start();
    } else {
      window.addEventListener('load', start);
    }
  </script>
</body>
</html>`);
});

exports.peachCheckoutResult = functions.https.onRequest((req, res) => {
    res.set('content-type', 'text/html');
    res.send(`<!doctype html>
<html>
<body style="font-family: Arial, sans-serif; padding: 24px;">
  <h2>Payment received</h2>
  <p>You can return to the Noko app now.</p>
</body>
</html>`);
});

exports.peachCheckoutWebhook = functions.https.onRequest(async (req, res) => {
    const checkoutId = req.body?.checkoutId || req.query?.checkoutId;
    if (!checkoutId) {
        res.status(204).send('');
        return;
    }

    const snapshot = await admin
        .firestore()
        .collection('orders')
        .where('peachCheckoutId', '==', checkoutId)
        .limit(1)
        .get();

    if (!snapshot.empty) {
        await snapshot.docs[0].ref.set({
            peachWebhookReceivedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }

    res.status(204).send('');
});
