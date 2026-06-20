/* global importScripts, firebase */

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

try {
  importScripts('./firebase-web-config.js');
} catch (error) {
  console.warn('Mobilis web push config not loaded yet.', error);
}

const firebaseConfig = self.MOBILIS_FIREBASE_CONFIG || null;
const hasValidConfig =
  firebaseConfig &&
  typeof firebaseConfig.apiKey === 'string' &&
  !firebaseConfig.apiKey.startsWith('YOUR_');

if (hasValidConfig) {
  firebase.initializeApp(firebaseConfig);

  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    self.registration.showNotification(notification.title || 'Mobilis', {
      body: notification.body || 'You have a new notification',
      icon: '/icons/Icon-192.png',
    });
  });
}
