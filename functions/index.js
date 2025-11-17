const { getMessaging } = require("firebase-admin/messaging");
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
exports.checkSlaEveryHour = onSchedule("every 60 minutes", async () => {
  const db = admin.firestore();
  const cutoffMillis = Date.now() - 48 * 60 * 60 * 1000;
  const cutoffTimestamp = admin.firestore.Timestamp.fromMillis(cutoffMillis);

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

      // Check if mentor replied
      const messagesRef = msgDoc.ref.parent;
      const replySnap = await messagesRef
        .where("senderId", "==", mentorId)
        .where("timestamp", ">", studentTs)
        .limit(1)
        .get();

      if (!replySnap.empty) continue;

      // Check mute
      const chatId = msgDoc.ref.parent.parent?.id;
      if (!chatId) continue;

      const chatDoc = await db.collection("privateChats").doc(chatId).get();
      if (!chatDoc.exists) continue;

      const mutedBy = chatDoc.data()?.mutedBy ?? [];
      if (mutedBy.includes(mentorId) || mutedBy.includes(studentId)) continue;

      // ---------- Notify Mentor ----------
      const mentorDoc = await db.collection("mentors").doc(mentorId).get();
      if (mentorDoc.exists) {
        let mentorTokens = [];
        const mentorData = mentorDoc.data();

        if (Array.isArray(mentorData?.fcmTokens)) mentorTokens = mentorData.fcmTokens;
        else if (mentorData?.fcmToken) mentorTokens = [mentorData.fcmToken];

        if (mentorTokens.length > 0) {
          await getMessaging().sendEachForMulticast({
            tokens: mentorTokens,
            notification: {
              title: "SLA Reminder",
              body: "A student message sent 48 hours ago has no reply."
            },
            data: { chatId, mentorId, studentId, messageId: msgDoc.id }
          });

          console.log("Mentor notified:", mentorId);
        }
      }

      // ---------- Notify Student ----------
      const studentDoc = await db.collection("students").doc(studentId).get();
      if (studentDoc.exists) {
        let studentTokens = [];
        const studentData = studentDoc.data();

        if (Array.isArray(studentData?.fcmTokens)) studentTokens = studentData.fcmTokens;
        else if (studentData?.fcmToken) studentTokens = [studentData.fcmToken];

        if (studentTokens.length > 0) {
          await getMessaging().sendEachForMulticast({
            tokens: studentTokens,
            notification: {
              title: "Still Waiting for Mentor",
              body: "Your mentor has not replied to your message for over 48 hours."
            },
            data: { chatId, mentorId, studentId, messageId: msgDoc.id }
          });

          console.log("Student notified:", studentId);
        }
      }

      // Update SLA flag
      await msgDoc.ref.update({ slaNotified: true });

      // Log SLA breach
      await db.collection("slaBreaches").add({
        chatId,
        messageId: msgDoc.id,
        mentorId,
        studentId,
        messageText: data.text ?? null,
        messageTimestamp: studentTs,
        detectedAt: admin.firestore.Timestamp.now()
      });

    } catch (err) {
      console.error("Error handling SLA for message", msgDoc.id, err);
    }
  }

  return null;
});

