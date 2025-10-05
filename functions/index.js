const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

admin.initializeApp();

// Callable function: disable/enable account
exports.setAccountDisabled = onCall(async (request) => {
  const { data, auth } = request;

  if (!(auth && auth.token && auth.token.admin)) {
    throw new HttpsError("permission-denied", "Only admins can modify users.");
  }

  try {
    await admin.auth().updateUser(data.uid, { disabled: data.disabled });
    return {
      message: `User ${data.uid} has been ${data.disabled ? "disabled" : "enabled"}.`,
    };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});


// Scheduled function: check SLA every 60 minutes
exports.checkSlaEveryHour = onSchedule("every 60 minutes", async (event) => {
  const now = admin.firestore.Timestamp.now();
  const cutoffMillis = Date.now() - 48 * 60 * 60 * 1000; // 48 hours ago
  const cutoffTimestamp = admin.firestore.Timestamp.fromMillis(cutoffMillis);

  const db = admin.firestore();
  const qSnapshot = await db
    .collectionGroup("messages")
    .where("senderRole", "==", "student")
    .where("slaNotified", "==", false)
    .where("timestamp", "<=", cutoffTimestamp)
    .limit(500)
    .get();

  if (qSnapshot.empty) {
    console.log("No candidate messages for SLA check.");
    return null;
  }

  for (const msgDoc of qSnapshot.docs) {
    try {
      const data = msgDoc.data();
      const studentTs = data.timestamp;
      const mentorId = data.mentorId;
      const studentId = data.studentId;

      if (!studentTs || !mentorId || !studentId) {
        console.warn("Skipping message missing metadata:", msgDoc.id);
        continue;
      }

      // check if mentor replied after studentTs
      const messagesCollectionRef = msgDoc.ref.parent;
      const replySnap = await messagesCollectionRef
        .where("senderId", "==", mentorId)
        .where("timestamp", ">", studentTs)
        .limit(1)
        .get();

      if (!replySnap.empty) continue;

       // NEW: Check mute
        const ids = [mentorId, studentId].sort();
        const chatId = ids.join("_");
        const muteDoc = await db.collection("mutedChats").doc(chatId).get();
        if (muteDoc.exists) {
          console.log(`Chat ${chatId} is muted, skip SLA notification.`);
          continue;
        }

      const mentorDoc = await db.collection("mentors").doc(mentorId).get();
      if (!mentorDoc.exists) {
        console.warn("Mentor doc not found for id", mentorId);
        continue;
      }

      const mentorData = mentorDoc.data();
      let tokens = [];
      if (Array.isArray(mentorData?.fcmTokens)) {
        tokens = mentorData.fcmTokens;
      } else if (mentorData?.fcmToken) {
        tokens = [mentorData.fcmToken];
      }

      if (tokens.length > 0) {
        const text = (data.text ?? "Attachment").toString();
        const short = text.length > 120 ? text.substring(0, 117) + "..." : text;

        const message = {
          tokens,
          notification: {
            title: "SLA Alert — Unanswered Student Message",
            body: "A student message has gone unanswered for over 48 hours: " + short,
          },
          data: {
            chatId: msgDoc.ref.parent.parent?.id ?? "",
            messageId: msgDoc.id,
            mentorId,
            studentId,
          },
        };

        const response = await admin.messaging().sendMulticast(message);
        console.log("FCM send response:", response);
      }

      await msgDoc.ref.update({ slaNotified: true });

      await db.collection("slaBreaches").add({
        chatId: msgDoc.ref.parent.parent?.id ?? "",
        messageId: msgDoc.id,
        mentorId,
        studentId,
        messageText: data.text ?? null,
        messageTimestamp: studentTs,
        detectedAt: admin.firestore.Timestamp.now(),
      });
    } catch (err) {
      console.error("Error handling SLA for msg", msgDoc.id, err);
    }
  }

  return null;
});


exports.notifySlaOnNewMessage = onDocumentCreated(
  'privateChats/{chatId}/messages/{messageId}',
  async (event) => {
    const data = event.data.data();
    const db = admin.firestore();

    if (data.senderRole !== "student") return null;

    const studentTs = data.timestamp?.toDate ? data.timestamp.toDate() : new Date();
    const mentorId = data.mentorId;
    const studentId = data.studentId;

    // Check if mentor already replied
    const messagesRef = event.data.ref.parent;
    const replySnap = await messagesRef
      .where("senderId", "==", mentorId)
      .where("timestamp", ">", studentTs)
      .limit(1)
      .get();

    if (!replySnap.empty) return null;

    // Check muted chats
    const ids = [mentorId, studentId].sort();
    const chatId = ids.join("_");
    const muteDoc = await db.collection("mutedChats").doc(chatId).get();
    if (muteDoc.exists) return null;

    // Get mentor FCM tokens
    const mentorDoc = await db.collection("mentors").doc(mentorId).get();
    if (!mentorDoc.exists) return null;

    let tokens = [];
    const mentorData = mentorDoc.data();
    if (Array.isArray(mentorData?.fcmTokens)) tokens = mentorData.fcmTokens;
    else if (mentorData?.fcmToken) tokens = [mentorData.fcmToken];

    if (tokens.length === 0) return null;

    // Calculate remaining SLA
    const now = new Date();
    const deadline = new Date(studentTs.getTime() + 48 * 60 * 60 * 1000);
    const remainingMs = Math.max(deadline - now, 0);
    const remainingHours = Math.floor(remainingMs / (1000 * 60 * 60));
    const remainingMinutes = Math.floor((remainingMs % (1000 * 60 * 60)) / (1000 * 60));

    // Send notification
    await admin.messaging().sendMulticast({
      tokens,
      notification: {
        title: "Student Message - SLA Reminder",
        body: `You have ${remainingHours}h ${remainingMinutes}m left to reply to this message.`,
      },
      data: {
        chatId,
        messageId: event.params.messageId,
        mentorId,
        studentId,
      },
    });

    return null;
  }
);

exports.sendAnnouncementNotification = onDocumentCreated("announcements/{announcementId}", async (event) => {
  const data = event.data.data();

  const title = data.title || "New Announcement";
  const body = `${data.subjectName} - ${data.className}`;

  // You would store FCM tokens under each student’s user doc
  const tokensSnap = await admin.firestore()
    .collection("students")
    .where("className", "==", data.className)
    .where("subjectName", "==", data.subjectName)
    .get();

  const tokens = tokensSnap.docs
    .map(doc => doc.data().fcmToken)
    .filter(token => !!token);

  if (tokens.length > 0) {
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { subjectName: data.subjectName, className: data.className }
    });
  }
});