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
  const cutoffMillis = Date.now() - 48 * 60 * 60 * 1000; // 48 hours
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

        if (!studentTs || !mentorId || !studentId) continue;

        // Check if mentor replied after studentTs
        const messagesCollectionRef = msgDoc.ref.parent;
        const replySnap = await messagesCollectionRef
          .where("senderId", "==", mentorId)
          .where("timestamp", ">", studentTs)
          .limit(1)
          .get();
        if (!replySnap.empty) continue;

        // Get chatId and check mutedBy
        const chatId = msgDoc.ref.parent.parent?.id;
        if (!chatId) continue;
        const chatDoc = await db.collection("privateChats").doc(chatId).get();
        if (!chatDoc.exists) continue;
        const mutedBy = chatDoc.data()?.mutedBy ?? [];
        if (mutedBy.includes(mentorId) || mutedBy.includes(studentId)) continue;

        // --- Notify Mentor ---
        const mentorDoc = await db.collection("mentors").doc(mentorId).get();
        if (mentorDoc.exists) {
          let mentorTokens = [];
          const mentorData = mentorDoc.data();
          if (Array.isArray(mentorData?.fcmTokens)) mentorTokens = mentorData.fcmTokens;
          else if (mentorData?.fcmToken) mentorTokens = [mentorData.fcmToken];

          if (mentorTokens.length > 0) {
            const text = (data.text ?? "Attachment").toString();
            const short = text.length > 120 ? text.substring(0, 117) + "..." : text;

            await admin.messaging().sendMulticast({
              tokens: mentorTokens,
              notification: {
                title: "SLA Alert — Unanswered Student Message",
                body: "A student message has gone unanswered for over 48 hours: " + short,
              },
              data: {
                chatId,
                messageId: msgDoc.id,
                mentorId,
                studentId,
              },
            });

            console.log("Mentor notified:", mentorId);
          }
        }

        // --- Notify Student ---
        const studentDoc = await db.collection("students").doc(studentId).get();
        if (studentDoc.exists) {
          let studentTokens = [];
          const studentData = studentDoc.data();
          if (Array.isArray(studentData?.fcmTokens)) studentTokens = studentData.fcmTokens;
          else if (studentData?.fcmToken) studentTokens = [studentData.fcmToken];

          if (studentTokens.length > 0) {
            await admin.messaging().sendMulticast({
              tokens: studentTokens,
              notification: {
                title: "Mentor Has Not Replied Yet",
                body: "Your message sent over 48 hours ago has not received a reply from your mentor yet.",
              },
              data: {
                chatId,
                messageId: msgDoc.id,
                mentorId,
                studentId,
              },
            });

            console.log("Student notified:", studentId);
          }
        }

        // --- Update SLA flag ---
        await msgDoc.ref.update({ slaNotified: true });

        // --- Log SLA breach ---
        await db.collection("slaBreaches").add({
          chatId,
          messageId: msgDoc.id,
          mentorId,
          studentId,
          messageText: data.text ?? null,
          messageTimestamp: studentTs,
          detectedAt: admin.firestore.Timestamp.now(),
        });

      } catch (err) {
        console.error("Error handling SLA for message", msgDoc.id, err);
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
    const chatId = event.params.chatId;
    const chatDoc = await db.collection("privateChats").doc(chatId).get();
    if (!chatDoc.exists) return null;
    const mutedBy = chatDoc.data()?.mutedBy ?? [];
    if (mutedBy.includes(mentorId) || mutedBy.includes(studentId)) return null;

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

exports.sendAnnouncementNotification = onDocumentCreated(
  "announcements/{announcementId}",
  async (event) => {
    const data = event.data.data();
    const db = admin.firestore();

    const title = data.title || "New Announcement";
    const body = `${data.subjectName || "Subject"} - ${data.sectionName || "Section"}`;

    // 1 Get all subject enrollments for this subject and section
    const enrollSnap = await db
      .collection("subjectEnrollments")
      .where("subjectId", "==", data.subjectId)
      .where("sectionId", "==", data.sectionId)
      .get();

    if (enrollSnap.empty) {
      console.log("No enrolled students found.");
      return null;
    }

    // 2  Get each student's FCM token
    const tokenPromises = enrollSnap.docs.map(async (doc) => {
      const studentId = doc.data().studentId;
      const studentDoc = await db.collection("students").doc(studentId).get();
      if (!studentDoc.exists) return null;
      return studentDoc.data().fcmToken || null;
    });

    const tokens = (await Promise.all(tokenPromises)).filter((t) => !!t);

    // 3 Send notifications with announcementId and route info
    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          announcementId: event.params.announcementId, // important
          route: "/previewAnnouncement",                // Flutter route
        },
      });

      console.log(`Sent announcement to ${tokens.length} students`);
    } else {
      console.log("No valid tokens found.");
    }

    return null;
  }
);
