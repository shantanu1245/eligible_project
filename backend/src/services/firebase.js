const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const config = require('../config/config');
const dummyData = require('../data/dummyData');

let rtdb = null;
let isLiveFirebase = false;
let resolvedDatabaseURL = '';

// Local in-memory / file fallback store for local development and offline guarantee
const localDbPath = path.resolve(__dirname, '../../data/local_db.json');
let localStore = {
  leads: [...dummyData.leads],
  campaigns: [...dummyData.campaigns],
  tasks: [...dummyData.tasks],
  team: [...dummyData.team],
  webhook_logs: [],
  settings: {},
};

function ensureLocalDb() {
  const dir = path.dirname(localDbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  if (fs.existsSync(localDbPath)) {
    try {
      const parsed = JSON.parse(fs.readFileSync(localDbPath, 'utf8'));
      localStore = {
        leads: parsed.leads || [...dummyData.leads],
        campaigns: parsed.campaigns || [...dummyData.campaigns],
        tasks: parsed.tasks || [...dummyData.tasks],
        team: parsed.team || [...dummyData.team],
        webhook_logs: parsed.webhook_logs || [],
        settings: parsed.settings || {},
      };
    } catch (e) {
      console.warn('⚠️  Could not parse local_db.json, re-seeding dummy dataset.');
      persistLocalDb();
    }
  } else {
    persistLocalDb();
  }
}

function persistLocalDb() {
  try {
    fs.writeFileSync(localDbPath, JSON.stringify(localStore, null, 2), 'utf8');
  } catch (err) {
    console.error('Error persisting local database:', err.message);
  }
}

function initializeFirebase() {
  try {
    let credential = null;
    let projectId = config.firebase.projectId;

    const candidatePaths = [
      config.firebase.serviceAccountPath,
      path.resolve(__dirname, '../../serviceAccount.json'),
      path.resolve(__dirname, '../../serviceAccountKey.json'),
    ].filter(Boolean);

    const foundPath = candidatePaths.find((p) => fs.existsSync(p));

    if (foundPath) {
      console.log(`🔑 Loading Firebase credentials from: ${foundPath}`);
      const serviceAccount = JSON.parse(fs.readFileSync(foundPath, 'utf8'));
      credential = admin.credential.cert(serviceAccount);
      projectId = serviceAccount.project_id || projectId;
    } else if (config.firebase.projectId && config.firebase.clientEmail && config.firebase.privateKey) {
      console.log('🔑 Loading Firebase credentials from environment variables...');
      credential = admin.credential.cert({
        projectId: config.firebase.projectId,
        clientEmail: config.firebase.clientEmail,
        privateKey: config.firebase.privateKey,
      });
    }

    if (credential) {
      resolvedDatabaseURL =
        config.firebase.databaseURL || `https://${projectId}-default-rtdb.firebaseio.com`;

      admin.initializeApp({
        credential,
        databaseURL: resolvedDatabaseURL,
      });

      rtdb = admin.database();
      isLiveFirebase = true;
      console.log('✅ Firebase Admin SDK initialized successfully with Realtime Database.');
      console.log(`📡 Realtime Database URL: ${resolvedDatabaseURL}`);
    } else {
      console.log('ℹ️  Operating in Local/Dev Storage mode.');
    }
  } catch (error) {
    console.error('⚠️  Failed to initialize Firebase Admin SDK:', error.message);
    isLiveFirebase = false;
  }
  ensureLocalDb();
}

// Initial bootstrap
initializeFirebase();

const FirebaseService = {
  isConfigured: () => isLiveFirebase,

  getStatus: () => ({
    connected: isLiveFirebase,
    mode: isLiveFirebase ? 'realtime_database' : 'local_storage',
    databaseURL: resolvedDatabaseURL || 'local',
    counts: {
      leads: localStore.leads.length,
      campaigns: localStore.campaigns.length,
      tasks: localStore.tasks.length,
      team: localStore.team.length,
    },
    serviceAccountFound: Boolean(
      (config.firebase.serviceAccountPath && fs.existsSync(config.firebase.serviceAccountPath)) ||
        fs.existsSync(path.resolve(__dirname, '../../serviceAccount.json')) ||
        fs.existsSync(path.resolve(__dirname, '../../serviceAccountKey.json'))
    ),
  }),

  // ===================== SEED ALL DUMMY DATA =====================
  async seedAllDummyData() {
    console.log('🌱 [Seed] Seeding all application dummy data...');
    ensureLocalDb();

    // 1. Always update local store
    localStore.leads = [...dummyData.leads];
    localStore.campaigns = [...dummyData.campaigns];
    localStore.tasks = [...dummyData.tasks];
    localStore.team = [...dummyData.team];
    persistLocalDb();

    let rtdbSuccess = false;
    let rtdbError = null;

    // 2. Push to live Firebase Realtime Database with timeout protection
    if (isLiveFirebase && rtdb) {
      try {
        const timeoutPromise = new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Realtime Database timeout (Database not created yet in console)')), 4000)
        );

        const pushPromise = Promise.all([
          // Leads
          Promise.all(
            dummyData.leads.map((l) => rtdb.ref(`${config.firebase.paths.leads}/${l.id}`).set(l))
          ),
          // Campaigns
          Promise.all(
            dummyData.campaigns.map((c) => rtdb.ref(`${config.firebase.paths.campaigns}/${c.id}`).set(c))
          ),
          // Tasks
          Promise.all(
            dummyData.tasks.map((t) => rtdb.ref(`tasks/${t.id}`).set(t))
          ),
          // Team
          Promise.all(
            dummyData.team.map((m) => rtdb.ref(`team/${m.id}`).set(m))
          ),
        ]);

        await Promise.race([pushPromise, timeoutPromise]);
        rtdbSuccess = true;
        console.log('✅ [Seed] Successfully pushed all dummy data to Firebase Realtime Database in cloud!');
      } catch (err) {
        rtdbError = err.message;
        console.warn('⚠️ [Seed] Cloud RTDB sync note:', err.message);
        console.log('ℹ️ Local storage has been fully seeded with all 10 leads, 4 campaigns, 4 tasks, and 4 team members.');
      }
    }

    return {
      success: true,
      rtdbSynced: rtdbSuccess,
      rtdbNote: rtdbError,
      seeded: {
        leads: dummyData.leads.length,
        campaigns: dummyData.campaigns.length,
        tasks: dummyData.tasks.length,
        team: dummyData.team.length,
      },
    };
  },

  // ===================== LEADS =====================
  async saveLead(leadData) {
    const timestamp = new Date().toISOString();
    const id = leadData.id || `lead_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const record = {
      id,
      ...leadData,
      createdAt: leadData.createdAt || timestamp,
      updatedAt: timestamp,
      source: leadData.source || 'Meta Ads',
      status: leadData.status || 'newLead',
      assignedTo: leadData.assignedTo || '',
    };

    // Always update local store
    ensureLocalDb();
    const existingIdx = localStore.leads.findIndex(
      (l) => l.id === id || (l.meta_leadgen_id && l.meta_leadgen_id === leadData.meta_leadgen_id)
    );
    if (existingIdx >= 0) {
      localStore.leads[existingIdx] = { ...localStore.leads[existingIdx], ...record };
    } else {
      localStore.leads.unshift(record);
    }
    persistLocalDb();

    // Async push to RTDB if active
    if (isLiveFirebase && rtdb) {
      rtdb.ref(`${config.firebase.paths.leads}/${id}`).set(record).catch(() => {});
    }

    return record;
  },

  async getLeads(filters = {}) {
    ensureLocalDb();
    let list = [...localStore.leads];

    if (filters.status) list = list.filter((l) => l.status === filters.status);
    if (filters.assignedTo) list = list.filter((l) => l.assignedTo === filters.assignedTo);
    return list;
  },

  async getLeadById(id) {
    ensureLocalDb();
    return localStore.leads.find((l) => l.id === id) || null;
  },

  async updateLead(id, updates) {
    const updatedAt = new Date().toISOString();
    ensureLocalDb();
    const idx = localStore.leads.findIndex((l) => l.id === id);
    if (idx >= 0) {
      localStore.leads[idx] = { ...localStore.leads[idx], ...updates, updatedAt };
      persistLocalDb();

      if (isLiveFirebase && rtdb) {
        rtdb.ref(`${config.firebase.paths.leads}/${id}`).update({ ...updates, updatedAt }).catch(() => {});
      }
      return localStore.leads[idx];
    }
    return null;
  },

  // ===================== CAMPAIGNS =====================
  async saveCampaign(campaignData) {
    const timestamp = new Date().toISOString();
    const id = campaignData.id || `camp_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const record = {
      id,
      ...campaignData,
      created_time: campaignData.created_time || timestamp,
      updated_time: timestamp,
    };

    ensureLocalDb();
    const existingIdx = localStore.campaigns.findIndex(
      (c) => c.id === id || (c.meta_campaign_id && c.meta_campaign_id === campaignData.meta_campaign_id)
    );
    if (existingIdx >= 0) {
      localStore.campaigns[existingIdx] = { ...localStore.campaigns[existingIdx], ...record };
    } else {
      localStore.campaigns.unshift(record);
    }
    persistLocalDb();

    if (isLiveFirebase && rtdb) {
      rtdb.ref(`${config.firebase.paths.campaigns}/${id}`).set(record).catch(() => {});
    }

    return record;
  },

  async getCampaigns() {
    ensureLocalDb();
    return localStore.campaigns;
  },

  async updateCampaign(id, updates) {
    const updated_time = new Date().toISOString();
    ensureLocalDb();
    const idx = localStore.campaigns.findIndex((c) => c.id === id || c.meta_campaign_id === id);
    if (idx >= 0) {
      localStore.campaigns[idx] = { ...localStore.campaigns[idx], ...updates, updated_time };
      persistLocalDb();

      if (isLiveFirebase && rtdb) {
        rtdb.ref(`${config.firebase.paths.campaigns}/${localStore.campaigns[idx].id}`).update({ ...updates, updated_time }).catch(() => {});
      }
      return localStore.campaigns[idx];
    }
    return null;
  },

  // ===================== TASKS =====================
  async getTasks(filter = 'All') {
    ensureLocalDb();
    if (filter === 'Pending') return localStore.tasks.filter((t) => t.status === 'Pending');
    if (filter === 'Completed') return localStore.tasks.filter((t) => t.status === 'Completed');
    return localStore.tasks;
  },

  async saveTask(taskData) {
    ensureLocalDb();
    const id = taskData.id || `task_${Date.now()}`;
    const record = {
      id,
      ...taskData,
      status: taskData.status || 'Pending',
      createdAt: new Date().toISOString(),
    };
    localStore.tasks.unshift(record);
    persistLocalDb();

    if (isLiveFirebase && rtdb) {
      rtdb.ref(`tasks/${id}`).set(record).catch(() => {});
    }
    return record;
  },

  async updateTask(id, updates) {
    ensureLocalDb();
    const idx = localStore.tasks.findIndex((t) => t.id === id);
    if (idx >= 0) {
      localStore.tasks[idx] = { ...localStore.tasks[idx], ...updates };
      persistLocalDb();

      if (isLiveFirebase && rtdb) {
        rtdb.ref(`tasks/${id}`).update(updates).catch(() => {});
      }
      return localStore.tasks[idx];
    }
    return null;
  },

  // ===================== TEAM =====================
  async getTeam() {
    ensureLocalDb();
    return localStore.team;
  },

  async saveTeamMember(memberData) {
    ensureLocalDb();
    const id = memberData.id || `user_${Date.now()}`;
    const record = {
      id,
      name: memberData.name,
      email: memberData.email,
      role: memberData.role || 'Sales Executive',
      initial: memberData.name ? memberData.name[0].toUpperCase() : 'U',
      allottedLeadsCount: 0,
      status: 'Active',
    };
    localStore.team.push(record);
    persistLocalDb();

    if (isLiveFirebase && rtdb) {
      rtdb.ref(`team/${id}`).set(record).catch(() => {});
    }
    return record;
  },

  async deleteTeamMember(id) {
    ensureLocalDb();
    const idx = localStore.team.findIndex((m) => m.id === id || m.name === id);
    if (idx >= 0) {
      const removed = localStore.team.splice(idx, 1)[0];
      persistLocalDb();

      if (isLiveFirebase && rtdb) {
        rtdb.ref(`team/${removed.id}`).remove().catch(() => {});
      }
      return true;
    }
    return false;
  },

  // ===================== LOGS =====================
  async logWebhook(payload) {
    const record = {
      id: `log_${Date.now()}_${Math.random().toString(36).substr(2, 6)}`,
      receivedAt: new Date().toISOString(),
      payload,
    };
    ensureLocalDb();
    localStore.webhook_logs.unshift(record);
    if (localStore.webhook_logs.length > 50) localStore.webhook_logs.pop();
    persistLocalDb();

    if (isLiveFirebase && rtdb) {
      rtdb.ref(config.firebase.paths.logs).push(record).catch(() => {});
    }
    return record;
  },

  async getWebhookLogs(limit = 20) {
    ensureLocalDb();
    return localStore.webhook_logs.slice(0, limit);
  },

  // ===================== SETTINGS & DYNAMIC META CONFIG =====================
  async getMetaConfig() {
    ensureLocalDb();
    if (isLiveFirebase && rtdb) {
      try {
        const snapshot = await rtdb.ref('settings/meta_config').once('value');
        const val = snapshot.val();
        if (val) return val;
      } catch (_) {}
    }
    return localStore.settings.meta_config || null;
  },

  async saveMetaConfig(metaConfig) {
    ensureLocalDb();
    const updated = {
      ...metaConfig,
      updated_time: new Date().toISOString(),
    };
    localStore.settings.meta_config = updated;
    persistLocalDb();

    if (isLiveFirebase && rtdb) {
      rtdb.ref('settings/meta_config').set(updated).catch(() => {});
    }
    return updated;
  },
};

module.exports = FirebaseService;
