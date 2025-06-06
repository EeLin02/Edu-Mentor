const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.setAccountDisabled = functions.https.onCall(async (data, context) => {
  // Check if the user has the admin claim
  if (!(context.auth && context.auth.token.admin)) {
    throw new functions.https.HttpsError('permission-denied', 'Only admins can modify users.');
  }

  const uid = data.uid;
  const disabled = data.disabled;

  try {
    await admin.auth().updateUser(uid, { disabled });
    return { message: `User ${uid} has been ${disabled ? 'disabled' : 'enabled'}.` };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
