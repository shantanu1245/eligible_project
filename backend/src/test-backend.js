const axios = require('axios');

const BASE_URL = process.env.TEST_URL || 'http://localhost:5000/api';

async function runTests() {
  console.log('🧪 Starting Eligible CRM Backend Verification Suite...');
  console.log(`🎯 Testing endpoint: ${BASE_URL}\n`);

  let passCount = 0;
  let failCount = 0;

  async function testStep(name, fn) {
    try {
      process.stdout.write(`⏳ Testing: ${name}... `);
      await fn();
      console.log('✅ PASSED');
      passCount++;
    } catch (err) {
      console.log('❌ FAILED');
      console.error(`   Error: ${err.response?.data?.message || err.message}`);
      failCount++;
    }
  }

  // 1. Health Check
  await testStep('1. Health Check (GET /api/health)', async () => {
    const res = await axios.get(`${BASE_URL}/health`);
    if (res.data.status !== 'online') throw new Error('Status not online');
  });

  // 2. Integration Status
  await testStep('2. Integration Status (GET /api/meta/status)', async () => {
    const res = await axios.get(`${BASE_URL}/meta/status`);
    if (!res.data.success || !res.data.data.firebase || !res.data.data.meta) {
      throw new Error('Status response malformed');
    }
  });

  // 3. Webhook Verification Handshake
  await testStep('3. Meta Webhook Verification Handshake (GET /api/webhooks/meta)', async () => {
    const challenge = 'random_challenge_string_998877';
    const res = await axios.get(`${BASE_URL}/webhooks/meta`, {
      params: {
        'hub.mode': 'subscribe',
        'hub.verify_token': 'eligible_crm_secure_verify_token_2026',
        'hub.challenge': challenge,
      },
    });
    if (res.data.toString() !== challenge) {
      throw new Error(`Expected challenge ${challenge}, got ${res.data}`);
    }
  });

  // 4. Webhook Lead Ingestion
  await testStep('4. Meta Webhook Ingestion (POST /api/webhooks/meta)', async () => {
    const payload = {
      object: 'page',
      entry: [
        {
          id: '1092837465',
          time: Math.floor(Date.now() / 1000),
          changes: [
            {
              field: 'leadgen',
              value: {
                created_time: Math.floor(Date.now() / 1000),
                leadgen_id: `test_lead_${Date.now()}`,
                page_id: '1092837465',
                form_id: 'form_pune_luxury_01',
                ad_id: 'ad_fb_001',
              },
            },
          ],
        },
      ],
    };

    const res = await axios.post(`${BASE_URL}/webhooks/meta`, payload);
    if (res.data !== 'EVENT_RECEIVED') {
      throw new Error(`Expected EVENT_RECEIVED, got ${res.data}`);
    }
  });

  // 5. Query Leads Stored
  await testStep('5. Retrieve Leads from Database (GET /api/leads)', async () => {
    const res = await axios.get(`${BASE_URL}/leads`);
    if (!res.data.success || !Array.isArray(res.data.data)) {
      throw new Error('Expected array of leads');
    }
    console.log(` [Found ${res.data.data.length} leads in database]`);
  });

  // 6. Create Meta Ads Campaign
  let createdCampaignId = null;
  await testStep('6. Create Meta Ads Campaign (POST /api/campaigns)', async () => {
    const res = await axios.post(`${BASE_URL}/campaigns`, {
      name: 'Verification Test Campaign 2026',
      dailyBudget: 1500,
      platform: 'Facebook & Instagram',
      targetLocations: ['IN'],
      headline: 'Modern 3 BHK Luxury Residences',
      bodyText: 'Book private tour in Pune. Prime location.',
      status: 'ACTIVE',
    });

    if (!res.data.success || !res.data.data.id) {
      throw new Error('Failed to create campaign');
    }
    createdCampaignId = res.data.data.id;
    console.log(` [Created Campaign ID: ${createdCampaignId}]`);
  });

  // 7. List Campaigns
  await testStep('7. List Campaigns (GET /api/campaigns)', async () => {
    const res = await axios.get(`${BASE_URL}/campaigns`);
    if (!res.data.success || !Array.isArray(res.data.data)) {
      throw new Error('Expected array of campaigns');
    }
  });

  // 8. Sync Leads from Meta Form
  await testStep('8. Manual Sync from Meta Form (POST /api/leads/sync)', async () => {
    const res = await axios.post(`${BASE_URL}/leads/sync`, {
      formId: '102938475601',
    });
    if (!res.data.success) {
      throw new Error('Sync returned failure');
    }
  });

  // 9. Seed All Dummy Data to Firebase
  await testStep('9. Seed Dummy Data to Firebase RTDB (POST /api/seed)', async () => {
    const res = await axios.post(`${BASE_URL}/seed`);
    if (!res.data.success || !res.data.seeded) {
      throw new Error('Seed returned failure');
    }
    console.log(` [Seeded ${res.data.seeded.leads} leads, ${res.data.seeded.campaigns} campaigns, ${res.data.seeded.tasks} tasks, ${res.data.seeded.team} members]`);
  });

  // 10. Tasks Endpoints
  await testStep('10. CRM Tasks (GET & POST /api/tasks)', async () => {
    const getRes = await axios.get(`${BASE_URL}/tasks`);
    if (!getRes.data.success || !Array.isArray(getRes.data.data)) {
      throw new Error('Failed to retrieve tasks');
    }

    const postRes = await axios.post(`${BASE_URL}/tasks`, {
      title: 'Automated Test Task',
      description: 'Verifying task pipeline',
      assignee: 'Amit Patil',
      priority: 'High',
      status: 'Pending',
    });
    if (!postRes.data.success || !postRes.data.data.id) {
      throw new Error('Failed to create task');
    }
  });

  // 11. Team Endpoints
  await testStep('11. Sales Team (GET & POST /api/team)', async () => {
    const getRes = await axios.get(`${BASE_URL}/team`);
    if (!getRes.data.success || !Array.isArray(getRes.data.data)) {
      throw new Error('Failed to retrieve team members');
    }

    const postRes = await axios.post(`${BASE_URL}/team`, {
      name: 'Rohan Mehta',
      email: 'rohan.m@eligiblecrm.com',
      role: 'Sales Executive',
    });
    if (!postRes.data.success || !postRes.data.data.id) {
      throw new Error('Failed to add team member');
    }
  });

  // 12. Dynamic Meta Configuration
  await testStep('12. Dynamic Meta Config (GET & POST /api/meta/config)', async () => {
    const postRes = await axios.post(`${BASE_URL}/meta/config`, {
      accessToken: 'EAAB_test_mock_token_1234567890',
      adAccountId: 'act_9988776655',
      pageId: '1092837465',
      pageName: 'Eligible Properties Pune',
      adAccountName: 'Main Lead Generation Account',
    });
    if (!postRes.data.success) {
      throw new Error('Failed to save dynamic Meta config');
    }

    const getRes = await axios.get(`${BASE_URL}/meta/config`);
    if (!getRes.data.success || !getRes.data.data.config) {
      throw new Error('Failed to retrieve active Meta config');
    }
  });

  // 13. Firebase Notifications & FCM for Admin and Sales Agents
  await testStep('13. Notifications & FCM Alerts (GET, POST & PATCH /api/notifications)', async () => {
    // 13a. Trigger test notification
    const testRes = await axios.post(`${BASE_URL}/notifications/test`, {
      customTitle: 'Ananya Deshmukh',
      customBody: 'VTP Sierra 2BHK Baner • ₹95 Lakhs',
    });
    if (!testRes.data.success) throw new Error('Failed to trigger test notification');

    // 13b. Register FCM token
    const tokenRes = await axios.post(`${BASE_URL}/notifications/register-token`, {
      userId: 'agent_priya',
      token: 'fcm_sample_priya_token_998877',
      role: 'sales_agent',
      name: 'Priya Nair',
    });
    if (!tokenRes.data.success || !tokenRes.data.data.topicSubscribed) {
      throw new Error('Failed to register FCM device token');
    }

    // 13c. Fetch notifications
    const getNotifs = await axios.get(`${BASE_URL}/notifications`);
    if (!getNotifs.data.success || getNotifs.data.count === 0) {
      throw new Error('No notifications returned');
    }

    // 13d. Mark first as read
    const firstNotifId = getNotifs.data.data[0].id;
    const markRes = await axios.patch(`${BASE_URL}/notifications/${firstNotifId}/read`);
    if (!markRes.data.success) throw new Error('Failed to mark notification as read');
  });

  console.log('\n======================================================');
  console.log(`🏁 TEST RESULTS: ${passCount} PASSED, ${failCount} FAILED`);
  console.log('======================================================\n');

  if (failCount > 0) {
    process.exit(1);
  }
}

runTests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
