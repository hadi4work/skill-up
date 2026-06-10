/**
 * عند إنشاء مستند جديد في notifications → إرسال Push عبر FCM للمستخدم (fcmToken في users).
 */
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// غيّر المنطقة إن رغبت (يجب أن تدعم Cloud Functions Gen2)
setGlobalOptions({region: "europe-west1"});

function channelIdForPriority(priority) {
  if (priority === "high") return "high_priority_channel";
  if (priority === "low") return "low_priority_channel";
  return "default_priority_channel";
}

function stringifyData(obj) {
  const out = {};
  if (!obj || typeof obj !== "object") return out;
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null) continue;
    out[String(k)] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

exports.sendPushOnNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("No snapshot data");
      return;
    }

    const data = snap.data();
    const userId = data.userId;
    const title = (data.title || "").toString().trim() || "SkillUp AI";
    const body = (data.body || "").toString().trim() || "لديك إشعار جديد";
    const priority = (data.priority || "default").toString();
    const actionType = (data.actionType || "").toString();
    const assignmentId = data.assignmentId != null ? String(data.assignmentId) : "";
    const type = (data.type || "").toString();

    if (!userId) {
      logger.warn("Notification without userId, skip push");
      return;
    }

    const userRef = admin.firestore().collection("users").doc(userId);
    const userSnap = await userRef.get();
    const fcmToken = userSnap.exists ? userSnap.data().fcmToken : null;

    if (!fcmToken || typeof fcmToken !== "string") {
      logger.warn(`No fcmToken for user ${userId}`);
      return;
    }

    const dataPayload = {
      actionType,
      assignmentId,
      type,
      priority,
      notificationId: snap.id,
      ...stringifyData(data.metadata || {}),
    };

    const message = {
      token: fcmToken,
      notification: {title, body},
      android: {
        priority: priority === "high" ? "high" : "normal",
        notification: {
          channelId: channelIdForPriority(priority),
          sound: priority === "low" ? undefined : "default",
        },
      },
      data: dataPayload,
    };

    try {
      await admin.messaging().send(message);
      logger.info(`Push sent to ${userId} for notification ${snap.id}`);
    } catch (err) {
      logger.error("FCM send failed", err);
      // إن كان التوكن غير صالح يمكن حذفه لاحقاً من users (اختياري)
      if (
        err.code === "messaging/invalid-registration-token" ||
        err.code === "messaging/registration-token-not-registered"
      ) {
        await userRef.update({fcmToken: admin.firestore.FieldValue.delete()}).catch(() => {});
      }
    }
  },
);