// 3) SLA Trigger on NEW STUDENT MESSAGE
exports.notifySlaOnNewMessage = onDocumentCreated(
  "privateChats/{chatId}/messages/{messageId}",
  async (event) => {
    const db = admin.firestore();
    const data = event.data.data();

    if (data.senderRole !== "student") return null;
    if (!data.mentorId || !data.studentId) return null;

    const mentorId = data.mentorId;
    const studentId = data.studentId;

    const studentTs = data.timestamp?.toDate?.();
    if (!studentTs) return null;

    const chatId = event.params.chatId;

    const chatDoc = await db.collection("privateChats").doc(chatId).get();
    if (!chatDoc.exists) return null;

    const mutedBy = chatDoc.data()?.mutedBy ?? [];
    if (mutedBy.includes(mentorId) || mutedBy.includes(studentId)) return null;

    // Mentor replied already?
    const messagesRef = event.data.ref.parent;
    const replySnap = await messagesRef
      .where("senderId", "==", mentorId)
      .where("timestamp", ">", studentTs)
      .limit(1)
      .get();

    if (!replySnap.empty) return null;

    // get mentor data
    const mentorDoc = await db.collection("mentors").doc(mentorId).get();
    if (!mentorDoc.exists) return null;

    // get student data
    const studentDoc = await db.collection("students").doc(studentId).get();

    const mentorName = mentorDoc.data().name || "Mentor";
    const studentName = studentDoc.exists
      ? studentDoc.data().name || "Student"
      : "Student";

    // Collect tokens
    let tokens = [];
    const mData = mentorDoc.data();

    if (Array.isArray(mData.fcmTokens)) tokens = mData.fcmTokens;
    else if (mData.fcmToken) tokens = [mData.fcmToken];

    if (tokens.length === 0) return null;

    // SLA countdown
    const deadline = new Date(studentTs.getTime() + 48 * 60 * 60 * 1000);
    const remainingMs = Math.max(deadline - new Date(), 0);
    const remainingHours = Math.floor(remainingMs / 3600000);
    const remainingMinutes = Math.floor((remainingMs % 3600000) / 60000);

    // SEND NOTIFICATION (fixed)
    await getMessaging().sendEachForMulticast({
      tokens,
      android: { priority: "high" },
      apns: {
        payload: {
          aps: { content_available: true }
        }
      },
      notification: {
        title: `New message from ${studentName}`,
        body: `Reply within ${remainingHours}h ${remainingMinutes}m.`,
      },
      data: {
        type: "sla_chat",
        chatId,
        mentorId,
        mentorName,
        studentId,
        studentName,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    });


    console.log("Mentor notified:", mentorId);
    return null;
  }
);

//-----notify students---------
exports.notifyStudentOnMentorReply = onDocumentCreated(
  "privateChats/{chatId}/messages/{messageId}",
  async (event) => {
    const db = admin.firestore();
    const data = event.data.data();

    // Only trigger when mentor replies
    if (data.senderRole !== "mentor") return null;

    const mentorId = data.mentorId;
    const studentId = data.studentId;
    if (!mentorId || !studentId) return null;

    const chatId = event.params.chatId;

    //  Fetch chat settings (for mute)
    const chatDoc = await db.collection("privateChats").doc(chatId).get();
    if (!chatDoc.exists) return null;

    const mutedBy = chatDoc.data()?.mutedBy ?? [];

    //  If student muted the chat → do NOT notify
    if (mutedBy.includes(studentId)) {
      console.log("Student muted chat – skipping notification");
      return null;
    }

    // Fetch student document
    const studentDoc = await db.collection("students").doc(studentId).get();
    if (!studentDoc.exists) return null;

    const sData = studentDoc.data();
    const studentName = sData.name || "Student";

    // Fetch mentor for display name
    const mentorDoc = await db.collection("mentors").doc(mentorId).get();
    const mentorName = mentorDoc.exists
      ? mentorDoc.data().name || "Mentor"
      : "Mentor";

    // Collect student tokens
    let tokens = [];
    if (Array.isArray(sData.fcmTokens)) tokens = sData.fcmTokens;
    else if (sData.fcmToken) tokens = [sData.fcmToken];

    if (tokens.length === 0) return null;

    // Send push notification
    await getMessaging().sendEachForMulticast({
      tokens,
      android: { priority: "high" },
      apns: { payload: { aps: { content_available: true } } },
      notification: {
        title: `Reply from ${mentorName}`,
        body: "Your mentor has responded to your message.",
      },
      data: {
        type: "mentor_reply",
        chatId,
        mentorId,
        mentorName,
        studentId,
        studentName,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    });

    console.log("Student notified:", studentId);
    return null;
  }
);



exports.sendAnnouncementNotification = onDocumentCreated(
  "announcements/{announcementId}",
  async (event) => {

    const db = admin.firestore();
    const data = event.data.data();

    const title = data.title || "New Announcement";

    const schoolId = data.schoolId;
    const programmeId = data.programmeId;
    const subjectId = data.subjectId;
    const sectionId = data.sectionId;

    //  1. Fetch subject name
    const subjectRef = db
      .collection("schools")
      .doc(schoolId)
      .collection("programmes")
      .doc(programmeId)
      .collection("subjects")
      .doc(subjectId);

    const subjectDoc = await subjectRef.get();
    const subjectName = subjectDoc.exists ? (subjectDoc.data().name || "Subject") : "Subject";


    //  2. Fetch section name
    const sectionRef = subjectRef
      .collection("sections")
      .doc(sectionId);

    const sectionDoc = await sectionRef.get();
    const sectionName = sectionDoc.exists ? (sectionDoc.data().name || "Section") : "Section";


    const body = `${subjectName} - ${sectionName}`;

    //  3. Find enrolled students
    const enrollSnap = await db
      .collection("subjectEnrollments")
      .where("subjectId", "==", subjectId)
      .where("sectionId", "==", sectionId)
      .get();

    if (enrollSnap.empty) return null;

    //  4. Collect FCM tokens
    const tokenPromises = enrollSnap.docs.map(async (doc) => {
      const studentId = doc.data().studentId;
      const sDoc = await db.collection("students").doc(studentId).get();
      if (!sDoc.exists) return null;

      const s = sDoc.data();
      if (Array.isArray(s.fcmTokens)) return s.fcmTokens;
      if (s.fcmToken) return [s.fcmToken];
      return null;
    });

    const tokens = (await Promise.all(tokenPromises)).flat().filter(Boolean);

    if (tokens.length === 0) return null;

    //  5. Send Notification
    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        announcementId: event.params.announcementId,
        route: "/previewAnnouncement",
      },
    });

    console.log(` Sent announcement to ${tokens.length} students.`);
    return null;
  }
);

