const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const config = {
  port: parseInt(process.env.PORT, 10) || 5000,
  env: process.env.NODE_ENV || 'development',
  clientUrl: process.env.CLIENT_URL || '*',

  firebase: {
    serviceAccountPath: process.env.FIREBASE_SERVICE_ACCOUNT_PATH
      ? path.resolve(__dirname, '../../', process.env.FIREBASE_SERVICE_ACCOUNT_PATH)
      : null,
    databaseURL: process.env.FIREBASE_DATABASE_URL || null,
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY
      ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
      : null,
    paths: {
      leads: process.env.FIREBASE_LEADS_PATH || 'leads',
      campaigns: process.env.FIREBASE_CAMPAIGNS_PATH || 'campaigns',
      logs: process.env.FIREBASE_LOGS_PATH || 'webhook_logs',
      settings: 'settings',
    },
  },

  meta: {
    apiVersion: process.env.META_API_VERSION || 'v21.0',
    appId: process.env.META_APP_ID || '',
    appSecret: process.env.META_APP_SECRET || '',
    accessToken: process.env.META_ACCESS_TOKEN || '',
    adAccountId: process.env.META_AD_ACCOUNT_ID
      ? (process.env.META_AD_ACCOUNT_ID.startsWith('act_')
          ? process.env.META_AD_ACCOUNT_ID
          : `act_${process.env.META_AD_ACCOUNT_ID}`)
      : '',
    pageId: process.env.META_PAGE_ID || '',
    webhookVerifyToken: process.env.META_WEBHOOK_VERIFY_TOKEN || 'eligible_crm_secure_verify_token_2026',
    baseUrl: `https://graph.facebook.com/${process.env.META_API_VERSION || 'v21.0'}`,
  },
};

module.exports = config;
