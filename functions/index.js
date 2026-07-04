/**
 * Cloud Functions for the Settlement app.
 *
 * These Firestore triggers push FCM notifications for every two-party event so
 * the OTHER party is alerted: friend requests, split-share approvals, payment
 * confirmations, and group invitations.
 *
 * Deploy with:  firebase deploy --only functions
 * (Requires the Blaze / pay-as-you-go plan.)
 */

const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();
const db = getFirestore();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const rupees = (n) => `₹${Math.round(Number(n) || 0)}`;

async function getUser(uid) {
  if (!uid) return null;
  const snap = await db.collection("users").doc(uid).get();
  return snap.exists ? snap.data() : null;
}

async function nameOf(uid) {
  const u = await getUser(uid);
  return (u && u.displayName) || "Someone";
}

/** Sends a notification to every device registered to [uid]. */
async function sendToUser(uid, title, body, data = {}) {
  const user = await getUser(uid);
  const tokens = (user && user.fcmTokens) || [];
  if (tokens.length === 0) return;

  const stringData = {};
  for (const [k, v] of Object.entries(data)) stringData[k] = String(v);

  let response;
  try {
    response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: stringData,
      android: {priority: "high"},
    });
  } catch (err) {
    logger.error("sendEachForMulticast failed", err);
    return;
  }

  // Prune tokens the FCM backend reports as dead so the array stays clean.
  const stale = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
      ) {
        stale.push(tokens[i]);
      }
    }
  });
  if (stale.length > 0) {
    await db.collection("users").doc(uid).update({
      fcmTokens: FieldValue.arrayRemove(...stale),
    });
  }
}

async function sendToEmail(email, title, body, data = {}) {
  if (!email) return;
  const q = await db
    .collection("users")
    .where("email", "==", String(email).toLowerCase())
    .limit(1)
    .get();
  if (q.empty) return;
  await sendToUser(q.docs[0].id, title, body, data);
}

/** Who must confirm a settlement: whichever side did NOT record it. */
function confirmerId(s) {
  if (!s.recordedBy) return s.toUserId;
  return s.recordedBy === s.fromUserId ? s.toUserId : s.fromUserId;
}

// ---------------------------------------------------------------------------
// Friend requests
// ---------------------------------------------------------------------------

exports.onFriendRequestCreated = onDocumentCreated(
  "friend_requests/{id}",
  async (event) => {
    const r = event.data && event.data.data();
    if (!r || r.status !== "pending") return;
    await sendToUser(
      r.toUserId,
      "New friend request",
      `${r.fromName || "Someone"} wants to be your friend`,
      {type: "friend_request", requestId: event.params.id},
    );
  },
);

exports.onFriendRequestUpdated = onDocumentUpdated(
  "friend_requests/{id}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.status === after.status) return;
    if (after.status === "accepted") {
      await sendToUser(
        after.fromUserId,
        "Friend request accepted",
        `${after.toName || "Your friend"} accepted your friend request`,
        {type: "friend_accepted"},
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Splits
// ---------------------------------------------------------------------------

exports.onSplitCreated = onDocumentCreated("splits/{id}", async (event) => {
  const split = event.data && event.data.data();
  if (!split) return;
  const payerName = await nameOf(split.paidBy);
  const participants = split.participants || [];
  const amounts = split.splitAmounts || {};

  await Promise.all(
    participants
      .filter((p) => p !== split.paidBy)
      .map((p) =>
        sendToUser(
          p,
          "Approve your share",
          `${payerName} split "${split.title}" — your share is ${rupees(amounts[p])}`,
          {type: "split_approval", splitId: event.params.id},
        ),
      ),
  );
});

exports.onSplitUpdated = onDocumentUpdated("splits/{id}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const splitId = event.params.id;

  // 1) New / changed settlements.
  const beforeById = {};
  for (const s of before.settlements || []) beforeById[s.id] = s;
  for (const s of after.settlements || []) {
    const prev = beforeById[s.id];
    if (!prev) {
      if (s.status === "pending") {
        const recorderName = await nameOf(s.recordedBy || s.fromUserId);
        await sendToUser(
          confirmerId(s),
          "Confirm a payment",
          `${recorderName} recorded a payment of ${rupees(s.amount)} for "${after.title}"`,
          {type: "settlement_confirm", splitId, settlementId: s.id},
        );
      }
    } else if (prev.status !== s.status && s.recordedBy) {
      if (s.status === "confirmed") {
        await sendToUser(
          s.recordedBy,
          "Payment confirmed",
          `Your ${rupees(s.amount)} payment for "${after.title}" was confirmed`,
          {type: "settlement_confirmed", splitId},
        );
      } else if (s.status === "rejected") {
        await sendToUser(
          s.recordedBy,
          "Payment rejected",
          `Your ${rupees(s.amount)} payment for "${after.title}" was rejected`,
          {type: "settlement_rejected", splitId},
        );
      }
    }
  }

  // 2) Participant approvals / declines → tell the payer.
  const beforeStatus = before.participantStatus || {};
  const afterStatus = after.participantStatus || {};
  for (const uid of Object.keys(afterStatus)) {
    if (uid === after.paidBy) continue;
    if (beforeStatus[uid] === afterStatus[uid]) continue;
    if (afterStatus[uid] === "accepted") {
      const who = await nameOf(uid);
      await sendToUser(
        after.paidBy,
        "Share approved",
        `${who} approved their share of "${after.title}"`,
        {type: "split_share_accepted", splitId},
      );
    } else if (afterStatus[uid] === "declined") {
      const who = await nameOf(uid);
      await sendToUser(
        after.paidBy,
        "Share declined",
        `${who} declined their share of "${after.title}"`,
        {type: "split_share_declined", splitId},
      );
    }
  }
});

// ---------------------------------------------------------------------------
// Group invitations
// ---------------------------------------------------------------------------

exports.onGroupInvitationCreated = onDocumentCreated(
  "group_invitations/{id}",
  async (event) => {
    const inv = event.data && event.data.data();
    if (!inv || inv.status !== "pending") return;
    await sendToEmail(
      inv.inviteeEmail,
      "Group invitation",
      `${inv.invitedByName || "Someone"} invited you to "${inv.groupName}"`,
      {type: "group_invite", groupId: inv.groupId},
    );
  },
);
