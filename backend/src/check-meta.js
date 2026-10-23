const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const axios = require('axios');
const metaService = require('./services/metaService');
const firebaseService = require('./services/firebase');

async function checkMetaData() {
  console.log('====================================================');
  console.log('🚀 CHECKING META ADS DATA FROM BACKEND');
  console.log('====================================================\n');

  console.log('📌 CONFIGURATION STATUS:');
  console.log(`- API Version:   ${process.env.META_API_VERSION || 'v21.0'}`);
  console.log(`- App ID:        ${process.env.META_APP_ID}`);
  console.log(`- Ad Account ID: ${process.env.META_AD_ACCOUNT_ID}`);
  console.log(`- Page ID:       ${process.env.META_PAGE_ID}`);
  console.log(`- Token set:     ${Boolean(process.env.META_ACCESS_TOKEN)}`);
  console.log(`- Token preview: ${process.env.META_ACCESS_TOKEN ? process.env.META_ACCESS_TOKEN.substring(0, 15) + '...' : 'None'}\n`);

  // 1. Diagnostics & Token validity
  console.log('----------------------------------------------------');
  console.log('🔍 1. TOKEN & DIAGNOSTICS CHECK:');
  console.log('----------------------------------------------------');
  try {
    const diag = await metaService.getDiagnostics();
    console.log('Diagnostics Result:', JSON.stringify(diag, null, 2));
  } catch (err) {
    console.error('❌ Diagnostics Error:', err.message, err.response?.data || '');
  }

  // 2. Ad Accounts
  console.log('\n----------------------------------------------------');
  console.log('💼 2. ACCESSIBLE AD ACCOUNTS:');
  console.log('----------------------------------------------------');
  try {
    const accounts = await metaService.getAdAccounts();
    console.log(`Found ${accounts ? accounts.length : 0} Ad Accounts:`);
    console.log(JSON.stringify(accounts, null, 2));
  } catch (err) {
    console.error('❌ Ad Accounts Error:', err.message, err.response?.data || '');
  }

  // 3. Campaigns
  console.log('\n----------------------------------------------------');
  console.log('🎯 3. META CAMPAIGNS:');
  console.log('----------------------------------------------------');
  try {
    const campaigns = await metaService.getCampaigns(process.env.META_AD_ACCOUNT_ID, { datePreset: 'maximum' });
    console.log(`Found ${campaigns ? campaigns.length : 0} Campaigns:`);
    console.log(JSON.stringify(campaigns, null, 2));
  } catch (err) {
    console.error('❌ Campaigns Error:', err.message, err.response?.data || '');
  }

  // 4. Ad Sets
  console.log('\n----------------------------------------------------');
  console.log('📁 4. META AD SETS:');
  console.log('----------------------------------------------------');
  try {
    const adSets = await metaService.getAdSets(process.env.META_AD_ACCOUNT_ID, { datePreset: 'maximum' });
    console.log(`Found ${adSets ? adSets.length : 0} Ad Sets:`);
    console.log(JSON.stringify(adSets, null, 2));
  } catch (err) {
    console.error('❌ Ad Sets Error:', err.message, err.response?.data || '');
  }

  // 5. Ads
  console.log('\n----------------------------------------------------');
  console.log('📢 5. META ADS:');
  console.log('----------------------------------------------------');
  try {
    const ads = await metaService.getAds(process.env.META_AD_ACCOUNT_ID, { datePreset: 'maximum' });
    console.log(`Found ${ads ? ads.length : 0} Ads:`);
    console.log(JSON.stringify(ads, null, 2));
  } catch (err) {
    console.error('❌ Ads Error:', err.message, err.response?.data || '');
  }

  // 6. Insights
  console.log('\n----------------------------------------------------');
  console.log('📊 6. META PERFORMANCE INSIGHTS (Last 30 Days):');
  console.log('----------------------------------------------------');
  try {
    const insights = await metaService.getInsights({
      adAccountId: process.env.META_AD_ACCOUNT_ID,
      level: 'account',
      datePreset: 'last_30d',
    });
    console.log('Insights Data:', JSON.stringify(insights, null, 2));
  } catch (err) {
    console.error('❌ Insights Error:', err.message, err.response?.data || '');
  }

  // 7. Lead Forms
  console.log('\n----------------------------------------------------');
  console.log('📝 7. META LEAD FORMS:');
  console.log('----------------------------------------------------');
  try {
    const forms = await metaService.getLeadForms(process.env.META_PAGE_ID);
    console.log(`Found ${forms ? forms.length : 0} Lead Forms:`);
    console.log(JSON.stringify(forms, null, 2));
  } catch (err) {
    console.error('❌ Lead Forms Error:', err.message, err.response?.data || '');
  }

  // 8. Firebase Leads
  console.log('\n----------------------------------------------------');
  console.log('👥 8. STORED LEADS (Firebase RTDB):');
  console.log('----------------------------------------------------');
  try {
    const leads = await firebaseService.getLeads();
    console.log(`Found ${leads ? leads.length : 0} Leads in Database:`);
    if (leads && leads.length > 0) {
      console.log('Sample Leads (up to 5):', JSON.stringify(leads.slice(0, 5), null, 2));
    }
  } catch (err) {
    console.error('❌ Firebase Leads Error:', err.message);
  }

  console.log('\n====================================================');
  console.log('✅ META ADS DATA CHECK COMPLETE');
  console.log('====================================================');
  process.exit(0);
}

checkMetaData().catch((err) => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
