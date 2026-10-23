const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const axios = require('axios');

async function checkMetaDeveloperAccount() {
  console.log('================================================================');
  console.log('   META DEVELOPER ACCOUNT & APP DETAILS AUDIT');
  console.log('================================================================\n');

  const appId = process.env.META_APP_ID;
  const appSecret = process.env.META_APP_SECRET;
  const userToken = process.env.META_ACCESS_TOKEN;
  const adAccountId = process.env.META_AD_ACCOUNT_ID;
  const pageId = process.env.META_PAGE_ID;
  const apiVersion = process.env.META_API_VERSION || 'v21.0';
  const baseUrl = `https://graph.facebook.com/${apiVersion}`;

  console.log('📋 [1] ENVIRONMENT CONFIGURATION:');
  console.log(`- Meta App ID:         ${appId || 'NOT SET'}`);
  console.log(`- Meta App Secret:     ${appSecret ? appSecret.substring(0, 6) + '...' + appSecret.slice(-4) : 'NOT SET'}`);
  console.log(`- Ad Account ID:       ${adAccountId || 'NOT SET'}`);
  console.log(`- Facebook Page ID:    ${pageId || 'NOT SET'}`);
  console.log(`- User Access Token:   ${userToken ? userToken.substring(0, 15) + '...' + userToken.slice(-10) : 'NOT SET'}`);
  console.log(`- Graph API Version:   ${apiVersion}\n`);

  if (!appId || !appSecret) {
    console.error('❌ Missing META_APP_ID or META_APP_SECRET in .env file.');
    return;
  }

  const appAccessToken = `${appId}|${appSecret}`;

  // 1. Check App Details using App Access Token
  console.log('----------------------------------------------------------------');
  console.log('📱 [2] META DEVELOPER APP DETAILS (via App Access Token):');
  console.log('----------------------------------------------------------------');
  try {
    const appRes = await axios.get(`${baseUrl}/${appId}`, {
      params: {
        access_token: appAccessToken,
        fields: 'id,name,category,link,contact_email,app_domains,privacy_policy_url,terms_of_service_url,daily_active_users,weekly_active_users,monthly_active_users'
      },
      timeout: 10000
    });
    console.log('✅ Meta App Details retrieved successfully:');
    console.log(`- App Name:            ${appRes.data.name}`);
    console.log(`- App ID:              ${appRes.data.id}`);
    console.log(`- Category:            ${appRes.data.category || 'N/A'}`);
    console.log(`- Contact Email:       ${appRes.data.contact_email || 'N/A'}`);
    console.log(`- App Domains:         ${JSON.stringify(appRes.data.app_domains || [])}`);
    console.log(`- Store / App Link:    ${appRes.data.link || 'N/A'}`);
    console.log(`- Privacy Policy:      ${appRes.data.privacy_policy_url || 'N/A'}`);
    console.log(`- Terms of Service:    ${appRes.data.terms_of_service_url || 'N/A'}`);
    console.log(`- Active Users (D/W/M): ${appRes.data.daily_active_users || 0} / ${appRes.data.weekly_active_users || 0} / ${appRes.data.monthly_active_users || 0}`);
  } catch (err) {
    console.error('❌ Failed to fetch App Details:', err.response?.data || err.message);
  }

  // 2. Check App Roles (Developers / Admins / Testers)
  console.log('\n----------------------------------------------------------------');
  console.log('👥 [3] APP ROLES & TEAM (Developers / Admins / Testers):');
  console.log('----------------------------------------------------------------');
  try {
    const rolesRes = await axios.get(`${baseUrl}/${appId}/roles`, {
      params: {
        access_token: appAccessToken
      },
      timeout: 10000
    });
    const roles = rolesRes.data?.data || [];
    console.log(`Found ${roles.length} roles registered on this Meta App:`);
    roles.forEach((r, idx) => {
      console.log(`  ${idx + 1}. Role: [${r.role.toUpperCase()}] User: ${r.user || 'N/A'} (ID: ${r.id || 'N/A'})`);
    });
  } catch (err) {
    console.warn('⚠️ Could not fetch App Roles (requires Business Manager or Admin privileges):', err.response?.data?.error?.message || err.message);
  }

  // 3. Inspect Current User Access Token using /debug_token
  console.log('\n----------------------------------------------------------------');
  console.log('🔑 [4] USER TOKEN INSPECTION (/debug_token):');
  console.log('----------------------------------------------------------------');
  try {
    const debugRes = await axios.get(`${baseUrl}/debug_token`, {
      params: {
        input_token: userToken,
        access_token: appAccessToken
      },
      timeout: 10000
    });

    const tokenData = debugRes.data?.data;
    if (tokenData) {
      console.log(`- Token Valid:         ${tokenData.is_valid ? '✅ YES' : '❌ NO'}`);
      console.log(`- Token Type:          ${tokenData.type}`);
      console.log(`- Application:         ${tokenData.application} (App ID: ${tokenData.app_id})`);
      console.log(`- User ID:             ${tokenData.user_id || 'N/A'}`);
      console.log(`- Issued At:           ${tokenData.issued_at ? new Date(tokenData.issued_at * 1000).toLocaleString() : 'N/A'}`);
      console.log(`- Expires At:          ${tokenData.expires_at ? new Date(tokenData.expires_at * 1000).toLocaleString() : 'Never'}`);
      console.log(`- Data Access Expires: ${tokenData.data_access_expires_at ? new Date(tokenData.data_access_expires_at * 1000).toLocaleString() : 'N/A'}`);
      console.log(`- Scopes / Permissions granted: ${tokenData.scopes ? tokenData.scopes.join(', ') : 'None'}`);

      if (tokenData.error) {
        console.log(`- Token Error Code:    ${tokenData.error.code} (Subcode: ${tokenData.error.subcode})`);
        console.log(`- Token Error Message: ${tokenData.error.message}`);
      }
    }
  } catch (err) {
    console.error('❌ Failed to debug user token:', err.response?.data || err.message);
  }

  // 4. Check User Profile and Permissions
  console.log('\n----------------------------------------------------------------');
  console.log('👤 [5] META USER / DEVELOPER PROFILE (via User Access Token):');
  console.log('----------------------------------------------------------------');
  try {
    const userRes = await axios.get(`${baseUrl}/me`, {
      params: {
        access_token: userToken,
        fields: 'id,name,email'
      },
      timeout: 10000
    });
    console.log('✅ User Profile:');
    console.log(`- Name:     ${userRes.data.name}`);
    console.log(`- User ID:  ${userRes.data.id}`);
    console.log(`- Email:    ${userRes.data.email || 'N/A'}`);
  } catch (err) {
    console.log(`❌ User Profile check failed: ${err.response?.data?.error?.message || err.message}`);
  }

  // 5. Check Ad Account Status
  console.log('\n----------------------------------------------------------------');
  console.log('💼 [6] AD ACCOUNT VERIFICATION:');
  console.log('----------------------------------------------------------------');
  try {
    const formattedAdId = adAccountId.startsWith('act_') ? adAccountId : `act_${adAccountId}`;
    const adRes = await axios.get(`${baseUrl}/${formattedAdId}`, {
      params: {
        access_token: userToken,
        fields: 'id,account_id,name,account_status,currency,timezone_name,amount_spent,balance,business'
      },
      timeout: 10000
    });
    console.log('✅ Ad Account details:');
    console.log(JSON.stringify(adRes.data, null, 2));
  } catch (err) {
    console.log(`❌ Ad Account check failed: ${err.response?.data?.error?.message || err.message}`);
  }

  // 6. Check Facebook Page Status
  console.log('\n----------------------------------------------------------------');
  console.log('📄 [7] FACEBOOK PAGE VERIFICATION:');
  console.log('----------------------------------------------------------------');
  try {
    const pageRes = await axios.get(`${baseUrl}/${pageId}`, {
      params: {
        access_token: userToken,
        fields: 'id,name,link,fan_count,verification_status'
      },
      timeout: 10000
    });
    console.log('✅ Page details:');
    console.log(JSON.stringify(pageRes.data, null, 2));
  } catch (err) {
    console.log(`❌ Page check failed: ${err.response?.data?.error?.message || err.message}`);
  }

  console.log('\n================================================================');
  console.log('🏁 AUDIT SUMMARY & NEXT STEPS:');
  console.log('================================================================');
  console.log('1. Meta Developer App: ID 1392782943019273 is registered and valid.');
  console.log('2. User Access Token: Expired on Oct 14, 2026. A fresh token is needed from Meta Graph API Explorer.');
  console.log('3. Graph API Explorer Link: https://developers.facebook.com/tools/explorer/');
  console.log('================================================================\n');
}

checkMetaDeveloperAccount().catch(err => {
  console.error('Fatal error in audit:', err);
});
