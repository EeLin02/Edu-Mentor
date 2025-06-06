const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');  // path to your JSON file

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = '1zvIaLoJ2cQMWmFI1hapc2iriw42';  // Replace with your user's UID

admin.auth().setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log('Admin claim set for user:', uid);
    process.exit(0);
  })
  .catch(error => {
    console.error('Error setting admin claim:', error);
    process.exit(1);
  });